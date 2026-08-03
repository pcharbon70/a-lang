-module(alang_phase4_broker_tests).

-include_lib("eunit/include/eunit.hrl").

decision_pipeline_returns_stable_reasons_and_redacted_events_test() ->
    with_broker(default_options(), fun(Broker) ->
        Now = erlang:monotonic_time(millisecond),
        Spec = grant_spec(self(), Now, 2, <<"workspace-a">>, [<<"notes">>]),
        {ok, Grant} = alang_phase4_broker:issue_grant(Broker, Spec),
        Context = request_context(Broker, Spec, self(), Now + 5000, false, <<"request-1">>),
        Arguments = workspace_arguments(<<"workspace-a">>, <<"notes/result.md">>,
            <<"secret body">>, <<"operation-1">>),
        Manifest = manifest([<<"workspace.write">>]),
        {ok, Authorization} = alang_phase4_broker:authorize(
            Broker, Grant, Manifest, <<"workspace.write">>, Arguments, Context
        ),
        ok = alang_phase4_broker:complete(Broker, Authorization, succeeded),
        ?assertEqual(
            denial(undeclared_effect),
            alang_phase4_broker:authorize(
                Broker, Grant, manifest([<<"model.complete">>]),
                <<"workspace.write">>, Arguments, Context#{correlation_id := <<"request-2">>}
            )
        ),
        ?assertEqual(
            denial(bad_input),
            alang_phase4_broker:authorize(
                Broker, Grant, Manifest, <<"erlang.apply">>, product({}),
                Context#{correlation_id := <<"request-3">>}
            )
        ),
        ?assertEqual(
            denial(unknown_grant),
            alang_phase4_broker:authorize(
                Broker, make_ref(), Manifest, <<"workspace.write">>, Arguments,
                Context#{correlation_id := <<"request-4">>}
            )
        ),
        ?assertEqual(
            denial(binding_mismatch),
            alang_phase4_broker:authorize(
                Broker, Grant, Manifest, <<"workspace.write">>, Arguments,
                Context#{session_id := <<"wrong-session">>, correlation_id := <<"request-5">>}
            )
        ),
        Escape = workspace_arguments(<<"workspace-a">>, <<"private/result.md">>,
            <<"secret body">>, <<"operation-2">>),
        ?assertEqual(
            denial(scope_mismatch),
            alang_phase4_broker:authorize(
                Broker, Grant, Manifest, <<"workspace.write">>, Escape,
                Context#{correlation_id := <<"request-6">>}
            )
        ),
        Audit = alang_phase4_broker:audit(Broker),
        Events = maps:get(events, Audit),
        ?assert(lists:any(fun(#{reason := Reason}) -> Reason =:= allowed end, Events)),
        ?assert(lists:any(fun(#{reason := Reason}) -> Reason =:= scope_mismatch end, Events)),
        ?assertNot(contains_reference(Audit)),
        ?assertNot(contains_binary(Audit, <<"secret body">>)),
        ?assert(lists:all(fun event_is_bounded/1, Events))
    end).

budget_deadline_cancellation_and_policy_order_test() ->
    with_broker(default_options(), fun(Broker) ->
        Now = erlang:monotonic_time(millisecond),
        Manifest = manifest([<<"workspace.write">>]),
        Arguments = workspace_arguments(<<"workspace-a">>, <<"notes/result.md">>,
            <<"body">>, <<"operation-1">>),
        OneUseSpec = grant_spec(self(), Now, 1, <<"workspace-a">>, [<<"notes">>]),
        {ok, OneUse} = alang_phase4_broker:issue_grant(Broker, OneUseSpec),
        Context = request_context(Broker, OneUseSpec, self(), Now + 5000, false, <<"budget-1">>),
        {ok, Authorization} = alang_phase4_broker:authorize(
            Broker, OneUse, Manifest, <<"workspace.write">>, Arguments, Context
        ),
        ok = alang_phase4_broker:complete(Broker, Authorization, succeeded),
        ?assertEqual(
            denial(exhausted_budget),
            alang_phase4_broker:authorize(
                Broker, OneUse, Manifest, <<"workspace.write">>, Arguments,
                Context#{correlation_id := <<"budget-2">>}
            )
        ),
        {ok, CancelledGrant} = alang_phase4_broker:issue_grant(Broker,
            grant_spec(self(), Now, 1, <<"workspace-a">>, [<<"notes">>])),
        ?assertEqual(
            denial(cancelled),
            alang_phase4_broker:authorize(
                Broker, CancelledGrant, Manifest, <<"workspace.write">>, Arguments,
                request_context(Broker, OneUseSpec, self(), Now + 5000, true, <<"cancelled">>)
            )
        ),
        {ok, ExpiredGrant} = alang_phase4_broker:issue_grant(Broker,
            grant_spec(self(), Now, 1, <<"workspace-a">>, [<<"notes">>])),
        ?assertEqual(
            denial(expired_deadline),
            alang_phase4_broker:authorize(
                Broker, ExpiredGrant, Manifest, <<"workspace.write">>, Arguments,
                request_context(Broker, OneUseSpec, self(), Now - 1, false, <<"expired">>)
            )
        ),
        {ok, PolicyGrant} = alang_phase4_broker:issue_grant(Broker,
            grant_spec(self(), Now, 1, <<"workspace-b">>, [<<"notes">>])),
        PolicyArguments = workspace_arguments(<<"workspace-b">>, <<"notes/result.md">>,
            <<"body">>, <<"operation-policy">>),
        PolicySpec = grant_spec(self(), Now, 1, <<"workspace-b">>, [<<"notes">>]),
        ?assertEqual(
            denial(policy_denied),
            alang_phase4_broker:authorize(
                Broker, PolicyGrant, Manifest, <<"workspace.write">>, PolicyArguments,
                request_context(Broker, PolicySpec, self(), Now + 5000, false, <<"policy">>)
            )
        )
    end).

admission_is_bounded_per_session_and_globally_test() ->
    Options = (default_options())#{limits := #{
        max_pending => 2,
        max_pending_per_session => 1,
        max_mailbox => 256,
        max_audit => 64,
        authorization_ttl_ms => 1000
    }},
    with_broker(Options, fun(Broker) ->
        Now = erlang:monotonic_time(millisecond),
        SpecA = grant_spec(self(), Now, 3, <<"workspace-a">>, [<<"notes">>]),
        {ok, GrantA} = alang_phase4_broker:issue_grant(Broker, SpecA),
        ContextA = request_context(Broker, SpecA, self(), Now + 5000, false, <<"admit-a1">>),
        Arguments = workspace_arguments(<<"workspace-a">>, <<"notes/a.md">>, <<"a">>, <<"a-1">>),
        {ok, AuthorizationA} = alang_phase4_broker:authorize(
            Broker, GrantA, manifest([<<"workspace.write">>]),
            <<"workspace.write">>, Arguments, ContextA
        ),
        ?assertEqual(1, alang_phase4_broker:pending_count(Broker)),
        ?assertEqual(
            denial(overloaded),
            alang_phase4_broker:authorize(
                Broker, GrantA, manifest([<<"workspace.write">>]),
                <<"workspace.write">>, Arguments, ContextA#{correlation_id := <<"admit-a2">>}
            )
        ),
        SpecB = SpecA#{session_id := <<"session-b">>, task_id := <<"task:b">>},
        {ok, GrantB} = alang_phase4_broker:issue_grant(Broker, SpecB),
        ContextB = request_context(Broker, SpecB, self(), Now + 5000, false, <<"admit-b1">>),
        {ok, AuthorizationB} = alang_phase4_broker:authorize(
            Broker, GrantB, manifest([<<"workspace.write">>]),
            <<"workspace.write">>, Arguments, ContextB
        ),
        ?assertEqual(2, alang_phase4_broker:pending_count(Broker)),
        SpecC = SpecA#{session_id := <<"session-c">>, task_id := <<"task:c">>},
        {ok, GrantC} = alang_phase4_broker:issue_grant(Broker, SpecC),
        ContextC = request_context(Broker, SpecC, self(), Now + 5000, false, <<"admit-c1">>),
        ?assertEqual(
            denial(overloaded),
            alang_phase4_broker:authorize(
                Broker, GrantC, manifest([<<"workspace.write">>]),
                <<"workspace.write">>, Arguments, ContextC
            )
        ),
        ok = alang_phase4_broker:complete(Broker, AuthorizationA, succeeded),
        ok = alang_phase4_broker:complete(Broker, AuthorizationB, succeeded),
        ?assertEqual(0, alang_phase4_broker:pending_count(Broker))
    end).

owner_death_removes_grants_test() ->
    with_broker(default_options(), fun(Broker) ->
        Owner = spawn(fun wait/0),
        Now = erlang:monotonic_time(millisecond),
        {ok, Grant} = alang_phase4_broker:issue_grant(Broker,
            grant_spec(Owner, Now, 1, <<"workspace-a">>, [])),
        Monitor = erlang:monitor(process, Owner),
        Owner ! stop,
        receive {'DOWN', Monitor, process, Owner, _} -> ok after 1000 -> error(owner_did_not_stop) end,
        ?assertEqual(ok, await_unknown_grant(Broker, Grant, 50)),
        Audit = alang_phase4_broker:audit(Broker),
        ?assert(lists:any(
            fun(#{reason := Reason}) -> Reason =:= owner_terminated end,
            maps:get(events, Audit)
        ))
    end).

supervised_restart_loses_grants_and_pending_work_test() ->
    {ok, Supervisor} = alang_phase4_broker_sup:start_link(default_options()),
    try
        {ok, Broker1} = alang_phase4_broker_sup:broker(Supervisor),
        Context1 = alang_phase4_broker:runtime_context(Broker1),
        Now = erlang:monotonic_time(millisecond),
        {ok, Grant} = alang_phase4_broker:issue_grant(Broker1,
            grant_spec(self(), Now, 1, <<"workspace-a">>, [])),
        Monitor = erlang:monitor(process, Broker1),
        exit(Broker1, kill),
        receive {'DOWN', Monitor, process, Broker1, killed} -> ok after 1000 -> error(broker_not_killed) end,
        {ok, Broker2} = await_new_broker(Supervisor, Broker1, 100),
        Context2 = alang_phase4_broker:runtime_context(Broker2),
        ?assertNotEqual(maps:get(runtime_instance, Context1), maps:get(runtime_instance, Context2)),
        ?assertNotEqual(maps:get(generation, Context1), maps:get(generation, Context2)),
        ?assertEqual({error, unknown_grant}, alang_phase4_broker:describe_grant(Broker2, Grant)),
        ?assertEqual(0, alang_phase4_broker:pending_count(Broker2))
    after
        alang_phase4_broker_sup:stop(Supervisor)
    end.

authorization_timeout_is_unknown_and_never_replayed_test() ->
    Options = (default_options())#{limits := #{
        max_pending => 1,
        max_pending_per_session => 1,
        max_mailbox => 64,
        max_audit => 64,
        authorization_ttl_ms => 20
    }},
    with_broker(Options, fun(Broker) ->
        Now = erlang:monotonic_time(millisecond),
        Spec = grant_spec(self(), Now, 1, <<"workspace-a">>, []),
        {ok, Grant} = alang_phase4_broker:issue_grant(Broker, Spec),
        Context = request_context(Broker, Spec, self(), Now + 1000, false, <<"unknown-1">>),
        Arguments = workspace_arguments(<<"workspace-a">>, <<"result.md">>, <<"body">>, <<"unknown-op">>),
        {ok, Authorization} = alang_phase4_broker:authorize(
            Broker, Grant, manifest([<<"workspace.write">>]),
            <<"workspace.write">>, Arguments, Context
        ),
        ?assertEqual(ok, await_pending(Broker, 0, 50)),
        ?assertEqual({error, unknown_authorization},
            alang_phase4_broker:complete(Broker, Authorization, succeeded)),
        Audit = alang_phase4_broker:audit(Broker),
        ?assert(lists:any(
            fun(#{reason := Reason}) -> Reason =:= outcome_unknown end,
            maps:get(events, Audit)
        )),
        ?assertEqual(
            denial(exhausted_budget),
            alang_phase4_broker:authorize(
                Broker, Grant, manifest([<<"workspace.write">>]),
                <<"workspace.write">>, Arguments, Context#{correlation_id := <<"unknown-2">>}
            )
        )
    end).

with_broker(Options, Fun) ->
    {ok, Supervisor} = alang_phase4_broker_sup:start_link(Options),
    try
        {ok, Broker} = alang_phase4_broker_sup:broker(Supervisor),
        Fun(Broker)
    after
        alang_phase4_broker_sup:stop(Supervisor)
    end.

default_options() -> #{
    limits => #{
        max_pending => 8,
        max_pending_per_session => 4,
        max_mailbox => 256,
        max_audit => 128,
        authorization_ttl_ms => 1000
    },
    policy => #{
        version => <<"phase4-policy-v1">>,
        workspaces => [<<"workspace-a">>],
        models => [<<"model-a">>]
    }
}.

grant_spec(Owner, Now, Budget, WorkspaceId, Prefix) -> #{
    invocations => [#{
        operation => <<"workspace.write">>,
        workspace_id => WorkspaceId,
        path_prefix => Prefix
    }],
    budgets => #{<<"workspace.write">> => Budget},
    deadline => Now + 10000,
    owner_pid => Owner,
    session_id => <<"session-a">>,
    artifact_digest => binary:copy(<<"a">>, 64),
    task_id => <<"task:Fixture.effect/0">>,
    combination => deny
}.

