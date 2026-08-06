-module(alang_fidelity_runtime).
-behaviour(gen_server).

-export([run/2, snapshot/1, start/3, stop/1]).
-export([handle_call/3, handle_cast/2, handle_info/2, init/1, terminate/2]).

-define(CALL_TIMEOUT, 15000).

-spec start(binary(), map(), map()) -> {ok, map()} | {error, term()}.
start(Beam, Expected, Options) ->
    case alang_fidelity_artifact_v2:inspect(Beam, Expected) of
        {ok, Inspection} ->
            Metadata = maps:get(metadata, Inspection),
            case validate_options(Options, Metadata) of
                {ok, Config} ->
                    case gen_server:start(?MODULE, {Inspection, Config}, []) of
                        {ok, Runtime} ->
                            Context = gen_server:call(Runtime, context, ?CALL_TIMEOUT),
                            {ok, #{
                                format => alang_fidelity_runtime_handle_v1,
                                runtime => Runtime,
                                beam => Beam,
                                metadata => Metadata,
                                inspection => Inspection,
                                context => Context
                            }};
                        {error, _} = Error -> Error
                    end;
                {error, _} = Error -> Error
            end;
        {error, _} = Error -> Error
    end.

-spec run(map(), map()) -> {ok, map()} | {error, term()}.
run(#{format := alang_fidelity_runtime_handle_v1, beam := Beam,
        metadata := Metadata, context := Context}, Inputs) when is_map(Inputs) ->
    case alang_fidelity_artifact_v2:load(Beam, Metadata) of
        {ok, Module, _Inspection} ->
            Result = try Module:execute(maps:get(task_id, Metadata), Inputs, Context) of
                Value -> Value
            catch
                Class:Reason -> {error, {generated_execution_exception, Class, Reason}}
            end,
            case alang_fidelity_artifact_v2:purge() of
                ok -> Result;
                {error, PurgeReason} -> {error, {artifact_purge_failed, PurgeReason}}
            end;
        {error, _} = Error -> Error
    end;
run(_Handle, _Inputs) -> {error, invalid_runtime_handle}.

-spec snapshot(map()) -> map().
snapshot(#{format := alang_fidelity_runtime_handle_v1, runtime := Runtime}) ->
    gen_server:call(Runtime, snapshot, ?CALL_TIMEOUT).

-spec stop(map()) -> ok.
stop(#{format := alang_fidelity_runtime_handle_v1, runtime := Runtime}) ->
    gen_server:stop(Runtime).

init({Inspection, Options}) ->
    process_flag(trap_exit, true),
    Metadata = maps:get(metadata, Inspection),
    initialize_runtime(Inspection, Metadata, Options).

initialize_runtime(Inspection, Metadata, Config) ->
    RuntimeDeadline = erlang:monotonic_time(millisecond) +
        maps:get(timeout_ms, maps:get(task_limits, Metadata)),
    BoundConfig = Config#{runtime_deadline => RuntimeDeadline},
    case start_broker(Metadata, BoundConfig) of
        {ok, Broker} ->
            case issue_parent_grant(Broker, Metadata, Inspection, BoundConfig) of
                {ok, Grant, GrantId} ->
                    case alang_phase6_child_sup:start_link() of
                        {ok, ChildSupervisor} ->
                            case start_workflow(Broker, Grant, GrantId,
                                    Metadata, Inspection, BoundConfig) of
                                {ok, Store, Workflow, Workspace} ->
                                    BindingDigest = digest({
                                        maps:get(metadata_sha256, Inspection),
                                        maps:get(bindings, BoundConfig),
                                        maps:get(session_id, BoundConfig)
                                    }),
                                    Context = #{
                                        format => alang_fidelity_runtime_context_v1,
                                        runtime => self(),
                                        binding_digest => BindingDigest
                                    },
                                    {ok, #{
                                        inspection => Inspection,
                                        metadata => Metadata,
                                        config => BoundConfig,
                                        broker => Broker,
                                        grant => Grant,
                                        grant_id => GrantId,
                                        child_supervisor => ChildSupervisor,
                                        store => Store,
                                        workflow => Workflow,
                                        workspace => Workspace,
                                        context => Context,
                                        binding_digest => BindingDigest,
                                        token => none,
                                        execution_owner => none,
                                        next_step => 0,
                                        results => #{},
                                        last_output => none,
                                        repair => none,
                                        deadline => RuntimeDeadline,
                                        remaining => maps:get(task_limits, Metadata),
                                        counters => zero_counters(),
                                        trace => [],
                                        witness => none,
                                        journal_result => none,
                                        status => ready
                                    }};
                                {error, Reason} ->
                                    alang_phase6_child_sup:stop(ChildSupervisor),
                                    gen_server:stop(Broker),
                                    {stop, Reason}
                            end;
                        {error, Reason} ->
                            gen_server:stop(Broker),
                            {stop, {child_supervisor_start_failed, Reason}}
                    end;
                {error, Reason} ->
                    gen_server:stop(Broker),
                    {stop, Reason}
            end;
        {error, Reason} -> {stop, Reason}
    end.

handle_call(context, _From, State) ->
    {reply, maps:get(context, State), State};
handle_call(snapshot, _From, State) ->
    {reply, runtime_snapshot(State), State};
handle_call({abi, BindingDigest, Request}, {Caller, _Tag}, State) ->
    case BindingDigest =:= maps:get(binding_digest, State) of
        false -> {reply, {error, runtime_binding_mismatch}, State};
        true ->
            {Reply, Updated} = handle_abi(Request, Caller, State),
            {reply, Reply, Updated}
    end;
handle_call(_Request, _From, State) ->
    {reply, {error, unsupported_runtime_call}, State}.

handle_cast(_Message, State) -> {noreply, State}.
handle_info(_Message, State) -> {noreply, State}.

terminate(_Reason, State) ->
    safe_stop_workflow(maps:get(workflow, State, none)),
    safe_stop_store(maps:get(store, State, none)),
    safe_stop_child_sup(maps:get(child_supervisor, State, none)),
    safe_stop_broker(maps:get(broker, State, none)),
    ok.

