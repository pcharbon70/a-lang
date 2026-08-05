-module(alang_fidelity_ast_tests).

-include_lib("eunit/include/eunit.hrl").

-define(V1_FIXTURE, "src/phase-02/fixtures/counter.alang").
-define(V2_FIXTURE, "assets/effectful-source-fidelity/corpus/attenuated-delegation/ad-error-branch.alang").

closed_ast_accepts_every_frozen_node_shape_test() ->
    Ast = v2_ast(),
    ?assertEqual({ok, Ast}, alang_fidelity_ast:validate(Ast)),
    Task = maps:get(task, Ast),
    ?assertEqual(4, length(maps:get(steps, Task))),
    ?assertEqual(attenuation, maps:get(value, maps:get(child, Task))).

ast_rejects_partial_extra_and_oversized_shapes_test() ->
    Ast = v2_ast(),
    Task = maps:get(task, Ast),
    assert_ast_error(invalid_ast_shape, Ast#{task => maps:remove(completion, Task)}),
    assert_ast_error(invalid_ast_shape, Ast#{task => Task#{unsupported => true}}),
    [Step | _] = maps:get(steps, Task),
    assert_ast_error(action_bound_exceeded, Ast#{task => Task#{steps => lists:duplicate(17, Step)}}),
    BadNameOrigin = (maps:get(name_origin, Task))#{byte => 9000},
    assert_ast_error(invalid_origin, Ast#{task => Task#{name_origin => BadNameOrigin}}).

ast_rejects_unsafe_completion_and_dynamic_operation_test() ->
    Ast = v2_ast(),
    Task = maps:get(task, Ast),
    Completion = maps:get(completion, Task),
    [FirstPredicate | OtherPredicates] = maps:get(predicates, Completion),
    UnsafePredicate = FirstPredicate#{target => <<"/workspace/../secret">>},
    UnsafeAst = Ast#{task => Task#{completion => Completion#{predicates => [UnsafePredicate | OtherPredicates]}}},
    assert_ast_error(unsafe_completion_path, UnsafeAst),
    [FirstStep | OtherSteps] = maps:get(steps, Task),
    DynamicStep = FirstStep#{operation => <<"runtime.select">>},
    DynamicAst = Ast#{task => Task#{steps => [DynamicStep | OtherSteps]}},
    assert_ast_error(unknown_operation, DynamicAst),
    Child = maps:get(child, Task),
    assert_ast_error(invalid_ast_shape, Ast#{task => Task#{child => Child#{grant => <<"forbidden">>}}}).

canonical_v2_round_trip_is_safe_and_deterministic_test() ->
    Ast = v2_ast(),
    {ok, Encoded1} = alang_fidelity_canonical:encode(Ast),
    {ok, Decoded} = alang_fidelity_canonical:decode(Encoded1),
    {ok, Encoded2} = alang_fidelity_canonical:encode(Decoded),
    {ok, Digest1} = alang_fidelity_canonical:digest(Ast),
    {ok, Digest2} = alang_fidelity_canonical:digest(Decoded),
    ?assertEqual(Ast, Decoded),
    ?assertEqual(Encoded1, Encoded2),
    ?assertEqual(Digest1, Digest2),
    ?assertEqual(64, byte_size(Digest1)),
    {error, [Trailing]} = alang_fidelity_canonical:decode(<<Encoded1/binary, 0>>),
    ?assertEqual(trailing_canonical_data, maps:get(code, Trailing)),
    {error, [Compressed]} = alang_fidelity_canonical:decode(<<131, 80, 0, 0, 0, 0>>),
    ?assertEqual(compressed_canonical_etf, maps:get(code, Compressed)),
    Invalid = term_to_binary({alang_source_canonical_v2, Ast#{unexpected => true}}, [deterministic]),
    {error, [InvalidDiagnostic]} = alang_fidelity_canonical:decode(Invalid),
    ?assertEqual(invalid_ast_shape, maps:get(code, InvalidDiagnostic)).

canonical_v1_products_remain_byte_identical_test() ->
    {ok, Source} = file:read_file(?V1_FIXTURE),
    {ok, Ast} = alang_phase2_parser:parse(Source),
    {ok, Legacy} = alang_phase2_canonical:encode(Ast),
    {ok, Compatible} = alang_fidelity_canonical:encode(Ast),
    ?assertEqual(Legacy, Compatible),
    ?assertEqual({ok, Ast}, alang_fidelity_canonical:decode(Compatible)),
    {ok, V2Canonical} = alang_fidelity_canonical:encode(v2_ast()),
    ?assertNotEqual(Compatible, V2Canonical).

malformed_text_and_token_work_is_bounded_test() ->
    Warmup = <<"#!alang-source-v2\ntask warmup {">>,
    _ = alang_fidelity_parser:parse(Warmup),
    AtomCount = erlang:system_info(atom_count),
    Inputs = [<<Byte>> || Byte <- lists:seq(0, 255)] ++ generated_inputs(20260805, 128),
    Results = [safe_parse(Input) || Input <- Inputs],
    ?assert(lists:all(fun(Result) -> Result =/= crashed end, Results)),
    lists:foreach(fun(Number) ->
        Name = integer_to_binary(Number),
        Source = <<"#!alang-source-v2\ntask generated-", Name/binary, " {">>,
        _ = alang_fidelity_parser:parse(Source)
    end, lists:seq(1, 256)),
    ?assertEqual(AtomCount, erlang:system_info(atom_count)),
    Token = {identifier, <<"x">>, #{byte => 0, line => 1, column => 1}},
    {error, [Diagnostic]} = alang_fidelity_parser:parse_tokens(lists:duplicate(4097, Token)),
    ?assertEqual(token_limit_exceeded, maps:get(code, Diagnostic)).

v2_ast() ->
    {ok, Source} = file:read_file(?V2_FIXTURE),
    {ok, Ast} = alang_fidelity_parser:parse(Source),
    Ast.

assert_ast_error(Code, Ast) ->
    {error, [Diagnostic]} = alang_fidelity_ast:validate(Ast),
    ?assertEqual(Code, maps:get(code, Diagnostic)),
    ?assertMatch(#{byte := _, line := _, column := _}, maps:get(origin, Diagnostic)).

safe_parse(Input) ->
    try alang_fidelity_parser:parse(Input) of
        Result -> Result
    catch
        _:_ -> crashed
    end.

generated_inputs(Seed, Count) ->
    _ = rand:seed(exsplus, {Seed, Seed bxor 16#5A5A, Seed bxor 16#A5A5}),
    [list_to_binary([rand:uniform(256) - 1 || _ <- lists:seq(1, rand:uniform(96))]) || _ <- lists:seq(1, Count)].
