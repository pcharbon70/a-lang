-module(alang_phase5_workflow).
-behaviour(gen_server).

-export([finalize/2, handle_effect/4, snapshot/1, start/1, stop/1]).
-export([handle_call/3, handle_cast/2, handle_info/2, init/1, terminate/2]).

-spec start(map()) -> gen_server:start_ret().
start(Options) -> gen_server:start(?MODULE, Options, []).

-spec handle_effect(pid(), binary(), term(), map()) -> {ok, binary()} | {error, term()}.
handle_effect(Workflow, Operation, Arguments, GatewayContext) ->
    gen_server:call(Workflow, {effect, Operation, Arguments, GatewayContext}, 10000).

-spec finalize(pid(), binary()) -> {ok, map()} | {error, term()}.
finalize(Workflow, ArtifactDigest) ->
    gen_server:call(Workflow, {finalize, ArtifactDigest}, 10000).

-spec snapshot(pid()) -> map().
snapshot(Workflow) -> gen_server:call(Workflow, snapshot, 2000).

-spec stop(pid()) -> ok.
stop(Workflow) -> gen_server:stop(Workflow).

init(Options) ->
    case validate_options(Options) of
        {ok, State} -> {ok, State};
        {error, Reason} -> {stop, Reason}
    end.

handle_call({effect, Operation, Arguments, GatewayContext}, _From, State) ->
    case execute_effect(Operation, Arguments, GatewayContext, State) of
        {ok, Digest, Updated} -> {reply, {ok, Digest}, Updated};
        {error, Reason, Updated} -> {reply, {error, Reason}, Updated}
    end;
handle_call({finalize, ArtifactDigest}, _From, State) ->
    case finalize_session(ArtifactDigest, State) of
        {ok, Evidence, Updated} -> {reply, {ok, Evidence}, Updated};
        {error, Reason, Updated} -> {reply, {error, Reason}, Updated}
    end;
handle_call(snapshot, _From, State) ->
    {reply, maps:with([state, journal, result_digest, checkpoints], State), State};
handle_call(_Request, _From, State) -> {reply, {error, unsupported_workflow_call}, State}.

handle_cast(_Message, State) -> {noreply, State}.
handle_info(_Message, State) -> {noreply, State}.
terminate(_Reason, _State) -> ok.

execute_effect(Operation, Arguments, GatewayContext, State0) ->
    case hook(before_intent, State0) of
        ok ->
            case alang_phase4_effect_registry:decode_abi(Operation, Arguments) of
                {ok, Decoded} -> begin_durable_effect(Decoded, Arguments, GatewayContext, State0);
                {error, Reason} -> {error, Reason, State0}
            end;
        {error, Reason} -> {error, Reason, State0}
    end.

begin_durable_effect(Decoded, Arguments, GatewayContext, State0) ->
    OperationId = maps:get(operation_id, maps:get(arguments, Decoded)),
    SessionId = maps:get(session_id, maps:get(state, State0)),
    TransitionOrdinal = maps:get(next_transition, maps:get(state, State0)),
    {ok, TransitionId} = alang_phase5_journal:transition_id(SessionId, TransitionOrdinal),
    PayloadDigest = workspace_payload_digest(Decoded),
    ArtifactDigest = workspace_artifact_digest(Decoded),
    Recovery = #{
        kind => workspace_write,
        workspace_id => maps:get(workspace_id, maps:get(arguments, Decoded)),
        path_segments => maps:get(path_segments, maps:get(arguments, Decoded)),
        artifact_digest => ArtifactDigest
    },
    Intent = #{
        operation_id => OperationId,
        transition_id => TransitionId,
        operation => maps:get(operation, Decoded),
        payload_digest => PayloadDigest,
        recovery => Recovery
    },
    case alang_phase5_state:begin_effect(maps:get(state, State0), Intent) of
        {ok, IntentState} ->
            IntentPayload = maps:without([recovery], Intent),
            case append_and_checkpoint(effect_intent, IntentPayload, IntentState, State0) of
                {ok, IntentDurable} -> after_intent(Decoded, Arguments, GatewayContext,
                    IntentDurable);
                {error, Reason, Failed} -> {error, Reason, Failed}
            end;
        {error, Reason} -> {error, Reason, State0}
    end.