handle_abi({begin_task, TaskId, Inputs}, Caller, #{status := ready} = State) ->
    Metadata = maps:get(metadata, State),
    case {TaskId =:= maps:get(task_id, Metadata), validate_inputs(Inputs, Metadata)} of
        {true, ok} ->
            Token = make_ref(),
            Updated = State#{
                token := Token,
                execution_owner := Caller,
                inputs => Inputs,
                status := running,
                trace := [event(begin_task, #{task_id => TaskId})]
            },
            {{ok, Token}, Updated};
        {false, _} -> {{error, task_identity_mismatch}, State};
        {_, {error, Reason}} -> {{error, Reason}, State}
    end;
handle_abi({begin_task, _TaskId, _Inputs}, _Caller, State) ->
    {{error, task_already_started}, State};
handle_abi({effect, Token, Ordinal, ActionId, Operation, Dependencies}, Caller, State) ->
    execute_effect(effect_request, Token, Ordinal, ActionId, Operation,
        Dependencies, Caller, State);
handle_abi({delegate, Token, Ordinal, ActionId, Operation, Dependencies}, Caller, State) ->
    execute_effect(delegate, Token, Ordinal, ActionId, Operation,
        Dependencies, Caller, State);
handle_abi({complete, Token, ActionId, Completion, TerminalClass}, Caller, State) ->
    execute_completion(Token, ActionId, Completion, TerminalClass, Caller, State);
handle_abi(_Request, _Caller, State) ->
    {{error, invalid_runtime_abi_request}, State}.

execute_effect(Kind, Token, Ordinal, ActionId, Operation, Dependencies, Caller, State) ->
    Expected = next_plan(State),
    Supplied = #{kind => Kind, effect_ordinal => Ordinal, action_id => ActionId,
        operation => Operation, dependencies => Dependencies},
    case preflight_step(Token, Caller, Expected, Supplied, State) of
        ok ->
            case injected_pre_effect_failure(Operation, State) of
                none ->
                    case reserve_effect(Operation, State) of
                        {ok, Reserved} ->
                            execute_reserved_effect(Expected, Reserved);
                        {error, Reason} ->
                            {{error, Reason}, fail_state(Reason, State)}
                    end;
                Reason -> {{error, Reason}, fail_state(Reason, State)}
            end;
        {error, Reason} -> {{error, Reason}, fail_state(Reason, State)}
    end.

execute_reserved_effect(#{operation := <<"model.generate">>} = Step, State) ->
    execute_model_generate(Step, State);
execute_reserved_effect(#{operation := <<"model.repair">>} = Step, State) ->
    execute_model_repair(Step, State);
execute_reserved_effect(#{operation := <<"workspace.write">>} = Step, State) ->
    execute_workspace(Step, State);
execute_reserved_effect(#{operation := <<"child.run">>} = Step, State) ->
    execute_child(Step, State).

execute_model_generate(Step, State) ->
    Request = original_model_request(Step, State),
    Fixture = response_fixture(maps:get(action_id, Step), State),
    case invoke_parent_model(Request, Fixture, State) of
        {ok, #{status := success, output := Output}, Updated} ->
            finish_step(Step, {model, success, digest_binary(Output)}, Output, Updated);
        {ok, #{status := Status} = Failure, Updated} when
                Status =:= invalid_syntax; Status =:= schema_failure ->
            RepairLimit = maps:get(repair_calls, maps:get(task_limits,
                maps:get(metadata, State))),
            {ok, Repair0} = alang_phase6_repair:new(Request, RepairLimit),
            Gate = #{consequential_effects => false, cancelled => false, authorized => true},
            case alang_phase6_repair:plan(Repair0, Failure, Gate) of
                {ok, RepairRequest, RepairState} ->
                    Diagnostic = maps:get(diagnostic, Failure),
                    StableFailure = maps:with([code, fragment, offset], Diagnostic),
                    finish_step(Step, {model, Status, digest(StableFailure)},
                        none, Updated#{repair := #{request => RepairRequest,
                            state => RepairState}});
                {terminal, Reason, _} ->
                    {{error, Reason}, fail_state(Reason, Updated)}
            end;
        {ok, #{status := Status}, Updated} ->
            {{error, Status}, fail_state(Status, Updated)};
        {error, Reason, Updated} ->
            {{error, Reason}, fail_state(Reason, Updated)}
    end.

execute_model_repair(Step, #{repair := #{request := Request,
        state := RepairState}} = State) ->
    Fixture = response_fixture(maps:get(action_id, Step), State),
    case invoke_parent_model(Request, Fixture, State) of
        {ok, Result, Updated} ->
            case alang_phase6_repair:record_response(RepairState, Request, Result) of
                {ok, Recorded} ->
                    case maps:get(status, Result) of
                        success -> finish_step(Step,
                            {repair, accepted, digest_binary(maps:get(output, Result))},
                            maps:get(output, Result), Updated#{repair := Recorded});
                        _ ->
                            {{error, repair_failed}, fail_state(repair_failed,
                                Updated#{repair := Recorded})}
                    end;
                {error, Reason} -> {{error, Reason}, fail_state(Reason, Updated)}
            end;
        {error, Reason, Updated} -> {{error, Reason}, fail_state(Reason, Updated)}
    end;
execute_model_repair(_Step, State) ->
    {{error, repair_without_failure}, fail_state(repair_without_failure, State)}.

execute_workspace(Step, #{last_output := Output, workflow := Workflow} = State)
        when is_binary(Output), is_pid(Workflow) ->
    Metadata = maps:get(metadata, State),
    {Logical, WorkspaceBinding} = only_workspace(State),
    _ = Logical,
    Relative = artifact_relative_path(Metadata),
    OperationId = operation_id(Step, State),
    Arguments = {alang_data_v1, product, {
        maps:get(workspace_id, WorkspaceBinding), Relative, Output, OperationId
    }},
    GatewayContext = #{
        requester_pid => self(),
        deadline => maps:get(deadline, State),
        correlation_id => correlation_id(OperationId)
    },
    ok = maybe_inject_workspace_fault(State),
    case alang_phase5_workflow:handle_effect(
            Workflow, <<"workspace.write">>, Arguments, GatewayContext) of
        {ok, ResultDigest} ->
            Journal = #{
                format => alang_workspace_result_evidence_v1,
                operation_id => OperationId,
                operation => <<"workspace.write">>,
                relative_path => Relative,
                artifact_digest => digest_binary(Output),
                result_digest => ResultDigest,
                outcome => succeeded
            },
            finish_step(Step, {workspace, succeeded, ResultDigest}, Output,
                State#{journal_result := Journal,
                    journal_action_id => maps:get(action_id, Step)});
        {error, Reason} -> {{error, normalize_effect_error(Reason)},
            fail_state(normalize_effect_error(Reason), State)}
    end;
execute_workspace(_Step, State) ->
    {{error, missing_workspace_content}, fail_state(missing_workspace_content, State)}.

execute_child(Step, #{last_output := ParentOutput} = State) when is_binary(ParentOutput) ->
    Metadata = maps:get(metadata, State),
    Child = maps:get(child, Metadata),
    case Child of
        none -> {{error, missing_child_descriptor}, fail_state(missing_child_descriptor, State)};
        _ ->
            Fixture = response_fixture(maps:get(action_id, Step), State),
            Spec = child_spec(Step, ParentOutput, State),
            Restriction = child_restriction(Child, State),
            Handler = child_handler(Fixture, State),
            case alang_phase6_child:start(maps:get(child_supervisor, State),
                    maps:get(broker, State), maps:get(grant, State),
                    Spec, Restriction, Handler) of
                {ok, Handle} ->
                    Wait = max(0, maps:get(deadline, State) -
                        erlang:monotonic_time(millisecond)),
                    case alang_phase6_child:await(Handle, Wait) of
                        {ok, #{status := complete, output := Output} = Result} ->
                            finish_step(Step, {child, complete, digest(Result)}, Output, State);
                        {ok, #{reason := Reason}} ->
                            {{error, Reason}, fail_state(Reason, State)};
                        {error, Reason} ->
                            {{error, Reason}, fail_state(Reason, State)}
                    end;
                {error, Reason} -> {{error, Reason}, fail_state(Reason, State)}
            end
    end;
execute_child(_Step, State) ->
    {{error, missing_child_input}, fail_state(missing_child_input, State)}.

execute_completion(Token, ActionId, Completion, TerminalClass, Caller, State) ->
    Expected = next_plan(State),
    Supplied = #{kind => complete, action_id => ActionId,
        dependencies => maps:get(dependencies, Expected, [])},
    case preflight_step(Token, Caller, Expected, Supplied, State) of
        ok ->
            Metadata = maps:get(metadata, State),
            case {Completion =:= maps:get(completion, Metadata),
                    TerminalClass =:= maps:get(terminal_class, Metadata),
                    reserve_counter(steps, 1, State)} of
                {true, true, {ok, Reserved}} -> finalize_completion(Expected, Reserved);
                {false, _, _} ->
                    {{error, completion_metadata_mismatch},
                        fail_state(completion_metadata_mismatch, State)};
                {_, false, _} ->
                    {{error, terminal_class_mismatch},
                        fail_state(terminal_class_mismatch, State)};
                {_, _, {error, Reason}} -> {{error, Reason}, fail_state(Reason, State)}
            end;
        {error, Reason} -> {{error, Reason}, fail_state(Reason, State)}
    end.

finalize_completion(Step, State) ->
    Metadata = maps:get(metadata, State),
    case durable_finalize(State) of
        {ok, Durable, Updated} ->
            Evidence = completion_evidence(Durable, Updated),
            case alang_fidelity_completion:verify(Metadata, Evidence) of
                {ok, Witness} ->
                    Result = #{node_id => maps:get(node_id, Step), status =>
                        maps:get(status, Witness), digest => maps:get(witness_digest, Witness)},
                    Final = advance_step(Step, Result, Updated#{witness := Witness,
                        status := maps:get(status, Witness)}),
                    {{ok, Witness}, Final};
                {error, Reason} -> {{error, Reason}, fail_state(Reason, Updated)}
            end;
        {error, Reason, Updated} -> {{error, Reason}, fail_state(Reason, Updated)}
    end.

durable_finalize(#{workflow := none} = State) -> {ok, none, State};
durable_finalize(#{workflow := Workflow, last_output := Output} = State)
        when is_pid(Workflow), is_binary(Output) ->
    ArtifactDigest = digest_binary(Output),
    case alang_phase5_workflow:finalize(Workflow, ArtifactDigest) of
        {ok, Durable} -> {ok, Durable, State};
        {error, Reason} -> {error, normalize_effect_error(Reason), State}
    end;
durable_finalize(State) -> {error, missing_durable_artifact, State}.

completion_evidence(_Durable, #{workspace := none, metadata := Metadata}) ->
    Clarifications = [maps:get(target, Predicate) || Predicate <-
        maps:get(predicates, maps:get(completion, Metadata)),
        maps:get(kind, Predicate) =:= <<"clarification-recorded">>],
    #{
        format => alang_fidelity_completion_evidence_v1,
        workspace_root => [],
        relative_path => <<>>,
        artifact_digest => none,
        artifact_bytes => none,
        journal_result => none,
        journal_action_id => <<>>,
        clarifications => Clarifications
    };
completion_evidence(_Durable, #{workspace := Workspace, last_output := Output} = State) ->
    ArtifactDigest = case test_fault(State) of
        wrong_digest ->
            <<"0000000000000000000000000000000000000000000000000000000000000000">>;
        _ -> digest_binary(Output)
    end,
    #{
        format => alang_fidelity_completion_evidence_v1,
        workspace_root => binary_to_list(maps:get(root, Workspace)),
        relative_path => artifact_relative_path(maps:get(metadata, State)),
        artifact_digest => ArtifactDigest,
        artifact_bytes => byte_size(Output),
        journal_result => maps:get(journal_result, State),
        journal_action_id => maps:get(journal_action_id, State),
        clarifications => []
    }.

preflight_step(Token, Caller, Expected, Supplied, State) ->
    case {
        maps:get(status, State) =:= running,
        Token =:= maps:get(token, State),
        Caller =:= maps:get(execution_owner, State),
        erlang:monotonic_time(millisecond) < maps:get(deadline, State),
        supplied_matches(Expected, Supplied),
        dependencies_satisfied(maps:get(dependencies, Expected), State)
    } of
        {true, true, true, true, true, true} -> ok;
        {false, _, _, _, _, _} -> {error, runtime_not_running};
        {_, false, _, _, _, _} -> {error, invalid_runtime_token};
        {_, _, false, _, _, _} -> {error, execution_owner_mismatch};
        {_, _, _, false, _, _} -> {error, deadline_exhausted};
        {_, _, _, _, false, _} -> {error, execution_plan_mismatch};
        {_, _, _, _, _, false} -> {error, unsatisfied_dependency}
    end.

supplied_matches(Expected, Supplied) ->
    maps:with(maps:keys(Supplied), Expected) =:= Supplied.

dependencies_satisfied(Dependencies, State) ->
    Results = maps:get(results, State),
    lists:all(fun(Dependency) -> maps:is_key(Dependency, Results) end, Dependencies).

next_plan(State) ->
    lists:nth(maps:get(next_step, State) + 1,
        maps:get(execution_plan, maps:get(metadata, State))).

reserve_effect(Operation, State) ->
    Reservations = case Operation of
        <<"model.generate">> -> [{steps, 1}, {model_calls, 1}];
        <<"model.repair">> -> [{steps, 1}, {model_calls, 1}, {repair_calls, 1}];
        <<"workspace.write">> -> [{steps, 1}, {workspace_writes, 1}];
        <<"child.run">> ->
            Child = maps:get(child, maps:get(metadata, State)),
            ChildModels = maps:get(model_calls, maps:get(limits, Child)),
            [{steps, 1}, {child_calls, 1}, {model_calls, ChildModels}]
    end,
    reserve_counters(Reservations, State).

reserve_counters([], State) -> {ok, State};
reserve_counters([{Key, Amount} | Rest], State) ->
    case reserve_counter(Key, Amount, State) of
        {ok, Updated} -> reserve_counters(Rest, Updated);
        {error, _} = Error -> Error
    end.

reserve_counter(Key, Amount, State) ->
    Remaining = maps:get(remaining, State),
    Value = maps:get(Key, Remaining),
    case Value >= Amount of
        true ->
            Counters = maps:get(counters, State),
            {ok, State#{
                remaining := Remaining#{Key := Value - Amount},
                counters := Counters#{Key := maps:get(Key, Counters) + Amount}
            }};
        false -> {error, {budget_exhausted, Key}}
    end.

finish_step(Step, Evidence, Output, State) ->
    Result = #{node_id => maps:get(node_id, Step), status => succeeded,
        digest => digest(Evidence)},
    case output_state(Output, State) of
        {ok, Updated0} ->
            Updated = advance_step(Step, Result, Updated0),
            {{ok, maps:get(digest, Result)}, Updated};
        {error, Reason} -> {{error, Reason}, fail_state(Reason, State)}
    end.

output_state(none, State) -> {ok, State};
output_state(Binary, State) when is_binary(Binary) -> record_output(Binary, State).

record_output(Binary, State) ->
    Limit = maps:get(output_bytes, maps:get(task_limits, maps:get(metadata, State))),
    Bytes = byte_size(Binary),
    case Bytes =< Limit of
        true ->
            Remaining = maps:get(remaining, State),
            Counters = maps:get(counters, State),
            {ok, State#{last_output := Binary,
                remaining := Remaining#{output_bytes := Limit - Bytes},
                counters := Counters#{output_bytes := Bytes}}};
        false -> {error, output_limit_exceeded}
    end.

advance_step(Step, Result, State) ->
    Results = maps:get(results, State),
    Trace = maps:get(trace, State),
    State#{
        next_step := maps:get(next_step, State) + 1,
        results := Results#{maps:get(node_id, Step) => Result},
        trace := Trace ++ [event(maps:get(kind, Step), #{
            action_id => maps:get(action_id, Step),
            node_id => maps:get(node_id, Step),
            result_digest => maps:get(digest, Result)
        })]
    }.

invoke_parent_model(Request, Fixture, State) ->
    invoke_model(Request, Fixture, maps:get(grant, State), parent_binding(State), State).

invoke_model(Request, Fixture, Grant, Binding, State) ->
    Broker = maps:get(broker, State),
    Profile = maps:get(profile, Request),
    OperationId = maps:get(operation_id, Request),
    ModelId = case test_fault(State) of
        denied_scope -> <<"undeclared-model">>;
        _ -> maps:get(model, Profile)
    end,
    Arguments = {alang_data_v1, product, {
        ModelId, maps:get(instruction, Request),
        maps:get(max_bytes, maps:get(output_schema, Request)), OperationId
    }},
    Context = broker_context(Broker, Binding, maps:get(deadline, State), OperationId),
    Manifest = runtime_manifest([<<"model.complete">>]),
    case alang_phase4_broker:authorize(Broker, Grant, Manifest,
            <<"model.complete">>, Arguments, Context) of
        {ok, Authorization} ->
            case run_mock(Request, Fixture, maps:get(deadline, State)) of
                {ok, Result} ->
                    Outcome = case maps:get(status, Result) of success -> succeeded; _ -> failed end,
                    ok = alang_phase4_broker:complete(Broker, Authorization, Outcome),
                    {ok, Result, State};
                {error, Reason} ->
                    _ = alang_phase4_broker:complete(Broker, Authorization, failed),
                    {error, Reason, State}
            end;
        {error, Reason} -> {error, normalize_effect_error(Reason), State}
    end.

run_mock(Request, Fixture, Deadline) ->
    {ok, RequestDigest} = alang_phase6_model_protocol:request_digest(Request),
    Options = #{profiles => [maps:get(profile, Request)],
        fixtures => #{RequestDigest => Fixture}, max_calls => 1},
    case alang_phase6_mock_model:start_link(Options) of
        {ok, Mock} ->
            try alang_phase6_mock_model:complete(Mock, Request, Deadline)
            after alang_phase6_mock_model:stop(Mock) end;
        {error, Reason} -> {error, {mock_model_start_failed, Reason}}
    end.

original_model_request(Step, State) ->
    Profile = selected_profile(State),
    OperationId = operation_id(Step, State),
    Inputs = maps:get(inputs, State),
    ContextContent = bounded_prompt(io_lib:format("~tp", [Inputs])),
    Fragment = #{
        format => alang_context_fragment_v1,
        id => <<"task-inputs">>,
        visibility => task_local,
        provenance => digest(Inputs),
        trust => data_only,
        content => ContextContent
    },
    Instruction = bounded_prompt(io_lib:format(
        "task=~s action=~s operation=~s; produce the declared artifact content",
        [maps:get(task_id, maps:get(metadata, State)), maps:get(action_id, Step),
            maps:get(operation, Step)])),
    {ok, Request} = alang_phase6_model_protocol:new_request(#{
        operation_id => OperationId,
        profile => Profile,
        context => [Fragment],
        instruction => Instruction,
        output_schema => #{format => alang_output_schema_v1,
            id => markdown_draft_v1,
            max_bytes => maps:get(output_bytes,
                maps:get(task_limits, maps:get(metadata, State))),
            required_sections => [<<"Findings">>]},
        deadline => maps:get(deadline, State),
        retry_class => repair_only,
        redaction_policy => #{format => alang_redaction_policy_v1,
            trace_content => digest_only, retain_provider_fields => []},
        provenance => #{format => alang_model_provenance_v1,
            task_id => maps:get(task_id, maps:get(metadata, State)),
            goal_digest => maps:get(semantic_sha256, maps:get(metadata, State)),
            parent_call_id => none}
    }),
    Request.

