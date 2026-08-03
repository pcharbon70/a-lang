-module(alang_phase3_test_fixtures).

-export([effect_ir/0, pure_ir/0, verifier_failure_ir/0]).

-spec pure_ir() -> map().
pure_ir() ->
    Origin = origin(10),
    Nodes = [
        node(<<"h0">>, input, int, #{name => <<"x">>}, Origin),
        node(<<"h1">>, literal, int, #{value => 1}, Origin),
        node(<<"h2">>, add, int, #{left => <<"h0">>, right => <<"h1">>}, Origin),
        node(<<"h3">>, result, int, #{}, Origin),
        node(<<"h4">>, equal, bool, #{left => <<"h3">>, right => <<"h2">>}, Origin),
        node(<<"h5">>, verify, bool, #{condition => <<"h4">>}, Origin),

        node(<<"m0">>, literal, int, #{value => 41}, Origin),
        node(<<"m1">>, apply, int, #{
            callable => <<"task:Fixture.add-one/1">>, arguments => [<<"m0">>]
        }, Origin),
        node(<<"m2">>, product, {product, [int, int]}, #{elements => [<<"m1">>, <<"m0">>]}, Origin),
        node(<<"m3">>, project, int, #{product => <<"m2">>, index => 1}, Origin),
        node(<<"m4">>, ok, {result, int, binary}, #{value => <<"m3">>}, Origin),
        node(<<"m5">>, input, int, #{name => <<"ok-value">>}, Origin),
        node(<<"m6">>, literal, int, #{value => 0}, Origin),
        node(<<"m7">>, match_result, int, #{
            value => <<"m20">>,
            ok_branch => <<"m5">>,
            error_branch => <<"m19">>,
            ok_binding => <<"ok-value">>,
            error_binding => <<"error-value">>
        }, Origin),
        node(<<"m8">>, bind, int, #{
            value => <<"m7">>, body => <<"m11">>, binding => <<"bound">>
        }, Origin),
        node(<<"m9">>, input, int, #{name => <<"bound">>}, Origin),
        node(<<"m10">>, ok, {result, int, binary}, #{value => <<"m0">>}, Origin),
        node(<<"m11">>, sequence, int, #{first => <<"m20">>, then => <<"m9">>}, Origin),
        node(<<"m12">>, result, int, #{}, Origin),
        node(<<"m13">>, literal, int, #{value => 42}, Origin),
        node(<<"m14">>, equal, bool, #{left => <<"m12">>, right => <<"m13">>}, Origin),
        node(<<"m15">>, verify, bool, #{condition => <<"m14">>}, Origin),
        node(<<"m16">>, input, binary, #{name => <<"error-value">>}, Origin),
        node(<<"m17">>, literal, binary, #{value => <<"unused-error">>}, Origin),
        node(<<"m18">>, product, {product, [int, binary]}, #{elements => [<<"m6">>, <<"m16">>]}, Origin),
        node(<<"m19">>, project, int, #{product => <<"m18">>, index => 1}, Origin),
        node(<<"m20">>, apply, {result, int, binary}, #{
            callable => <<"task:Fixture.ok-value/0">>, arguments => []
        }, Origin),

        node(<<"r0">>, literal, binary, #{value => <<"fixture-error">>}, Origin),
        node(<<"r1">>, error, {result, int, binary}, #{value => <<"r0">>}, Origin),
        node(<<"r2">>, literal, int, #{value => 7}, Origin),
        node(<<"r3">>, match_result, int, #{
            value => <<"r11">>,
            ok_branch => <<"r7">>,
            error_branch => <<"r10">>,
            ok_binding => <<"recover-ok">>,
            error_binding => <<"recover-error">>
        }, Origin),
        node(<<"r4">>, result, int, #{}, Origin),
        node(<<"r5">>, equal, bool, #{left => <<"r4">>, right => <<"r2">>}, Origin),
        node(<<"r6">>, verify, bool, #{condition => <<"r5">>}, Origin),
        node(<<"r7">>, input, int, #{name => <<"recover-ok">>}, Origin),
        node(<<"r8">>, input, binary, #{name => <<"recover-error">>}, Origin),
        node(<<"r9">>, product, {product, [int, binary]}, #{elements => [<<"r2">>, <<"r8">>]}, Origin),
        node(<<"r10">>, project, int, #{product => <<"r9">>, index => 1}, Origin),
        node(<<"r11">>, apply, {result, int, binary}, #{
            callable => <<"task:Fixture.error-value/0">>, arguments => []
        }, Origin),

        node(<<"p0">>, sequence, {result, int, binary}, #{first => <<"r11">>, then => <<"m20">>}, Origin),
        node(<<"p1">>, literal, bool, #{value => true}, Origin),
        node(<<"p2">>, verify, bool, #{condition => <<"p1">>}, Origin)
    ],
    #{
        format => alang_typed_task_ir_v1,
        module => <<"FixturePure">>,
        tasks => [
            task(<<"task:Fixture.add-one/1">>, [parameter(<<"x">>, int, Origin)], int, <<"h2">>, <<"h5">>, [], Origin),
            task(<<"task:Fixture.main/0">>, [], int, <<"m8">>, <<"m15">>, [], Origin),
            task(<<"task:Fixture.recover/0">>, [], int, <<"r3">>, <<"r6">>, [], Origin),
            task(<<"task:Fixture.propagate/0">>, [], {result, int, binary}, <<"p0">>, <<"p2">>, [], Origin),
            task(<<"task:Fixture.ok-value/0">>, [], {result, int, binary}, <<"m4">>, <<"p2">>, [], Origin),
            task(<<"task:Fixture.error-value/0">>, [], {result, int, binary}, <<"r1">>, <<"p2">>, [], Origin)
        ],
        nodes => Nodes
    }.

-spec effect_ir() -> map().
effect_ir() ->
    Origin = origin(30),
    Nodes = [
        node(<<"e0">>, literal, int, #{value => 41}, Origin),
        node(<<"e1">>, effect_request, {result, int, binary}, #{
            operation => <<"fixture.increment">>,
            arguments => [<<"e0">>],
            deadline => 1000
        }, Origin),
        node(<<"e2">>, result, {result, int, binary}, #{}, Origin),
        node(<<"e3">>, literal, int, #{value => 42}, Origin),
        node(<<"e4">>, ok, {result, int, binary}, #{value => <<"e3">>}, Origin),
        node(<<"e5">>, equal, bool, #{left => <<"e2">>, right => <<"e4">>}, Origin),
        node(<<"e6">>, verify, bool, #{condition => <<"e5">>}, Origin)
    ],
    #{
        format => alang_typed_task_ir_v1,
        module => <<"FixtureEffect">>,
        tasks => [task(
            <<"task:Fixture.effect/0">>,
            [],
            {result, int, binary},
            <<"e1">>,
            <<"e6">>,
            [<<"fixture.increment">>],
            Origin
        )],
        nodes => Nodes
    }.

-spec verifier_failure_ir() -> map().
verifier_failure_ir() ->
    Origin = origin(50),
    Nodes = [
        node(<<"f0">>, literal, int, #{value => 1}, Origin),
        node(<<"f1">>, result, int, #{}, Origin),
        node(<<"f2">>, literal, int, #{value => 2}, Origin),
        node(<<"f3">>, equal, bool, #{left => <<"f1">>, right => <<"f2">>}, Origin),
        node(<<"f4">>, verify, bool, #{condition => <<"f3">>}, Origin)
    ],
    #{
        format => alang_typed_task_ir_v1,
        module => <<"FixtureVerifierFailure">>,
        tasks => [task(<<"task:Fixture.verifier-failure/0">>, [], int, <<"f0">>, <<"f4">>, [], Origin)],
        nodes => Nodes
    }.

task(Id, Parameters, ResultType, BodyRoot, CompletionRoot, Effects, Origin) ->
    #{
        id => Id,
        name => Id,
        parameters => Parameters,
        result_type => ResultType,
        effects => Effects,
        requirements => [],
        body_root => BodyRoot,
        completion_root => CompletionRoot,
        origin => Origin
    }.

parameter(Name, Type, Origin) -> #{name => Name, type => Type, origin => Origin}.

node(Id, Kind, Type, Fields, Origin) ->
    maps:merge(#{id => Id, kind => Kind, type => Type, origin => Origin}, Fields).

origin(Line) -> #{byte => Line * 10, line => Line, column => 1}.
