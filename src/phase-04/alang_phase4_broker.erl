-module(alang_phase4_broker).

-behaviour(gen_server).

-export([
    audit/1,
    adapter_events/1,
    adapter_status/1,
    authorize/6,
    combine_grants/3,
    complete/3,
    dispatch/3,
    describe_grant/2,
    issue_grant/2,
    lookup_workspace/3,
    pending_count/1,
    request/6,
    restrict_grant/3,
    revoke_grant/2,
    runtime_context/1,
    start_link/1
]).
-export([handle_call/3, handle_cast/2, handle_info/2, init/1, terminate/2]).

-define(MAX_CALL_TIMEOUT, 5000).
-define(MAX_ID_BYTES, 128).

-spec start_link(map()) -> gen_server:start_ret().
start_link(Options) -> gen_server:start_link(?MODULE, Options, []).

-spec issue_grant(pid(), map()) -> {ok, tuple()} | {error, atom()}.
issue_grant(Broker, Spec) -> gen_server:call(Broker, {issue_grant, Spec}, ?MAX_CALL_TIMEOUT).

-spec restrict_grant(pid(), term(), map()) -> {ok, tuple()} | {error, atom()}.
restrict_grant(Broker, Parent, Restriction) ->
    gen_server:call(Broker, {restrict_grant, Parent, Restriction}, ?MAX_CALL_TIMEOUT).

-spec combine_grants(pid(), term(), term()) -> {ok, tuple()} | {error, atom()}.
combine_grants(Broker, Left, Right) ->
    gen_server:call(Broker, {combine_grants, Left, Right}, ?MAX_CALL_TIMEOUT).

-spec revoke_grant(pid(), term()) -> {ok, non_neg_integer()} | {error, atom()}.
revoke_grant(Broker, Grant) -> gen_server:call(Broker, {revoke_grant, Grant}, ?MAX_CALL_TIMEOUT).

-spec describe_grant(pid(), term()) -> {ok, map()} | {error, atom()}.
describe_grant(Broker, Grant) -> gen_server:call(Broker, {describe_grant, Grant}, ?MAX_CALL_TIMEOUT).

-spec runtime_context(pid()) -> map().
runtime_context(Broker) -> gen_server:call(Broker, runtime_context, ?MAX_CALL_TIMEOUT).

-spec authorize(pid(), term(), map(), binary(), term(), map()) ->
    {ok, tuple()} | {error, tuple()}.
authorize(Broker, Grant, Manifest, Operation, Arguments, Context) ->
    gen_server:call(
        Broker,
        {authorize, Grant, Manifest, Operation, Arguments, Context},
        ?MAX_CALL_TIMEOUT
    ).

-spec request(pid(), term(), map(), binary(), term(), map()) ->
    {ok, binary()} | {error, term()}.
request(Broker, Grant, Manifest, Operation, Arguments, Context) ->
    gen_server:call(
        Broker,
        {request, Grant, Manifest, Operation, Arguments, Context},
        ?MAX_CALL_TIMEOUT
    ).

-spec lookup_workspace(pid(), map(), integer()) -> {ok, map()} | {error, term()}.
lookup_workspace(Broker, Query, Deadline) ->
    gen_server:call(Broker, {lookup_workspace, Query, Deadline}, ?MAX_CALL_TIMEOUT).

-spec dispatch(pid(), tuple(), map()) -> {ok, binary()} | {error, term()}.
dispatch(Broker, Authorization, Context) ->
    gen_server:call(Broker, {dispatch, Authorization, Context}, ?MAX_CALL_TIMEOUT).

-spec complete(pid(), tuple(), atom()) -> ok | {error, atom()}.
complete(Broker, Authorization, Outcome) ->
    gen_server:call(Broker, {complete, Authorization, Outcome}, ?MAX_CALL_TIMEOUT).

-spec audit(pid()) -> map().
audit(Broker) -> gen_server:call(Broker, audit, ?MAX_CALL_TIMEOUT).