child_handler(Fixture, State) ->
    Broker = maps:get(broker, State),
    Deadline = maps:get(deadline, State),
    Metadata = maps:get(metadata, State),
    fun(Spec, ChildGrant, ChildContext) ->
        Profile = selected_profile(State),
        OperationId = child_operation_id(Spec, Metadata),
        Content = maps:get(source_draft, maps:get(input, Spec)),
        Fragment = #{format => alang_context_fragment_v1, id => <<"parent-draft">>,
            visibility => task_local, provenance => digest(Content), trust => data_only,
            content => Content},
        {ok, Request} = alang_phase6_model_protocol:new_request(#{
            operation_id => OperationId,
            profile => Profile,
            context => [Fragment],
            instruction => <<"Produce the attenuated child artifact. Do not widen authority.">>,
            output_schema => maps:get(output_schema, Spec),
            deadline => Deadline,
            retry_class => none,
            redaction_policy => #{format => alang_redaction_policy_v1,
                trace_content => digest_only, retain_provider_fields => []},
            provenance => #{format => alang_model_provenance_v1,
                task_id => maps:get(child_task_id, Spec),
                goal_digest => maps:get(semantic_sha256, Metadata),
                parent_call_id => none}
        }),
        Binding = maps:with([owner_pid, session_id, artifact_digest, task_id], ChildContext),
        Arguments = {alang_data_v1, product, {maps:get(model, Profile),
            maps:get(instruction, Request), maps:get(max_bytes,
                maps:get(output_schema, Request)), OperationId}},
        Context = broker_context(Broker, Binding, Deadline, OperationId),
        case alang_phase4_broker:authorize(Broker, ChildGrant,
                runtime_manifest([<<"model.complete">>]), <<"model.complete">>,
                Arguments, Context) of
            {ok, Authorization} ->
                Result = run_mock(Request, Fixture, Deadline),
                case Result of
                    {ok, #{status := success, output := Output}} ->
                        ok = alang_phase4_broker:complete(Broker, Authorization, succeeded),
                        #{format => alang_child_result_v1, status => complete,
                            output => Output, evidence_digest => digest_binary(Output)};
                    _ ->
                        _ = alang_phase4_broker:complete(Broker, Authorization, failed),
                        #{format => alang_child_result_v1, status => failed,
                            reason => model_failure}
                end;
            {error, _} -> #{format => alang_child_result_v1, status => failed,
                reason => model_failure}
        end
    end.