request_context(Broker, Spec, Presenter, Deadline, Cancelled, CorrelationId) ->
    maps:merge(alang_phase4_broker:runtime_context(Broker), #{
        session_id => maps:get(session_id, Spec),
        artifact_digest => maps:get(artifact_digest, Spec),
        owner_pid => maps:get(owner_pid, Spec),
        task_id => maps:get(task_id, Spec),
        presenter_pid => Presenter,
        request_deadline => Deadline,
        cancelled => Cancelled,
        correlation_id => CorrelationId
    }).

workspace_arguments(WorkspaceId, Path, Content, OperationId) ->
    product({WorkspaceId, Path, Content, OperationId}).

product(Elements) -> {alang_data_v1, product, Elements}.

manifest(Effects) -> #{effects => Effects, requirements => []}.

denial(Reason) -> {error, {alang_broker_denial_v1, Reason}}.

event_is_bounded(Event) ->
    maps:get(format, Event) =:= alang_broker_event_v1 andalso
        erlang:external_size(Event) =< 4096.

contains_reference(Term) when is_reference(Term) -> true;
contains_reference(Term) when is_map(Term) ->
    lists:any(fun contains_reference/1, maps:keys(Term) ++ maps:values(Term));
contains_reference(Term) when is_tuple(Term) -> contains_reference(tuple_to_list(Term));
contains_reference(Term) when is_list(Term) -> lists:any(fun contains_reference/1, Term);
contains_reference(_Term) -> false.

