-module(alang_phase3_integration_tests).

-include_lib("eunit/include/eunit.hrl").

-define(TOOLCHAIN, "src/phase-01/toolchain.config").

phase2_source_reference_and_phase3_beam_agree_test() ->
    {ok, Source} = file:read_file("src/phase-02/fixtures/counter.alang"),
    {ok, Product} = alang_phase2_compiler:compile_source(Source),
    Reference = maps:get(reference, Product),
    Ir = maps:get(ir, Product),
    {ok, Compiled} = compile_ir(Ir, sha256(Source)),
    {ok, Runtime} = run(
        maps:get(beam, Compiled),
        <<"task:Counter.successor/1">>,
        #{<<"value">> => 41},
        fun unexpected_effect/2
    ),
    ?assertEqual(maps:get(result, Reference), maps:get(value, Runtime)),
    ?assertEqual(true, maps:get(completion, Reference)),
    ?assertEqual([], maps:get(effects, Reference)),
    ?assertEqual([], effect_trace(maps:get(trace, Runtime))).

promoted_pure_data_control_and_calls_are_differential_test() ->
    Ir = alang_phase3_test_fixtures:pure_ir(),
    {ok, Compiled} = compile_ir(Ir, fixture_digest(pure)),
    Cases = [
        {<<"task:Fixture.add-one/1">>, #{<<"x">> => 41}},
        {<<"task:Fixture.main/0">>, #{}},
        {<<"task:Fixture.recover/0">>, #{}},
        {<<"task:Fixture.propagate/0">>, #{}}
    ],
    lists:foreach(
        fun({TaskId, Inputs}) ->
            {ok, Reference} = alang_phase3_reference:evaluate(Ir, TaskId, Inputs, fun unexpected_effect/2),
            {ok, Runtime} = run(maps:get(beam, Compiled), TaskId, Inputs, fun unexpected_effect/2),
            ?assertEqual(true, maps:get(completion, Reference)),
            ?assertEqual(maps:get(result, Reference), maps:get(value, Runtime)),
            ?assertEqual([], maps:get(effects, Reference))
        end,
        Cases
    ).

effect_intent_result_and_verifier_are_differential_test() ->
    Ir = alang_phase3_test_fixtures:effect_ir(),
    Handler = fun(<<"fixture.increment">>, {alang_data_v1, product, {Value}}) -> {ok, Value + 1} end,
    {ok, Reference} = alang_phase3_reference:evaluate(
        Ir, <<"task:Fixture.effect/0">>, #{}, Handler
    ),
    {ok, Compiled} = compile_ir(Ir, fixture_digest(effect)),
    {ok, Runtime} = run(
        maps:get(beam, Compiled), <<"task:Fixture.effect/0">>, #{}, Handler
    ),
    ?assertEqual(true, maps:get(completion, Reference)),
    ?assertEqual(maps:get(result, Reference), maps:get(value, Runtime)),
    [ReferenceEffect] = maps:get(effects, Reference),
    ?assertEqual(
        maps:get(operation, ReferenceEffect),
        maps:get(detail, hd(effect_trace(maps:get(trace, Runtime))))
    ).

verifier_failure_preserves_runtime_domain_and_source_origin_test() ->
    Ir = alang_phase3_test_fixtures:verifier_failure_ir(),
    {ok, Reference} = alang_phase3_reference:evaluate(
        Ir, <<"task:Fixture.verifier-failure/0">>, #{}, fun unexpected_effect/2
    ),
    ?assertEqual(false, maps:get(completion, Reference)),
    {ok, Compiled} = compile_ir(Ir, fixture_digest(verifier_failure)),
    {error, Runtime} = run(
        maps:get(beam, Compiled),
        <<"task:Fixture.verifier-failure/0">>,
        #{},
        fun unexpected_effect/2
    ),
    ?assertEqual(
        {alang_runtime_error_v1, verification_failed, {source, 500, 50, 1}},
        maps:get(reason, Runtime)
    ).

cyclic_ir_and_unknown_task_fail_closed_test() ->
    {error, CycleErrors} = alang_phase3_contract:validate_ir(cyclic_ir()),
    ?assert(lists:member(cyclic_node_graph, error_codes(CycleErrors))),
    Ir = alang_phase3_test_fixtures:pure_ir(),
    {ok, Compiled} = compile_ir(Ir, fixture_digest(unknown_task)),
    {error, Runtime} = run(
        maps:get(beam, Compiled), <<"task:Fixture.unknown/0">>, #{}, fun unexpected_effect/2
    ),
    ?assertEqual(unknown_task, maps:get(reason, Runtime)).

scheduler_smoke_runs_concurrent_supervised_sessions_test_() ->
    {timeout, 10, fun scheduler_smoke/0}.

scheduler_smoke() ->
    {ok, Source} = file:read_file("src/phase-02/fixtures/counter.alang"),
    {ok, Product} = alang_phase2_compiler:compile_source(Source),
    {ok, Compiled} = compile_ir(maps:get(ir, Product), sha256(Source)),
    Beam = maps:get(beam, Compiled),
    {ok, Module, _Inspection} = alang_phase3_artifact:load(Beam),
    Parent = self(),
    try
        [
            spawn(fun() ->
                Result = alang_phase3_launcher:run(
                    Module,
                    <<"task:Counter.successor/1">>,
                    #{<<"value">> => Input},
                    runtime_options(fun unexpected_effect/2)
                ),
                Parent ! {scheduler_result, Input, Result}
            end)
         || Input <- lists:seq(1, 32)
        ],
        Results = gather_scheduler_results(32, []),
        ?assertEqual(
            lists:seq(1, 32),
            lists:sort([Input || {Input, {ok, #{value := Value}}} <- Results, Value =:= Input + 1])
        )
    after
        ok = alang_phase3_artifact:purge(Module)
    end.

whole_toolchain_residency_evidence_is_reproducible_test() ->
    ?assertEqual(true, alang_phase3_reference:reference_only()),
    {ok, Evidence} = alang_phase3_residency:verify(),
    ?assertEqual(beam, maps:get(engine, Evidence)),
    ?assertEqual(true, maps:get(all_modules_are_beam, Evidence)),
    ?assertEqual(true, maps:get(no_foreign_imports, Evidence)),
    ?assertEqual([], maps:get(foreign_compiler_executables, Evidence)),
    ?assertEqual(false, maps:get(erlang_source_emitted, Evidence)),
    ?assertEqual(false, maps:get(core_erlang_used, Evidence)),
    EvidencePath = "build/phase-03/evidence/residency.config",
    {ok, Written} = alang_phase3_residency:write(EvidencePath),
    {ok, [ReadBack]} = file:consult(EvidencePath),
    ?assertEqual(Written, ReadBack).

compile_ir(Ir, SourceDigest) ->
    Context = #{source_sha256 => SourceDigest, capability_manifest => manifest(Ir)},
    alang_phase3_backend:compile_ir(Ir, Context, ?TOOLCHAIN).

run(Beam, TaskId, Inputs, Handler) ->
    alang_phase3_artifact:run(Beam, TaskId, Inputs, runtime_options(Handler)).

runtime_options(Handler) ->
    #{
        handler => Handler,
        timeout => 1000,
        max_in_flight => 4,
        max_mailbox => 32,
        max_trace_events => 64
    }.

manifest(#{tasks := Tasks}) ->
    #{
        effects => lists:usort(lists:append([maps:get(effects, Task) || Task <- Tasks])),
        requirements => lists:usort(lists:append([maps:get(requirements, Task) || Task <- Tasks]))
    }.

effect_trace(Trace) -> [Event || #{kind := effect_intent} = Event <- Trace].

gather_scheduler_results(0, Acc) -> Acc;
gather_scheduler_results(Remaining, Acc) ->
    receive
        {scheduler_result, Input, Result} ->
            gather_scheduler_results(Remaining - 1, [{Input, Result} | Acc])
    after 5000 ->
        error({scheduler_results_missing, Remaining})
    end.

cyclic_ir() ->
    Origin = #{byte => 10, line => 2, column => 1},
    #{
        format => alang_typed_task_ir_v1,
        module => <<"Cyclic">>,
        tasks => [#{
            id => <<"task:Cyclic.run/0">>,
            name => <<"run">>,
            parameters => [],
            result_type => int,
            effects => [],
            requirements => [],
            body_root => <<"c0">>,
            completion_root => <<"c3">>,
            origin => Origin
        }],
        nodes => [
            #{id => <<"c0">>, kind => add, type => int, left => <<"c0">>, right => <<"c1">>, origin => Origin},
            #{id => <<"c1">>, kind => literal, type => int, value => 1, origin => Origin},
            #{id => <<"c2">>, kind => literal, type => bool, value => true, origin => Origin},
            #{id => <<"c3">>, kind => verify, type => bool, condition => <<"c2">>, origin => Origin}
        ]
    }.

error_codes(Errors) -> [Code || {alang_compile_error_v1, Code, _Id, _Origin} <- Errors].

unexpected_effect(_Operation, _Arguments) -> {error, <<"unexpected-effect">>}.

fixture_digest(Name) -> sha256(term_to_binary({phase3_fixture, Name}, [deterministic])).

sha256(Binary) ->
    iolist_to_binary([io_lib:format("~2.16.0b", [Byte]) || <<Byte>> <= crypto:hash(sha256, Binary)]).