child_spec(Step, ParentOutput, State) ->
    Metadata = maps:get(metadata, State),
    Child = maps:get(child, Metadata),
    MaxBytes = maps:get(output_bytes, maps:get(limits, Child)),
    ChildTaskId = child_task_id(Metadata),
    #{
        format => alang_child_spec_v1,
        parent_task_id => maps:get(task_id, Metadata),
        child_task_id => ChildTaskId,
        session_id => child_session_id(State),
        artifact_digest => maps:get(beam_sha256, maps:get(inspection, State)),
        deadline => maps:get(deadline, State),
        input => #{topic => maps:get(action_id, Step), source_draft => ParentOutput},
        output_schema => #{format => alang_output_schema_v1, id => markdown_draft_v1,
            max_bytes => MaxBytes, required_sections => [<<"Findings">>]},
        completion_predicate => #{format => alang_child_completion_v1,
            required_section => <<"Findings">>, minimum_bytes => 1},
        capability_summary => #{operations => [<<"model.complete">>],
            constraints => [<<"source-declared-attenuation">>]}
    }.

child_restriction(Child, State) ->
    Profile = selected_profile(State),
    #{
        invocations => [#{operation => <<"model.complete">>,
            model_id => maps:get(model, Profile)}],
        budgets => #{<<"model.complete">> =>
            maps:get(model_calls, maps:get(limits, Child))},
        deadline => maps:get(deadline, State)
    }.

