-module(alang_phase2_compiler_tests).

-include_lib("eunit/include/eunit.hrl").

-define(FIXTURE, "src/phase-02/fixtures/counter.alang").

text_frontend_parses_counter_test() ->
    {ok, Source} = file:read_file(?FIXTURE),
    {ok, Ast} = alang_phase2_parser:parse(Source),
    ?assertEqual(alang_source_ast_v1, maps:get(format, Ast)),
    ?assertEqual(<<"Counter">>, maps:get(name, Ast)),
    ?assertEqual(1, length(maps:get(tasks, Ast))).

lexer_tracks_source_origin_test() ->
    {ok, [{module_kw, none, Origin} | _]} = alang_phase2_lexer:scan(<<"module X version \"alang-source-v1\" { task x() -> Int effect [] requires [] = 1 ensures true; }">>),
    ?assertEqual(#{byte => 0, line => 1, column => 1}, Origin).

frontend_rejects_nonempty_authority_lists_test() ->
    Source = <<"module X version \"alang-source-v1\" { task x() -> Int effect [net] requires [] = 1 ensures true; }">>,
    {error, [Diagnostic]} = alang_phase2_parser:parse(Source),
    ?assertEqual(effects_must_be_empty, maps:get(code, Diagnostic)),
    {error, [IntegerDiagnostic]} = alang_phase2_lexer:scan(<<"12345678901234567890">>),
    ?assertEqual(integer_literal_too_long, maps:get(code, IntegerDiagnostic)).

canonical_etf_round_trip_test() ->
    {ok, Source} = file:read_file(?FIXTURE),
    {ok, Ast} = alang_phase2_parser:parse(Source),
    {ok, Encoded1} = alang_phase2_canonical:encode(Ast),
    {ok, Decoded} = alang_phase2_canonical:decode(Encoded1),
    {ok, Encoded2} = alang_phase2_canonical:encode(Decoded),
    ?assertEqual(Ast, Decoded),
    ?assertEqual(Encoded1, Encoded2),
    {error, [Trailing]} = alang_phase2_canonical:decode(<<Encoded1/binary, 0>>),
    ?assertEqual(trailing_canonical_data, maps:get(code, Trailing)),
    {error, [Compressed]} = alang_phase2_canonical:decode(<<131, 80, 0, 0, 0, 0>>),
    ?assertEqual(compressed_canonical_etf, maps:get(code, Compressed)),
    InvalidAst = term_to_binary(#{
        format => alang_source_ast_v1,
        kind => module,
        name => <<"X">>,
        version => <<"alang-source-v1">>,
        tasks => [invalid],
        origin => #{byte => 0, line => 1, column => 1}
    }, [deterministic]),
    {error, [Invalid]} = alang_phase2_canonical:decode(InvalidAst),
    ?assertEqual(invalid_canonical_ast, maps:get(code, Invalid)).

static_semantics_resolve_and_type_counter_test() ->
    {ok, Checked} = checked_fixture(),
    [Task] = maps:get(tasks, Checked),
    ?assertEqual(<<"task:Counter.successor/1">>, maps:get(id, Task)),
    ?assertEqual(int, maps:get(result_type, Task)),
    ?assertEqual([], maps:get(effects, Task)),
    ?assertEqual([], maps:get(requirements, Task)).

static_semantics_reject_unresolved_name_test() ->
    Source = <<"module X version \"alang-source-v1\" { task x(value: Int) -> Int effect [] requires [] = missing + 1 ensures true; }">>,
    {ok, Ast} = alang_phase2_parser:parse(Source),
    {error, [Diagnostic]} = alang_phase2_semantics:check(Ast),
    ?assertEqual(unresolved_name, maps:get(code, Diagnostic)).

typed_ir_is_stable_and_valid_test() ->
    {ok, Checked} = checked_fixture(),
    {ok, Ir1} = alang_phase2_ir:lower(Checked),
    {ok, Ir2} = alang_phase2_ir:lower(Checked),
    ?assertEqual(Ir1, Ir2),
    ?assertEqual(ok, alang_phase2_ir:validate(Ir1)),
    [First | _] = maps:get(nodes, Ir1),
    ?assertEqual(<<"node:task:Counter.successor/1:0000">>, maps:get(id, First)).

