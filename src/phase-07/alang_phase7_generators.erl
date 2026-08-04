-module(alang_phase7_generators).

-include_lib("proper/include/proper.hrl").

-export([
    case_from_seed/2,
    effect_ir_case/0,
    promoted_kinds/0,
    pure_ir_case/0,
    shrink_case/1,
    source_case/0,
    transform/0
]).

-spec promoted_kinds() -> [atom()].
promoted_kinds() -> [source, pure_ir, effect_ir].

-spec source_case() -> proper_types:type().
source_case() ->
    ?LET({Seed, Delta, Input},
        {proper_types:integer(0, 1000000), proper_types:integer(0, 32),
            proper_types:integer(-1024, 1024)},
        source_case(Seed, Delta, Input)).

-spec pure_ir_case() -> proper_types:type().
pure_ir_case() ->
    ?LET(Seed, proper_types:integer(0, 1000000), case_from_seed(pure_ir, Seed)).

-spec effect_ir_case() -> proper_types:type().
effect_ir_case() ->
    ?LET(Seed, proper_types:integer(0, 1000000), case_from_seed(effect_ir, Seed)).

-spec transform() -> proper_types:type().
transform() -> proper_types:elements([increment, double, negate]).

-spec case_from_seed(atom(), non_neg_integer()) -> map().
case_from_seed(source, Seed) ->
    Delta = Seed rem 33,
    Input = seed_value(Seed div 33),
    source_case(Seed, Delta, Input);
case_from_seed(pure_ir, Seed) ->
    Value = seed_value(Seed),
    Ir0 = alang_phase3_test_fixtures:pure_ir(),
    Ir = Ir0#{nodes := rewrite_nodes(maps:get(nodes, Ir0), #{
        <<"m0">> => Value,
        <<"m13">> => Value + 1
    })},
    #{format => alang_generated_case_v1, kind => pure_ir, seed => Seed,
        ir => Ir, task_id => <<"task:Fixture.main/0">>, inputs => #{},
        expected => Value + 1};
case_from_seed(effect_ir, Seed) ->
    Value = seed_value(Seed),
    Ir0 = alang_phase3_test_fixtures:effect_ir(),
    Ir = Ir0#{nodes := rewrite_nodes(maps:get(nodes, Ir0), #{
        <<"e0">> => Value,
        <<"e3">> => Value + 1
    })},
    #{format => alang_generated_case_v1, kind => effect_ir, seed => Seed,
        ir => Ir, task_id => <<"task:Fixture.effect/0">>, inputs => #{},
        expected => {alang_data_v1, ok, Value + 1}}.

-spec shrink_case(map()) -> [map()].
shrink_case(#{format := alang_generated_case_v1, kind := Kind, seed := Seed}) ->
    Seeds = lists:usort([0, Seed div 2, erlang:min(Seed, 1)]),
    [case_from_seed(Kind, Candidate) || Candidate <- Seeds, Candidate =/= Seed];
shrink_case(_) -> [].

source_case(Seed, Delta, Input) ->
    DeltaBinary = integer_to_binary(Delta),
    Source = iolist_to_binary([
        "module Generated version \"alang-source-v1\" {\n",
        "  task apply(value: Int) -> Int\n",
        "    effect []\n",
        "    requires []\n",
        "    = value + ", DeltaBinary, "\n",
        "    ensures result == value + ", DeltaBinary, ";\n",
        "}\n"
    ]),
    #{format => alang_generated_case_v1, kind => source, seed => Seed,
        source => Source, task_id => <<"task:Generated.apply/1">>,
        inputs => #{<<"value">> => Input}, expected => Input + Delta}.

rewrite_nodes(Nodes, Replacements) ->
    [case maps:find(maps:get(id, Node), Replacements) of
        {ok, Value} -> Node#{value := Value};
        error -> Node
    end || Node <- Nodes].

seed_value(Seed) -> (Seed rem 129) - 64.