selected_profile(State) ->
    Models = maps:get(models, maps:get(bindings, maps:get(config, State))),
    [{_Logical, Binding} | _] = lists:sort(maps:to_list(Models)),
    maps:get(profile, Binding).

response_fixture(ActionId, State) ->
    maps:get(ActionId, maps:get(responses, maps:get(config, State)),
        #{status => permanent}).

validate_options(Options, Metadata) when is_map(Options) ->
    Keys = [format, session_id, bindings, responses, store_root, test_mode, test_fault],
    case lists:sort(maps:keys(Options)) =:= lists:sort(Keys) andalso
            maps:get(format, Options, invalid) =:= alang_fidelity_runtime_options_v1 andalso
            valid_id(maps:get(session_id, Options, invalid)) andalso
            is_map(maps:get(responses, Options, invalid)) andalso
            is_list(maps:get(store_root, Options, invalid)) andalso
            filename:pathtype(maps:get(store_root, Options, invalid)) =:= absolute andalso
            is_boolean(maps:get(test_mode, Options, invalid)) andalso
            valid_test_fault(maps:get(test_fault, Options, invalid),
                maps:get(test_mode, Options, false)) of
        true -> validate_bindings(Options, Metadata);
        false -> {error, invalid_fidelity_runtime_options}
    end;
validate_options(_Options, _Metadata) -> {error, invalid_fidelity_runtime_options}.

validate_bindings(Options, Metadata) ->
    Bindings = maps:get(bindings, Options),
    case lists:sort(maps:keys(Bindings)) =:= [models, workspaces] of
        false -> {error, invalid_operator_bindings};
        true ->
            Models = maps:get(models, Bindings),
            Workspaces = maps:get(workspaces, Bindings),
            Resources = maps:get(resources, maps:get(manifest, Metadata)),
            case lists:sort(maps:keys(Models)) =:= maps:get(models, Resources) andalso
                    lists:sort(maps:keys(Workspaces)) =:= maps:get(workspaces, Resources) andalso
                    map_size(Workspaces) =< 1 andalso valid_model_bindings(Models) andalso
                    valid_workspace_bindings(Workspaces) andalso
                    valid_responses(maps:get(responses, Options),
                        maps:get(execution_plan, Metadata)) of
                true -> {ok, Options};
                false -> {error, operator_binding_mismatch}
            end
    end.

valid_model_bindings(Models) when is_map(Models) ->
    lists:all(fun({_Logical, Binding}) ->
        is_map(Binding) andalso lists:sort(maps:keys(Binding)) =:= [model_id, profile] andalso
            valid_id(maps:get(model_id, Binding)) andalso
            alang_phase6_model_protocol:validate_profile(maps:get(profile, Binding)) =:= ok andalso
            maps:get(provider_class, maps:get(profile, Binding)) =:= mock andalso
            maps:get(model, maps:get(profile, Binding)) =:= maps:get(model_id, Binding)
    end, maps:to_list(Models));
valid_model_bindings(_) -> false.

valid_workspace_bindings(Workspaces) when is_map(Workspaces) ->
    lists:all(fun({_Logical, Binding}) ->
        is_map(Binding) andalso lists:sort(maps:keys(Binding)) =:= [root, workspace_id] andalso
            valid_id(maps:get(workspace_id, Binding)) andalso
            is_binary(maps:get(root, Binding)) andalso
            filename:pathtype(binary_to_list(maps:get(root, Binding))) =:= absolute
    end, maps:to_list(Workspaces));
valid_workspace_bindings(_) -> false.

valid_responses(Responses, Plan) when is_map(Responses) ->
    Allowed = [maps:get(action_id, Step) || Step <- Plan,
        maps:get(kind, Step) =:= delegate orelse
        lists:member(maps:get(operation, Step, <<>>),
            [<<"model.generate">>, <<"model.repair">>])],
    lists:all(fun({ActionId, Fixture}) ->
        lists:member(ActionId, Allowed) andalso valid_fixture(Fixture)
    end, maps:to_list(Responses));
valid_responses(_, _) -> false.

valid_fixture(#{status := success, output := Output} = Fixture) ->
    map_size(Fixture) =:= 2 andalso is_binary(Output) andalso byte_size(Output) > 0 andalso
        byte_size(Output) =< 65536;
valid_fixture(#{status := Status} = Fixture) when
        Status =:= transient; Status =:= permanent; Status =:= content_policy_denial;
        Status =:= timeout; Status =:= budget_exhausted; Status =:= outcome_unknown ->
    map_size(Fixture) =:= 1;
valid_fixture(#{status := Status, fragment := Fragment} = Fixture) when
        Status =:= invalid_syntax; Status =:= schema_failure ->
    map_size(Fixture) =:= 2 andalso is_binary(Fragment) andalso byte_size(Fragment) =< 4096;
valid_fixture(_) -> false.

valid_test_fault(none, _TestMode) -> true;
valid_test_fault(Fault, true) -> lists:member(Fault,
    [denied_scope, cancel_before_child, workspace_outcome_unknown, wrong_digest]);
valid_test_fault(_Fault, _TestMode) -> false.

validate_inputs(Inputs, Metadata) when is_map(Inputs) ->
    Parameters = maps:get(parameters, Metadata),
    Names = lists:sort([maps:get(name, Parameter) || Parameter <- Parameters]),
    case lists:sort(maps:keys(Inputs)) -- Names of
        [] -> validate_input_values(Parameters, Inputs,
            maps:get(terminal_class, Metadata));
        _ -> {error, unexpected_task_input}
    end;
validate_inputs(_, _Metadata) -> {error, invalid_task_inputs}.

validate_input_values([], _Inputs, _Terminal) -> ok;
validate_input_values([Parameter | Rest], Inputs, Terminal) ->
    Name = maps:get(name, Parameter),
    case maps:find(Name, Inputs) of
        {ok, Value} ->
            case valid_input_type(maps:get(type, Parameter), Value) of
                true -> validate_input_values(Rest, Inputs, Terminal);
                false -> {error, invalid_task_input_type}
            end;
        error when Terminal =:= <<"needs-clarification">> ->
            validate_input_values(Rest, Inputs, Terminal);
        error -> {error, missing_required_task_input}
    end.

valid_input_type(binary, Value) -> is_binary(Value);
valid_input_type(path, Value) -> is_binary(Value);
valid_input_type(model_profile, Value) -> is_binary(Value);
valid_input_type(json, Value) -> is_map(Value) orelse is_list(Value) orelse
    is_binary(Value) orelse is_integer(Value) orelse is_boolean(Value) orelse Value =:= null.

start_broker(_Metadata, Config) ->
    Bindings = maps:get(bindings, Config),
    ok = ensure_workspace_roots(maps:get(workspaces, Bindings)),
    Models = lists:usort([maps:get(model_id, Binding) || Binding <-
        maps:values(maps:get(models, Bindings))]),
    Workspaces = lists:usort([maps:get(workspace_id, Binding) || Binding <-
        maps:values(maps:get(workspaces, Bindings))]),
    Adapter = case maps:to_list(maps:get(workspaces, Bindings)) of
        [] -> disabled;
        [{_Logical, Workspace}] -> workspace_adapter_options(Workspace, Config)
    end,
    Options0 = #{
        limits => #{max_pending => 16, max_pending_per_session => 8,
            max_mailbox => 256, max_audit => 512, authorization_ttl_ms => 5000},
        policy => #{version => <<"fidelity-runtime-policy-v1">>,
            workspaces => Workspaces, models => Models}
    },
    Options = case Adapter of disabled -> Options0; _ -> Options0#{adapter => Adapter} end,
    case alang_phase4_broker:start_link(Options) of
        {ok, Broker} -> {ok, Broker};
        {error, Reason} -> {error, {broker_start_failed, Reason}}
    end.

ensure_workspace_roots(Workspaces) ->
    lists:foreach(fun(Binding) ->
        Root = binary_to_list(maps:get(root, Binding)),
        ok = filelib:ensure_dir(filename:join(Root, ".keep"))
    end, maps:values(Workspaces)),
    ok.

workspace_adapter_options(Workspace, Config) -> #{
    workspace_id => maps:get(workspace_id, Workspace),
    root => maps:get(root, Workspace),
    beam_dir => list_to_binary(filename:absname("build/phase-04/runtime")),
    test_faults => maps:get(test_mode, Config),
    limits => #{max_request_bytes => 98304, max_response_bytes => 4096,
        max_content_bytes => 65536, max_cache_entries => 128,
        request_timeout_ms => 3000, address_space_bytes => 2147483648,
        cpu_seconds => 5, open_files => 64, file_size_bytes => 67108864,
        processes => 4096}
}.

