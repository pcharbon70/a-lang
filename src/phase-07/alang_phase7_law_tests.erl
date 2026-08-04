-module(alang_phase7_law_tests).

-include_lib("proper/include/proper.hrl").
-include_lib("eunit/include/eunit.hrl").

-export([
    prop_categorical_laws/0,
    prop_effectful_reference_beam_agreement/0,
    prop_generated_source_round_trip/0,
    prop_pure_reference_beam_agreement/0,
    prop_semantic_shrinkers/0,
    run/0
]).

-define(TOOLCHAIN, "src/phase-01/toolchain.config").

generated_source_and_canonical_round_trip_test() ->
    ?assertEqual(true, quickcheck(prop_generated_source_round_trip(), 80)).

semantic_shrinkers_preserve_validity_test() ->
    ?assertEqual(true, quickcheck(prop_semantic_shrinkers(), 60)).

categorical_and_observation_laws_test() ->
    ?assertEqual(true, quickcheck(prop_categorical_laws(), 160)).

pure_reference_and_compiled_beam_agree_test_() ->
    {timeout, 30, fun() ->
        ?assertEqual(true, quickcheck(prop_pure_reference_beam_agreement(), 24))
    end}.

effectful_reference_and_compiled_beam_agree_test_() ->
    {timeout, 30, fun() ->
        ?assertEqual(true, quickcheck(prop_effectful_reference_beam_agreement(), 24))
    end}.

-spec run() -> map().
run() ->
    Results = [
        {source, quickcheck(prop_generated_source_round_trip(), 80)},
        {shrinkers, quickcheck(prop_semantic_shrinkers(), 60)},
        {categorical, quickcheck(prop_categorical_laws(), 160)},
        {pure_differential, quickcheck(prop_pure_reference_beam_agreement(), 24)},
        {effect_differential, quickcheck(prop_effectful_reference_beam_agreement(), 24)}
    ],
    #{format => alang_phase7_section_result_v1, section => <<"7.1">>,
        cases => 348, results => Results,
        passed => lists:all(fun({_Name, Result}) -> Result =:= true end, Results)}.

prop_generated_source_round_trip() ->
    ?FORALL(Case, alang_phase7_generators:source_case(), source_round_trip(Case)).

prop_semantic_shrinkers() ->
    ?FORALL(Case, proper_types:oneof([
        alang_phase7_generators:pure_ir_case(),
        alang_phase7_generators:effect_ir_case()
    ]),
        lists:all(fun valid_generated_case/1,
            [Case | alang_phase7_generators:shrink_case(Case)])).

prop_categorical_laws() ->
    ?FORALL({F, G, H, Value, EffectsA, EffectsB},
        {alang_phase7_generators:transform(), alang_phase7_generators:transform(),
            alang_phase7_generators:transform(), proper_types:integer(-1024, 1024),
            proper_types:list(proper_types:elements([<<"a">>, <<"b">>, <<"c">>])),
            proper_types:list(proper_types:elements([<<"b">>, <<"c">>, <<"d">>]))},
        categorical_laws(F, G, H, Value, EffectsA, EffectsB)).

prop_pure_reference_beam_agreement() ->
    ?FORALL(Case, alang_phase7_generators:pure_ir_case(), differential(Case)).

prop_effectful_reference_beam_agreement() ->
    ?FORALL(Case, alang_phase7_generators:effect_ir_case(), differential(Case)).

source_round_trip(#{source := Source, task_id := TaskId, inputs := Inputs,
    expected := Expected}) ->
    case alang_phase2_parser:parse(Source) of
        {ok, Ast} ->
            case alang_phase2_canonical:encode(Ast) of
                {ok, Encoded} ->
                    case {alang_phase2_canonical:decode(Encoded),
                        alang_phase2_semantics:check(Ast)} of
                        {{ok, Ast}, {ok, Checked}} ->
                            case alang_phase2_ir:lower(Checked) of
                                {ok, Ir} ->
                                    alang_phase2_ir:validate(Ir) =:= ok andalso
                                        source_reference(Ir, TaskId, Inputs, Expected);
                                _ -> false
                            end;
                        _ -> false
                    end;
                _ -> false
            end;
        _ -> false
    end.