after_intent(Decoded, Arguments, GatewayContext, State0) ->
    case hook(after_intent_commit, State0) of
        ok -> authorize_effect(Decoded, Arguments, GatewayContext, State0);
        {error, Reason} -> {error, Reason, State0}
    end.

authorize_effect(Decoded, Arguments, GatewayContext, State0) ->
    Broker = maps:get(broker, State0),
    Grant = maps:get(grant, State0),
    Manifest = maps:get(manifest, State0),
    Operation = maps:get(operation, Decoded),
    Context = broker_context(GatewayContext, State0),
    case alang_phase4_broker:authorize(Broker, Grant, Manifest, Operation, Arguments, Context) of
        {ok, Authorization} ->
            OperationId = maps:get(operation_id, maps:get(arguments, Decoded)),
            {ok, AuthorizedState0} = alang_phase5_state:mark_effect(
                maps:get(state, State0), OperationId, authorized, undefined),
            {ok, Description} = alang_phase4_broker:describe_grant(Broker, Grant),
            Remaining = maps:get(Operation, maps:get(remaining_budgets, Description)),
            AuthorizedState = reduce_authority_budget(
                AuthorizedState0, maps:get(grant_id, State0), Operation, Remaining),
            DecisionDigest = stable_digest({Authorization, allowed}),
            Payload = #{
                operation_id => OperationId,
                grant_id => maps:get(grant_id, State0),
                decision => allowed,
                decision_digest => DecisionDigest,
                remaining_budget => Remaining
            },
            case append_and_checkpoint(authorization, Payload, AuthorizedState, State0) of
                {ok, AuthorizedDurable} -> after_authorization(Authorization, Decoded,
                    Context, AuthorizedDurable);
                {error, Reason, Failed} -> {error, Reason, Failed}
            end;
        {error, Reason} -> {error, Reason, State0}
    end.

after_authorization(Authorization, Decoded, Context, State0) ->
    case hook(after_authorization, State0) of
        ok -> submit_effect(Authorization, Decoded, Context, State0);
        {error, Reason} -> {error, Reason, State0}
    end.

submit_effect(Authorization, Decoded, Context, State0) ->
    OperationId = maps:get(operation_id, maps:get(arguments, Decoded)),
    AdapterIdentity = <<"workspace-v1">>,
    {ok, SubmittedState} = alang_phase5_state:mark_effect(
        maps:get(state, State0), OperationId, submitted, AdapterIdentity),
    Payload = #{
        operation_id => OperationId,
        adapter_identity => AdapterIdentity,
        payload_digest => maps:get(payload_digest, maps:get(pending, SubmittedState))
    },
    case append_and_checkpoint(submission, Payload, SubmittedState, State0) of
        {ok, SubmittedDurable} -> after_submission(Authorization, Context, SubmittedDurable);
        {error, Reason, Failed} -> {error, Reason, Failed}
    end.

after_submission(Authorization, Context, State0) ->
    case hook(after_submission, State0) of
        ok -> dispatch_effect(Authorization, Context, State0);
        {error, Reason} -> {error, Reason, State0}
    end.