issue_parent_grant(Broker, Metadata, Inspection, Config) ->
    Invocations = parent_invocations(Metadata, Config),
    case Invocations of
        [] -> {ok, none, none};
        _ ->
            Limits = maps:get(task_limits, Metadata),
            Budgets0 = #{
                <<"model.complete">> => maps:get(model_calls, Limits),
                <<"workspace.write">> => maps:get(workspace_writes, Limits)
            },
            Operations = lists:usort([maps:get(operation, Invocation) ||
                Invocation <- Invocations]),
            Budgets = maps:with(Operations, Budgets0),
            Spec = #{
                invocations => Invocations,
                budgets => Budgets,
                deadline => maps:get(runtime_deadline, Config),
                owner_pid => self(),
                session_id => maps:get(session_id, Config),
                artifact_digest => maps:get(beam_sha256, Inspection),
                task_id => maps:get(task_id, Metadata),
                combination => intersect
            },
            case alang_phase4_broker:issue_grant(Broker, Spec) of
                {ok, Grant} -> {ok, Grant, digest({grant, maps:get(session_id, Config),
                    maps:get(beam_sha256, Inspection)})};
                {error, Reason} -> {error, {grant_issue_failed, Reason}}
            end
    end.

parent_invocations(Metadata, Config) ->
    Bindings = maps:get(bindings, Config),
    ModelInvocations = [#{operation => <<"model.complete">>,
        model_id => maps:get(model_id, Binding)} || Binding <-
        maps:values(maps:get(models, Bindings))],
    RelativePaths = [strip_workspace_prefix(Path) || Path <-
        maps:get(paths, maps:get(resources, maps:get(manifest, Metadata)))],
    WorkspaceInvocations = lists:append([[#{operation => <<"workspace.write">>,
        workspace_id => maps:get(workspace_id, Binding),
        path_prefix => binary:split(Path, <<"/">>, [global])} || Path <- RelativePaths]
        || Binding <- maps:values(maps:get(workspaces, Bindings))]),
    ModelInvocations ++ WorkspaceInvocations.