source_reference(Ir, TaskId, Inputs, Expected) ->
    case alang_phase2_reference:evaluate(Ir, TaskId, Inputs) of
        {ok, #{result := Expected, completion := true, effects := []}} -> true;
        _ -> false
    end.

valid_generated_case(#{ir := Ir}) -> alang_phase3_contract:validate_ir(Ir) =:= ok;
valid_generated_case(_) -> false.

categorical_laws(F, G, H, Value, EffectsA, EffectsB) ->
    Identity = alang_phase2_ir:identity(),
    Apply = fun(Morphism) -> alang_phase2_ir:apply_transform(Morphism, Value) end,
    LeftIdentity = Apply(alang_phase2_ir:compose(Identity, F)) =:= Apply(F),
    RightIdentity = Apply(alang_phase2_ir:compose(F, Identity)) =:= Apply(F),
    Associative = Apply(alang_phase2_ir:compose(alang_phase2_ir:compose(F, G), H)) =:=
        Apply(alang_phase2_ir:compose(F, alang_phase2_ir:compose(G, H))),
    Pair = {alang_data_v1, product, {Value, Value + 1}},
    Products = element(1, element(3, Pair)) =:= Value andalso
        element(2, element(3, Pair)) =:= Value + 1,
    Result = {alang_data_v1, ok, Value},
    {alang_data_v1, ok, Bound} = Result,
    Results = Bound =:= Value,
    Union = alang_phase7_observation:manifest_union(
        #{effects => EffectsA, requirements => EffectsB},
        #{effects => EffectsB, requirements => EffectsA}),
    UnionCommutative = Union =:= alang_phase7_observation:manifest_union(
        #{effects => EffectsB, requirements => EffectsA},
        #{effects => EffectsA, requirements => EffectsB}),
    Normalized = alang_phase7_observation:equivalent(
        #{pid => self(), value => Value}, #{pid => self(), value => Value}),
    LeftIdentity andalso RightIdentity andalso Associative andalso Products andalso
        Results andalso UnionCommutative andalso Normalized.

differential(#{ir := Ir, task_id := TaskId, inputs := Inputs, expected := Expected,
    seed := Seed}) ->
    Handler = fun
        (<<"fixture.increment">>, {alang_data_v1, product, {Value}}) -> {ok, Value + 1};
        (_Operation, _Arguments) -> {error, <<"unexpected-effect">>}
    end,
    case alang_phase3_reference:evaluate(Ir, TaskId, Inputs, Handler) of
        {ok, Reference} ->
            Context = #{source_sha256 => digest({phase7, Seed}),
                capability_manifest => manifest(Ir)},
            case alang_phase3_backend:compile_ir(Ir, Context, ?TOOLCHAIN) of
                {ok, Compiled} ->
                    Options = #{handler => Handler, timeout => 2000, max_in_flight => 2,
                        max_mailbox => 32, max_trace_events => 64},
                    case alang_phase3_artifact:run(maps:get(beam, Compiled),
                        TaskId, Inputs, Options) of
                        {ok, Runtime} ->
                            maps:get(result, Reference) =:= Expected andalso
                                alang_phase7_observation:reference(Reference) =:=
                                    alang_phase7_observation:runtime(Runtime);
                        _ -> false
                    end;
                _ -> false
            end;
        _ -> false
    end.

manifest(#{tasks := Tasks}) -> #{
    effects => lists:usort(lists:append([maps:get(effects, Task) || Task <- Tasks])),
    requirements => lists:usort(lists:append([maps:get(requirements, Task) || Task <- Tasks]))
}.

quickcheck(Property, Count) ->
    proper:quickcheck(Property, [{numtests, Count}, {max_size, 24}, quiet]).

digest(Term) ->
    hex(crypto:hash(sha256, term_to_binary(Term, [deterministic]))).
hex(Binary) -> << <<(hex_digit(Nibble))>> || <<Nibble:4>> <= Binary >>.
hex_digit(Nibble) when Nibble < 10 -> $0 + Nibble;
hex_digit(Nibble) -> $a + Nibble - 10.
