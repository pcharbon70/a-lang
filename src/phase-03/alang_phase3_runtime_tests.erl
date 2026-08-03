-module(alang_phase3_runtime_tests).

-include_lib("eunit/include/eunit.hrl").

closed_envelope_round_trip_test() ->
    Deadline = erlang:monotonic_time(millisecond) + 1000,
    {ok, Envelope} = alang_phase3_abi:new(
        effect_intent,
        <<"session-1">>,
        <<"task:Fixture.effect/0">>,
        <<"effect-1">>,
        Deadline,
        {effect_request, #{operation => <<"fixture.increment">>, arguments => {41}}},
        self(),
        {source, 10, 2, 3}
    ),
    ?assertEqual(ok, alang_phase3_abi:validate(Envelope)),
    ?assertEqual(ok, alang_phase3_abi:validate_at(Envelope, Deadline)),
    ?assertEqual({error, stale_message}, alang_phase3_abi:validate_at(Envelope, Deadline + 1)).

unknown_versions_tags_and_oversized_payloads_fail_closed_test() ->
    Deadline = erlang:monotonic_time(millisecond) + 1000,
    Base = {
        alang_envelope_v1,
        effect_intent,
        <<"session-1">>,
        <<"task-1">>,
        <<"effect-1">>,
        Deadline,
        {effect_request, #{}},
        self(),
        {source, 0, 1, 1}
    },
    ?assertEqual({error, unsupported_abi_version},
        alang_phase3_abi:validate(setelement(1, Base, alang_envelope_v2))),
    ?assertEqual({error, invalid_kind_or_payload_tag},
        alang_phase3_abi:validate(setelement(2, Base, unknown_kind))),
    ?assertEqual({error, invalid_kind_or_payload_tag},
        alang_phase3_abi:validate(setelement(7, Base, {unknown_payload, #{}}))),
    Oversized = setelement(7, Base, {effect_request, binary:copy(<<0>>, 65537)}),
    ?assertEqual({error, payload_too_large}, alang_phase3_abi:validate(Oversized)).

message_validation_does_not_intern_source_atoms_test() ->
    Deadline = erlang:monotonic_time(millisecond) + 1000,
    Warm = malformed_binary_tag(<<"warm">>, Deadline),
    ?assertEqual({error, invalid_kind_or_payload_tag}, alang_phase3_abi:validate(Warm)),
    Before = erlang:system_info(atom_count),
    lists:foreach(
        fun(Number) ->
            BinaryTag = <<"source-tag-", (integer_to_binary(Number))/binary>>,
            ?assertEqual(
                {error, invalid_kind_or_payload_tag},
                alang_phase3_abi:validate(malformed_binary_tag(BinaryTag, Deadline))
            )
        end,
        lists:seq(1, 100)
    ),
    ?assertEqual(Before, erlang:system_info(atom_count)).

pure_task_runs_under_session_supervision_test() ->
    {ok, Result} = alang_phase3_launcher:run(
        alang_phase3_runtime_fixture,
        <<"task:Fixture.pure/0">>,
        #{},
        options(fun unexpected_effect/2, 1000)
    ),
    ?assertEqual(42, maps:get(value, Result)),
    assert_trace_kinds(maps:get(trace, Result), [task_start, completion]).

effect_result_crosses_gateway_once_test() ->
    Parent = self(),
    Handler = fun(Operation, Arguments) ->
        Parent ! {effect_invoked, Operation, Arguments},
        {ok, 42}
    end,
    {ok, Result} = alang_phase3_launcher:run(
        alang_phase3_runtime_fixture,
        <<"task:Fixture.effect/0">>,
        #{},
        options(Handler, 1000)
    ),
    ?assertEqual({alang_data_v1, ok, 42}, maps:get(value, Result)),
    receive
        {effect_invoked, <<"fixture.increment">>, {alang_data_v1, product, {41}}} -> ok
    after 100 ->
        ?assert(false)
    end,
    receive
        {effect_invoked, _, _} -> ?assert(false)
    after 20 -> ok
    end,
    assert_trace_kinds(maps:get(trace, Result), [effect_intent, effect_result]).

contextual_handler_receives_bound_runtime_identity_test() ->
    Parent = self(),
    SessionId = <<"session-contextual-handler">>,
    Handler = fun(Operation, Arguments, Context) ->
        Parent ! {contextual_effect, Operation, Arguments, Context},
        {ok, 42}
    end,
    Options = (options(Handler, 1000))#{session_id => SessionId},
    {ok, Result} = alang_phase3_launcher:run(
        alang_phase3_runtime_fixture,
        <<"task:Fixture.effect/0">>,
        #{},
        Options
    ),
    ?assertEqual({alang_data_v1, ok, 42}, maps:get(value, Result)),
    receive
        {contextual_effect, <<"fixture.increment">>, {alang_data_v1, product, {41}}, Context} ->
            ?assertEqual(SessionId, maps:get(session_id, Context)),
            ?assertEqual(<<"task:Fixture.effect/0">>, maps:get(task_id, Context)),
            ?assert(is_binary(maps:get(correlation_id, Context))),
            ?assert(is_integer(maps:get(deadline, Context))),
            ?assert(is_pid(maps:get(requester_pid, Context))),
            ?assert(is_pid(maps:get(gateway_pid, Context))),
            ?assertMatch({source, _, _, _}, maps:get(origin, Context))
    after 100 ->
        ?assert(false)
    end.

denial_is_a_typed_result_not_an_exception_test() ->
    Handler = fun(_Operation, _Arguments) -> {error, <<"policy-denied">>} end,
    {ok, Result} = alang_phase3_launcher:run(
        alang_phase3_runtime_fixture,
        <<"task:Fixture.effect/0">>,
        #{},
        options(Handler, 1000)
    ),
    ?assertEqual({alang_data_v1, error, <<"policy-denied">>}, maps:get(value, Result)),
    assert_trace_kinds(maps:get(trace, Result), [effect_denied, completion]).

gateway_rejects_work_above_the_in_flight_limit_test() ->
    Parent = self(),
    Handler = fun(Operation, _Arguments) ->
        Parent ! {gateway_handler_started, self(), Operation},
        receive
            release -> {ok, Operation}
        end
    end,
    {ok, Trace} = alang_phase3_trace:start_link(16),
    {ok, Gateway} = alang_phase3_effect_gateway:start_link(<<"session-limit">>, Handler, limits()),
    Deadline = erlang:monotonic_time(millisecond) + 1000,
    FirstContext = effect_context(<<"session-limit">>, <<"task:first">>, Gateway, Trace, Deadline),
    SecondContext = effect_context(<<"session-limit">>, <<"task:second">>, Gateway, Trace, Deadline),
    spawn(fun() ->
        Result = alang_phase3_abi:request_effect(
            FirstContext, <<"first">>, {alang_data_v1, product, {}}, {source, 0, 1, 1}, 1000
        ),
        Parent ! {first_gateway_result, Result}
    end),
    EffectWorker = receive
        {gateway_handler_started, Worker, <<"first">>} -> Worker
    after 100 ->
        ?assert(false)
    end,
    spawn(fun() ->
        Result = alang_phase3_abi:request_effect(
            SecondContext, <<"second">>, {alang_data_v1, product, {}}, {source, 0, 1, 1}, 1000
        ),
        Parent ! {second_gateway_result, Result}
    end),
    receive
        {second_gateway_result, {alang_data_v1, error, <<"gateway-in-flight-limit">>}} -> ok
    after 100 ->
        ?assert(false)
    end,
    EffectWorker ! release,
    receive
        {first_gateway_result, {alang_data_v1, ok, <<"first">>}} -> ok
    after 100 ->
        ?assert(false)
    end,
    ok = gen_server:stop(Gateway),
    ok = gen_server:stop(Trace).

deadline_cancels_without_retry_test() ->
    Parent = self(),
    Handler = fun(Operation, _Arguments) ->
        Parent ! {slow_effect_invoked, Operation},
        timer:sleep(250),
        {ok, late}
    end,
    {error, Result} = alang_phase3_launcher:run(
        alang_phase3_runtime_fixture,
        <<"task:Fixture.slow/0">>,
        #{},
        options(Handler, 30)
    ),
    ?assertEqual(<<"task-deadline-exceeded">>, maps:get(reason, Result)),
    receive
        {slow_effect_invoked, <<"fixture.slow">>} -> ok
    after 100 ->
        ?assert(false)
    end,
    receive
        {slow_effect_invoked, _} -> ?assert(false)
    after 100 -> ok
    end.

gateway_death_terminates_task_and_does_not_retry_test() ->
    Parent = self(),
    Handler = fun(Operation, _Arguments) ->
        Parent ! {gateway_death_effect, Operation},
        timer:sleep(500),
        {ok, late}
    end,
    Limits = limits(),
    {ok, Supervisor} = alang_phase3_session_sup:start_link(<<"session-gateway-death">>, Handler, Limits),
    Deadline = erlang:monotonic_time(millisecond) + 1000,
    {ok, Start} = start_envelope(<<"session-gateway-death">>, <<"task:Fixture.slow/0">>, Deadline),
    {ok, Worker} = alang_phase3_session_sup:start_task(Supervisor, alang_phase3_runtime_fixture, Start),
    Monitor = erlang:monitor(process, Worker),
    receive
        {gateway_death_effect, <<"fixture.slow">>} -> ok
    after 100 ->
        ?assert(false)
    end,
    {ok, Before} = alang_phase3_session_sup:topology(Supervisor),
    exit(maps:get(effect_gateway, Before), kill),
    receive
        {'DOWN', Monitor, process, Worker, _Reason} -> ok
    after 500 ->
        ?assert(false)
    end,
    timer:sleep(20),
    {ok, After} = alang_phase3_session_sup:topology(Supervisor),
    ?assertNotEqual(maps:get(effect_gateway, Before), maps:get(effect_gateway, After)),
    receive
        {gateway_death_effect, _} -> ?assert(false)
    after 50 -> ok
    end,
    ok = alang_phase3_session_sup:stop(Supervisor).

trace_collector_is_bounded_test() ->
    {ok, Trace} = alang_phase3_trace:start_link(2),
    ?assertEqual(ok, alang_phase3_trace:record(Trace, event(task_start))),
    ?assertEqual(ok, alang_phase3_trace:record(Trace, event(completion))),
    ?assertEqual({error, trace_full}, alang_phase3_trace:record(Trace, event(runtime_failure))),
    {ok, Events} = alang_phase3_trace:snapshot(Trace),
    ?assertEqual(3, length(Events)),
    ?assertEqual(1, maps:get(dropped, lists:last(Events))),
    ok = gen_server:stop(Trace).

malformed_binary_tag(BinaryTag, Deadline) ->
    {
        alang_envelope_v1,
        effect_intent,
        <<"session-1">>,
        <<"task-1">>,
        <<"effect-1">>,
        Deadline,
        {BinaryTag, #{}},
        self(),
        {source, 0, 1, 1}
    }.

options(Handler, Timeout) ->
    (limits())#{handler => Handler, timeout => Timeout}.

limits() ->
    #{max_in_flight => 1, max_mailbox => 16, max_trace_events => 32}.

effect_context(SessionId, TaskId, Gateway, Trace, Deadline) ->
    #{
        session_id => SessionId,
        task_id => TaskId,
        gateway => Gateway,
        trace => Trace,
        deadline => Deadline
    }.

start_envelope(SessionId, TaskId, Deadline) ->
    alang_phase3_abi:new(
        task_start,
        SessionId,
        TaskId,
        <<"task">>,
        Deadline,
        {start, #{}},
        self(),
        {source, 0, 1, 1}
    ).

event(Kind) -> #{kind => Kind, monotonic_time => erlang:monotonic_time(millisecond)}.

unexpected_effect(_Operation, _Arguments) -> {error, <<"unexpected-effect">>}.

assert_trace_kinds(Events, Expected) ->
    Actual = [maps:get(kind, Event) || Event <- Events],
    lists:foreach(fun(Kind) -> ?assert(lists:member(Kind, Actual)) end, Expected).