start_workflow(_Broker, _Grant, _GrantId, _Metadata, _Inspection,
        #{bindings := #{workspaces := Workspaces}}) when map_size(Workspaces) =:= 0 ->
    {ok, none, none, none};
start_workflow(Broker, Grant, GrantId, Metadata, Inspection, Config) ->
    {_Logical, Workspace} = only_map_entry(
        maps:get(workspaces, maps:get(bindings, Config))),
    Root = binary_to_list(maps:get(root, Workspace)),
    ok = filelib:ensure_dir(filename:join(Root, ".keep")),
    StoreRoot = maps:get(store_root, Config),
    SessionId = maps:get(session_id, Config),
    StoreOptions = #{root => StoreRoot, session_id => SessionId, test_faults => false},
    State = durable_state(Metadata, Inspection, Config, GrantId, Workspace),
    case initialize_store(StoreOptions, State, maps:get(beam_sha256, Inspection)) of
        ok ->
            case alang_phase5_store:start(StoreOptions) of
                {ok, Store} ->
                    WorkflowOptions = #{
                        store => Store,
                        broker => Broker,
                        state => State,
                        grant => Grant,
                        grant_id => GrantId,
                        manifest => runtime_manifest([<<"workspace.write">>]),
                        artifact_digest => maps:get(beam_sha256, Inspection),
                        task_id => maps:get(task_id, Metadata),
                        owner_pid => self(),
                        failure_stage => none,
                        controller => undefined
                    },
                    case alang_phase5_workflow:start(WorkflowOptions) of
                        {ok, Workflow} -> {ok, Store, Workflow, Workspace};
                        {error, Reason} ->
                            alang_phase5_store:stop(Store),
                            {error, {workflow_start_failed, Reason}}
                    end;
                {error, Reason} -> {error, {store_start_failed, Reason}}
            end;
        {error, Reason} -> {error, Reason}
    end.

durable_state(Metadata, Inspection, Config, GrantId, Workspace) ->
    Limits = maps:get(task_limits, Metadata),
    Invocation = #{operation => <<"workspace.write">>,
        workspace_id => maps:get(workspace_id, Workspace), path_prefix => []},
    Deadline = erlang:system_time(millisecond) + maps:get(timeout_ms, Limits),
    {ok, State} = alang_phase5_state:new(#{
        session_id => maps:get(session_id, Config),
        generation => 1,
        program => #{artifact_digest => maps:get(beam_sha256, Inspection),
            module_name => <<"alang_fidelity_program_v2">>, abi_version => 1,
            state_schema => 1},
        logical_state => #{<<"stage">> => <<"ready">>},
        budgets => #{<<"workspace.write">> => maps:get(workspace_writes, Limits)},
        deadline => Deadline,
        authority => [#{grant_id => GrantId, invocations => [Invocation],
            budgets => #{<<"workspace.write">> => maps:get(workspace_writes, Limits)},
            expires_at => Deadline, task_id => maps:get(task_id, Metadata),
            combination => deny}]
    }),
    State.

initialize_store(StoreOptions, State, ArtifactDigest) ->
    case alang_phase5_store:start(StoreOptions) of
        {ok, Store} ->
            SessionId = maps:get(session_id, StoreOptions),
            {ok, Journal0} = alang_phase5_journal:new(SessionId),
            {ok, StateDigest} = alang_phase5_state:checkpoint_digest(State),
            Now = erlang:system_time(millisecond),
            {ok, Creation, Journal1} = alang_phase5_journal:append(Journal0,
                session_created, 1, #{state_digest => StateDigest,
                    artifact_digest => ArtifactDigest}, Now),
            Deadline = erlang:monotonic_time(millisecond) + 3000,
            Result = case alang_phase5_store:append(Store, Creation, Deadline) of
                {ok, _} ->
                    {ok, Checkpoint, Journal2} = alang_phase5_journal:append(Journal1,
                        checkpoint, 1, #{state_digest => StateDigest}, Now),
                    {ok, _} = alang_phase5_store:append(Store, Checkpoint, Deadline),
                    {ok, _} = alang_phase5_store:checkpoint(Store, State,
                        maps:get(next_sequence, Journal2), Deadline),
                    ok;
                {error, Reason} -> {error, {store_initialize_failed, Reason}}
            end,
            alang_phase5_store:stop(Store),
            Result;
        {error, Reason} -> {error, {store_initialize_failed, Reason}}
    end.

only_workspace(State) ->
    only_map_entry(maps:get(workspaces,
        maps:get(bindings, maps:get(config, State)))).

only_map_entry(Map) ->
    [Entry] = maps:to_list(Map),
    Entry.

parent_binding(State) -> #{
    owner_pid => self(),
    session_id => maps:get(session_id, maps:get(config, State)),
    artifact_digest => maps:get(beam_sha256, maps:get(inspection, State)),
    task_id => maps:get(task_id, maps:get(metadata, State))
}.

broker_context(Broker, Binding, Deadline, OperationId) ->
    maps:merge(alang_phase4_broker:runtime_context(Broker), #{
        session_id => maps:get(session_id, Binding),
        artifact_digest => maps:get(artifact_digest, Binding),
        owner_pid => maps:get(owner_pid, Binding),
        task_id => maps:get(task_id, Binding),
        presenter_pid => maps:get(owner_pid, Binding),
        request_deadline => Deadline,
        cancelled => false,
        correlation_id => correlation_id(OperationId)
    }).

