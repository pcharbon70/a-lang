-module(alang_fidelity_contract_tests).

-include_lib("eunit/include/eunit.hrl").

valid_comprehension_test() ->
    Value = comprehension(),
    ?assertMatch({ok, _}, alang_fidelity_contract:validate_comprehension(Value)),
    ?assertEqual(64, byte_size(alang_fidelity_contract:semantic_digest(Value))).

closed_schemas_are_decodable_test() ->
    ComprehensionSchema = schema("alang-task-comprehension-v1.schema.json"),
    ?assertEqual(false, maps:get(<<"additionalProperties">>, ComprehensionSchema)),
    ?assertEqual(
        <<"https://a-lang.invalid/schema/alang-task-comprehension-v1.schema.json">>,
        maps:get(<<"$id">>, ComprehensionSchema)
    ),
    AnswerSchema = schema("alang-answer-key-v1.schema.json"),
    ?assertEqual(false, maps:get(<<"additionalProperties">>, AnswerSchema)).

representation_neutral_answer_key_test() ->
    Value = comprehension(),
    AnswerKey = #{
        <<"format">> => <<"alang-answer-key-v1">>,
        <<"case_id">> => maps:get(<<"case_id">>, Value),
        <<"semantic_digest">> => alang_fidelity_contract:semantic_digest(Value),
        <<"expected">> => Value
    },
    ?assertMatch({ok, _}, alang_fidelity_contract:validate_answer_key(AnswerKey)),
    Reordered = Value#{
        <<"goal_facts">> => lists:reverse(maps:get(<<"goal_facts">>, Value)),
        <<"effects">> => lists:reverse(maps:get(<<"effects">>, Value)),
        <<"requirements">> => lists:reverse(maps:get(<<"requirements">>, Value))
    },
    ?assertEqual(
        alang_fidelity_contract:semantic_digest(Value),
        alang_fidelity_contract:semantic_digest(Reordered)
    ).

answer_key_digest_mismatch_test() ->
    Value = comprehension(),
    AnswerKey = #{
        <<"format">> => <<"alang-answer-key-v1">>,
        <<"case_id">> => maps:get(<<"case_id">>, Value),
        <<"semantic_digest">> => binary:copy(<<"0">>, 64),
        <<"expected">> => Value
    },
    ?assertMatch(
        {error, {contract_error, [<<"semantic_digest">>], _}},
        alang_fidelity_contract:validate_answer_key(AnswerKey)
    ).

duplicate_json_key_is_rejected_test() ->
    Json = <<"{\"format\":\"alang_task_comprehension_v1\",\"format\":\"other\"}">>,
    ?assertEqual({error, {duplicate_key, <<"format">>}}, alang_fidelity_contract:decode_comprehension(Json)).

unknown_field_is_rejected_test() ->
    Value = comprehension(),
    Mutant = Value#{<<"dynamic_tag">> => <<"run-anything">>},
    ?assertMatch(
        {error, {contract_error, [], {unknown_fields, [<<"dynamic_tag">>]}}},
        alang_fidelity_contract:validate_comprehension(Mutant)
    ).

dynamic_operation_is_rejected_test() ->
    Value = comprehension(),
    [First | Rest] = maps:get(<<"actions">>, Value),
    Mutant = Value#{<<"actions">> => [First#{<<"operation">> => <<"plugin.dynamic">>} | Rest]},
    ?assertMatch(
        {error, {contract_error, [<<"actions">>, 0, <<"operation">>], _}},
        alang_fidelity_contract:validate_comprehension(Mutant)
    ).

out_of_bounds_budget_is_rejected_test() ->
    Value = comprehension(),
    Budgets = maps:get(<<"budgets">>, Value),
    Mutant = Value#{<<"budgets">> => Budgets#{<<"output_bytes">> => 8193}},
    ?assertMatch(
        {error, {contract_error, [<<"budgets">>, <<"output_bytes">>], _}},
        alang_fidelity_contract:validate_comprehension(Mutant)
    ).

child_authority_widening_is_rejected_test() ->
    Value = comprehension(),
    Child = #{
        <<"effects">> => [<<"child.run">>],
        <<"requirements">> => [],
        <<"scopes">> => #{<<"models">> => [], <<"workspaces">> => [], <<"paths">> => []},
        <<"budgets">> => #{
            <<"steps">> => 1,
            <<"model_calls">> => 0,
            <<"repair_calls">> => 0,
            <<"child_calls">> => 0,
            <<"workspace_writes">> => 0,
            <<"output_bytes">> => 64,
            <<"timeout_ms">> => 1000
        }
    },
    Mutant = Value#{<<"child_attenuation">> => Child},
    ?assertMatch(
        {error, {contract_error, [<<"child_attenuation">>, <<"effects">>], child_effect_widens_authority}},
        alang_fidelity_contract:validate_comprehension(Mutant)
    ).

comprehension() ->
    #{
        <<"format">> => <<"alang_task_comprehension_v1">>,
        <<"case_id">> => <<"single-model-simple">>,
        <<"goal_facts">> => [<<"Produce a concise release note">>, <<"Do not invent changes">>],
        <<"inputs">> => [
            #{<<"name">> => <<"change-summary">>, <<"type">> => <<"text">>, <<"required">> => true}
        ],
        <<"actions">> => [
            #{<<"id">> => <<"draft">>, <<"operation">> => <<"model.generate">>, <<"depends_on">> => []},
            #{<<"id">> => <<"publish">>, <<"operation">> => <<"workspace.write">>, <<"depends_on">> => [<<"draft">>]},
            #{<<"id">> => <<"finish">>, <<"operation">> => <<"complete">>, <<"depends_on">> => [<<"publish">>]}
        ],
        <<"effects">> => [<<"model.generate">>, <<"workspace.write">>],
        <<"requirements">> => [
            #{<<"kind">> => <<"model">>, <<"resource">> => <<"editor">>},
            #{<<"kind">> => <<"workspace">>, <<"resource">> => <<"artifact-store">>}
        ],
        <<"scopes">> => #{
            <<"models">> => [<<"editor">>],
            <<"workspaces">> => [<<"artifact-store">>],
            <<"paths">> => [<<"/workspace/release-note.md">>]
        },
        <<"budgets">> => #{
            <<"steps">> => 3,
            <<"model_calls">> => 1,
            <<"repair_calls">> => 0,
            <<"child_calls">> => 0,
            <<"workspace_writes">> => 1,
            <<"output_bytes">> => 2048,
            <<"timeout_ms">> => 30000
        },
        <<"error_branches">> => [
            #{<<"action">> => <<"draft">>, <<"on">> => <<"timeout">>, <<"terminal_class">> => <<"failed">>}
        ],
        <<"child_attenuation">> => null,
        <<"completion_predicates">> => [
            #{<<"kind">> => <<"artifact-exists">>, <<"target">> => <<"/workspace/release-note.md">>, <<"expected">> => true},
            #{<<"kind">> => <<"utf8">>, <<"target">> => <<"/workspace/release-note.md">>, <<"expected">> => true},
            #{<<"kind">> => <<"max-bytes">>, <<"target">> => <<"/workspace/release-note.md">>, <<"expected">> => 2048}
        ],
        <<"clarification_needs">> => [],
        <<"terminal_class">> => <<"complete">>
    }.

schema(Name) ->
    Path = filename:join(["assets", "effectful-source-fidelity", "contracts", Name]),
    {ok, Value} = alang_fidelity_json:decode_file(Path),
    Value.