typed_ir_preserves_boolean_bindings_test() ->
    Source = <<"module X version \"alang-source-v1\" { task x(flag: Bool) -> Bool effect [] requires [] = flag ensures result == flag; }">>,
    {ok, Ast} = alang_phase2_parser:parse(Source),
    {ok, Checked} = alang_phase2_semantics:check(Ast),
    {ok, Ir} = alang_phase2_ir:lower(Checked),
    InputAndResult = [Node || #{kind := Kind} = Node <- maps:get(nodes, Ir), Kind =:= input orelse Kind =:= result],
    ?assert(lists:all(fun(Node) -> maps:get(type, Node) =:= bool end, InputAndResult)).

reference_oracle_and_views_agree_test() ->
    {ok, Ir} = ir_fixture(),
    {ok, Reference} = alang_phase2_reference:evaluate(
        Ir,
        <<"task:Counter.successor/1">>,
        #{<<"value">> => 41}
    ),
    {ok, Views} = alang_phase2_views:project(Ir),
    ?assertEqual(42, maps:get(result, Reference)),
    ?assertEqual(true, maps:get(completion, Reference)),
    ?assertEqual(false, maps:get(deployable, Reference)),
    ?assertEqual([], maps:get(effects, maps:get(capability_manifest, Views))),
    ?assertEqual(true, maps:get(complete_node_coverage, maps:get(explanation, Views))).

category_identity_law_test() ->
    Values = lists:seq(-32, 32),
    Morphisms = [increment, double, negate],
    ?assert(lists:all(
        fun({Morphism, Value}) ->
            alang_phase2_ir:apply_transform(alang_phase2_ir:compose(alang_phase2_ir:identity(), Morphism), Value) =:=
                alang_phase2_ir:apply_transform(Morphism, Value) andalso
                alang_phase2_ir:apply_transform(alang_phase2_ir:compose(Morphism, alang_phase2_ir:identity()), Value) =:=
                    alang_phase2_ir:apply_transform(Morphism, Value)
        end,
        [{Morphism, Value} || Morphism <- Morphisms, Value <- Values]
    )).

category_associativity_law_test() ->
    Values = lists:seq(-32, 32),
    Morphisms = [increment, double, negate],
    ?assert(lists:all(
        fun({F, G, H, Value}) ->
            Left = alang_phase2_ir:compose(alang_phase2_ir:compose(F, G), H),
            Right = alang_phase2_ir:compose(F, alang_phase2_ir:compose(G, H)),
            alang_phase2_ir:apply_transform(Left, Value) =:= alang_phase2_ir:apply_transform(Right, Value)
        end,
        [{F, G, H, Value} || F <- Morphisms, G <- Morphisms, H <- Morphisms, Value <- Values]
    )).

beam_resident_compiler_invariant_test() ->
    Modules = [
        alang_phase2_lexer,
        alang_phase2_parser,
        alang_phase2_canonical,
        alang_phase2_semantics,
        alang_phase2_ir,
        alang_phase2_reference,
        alang_phase2_views,
        alang_phase2_bridge,
        alang_phase2_compiler
    ],
    ?assert(lists:all(fun(Module) -> filename:extension(code:which(Module)) =:= ".beam" end, Modules)),
    ?assertEqual([], filelib:wildcard("src/phase-02/*.rs")),
    ?assertEqual(false, filelib:is_file("src/phase-02/Cargo.toml")),
    ?assertEqual(false, filelib:is_file("rust-toolchain.toml")).

bridge_is_fail_closed_test() ->
    {ok, Ir} = ir_fixture(),
    {ok, Generated} = alang_phase2_bridge:phase1_fixture(Ir, "src/phase-01/semantic-fixture.config"),
    {ok, Golden} = file:read_file("src/phase-01/semantic-fixture.config"),
    ?assertEqual(Golden, Generated),
    ?assertEqual({error, unsupported_phase1_bridge_profile}, alang_phase2_bridge:phase1_fixture(#{}, "missing" )).

deterministic_malformed_input_smoke_test() ->
    Inputs = [
        <<Byte>> || Byte <- lists:seq(0, 255)
    ] ++ [
        <<"module X version \"alang-source-v1\" {", Suffix/binary>>
        || Suffix <- [<<>>, <<"!">>, <<"task">>, <<0, 1, 2>>]
    ],
    Results = [safe_compile(Input) || Input <- Inputs],
    ?assert(lists:all(fun(Result) -> element(1, Result) =/= unexpected_exception end, Results)).

checked_fixture() ->
    {ok, Source} = file:read_file(?FIXTURE),
    {ok, Ast} = alang_phase2_parser:parse(Source),
    alang_phase2_semantics:check(Ast).

ir_fixture() ->
    {ok, Checked} = checked_fixture(),
    alang_phase2_ir:lower(Checked).

safe_compile(Input) ->
    try alang_phase2_compiler:compile_source(Input) of
        Result -> Result
    catch
        Class:Reason -> {unexpected_exception, Class, Reason}
    end.