dispatch_effect(Authorization, Context, State0) ->
    case alang_phase4_broker:dispatch(maps:get(broker, State0), Authorization, Context) of
        {ok, Digest} ->
            case hook(after_mutation, State0#{result_digest := Digest}) of
                ok -> commit_result(Digest, State0#{result_digest := Digest});
                {error, Reason} -> {error, Reason, State0#{result_digest := Digest}}
            end;
        {error, Reason} -> {error, Reason, State0}
    end.

commit_result(Digest, State0) ->
    Pending = maps:get(pending, maps:get(state, State0)),
    Payload = #{
        operation_id => maps:get(operation_id, Pending),
        outcome => succeeded,
        result_digest => Digest
    },
    case append_record(effect_result, Payload, State0) of
        {ok, Record, ResultDurable} ->
            case hook(after_result_commit, ResultDurable) of
                ok -> checkpoint_result(Digest, Record, ResultDurable);
                {error, Reason} -> {error, Reason, ResultDurable}
            end;
        {error, Reason, Failed} -> {error, Reason, Failed}
    end.

checkpoint_result(Digest, ResultRecord, State0) ->
    RecordDigest = maps:get(record_digest, ResultRecord),
    SessionState = maps:get(state, State0),
    {ok, Ack} = alang_phase5_state:result_ack(SessionState, Digest, RecordDigest),
    Budgets = (maps:get(budgets, SessionState))#{<<"workspace.write">> := 0},
    {ok, Advanced} = alang_phase5_state:advance_effect(SessionState, Ack,
        #{<<"stage">> => <<"effect-complete">>, <<"artifact-digest">> => Digest}, Budgets),
    case commit_checkpoint(Advanced, State0) of
        {ok, Checkpointed} ->
            case hook(after_checkpoint, Checkpointed) of
                ok -> {ok, Digest, Checkpointed};
                {error, Reason} -> {error, Reason, Checkpointed}
            end;
        {error, Reason, Failed} -> {error, Reason, Failed}
    end.

finalize_session(ArtifactDigest, State0) ->
    case hook(before_terminal, State0) of
        ok ->
            case alang_phase5_state:complete(maps:get(state, State0), [ArtifactDigest]) of
                {ok, Completed} ->
                    case commit_checkpoint(Completed, State0) of
                        {ok, TerminalDurable} -> append_completion(Completed, ArtifactDigest,
                            TerminalDurable);
                        {error, Reason, Failed} -> {error, Reason, Failed}
                    end;
                {error, Reason} -> {error, Reason, State0}
            end;
        {error, Reason} -> {error, Reason, State0}
    end.

append_completion(Completed, ArtifactDigest, State0) ->
    {ok, StateDigest} = alang_phase5_state:checkpoint_digest(Completed),
    Payload = #{state_digest => StateDigest, evidence_digest => ArtifactDigest},
    case append_record(completion, Payload, State0) of
        {ok, _Record, CompletedState} ->
            case hook(after_terminal, CompletedState) of
                ok ->
                    Ack = maps:get(last_checkpoint_ack, CompletedState),
                    ok = alang_phase5_state:completion_gate(Completed, Ack),
                    {ok, #{
                        state_digest => StateDigest,
                        artifact_digest => ArtifactDigest,
                        journal_head_digest => maps:get(head_digest, maps:get(journal, CompletedState)),
                        journal_records => length(maps:get(records, maps:get(journal, CompletedState)))
                    }, CompletedState};
                {error, Reason} -> {error, Reason, CompletedState}
            end;
        {error, Reason, Failed} -> {error, Reason, Failed}
    end.

append_and_checkpoint(Kind, Payload, SessionState, State0) ->
    case append_record(Kind, Payload, State0#{state := SessionState}) of
        {ok, _Record, Appended} -> commit_checkpoint(SessionState, Appended);
        {error, Reason, Failed} -> {error, Reason, Failed}
    end.

append_record(Kind, Payload, State0) ->
    Journal = maps:get(journal, State0),
    Generation = maps:get(generation, maps:get(state, State0)),
    case alang_phase5_journal:append(
        Journal, Kind, Generation, Payload, erlang:system_time(millisecond))
    of
        {ok, Record, UpdatedJournal} ->
            case alang_phase5_store:append(maps:get(store, State0), Record, deadline(State0)) of
                {ok, _} -> {ok, Record, State0#{journal := UpdatedJournal}};
                {error, Reason} -> {error, Reason, State0}
            end;
        {error, Reason} -> {error, Reason, State0}
    end.

commit_checkpoint(SessionState, State0) ->
    {ok, StateDigest} = alang_phase5_state:checkpoint_digest(SessionState),
    case append_record(checkpoint, #{state_digest => StateDigest}, State0#{state := SessionState}) of
        {ok, _Record, Journaled} ->
            Sequence = maps:get(next_sequence, maps:get(journal, Journaled)),
            case alang_phase5_store:checkpoint(
                maps:get(store, Journaled), SessionState, Sequence, deadline(Journaled))
            of
                {ok, Ack} -> {ok, Journaled#{
                    state := SessionState,
                    last_checkpoint_ack => Ack,
                    checkpoints := maps:get(checkpoints, Journaled) + 1
                }};
                {error, Reason} -> {error, Reason, Journaled}
            end;
        {error, Reason, Failed} -> {error, Reason, Failed}
    end.

validate_options(Options) when is_map(Options) ->
    Required = [store, broker, state, grant, grant_id, manifest, artifact_digest,
        task_id, owner_pid, failure_stage, controller],
    case lists:sort(maps:keys(Options)) =:= lists:sort(Required) andalso
        is_pid(maps:get(store, Options, invalid)) andalso
        is_pid(maps:get(broker, Options, invalid)) andalso
        is_pid(maps:get(owner_pid, Options, invalid)) andalso
        alang_phase5_state:validate(maps:get(state, Options, invalid)) =:= ok
    of
        true ->
            case alang_phase5_store:read(maps:get(store, Options),
                erlang:monotonic_time(millisecond) + 2000) of
                {ok, Snapshot} ->
                    case alang_phase5_journal:validate(
                        maps:get(records, Snapshot), maps:get(session_id, Snapshot))
                    of
                        {ok, Journal} -> {ok, Options#{journal => Journal,
                            result_digest => undefined, checkpoints => 0}};
                        {error, Reason} -> {error, {invalid_journal, Reason}}
                    end;
                {error, Reason} -> {error, Reason}
            end;
        false -> {error, invalid_workflow_options}
    end;
validate_options(_Options) -> {error, invalid_workflow_options}.

broker_context(GatewayContext, State) ->
    maps:merge(alang_phase4_broker:runtime_context(maps:get(broker, State)), #{
        session_id => maps:get(session_id, maps:get(state, State)),
        artifact_digest => maps:get(artifact_digest, State),
        owner_pid => maps:get(owner_pid, State),
        task_id => maps:get(task_id, State),
        presenter_pid => maps:get(requester_pid, GatewayContext),
        request_deadline => maps:get(deadline, GatewayContext),
        cancelled => false,
        correlation_id => maps:get(correlation_id, GatewayContext)
    }).

reduce_authority_budget(State, GrantId, Operation, Remaining) ->
    Authority = maps:get(authority, State),
    Updated = [case Descriptor of
        #{grant_id := GrantId, budgets := Budgets} ->
            Descriptor#{budgets := Budgets#{Operation := Remaining}};
        _ -> Descriptor
    end || Descriptor <- Authority],
    State#{authority := Updated}.

workspace_payload_digest(Decoded) ->
    Arguments = maps:get(arguments, Decoded),
    stable_digest({
        maps:get(workspace_id, Arguments),
        maps:get(path_segments, Arguments),
        maps:get(content, Arguments)
    }).

workspace_artifact_digest(Decoded) ->
    hex(crypto:hash(sha256, maps:get(content, maps:get(arguments, Decoded)))).

hook(Stage, #{failure_stage := Stage, controller := Controller}) when is_pid(Controller) ->
    Controller ! {phase5_workflow_hook, Stage, self()},
    receive
        continue -> ok
    after 60000 -> {error, {injected_timeout, Stage}}
    end;
hook(_Stage, _State) -> ok.

deadline(_State) -> erlang:monotonic_time(millisecond) + 3000.

stable_digest(Term) -> hex(crypto:hash(sha256, term_to_binary(Term, [deterministic]))).

hex(Binary) -> << <<(hex_digit(Nibble))>> || <<Nibble:4>> <= Binary >>.

hex_digit(Nibble) when Nibble < 10 -> $0 + Nibble;
hex_digit(Nibble) -> $a + Nibble - 10.