-spec pending_count(pid()) -> non_neg_integer().
pending_count(Broker) -> gen_server:call(Broker, pending_count, ?MAX_CALL_TIMEOUT).

-spec adapter_status(pid()) -> {ok, map()} | {error, atom()}.
adapter_status(Broker) -> gen_server:call(Broker, adapter_status, ?MAX_CALL_TIMEOUT).

-spec adapter_events(pid()) -> {ok, [map()]} | {error, atom()}.
adapter_events(Broker) -> gen_server:call(Broker, adapter_events, ?MAX_CALL_TIMEOUT).

init(Options) ->
    case validate_options(Options) of
        {ok, Limits, Policy, AdapterConfig} ->
            Generation = erlang:unique_integer([monotonic, positive]),
            Base = #{
                grants => alang_phase4_grants:new_store(Generation),
                limits => Limits,
                policy => Policy,
                adapter => disabled,
                pending => #{},
                owner_monitors => #{},
                audit => [],
                audit_overflow => 0
            },
            case start_owned_adapter(AdapterConfig, Base) of
                {ok, Started} -> {ok, Started};
                {error, Reason} -> {stop, {adapter_start_failed, Reason}}
            end;
        {error, Reason} -> {stop, Reason}
    end.

handle_call(runtime_context, _From, State) ->
    {reply, alang_phase4_grants:runtime_context(maps:get(grants, State)), State};