contains_binary(Binary, Binary) -> true;
contains_binary(Term, Binary) when is_map(Term) ->
    lists:any(fun(Value) -> contains_binary(Value, Binary) end,
        maps:keys(Term) ++ maps:values(Term));
contains_binary(Term, Binary) when is_tuple(Term) -> contains_binary(tuple_to_list(Term), Binary);
contains_binary(Term, Binary) when is_list(Term) ->
    lists:any(fun(Value) -> contains_binary(Value, Binary) end, Term);
contains_binary(_Term, _Binary) -> false.

await_unknown_grant(_Broker, _Grant, 0) -> timeout;
await_unknown_grant(Broker, Grant, Attempts) ->
    case alang_phase4_broker:describe_grant(Broker, Grant) of
        {error, unknown_grant} -> ok;
        _ -> receive after 5 -> await_unknown_grant(Broker, Grant, Attempts - 1) end
    end.

await_new_broker(_Supervisor, _Old, 0) -> {error, timeout};
await_new_broker(Supervisor, Old, Attempts) ->
    case alang_phase4_broker_sup:broker(Supervisor) of
        {ok, New} when New =/= Old -> {ok, New};
        _ -> receive after 5 -> await_new_broker(Supervisor, Old, Attempts - 1) end
    end.

await_pending(_Broker, _Expected, 0) -> timeout;
await_pending(Broker, Expected, Attempts) ->
    case alang_phase4_broker:pending_count(Broker) of
        Expected -> ok;
        _ -> receive after 5 -> await_pending(Broker, Expected, Attempts - 1) end
    end.

wait() -> receive stop -> ok end.