runtime_manifest(Effects) -> #{effects => Effects,
    requirements => [requirement(Effect) || Effect <- Effects]}.
requirement(<<"model.complete">>) -> <<"model:complete">>;
requirement(<<"workspace.write">>) -> <<"workspace:write">>.

artifact_relative_path(Metadata) ->
    Paths = maps:get(paths, maps:get(resources, maps:get(manifest, Metadata))),
    [Path] = Paths,
    strip_workspace_prefix(Path).

strip_workspace_prefix(<<"/workspace/", Relative/binary>>) -> Relative.

operation_id(Step, State) ->
    digest({maps:get(session_id, maps:get(config, State)),
        maps:get(node_id, Step), maps:get(effect_ordinal, Step)}).

child_operation_id(Spec, Metadata) ->
    digest({maps:get(session_id, Spec), maps:get(task_id, Metadata), child_model}).

child_task_id(Metadata) ->
    Prefix = binary:part(maps:get(semantic_sha256, Metadata), 0, 32),
    <<"task:child-", Prefix/binary, "/0">>.

child_session_id(State) ->
    Session = maps:get(session_id, maps:get(config, State)),
    Prefix = binary:part(digest({Session, child}), 0, 24),
    <<"child-", Prefix/binary>>.

correlation_id(OperationId) -> <<"corr-", OperationId/binary>>.

injected_pre_effect_failure(<<"child.run">>, State) ->
    case test_fault(State) of
        cancel_before_child -> cancelled;
        _ -> none
    end;
injected_pre_effect_failure(_Operation, _State) -> none.

maybe_inject_workspace_fault(State) ->
    case test_fault(State) of
        workspace_outcome_unknown ->
            alang_phase4_broker:inject_adapter_test_fault(
                maps:get(broker, State), crash_after_mutation);
        _ -> ok
    end.

test_fault(State) -> maps:get(test_fault, maps:get(config, State), none).

bounded_prompt(IoData) ->
    Binary = iolist_to_binary(IoData),
    case byte_size(Binary) =< 16384 of
        true -> Binary;
        false -> binary:part(Binary, 0, 16384)
    end.

normalize_effect_error(Reason) ->
    case contains_outcome_unknown(Reason) of
        true -> outcome_unknown;
        false -> normalize_definitive_error(Reason)
    end.

normalize_definitive_error({alang_effect_denied_v1, Reason, _Operation, _Resource,
        _DecisionId}) -> Reason;
normalize_definitive_error({alang_broker_denial_v1, Reason}) -> Reason;
normalize_definitive_error({Reason, _}) when is_atom(Reason) -> Reason;
normalize_definitive_error(Reason) when is_atom(Reason) -> Reason;
normalize_definitive_error(_) -> effect_failed.

contains_outcome_unknown(outcome_unknown) -> true;
contains_outcome_unknown(<<"adapter-outcome-unknown">>) -> true;
contains_outcome_unknown(Term) when is_tuple(Term) ->
    contains_outcome_unknown(tuple_to_list(Term));
contains_outcome_unknown(Term) when is_list(Term) ->
    lists:any(fun contains_outcome_unknown/1, Term);
contains_outcome_unknown(Term) when is_map(Term) ->
    contains_outcome_unknown(maps:keys(Term) ++ maps:values(Term));
contains_outcome_unknown(_) -> false.

runtime_snapshot(State) ->
    BrokerAudit = case maps:get(broker, State) of
        Broker when is_pid(Broker) -> normalize_audit(alang_phase4_broker:audit(Broker));
        _ -> none
    end,
    Journal = case maps:get(store, State) of
        Store when is_pid(Store) ->
            case alang_phase5_store:read(Store,
                    erlang:monotonic_time(millisecond) + 2000) of
                {ok, Snapshot} -> Snapshot;
                {error, Reason} -> #{error => Reason}
            end;
        _ -> none
    end,
    #{
        format => alang_fidelity_runtime_snapshot_v1,
        status => maps:get(status, State),
        binding_digest => maps:get(binding_digest, State),
        metadata_sha256 => maps:get(metadata_sha256, maps:get(inspection, State)),
        remaining => maps:get(remaining, State),
        counters => maps:get(counters, State),
        trace => maps:get(trace, State),
        broker_audit => BrokerAudit,
        journal => Journal,
        witness => maps:get(witness, State)
    }.

normalize_audit(#{events := Events} = Audit) ->
    Audit#{events := [maps:without([monotonic_time, decision_id], Event) || Event <- Events]}.

event(Kind, Fields) -> Fields#{format => alang_fidelity_runtime_event_v1,
    ordinal => maps:size(Fields), kind => Kind}.

zero_counters() -> #{steps => 0, model_calls => 0, repair_calls => 0,
    child_calls => 0, workspace_writes => 0, output_bytes => 0, timeout_ms => 0}.

fail_state(Reason, State) ->
    State#{status := failed, trace := maps:get(trace, State) ++
        [event(failed, #{reason => Reason})]}.

safe_stop_workflow(none) -> ok;
safe_stop_workflow(Pid) when is_pid(Pid) ->
    case is_process_alive(Pid) of true -> alang_phase5_workflow:stop(Pid); false -> ok end.
safe_stop_store(none) -> ok;
safe_stop_store(Pid) when is_pid(Pid) ->
    case is_process_alive(Pid) of true -> alang_phase5_store:stop(Pid); false -> ok end.
safe_stop_child_sup(none) -> ok;
safe_stop_child_sup(Pid) when is_pid(Pid) ->
    case is_process_alive(Pid) of true -> alang_phase6_child_sup:stop(Pid); false -> ok end.
safe_stop_broker(none) -> ok;
safe_stop_broker(Pid) when is_pid(Pid) ->
    case is_process_alive(Pid) of true -> gen_server:stop(Pid); false -> ok end.

valid_id(Value) when is_binary(Value), byte_size(Value) > 0, byte_size(Value) =< 128 ->
    binary:match(Value, <<0>>) =:= nomatch;
valid_id(_) -> false.

digest_binary(Binary) -> hex(crypto:hash(sha256, Binary)).
digest(Term) -> hex(crypto:hash(sha256, term_to_binary(Term, [deterministic]))).
hex(Binary) -> << <<(hex_digit(Nibble))>> || <<Nibble:4>> <= Binary >>.
hex_digit(Nibble) when Nibble < 10 -> $0 + Nibble;
hex_digit(Nibble) -> $a + Nibble - 10.