handle_call({issue_grant, Spec}, _From, State) ->
    Now = erlang:monotonic_time(millisecond),
    case alang_phase4_grants:issue(maps:get(grants, State), Spec, Now) of
        {ok, Grant, GrantStore} ->
            Monitored = monitor_owner(maps:get(owner_pid, Spec), State#{grants := GrantStore}),
            {reply, {ok, Grant}, Monitored};
        {error, _} = Error -> {reply, Error, State}
    end;
handle_call({restrict_grant, Parent, Restriction}, _From, State) ->
    Now = erlang:monotonic_time(millisecond),
    case alang_phase4_grants:restrict(maps:get(grants, State), Parent, Restriction, Now) of
        {ok, Grant, GrantStore} -> {reply, {ok, Grant}, State#{grants := GrantStore}};
        {error, _} = Error -> {reply, Error, State}
    end;
handle_call({combine_grants, Left, Right}, _From, State) ->
    Now = erlang:monotonic_time(millisecond),
    case alang_phase4_grants:combine(maps:get(grants, State), Left, Right, Now) of
        {ok, Grant, GrantStore} -> {reply, {ok, Grant}, State#{grants := GrantStore}};
        {error, _} = Error -> {reply, Error, State}
    end;
handle_call({revoke_grant, Grant}, _From, State) ->
    case alang_phase4_grants:revoke(maps:get(grants, State), Grant) of
        {ok, Count, GrantStore} -> {reply, {ok, Count}, State#{grants := GrantStore}};
        {error, _} = Error -> {reply, Error, State}
    end;
handle_call({describe_grant, Grant}, _From, State) ->
    {reply, alang_phase4_grants:describe(maps:get(grants, State), Grant), State};
handle_call({authorize, Grant, Manifest, Operation, Arguments, Context}, _From, State) ->
    {Reply, Updated} = authorize_request(Grant, Manifest, Operation, Arguments, Context, State),
    {reply, Reply, Updated};
handle_call({request, Grant, Manifest, Operation, Arguments, Context}, _From, State) ->
    {Reply, Updated} = request_effect(Grant, Manifest, Operation, Arguments, Context, State),
    {reply, Reply, Updated};
handle_call({lookup_workspace, Query, Deadline}, _From, State) ->
    {reply, lookup_owned_adapter(Query, Deadline, State), State};
handle_call({dispatch, Authorization, Context}, _From, State) ->
    {Reply, Updated} = dispatch_authorization(Authorization, Context, State),
    {reply, Reply, Updated};
handle_call({complete, Authorization, Outcome}, _From, State) ->
    {Reply, Updated} = complete_authorization(Authorization, Outcome, State),
    {reply, Reply, Updated};
handle_call(audit, _From, State) ->
    {reply, #{
        format => alang_broker_audit_v1,
        events => lists:reverse(maps:get(audit, State)),
        overflow => maps:get(audit_overflow, State)
    }, State};
handle_call(pending_count, _From, State) ->
    {reply, map_size(maps:get(pending, State)), State};
handle_call(adapter_status, _From, State) ->
    {reply, owned_adapter_call(status, State), State};
handle_call(adapter_events, _From, State) ->
    {reply, owned_adapter_call(events, State), State};
handle_call(_Request, _From, State) -> {reply, {error, unsupported_broker_call}, State}.

handle_cast(_Message, State) -> {noreply, State}.

handle_info({authorization_expired, Ticket}, State) ->
    {noreply, expire_authorization(Ticket, State)};
handle_info({'DOWN', Monitor, process, Adapter, Reason},
    #{adapter := #{pid := Adapter, monitor := Monitor}} = State) ->
    {noreply, restart_owned_adapter(Reason, State)};
handle_info({'DOWN', Monitor, process, Owner, _Reason}, State) ->
    {noreply, owner_down(Monitor, Owner, State)};
handle_info(_Message, State) -> {noreply, State}.

terminate(_Reason, State) ->
    maps:foreach(
        fun(_Ticket, #{timer := Timer}) -> _ = erlang:cancel_timer(Timer) end,
        maps:get(pending, State)
    ),
    maps:foreach(
        fun(_Owner, Monitor) -> erlang:demonitor(Monitor, [flush]) end,
        maps:get(owner_monitors, State)
    ),
    stop_owned_adapter(maps:get(adapter, State)),
    ok.

request_effect(Grant, Manifest, Operation, Arguments, Context, State) ->
    case authorize_request(Grant, Manifest, Operation, Arguments, Context, State) of
        {{ok, Authorization}, AuthorizedState} ->
            dispatch_authorization(Authorization, Context, AuthorizedState);
        {{error, _} = Error, DeniedState} -> {Error, DeniedState}
    end.

dispatch_authorization(
    {alang_broker_authorization_v1, Ticket, _DecisionId} = Authorization,
    Context,
    #{adapter := #{pid := Adapter, seal := Seal}, pending := Pending} = State
) ->
    case maps:find(Ticket, Pending) of
        {ok, #{decoded := Decoded}} ->
            AdapterResult = try alang_phase4_workspace_adapter:dispatch(
                Adapter,
                Seal,
                Decoded,
                maps:get(request_deadline, Context)
            ) of
                Result -> Result
            catch
                exit:_Reason -> {error, {adapter_exit, outcome_unknown}}
            end,
            {EffectResult, Outcome} = classify_adapter_result(AdapterResult),
            case complete_authorization(Authorization, Outcome, State) of
                {ok, CompletedState} -> {EffectResult, CompletedState};
                {{error, _}, CompletionState} ->
                    {{error, <<"adapter-outcome-unknown">>}, CompletionState}
            end;
        error -> {{error, <<"unknown-authorization">>}, State}
    end;
dispatch_authorization(Authorization, _Context, State) ->
    case complete_authorization(Authorization, failed, State) of
        {ok, CompletedState} -> {{error, <<"adapter-unavailable">>}, CompletedState};
        {{error, _}, CompletionState} -> {{error, <<"adapter-unavailable">>}, CompletionState}
    end.

classify_adapter_result({ok, #{digest := Digest}}) when is_binary(Digest), byte_size(Digest) =:= 64 ->
    {{ok, Digest}, succeeded};
classify_adapter_result({error, {_Class, outcome_unknown}}) ->
    {{error, <<"adapter-outcome-unknown">>}, outcome_unknown};
classify_adapter_result({error, Reason}) when is_atom(Reason) ->
    {{error, reason_binary(Reason)}, denied};
classify_adapter_result(_Other) -> {{error, <<"adapter-failed">>}, failed}.

authorize_request(Grant, Manifest, Operation, Arguments, Context, State) ->
    case admit(Context, State) of
        ok -> decode_stage(Grant, Manifest, Operation, Arguments, Context, State);
        {error, Reason} -> deny(admission, Reason, Operation, undefined, Grant, Context, undefined, State)
    end.

decode_stage(Grant, Manifest, Operation, Arguments, Context, State) ->
    case alang_phase4_effect_registry:decode_abi(Operation, Arguments) of
        {ok, Decoded} -> manifest_stage(Grant, Manifest, Decoded, Context, State);
        {error, _RegistryReason} ->
            deny(decode, bad_input, Operation, undefined, Grant, Context, undefined, State)
    end.

manifest_stage(Grant, Manifest, Decoded, Context, State) ->
    Operation = maps:get(operation, Decoded),
    case alang_phase4_effect_registry:validate_manifest(Manifest) of
        ok ->
            case lists:member(Operation, maps:get(effects, Manifest)) of
                true -> reference_stage(Grant, Decoded, Context, State);
                false -> deny(manifest, undeclared_effect, Operation, Decoded, Grant, Context, undefined, State)
            end;
        {error, _} -> deny(manifest, invalid_manifest, Operation, Decoded, Grant, Context, undefined, State)
    end.

reference_stage(Grant, Decoded, Context, State) ->
    GrantContext = maps:with(grant_context_keys(), Context),
    case alang_phase4_grants:resolve_bound(maps:get(grants, State), Grant, GrantContext) of
        {ok, Resolved, GrantStore} ->
            ownership_stage(Grant, Resolved, Decoded, Context, State#{grants := GrantStore});
        {error, Reason, GrantStore} ->
            deny(reference, decision_reason(Reason), maps:get(operation, Decoded), Decoded,
                Grant, Context, undefined, State#{grants := GrantStore})
    end.

ownership_stage(Grant, Resolved, Decoded, Context, State) ->
    case owner_alive(Resolved) of
        true -> scope_stage(Grant, Resolved, Decoded, Context, State);
        false -> deny(ownership, binding_mismatch, maps:get(operation, Decoded), Decoded,
            Grant, Context, undefined, State)
    end.

scope_stage(Grant, Resolved, Decoded, Context, State) ->
    case alang_phase4_grants:allows(Resolved, Decoded) of
        true -> budget_stage(Grant, Resolved, Decoded, Context, State);
        false -> deny(scope, scope_mismatch, maps:get(operation, Decoded), Decoded,
            Grant, Context, undefined, State)
    end.

budget_stage(Grant, Resolved, Decoded, Context, State) ->
    Operation = maps:get(operation, Decoded),
    case alang_phase4_grants:remaining(maps:get(grants, State), Grant, Operation) of
        {ok, Remaining} when Remaining > 0 ->
            deadline_stage(Grant, Resolved, Decoded, Context, Remaining, State);
        {ok, _} -> deny(budget, exhausted_budget, Operation, Decoded, Grant, Context, 0, State);
        {error, Reason} -> deny(budget, decision_reason(Reason), Operation, Decoded,
            Grant, Context, undefined, State)
    end.

deadline_stage(Grant, Resolved, Decoded, Context, Remaining, State) ->
    Now = erlang:monotonic_time(millisecond),
    case maps:get(deadline, Resolved) >= Now andalso maps:get(request_deadline, Context) >= Now of
        true -> cancellation_stage(Grant, Decoded, Context, Remaining, State);
        false ->
            GrantContext = maps:with(grant_context_keys(), Context),
            GrantStore = case alang_phase4_grants:resolve(
                maps:get(grants, State), Grant, GrantContext, Now
            ) of
                {error, expired_grant, ExpiredStore} -> ExpiredStore;
                _ -> maps:get(grants, State)
            end,
            deny(deadline, expired_deadline, maps:get(operation, Decoded), Decoded,
                Grant, Context, Remaining, State#{grants := GrantStore})
    end.

cancellation_stage(Grant, Decoded, Context, Remaining, State) ->
    case maps:get(cancelled, Context) of
        true -> deny(cancellation, cancelled, maps:get(operation, Decoded), Decoded,
            Grant, Context, Remaining, State);
        false -> policy_stage(Grant, Decoded, Context, Remaining, State)
    end.

policy_stage(Grant, Decoded, Context, Remaining, State) ->
    case policy_allows(maps:get(policy, State), Decoded) of
        true -> allow(Grant, Decoded, Context, State);
        false -> deny(policy, policy_denied, maps:get(operation, Decoded), Decoded,
            Grant, Context, Remaining, State)
    end.

allow(Grant, Decoded, Context, State) ->
    Operation = maps:get(operation, Decoded),
    case alang_phase4_grants:consume(maps:get(grants, State), Grant, Operation) of
        {ok, Remaining, GrantStore} ->
            Ticket = make_ref(),
            DecisionId = decision_id(),
            Limits = maps:get(limits, State),
            Timer = erlang:send_after(maps:get(authorization_ttl_ms, Limits), self(),
                {authorization_expired, Ticket}),
            PendingEntry = #{
                decision_id => DecisionId,
                session_id => maps:get(session_id, Context),
                owner_pid => maps:get(owner_pid, Context),
                decoded => Decoded,
                timer => Timer
            },
            Pending = (maps:get(pending, State))#{Ticket => PendingEntry},
            Event = event(allow, policy, allowed, DecisionId, Operation, Decoded,
                Grant, Context, Remaining, State),
            Updated = record_event(Event, State#{grants := GrantStore, pending := Pending}),
            {{ok, {alang_broker_authorization_v1, Ticket, DecisionId}}, Updated};
        {error, Reason} -> deny(budget, decision_reason(Reason), Operation, Decoded,
            Grant, Context, undefined, State)
    end.

deny(Stage, Reason, Operation, Decoded, Grant, Context, Remaining, State) ->
    DecisionId = decision_id(),
    Event = event(deny, Stage, Reason, DecisionId, safe_operation(Operation), Decoded,
        Grant, Context, Remaining, State),
    {{error, {alang_broker_denial_v1, Reason}}, record_event(Event, State)}.

admit(Context, State) ->
    case valid_request_context(Context) of
        false -> {error, bad_input};
        true ->
            Pending = maps:get(pending, State),
            Limits = maps:get(limits, State),
            SessionId = maps:get(session_id, Context),
            SessionPending = length([
                ok
             || #{session_id := PendingSession} <- maps:values(Pending),
                PendingSession =:= SessionId
            ]),
            case {
                map_size(Pending) < maps:get(max_pending, Limits),
                SessionPending < maps:get(max_pending_per_session, Limits),
                mailbox_length() < maps:get(max_mailbox, Limits)
            } of
                {true, true, true} -> ok;
                _ -> {error, overloaded}
            end
    end.

valid_request_context(Context) when is_map(Context) ->
    lists:sort(maps:keys(Context)) =:= lists:sort(
        grant_context_keys() ++ [request_deadline, cancelled, correlation_id]
    ) andalso
        is_integer(maps:get(request_deadline, Context, invalid)) andalso
        is_boolean(maps:get(cancelled, Context, invalid)) andalso
        valid_id(maps:get(correlation_id, Context, invalid));
valid_request_context(_) -> false.

grant_context_keys() -> [
    node,
    runtime_instance,
    generation,
    session_id,
    artifact_digest,
    owner_pid,
    task_id,
    presenter_pid
].

complete_authorization({alang_broker_authorization_v1, Ticket, DecisionId}, Outcome, State) when
    is_reference(Ticket),
    is_binary(DecisionId)
->
    case {valid_outcome(Outcome), maps:take(Ticket, maps:get(pending, State))} of
        {true, {#{decision_id := DecisionId, timer := Timer} = Entry, Remaining}} ->
            _ = erlang:cancel_timer(Timer),
            Event = completion_event(Entry, Outcome, State),
            {ok, record_event(Event, State#{pending := Remaining})};
        {false, _} -> {{error, invalid_completion_outcome}, State};
        {true, error} -> {{error, unknown_authorization}, State};
        {true, {_Entry, _Remaining}} -> {{error, unknown_authorization}, State}
    end;
complete_authorization(_Authorization, _Outcome, State) ->
    {{error, unknown_authorization}, State}.

expire_authorization(Ticket, State) ->
    case maps:take(Ticket, maps:get(pending, State)) of
        {Entry, Remaining} ->
            Event = completion_event(Entry, outcome_unknown, State),
            record_event(Event, State#{pending := Remaining});
        error -> State
    end.

completion_event(Entry, Outcome, State) ->
    Decoded = maps:get(decoded, Entry),
    #{
        format => alang_broker_event_v1,
        decision_id => maps:get(decision_id, Entry),
        correlation_id => <<"internal-completion">>,
        operation => maps:get(operation, Decoded),
        resource => maps:get(resource, Decoded),
        decision => completion,
        stage => dispatch,
        reason => Outcome,
        policy_version => maps:get(version, maps:get(policy, State)),
        remaining_budget => undefined,
        grant_id => undefined,
        monotonic_time => erlang:monotonic_time(millisecond)
    }.

event(Decision, Stage, Reason, DecisionId, Operation, Decoded, Grant, Context,
    Remaining, State) ->
    #{
        format => alang_broker_event_v1,
        decision_id => DecisionId,
        correlation_id => safe_correlation(Context),
        operation => Operation,
        resource => safe_resource(Decoded),
        decision => Decision,
        stage => Stage,
        reason => Reason,
        policy_version => maps:get(version, maps:get(policy, State)),
        remaining_budget => Remaining,
        grant_id => grant_id(maps:get(grants, State), Grant),
        monotonic_time => erlang:monotonic_time(millisecond)
    }.

record_event(Event, State) ->
    Maximum = maps:get(max_audit, maps:get(limits, State)),
    Events = [Event | maps:get(audit, State)],
    case length(Events) =< Maximum of
        true -> State#{audit := Events};
        false -> State#{
            audit := lists:sublist(Events, Maximum),
            audit_overflow := maps:get(audit_overflow, State) + 1
        }
    end.

grant_id(GrantStore, Grant) ->
    case alang_phase4_grants:describe(GrantStore, Grant) of
        {ok, Description} -> maps:get(id, Description);
        {error, _} -> undefined
    end.

safe_operation(Operation) when is_binary(Operation) ->
    case lists:member(Operation, alang_phase4_effect_registry:operations()) of
        true -> Operation;
        false -> <<"invalid">>
    end;
safe_operation(_) -> <<"invalid">>.

safe_resource(#{resource := Resource}) -> Resource;
safe_resource(_) -> undefined.

safe_correlation(Context) when is_map(Context) ->
    case maps:get(correlation_id, Context, undefined) of
        Correlation when is_binary(Correlation), byte_size(Correlation) =< ?MAX_ID_BYTES -> Correlation;
        _ -> <<"invalid">>
    end;
safe_correlation(_) -> <<"invalid">>.

decision_reason(unknown_grant) -> unknown_grant;
decision_reason(revoked_grant) -> revoked_grant;
decision_reason(binding_mismatch) -> binding_mismatch;
decision_reason(scope_mismatch) -> scope_mismatch;
decision_reason(exhausted_budget) -> exhausted_budget;
decision_reason(_) -> policy_failure.

policy_allows(#{workspaces := Workspaces}, #{operation_tag := workspace_write,
    resource := #{workspace_id := WorkspaceId}}) ->
    lists:member(WorkspaceId, Workspaces);
policy_allows(#{models := Models}, #{operation_tag := model_complete,
    resource := #{model_id := ModelId}}) ->
    lists:member(ModelId, Models);
policy_allows(_Policy, _Decoded) -> false.

owner_alive(#{owner_pid := Owner}) -> erlang:is_process_alive(Owner).

monitor_owner(Owner, #{owner_monitors := Monitors} = State) ->
    case maps:is_key(Owner, Monitors) of
        true -> State;
        false -> State#{owner_monitors := Monitors#{Owner => erlang:monitor(process, Owner)}}
    end.

owner_down(Monitor, Owner, #{owner_monitors := Monitors} = State) ->
    case maps:find(Owner, Monitors) of
        {ok, Monitor} ->
            {Removed, GrantStore} = alang_phase4_grants:remove_owner(maps:get(grants, State), Owner),
            {RemovedPending, RemainingPending} = remove_owner_pending(
                Owner,
                maps:get(pending, State)
            ),
            Event = #{
                format => alang_broker_event_v1,
                decision_id => decision_id(),
                correlation_id => <<"owner-down">>,
                operation => <<"none">>,
                resource => undefined,
                decision => lifecycle,
                stage => ownership,
                reason => owner_terminated,
                policy_version => maps:get(version, maps:get(policy, State)),
                remaining_budget => undefined,
                grant_id => undefined,
                removed_grants => Removed,
                removed_authorizations => RemovedPending,
                monotonic_time => erlang:monotonic_time(millisecond)
            },
            record_event(Event, State#{
                grants := GrantStore,
                pending := RemainingPending,
                owner_monitors := maps:remove(Owner, Monitors)
            });
        _ -> State
    end.

remove_owner_pending(Owner, Pending) ->
    maps:fold(
        fun(Ticket, #{owner_pid := PendingOwner, timer := Timer} = Entry, {Count, Acc}) ->
            case PendingOwner =:= Owner of
                true ->
                    _ = erlang:cancel_timer(Timer),
                    {Count + 1, Acc};
                false -> {Count, Acc#{Ticket => Entry}}
            end
        end,
        {0, #{}},
        Pending
    ).

validate_options(#{limits := Limits, policy := Policy} = Options) when
    map_size(Options) =:= 2 orelse map_size(Options) =:= 3
->
    AdapterConfig = maps:get(adapter, Options, disabled),
    ValidKeys = lists:sort(maps:keys(Options)) =:= [limits, policy] orelse
        lists:sort(maps:keys(Options)) =:= [adapter, limits, policy],
    case {ValidKeys, validate_limits(Limits), validate_policy(Policy)} of
        {true, ok, ok} when AdapterConfig =:= disabled; is_map(AdapterConfig) ->
            {ok, Limits, Policy, AdapterConfig};
        {false, _, _} -> {error, invalid_broker_options};
        {true, ok, ok} -> {error, invalid_adapter_configuration};
        {true, {error, _} = Error, _} -> Error;
        {true, _, {error, _} = Error} -> Error
    end;
validate_options(_) -> {error, invalid_broker_options}.

start_owned_adapter(disabled, State) -> {ok, State};
start_owned_adapter(Config, State) when is_map(Config) ->
    Seal = make_ref(),
    case alang_phase4_workspace_adapter:start(self(), Config, Seal) of
        {ok, Adapter} ->
            Monitor = erlang:monitor(process, Adapter),
            {ok, State#{adapter := #{
                pid => Adapter,
                seal => Seal,
                monitor => Monitor,
                config => Config
            }}};
        {error, Reason} -> {error, Reason}
    end.

restart_owned_adapter(Reason, #{adapter := #{config := Config}} = State) ->
    Event = #{
        format => alang_broker_event_v1,
        decision_id => decision_id(),
        correlation_id => <<"adapter-down">>,
        operation => <<"workspace.write">>,
        resource => undefined,
        decision => lifecycle,
        stage => dispatch,
        reason => adapter_restarted,
        policy_version => maps:get(version, maps:get(policy, State)),
        remaining_budget => undefined,
        grant_id => undefined,
        adapter_failure => bounded_adapter_reason(Reason),
        monotonic_time => erlang:monotonic_time(millisecond)
    },
    Base = record_event(Event, State#{adapter := disabled}),
    case start_owned_adapter(Config, Base) of
        {ok, Restarted} -> Restarted;
        {error, _StartReason} -> Base
    end;
restart_owned_adapter(_Reason, State) -> State.

stop_owned_adapter(disabled) -> ok;
stop_owned_adapter(#{pid := Adapter, seal := Seal, monitor := Monitor}) ->
    erlang:demonitor(Monitor, [flush]),
    _ = try alang_phase4_workspace_adapter:stop(Adapter, Seal)
        catch
            exit:_Reason -> ok
        end,
    ok.

owned_adapter_call(_Kind, #{adapter := disabled}) -> {error, adapter_unavailable};
owned_adapter_call(status, #{adapter := #{pid := Adapter}}) ->
    try {ok, alang_phase4_workspace_adapter:status(Adapter)}
    catch
        exit:_Reason -> {error, adapter_unavailable}
    end;
owned_adapter_call(events, #{adapter := #{pid := Adapter}}) ->
    try {ok, alang_phase4_workspace_adapter:events(Adapter)}
    catch
        exit:_Reason -> {error, adapter_unavailable}
    end.

lookup_owned_adapter(_Query, _Deadline, #{adapter := disabled}) -> {error, adapter_unavailable};
lookup_owned_adapter(Query, Deadline, #{adapter := #{pid := Adapter, seal := Seal}}) ->
    try alang_phase4_workspace_adapter:lookup(Adapter, Seal, Query, Deadline) of
        Result -> Result
    catch
        exit:_Reason -> {error, adapter_unavailable}
    end.

bounded_adapter_reason(Reason) ->
    Binary = iolist_to_binary(io_lib:format("~tp", [Reason])),
    case byte_size(Binary) =< 128 of
        true -> Binary;
        false -> binary:part(Binary, 0, 128)
    end.

reason_binary(Reason) ->
    iolist_to_binary(io_lib:format("~tp", [Reason])).

validate_limits(#{
    max_pending := MaxPending,
    max_pending_per_session := MaxPerSession,
    max_mailbox := MaxMailbox,
    max_audit := MaxAudit,
    authorization_ttl_ms := AuthorizationTtl
} = Limits) when
    map_size(Limits) =:= 5,
    is_integer(MaxPending), MaxPending > 0, MaxPending =< 128,
    is_integer(MaxPerSession), MaxPerSession > 0, MaxPerSession =< MaxPending,
    is_integer(MaxMailbox), MaxMailbox > 0, MaxMailbox =< 4096,
    is_integer(MaxAudit), MaxAudit > 0, MaxAudit =< 4096,
    is_integer(AuthorizationTtl), AuthorizationTtl > 0, AuthorizationTtl =< 60000
-> ok;
validate_limits(_) -> {error, invalid_broker_limits}.

validate_policy(#{version := Version, workspaces := Workspaces, models := Models} = Policy) when
    map_size(Policy) =:= 3,
    is_list(Workspaces),
    is_list(Models),
    length(Workspaces) =< 32,
    length(Models) =< 32
->
    case valid_id(Version) andalso lists:all(fun valid_id/1, Workspaces ++ Models) of
        true -> ok;
        false -> {error, invalid_broker_policy}
    end;
validate_policy(_) -> {error, invalid_broker_policy}.

valid_id(Value) ->
    is_binary(Value) andalso byte_size(Value) > 0 andalso byte_size(Value) =< ?MAX_ID_BYTES.

valid_outcome(succeeded) -> true;
valid_outcome(denied) -> true;
valid_outcome(failed) -> true;
valid_outcome(timed_out) -> true;
valid_outcome(cancelled) -> true;
valid_outcome(outcome_unknown) -> true;
valid_outcome(_) -> false.

mailbox_length() ->
    case process_info(self(), message_queue_len) of
        {message_queue_len, Length} -> Length;
        undefined -> 0
    end.

decision_id() ->
    Integer = erlang:unique_integer([monotonic, positive]),
    <<"decision-", (integer_to_binary(Integer))/binary>>.
