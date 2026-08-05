-module(alang_fidelity_representation_tests).

-include_lib("eunit/include/eunit.hrl").

source_contract_is_frozen_test() ->
    {ok, Contract} = alang_fidelity_representation:load_source_contract(source_contract_path()),
    ?assertEqual(<<"alang-source-v2">>, maps:get(<<"candidate_format">>, Contract)),
    ?assertEqual(
        #{<<"format">> => <<"alang-source-v1">>, <<"accepted_unchanged">> => true},
        maps:get(<<"preserves">>, Contract)
    ),
    ?assertEqual(false, maps:get(<<"source_to_erlang">>, maps:get(<<"compiler_path">>, Contract))).

forbidden_feature_change_is_rejected_test() ->
    {ok, Contract} = alang_fidelity_json:decode_file(source_contract_path()),
    Mutant = Contract#{<<"forbidden">> => maps:get(<<"forbidden">>, Contract) -- [<<"recursion">>]},
    ?assertMatch(
        {error, {frozen_contract_mismatch, source_contract, _, _}},
        alang_fidelity_representation:validate_source_contract(Mutant)
    ).

pairing_and_materialization_contract_is_frozen_test() ->
    {ok, Contract} = alang_fidelity_representation:load_pairing_contract(pairing_contract_path()),
    Trial = maps:get(<<"trial_materialization">>, Contract),
    ?assertEqual(2026080501, maps:get(<<"schedule_seed">>, Trial)),
    ?assertEqual(true, maps:get(<<"representation_visible_treatment">>, Trial)),
    ?assert(lists:member(<<"answer-key">>, maps:get(<<"model_visible_exclusions">>, Trial))).

schedule_seed_change_is_rejected_test() ->
    {ok, Contract} = alang_fidelity_json:decode_file(pairing_contract_path()),
    Trial = maps:get(<<"trial_materialization">>, Contract),
    Mutant = Contract#{<<"trial_materialization">> => Trial#{<<"schedule_seed">> => 1}},
    ?assertMatch(
        {error, {frozen_contract_mismatch, pairing_contract, _, _}},
        alang_fidelity_representation:validate_pairing_contract(Mutant)
    ).

control_schema_and_pair_schema_are_closed_test() ->
    ControlSchema = schema("alang-task-json-v1.schema.json"),
    PairSchema = schema("semantic-pair-v1.schema.json"),
    ?assertEqual(false, maps:get(<<"additionalProperties">>, ControlSchema)),
    ?assertEqual(false, maps:get(<<"additionalProperties">>, PairSchema)).

typed_json_decodes_to_origin_free_semantics_test() ->
    Control = control(),
    {ok, Decoded} = alang_fidelity_representation:validate_control(Control),
    Origins = maps:get(<<"origins">>, Decoded),
    ?assert(lists:any(
        fun(Origin) -> maps:get(<<"pointer">>, Origin) =:= <<"/task/actions/0/operation">> end,
        Origins
    )),
    ?assertEqual(false, maps:is_key(<<"origins">>, maps:get(<<"semantic">>, Decoded))),
    Comprehension = (maps:get(<<"task">>, Control))#{
        <<"format">> => <<"alang_task_comprehension_v1">>,
        <<"case_id">> => maps:get(<<"case_id">>, Control)
    },
    ?assertEqual(
        alang_fidelity_contract:semantic_digest(Comprehension),
        maps:get(<<"semantic_digest">>, Decoded)
    ).

set_presentation_order_does_not_change_digest_test() ->
    Control = control(),
    Task = maps:get(<<"task">>, Control),
    ReorderedTask = Task#{
        <<"goal_facts">> => lists:reverse(maps:get(<<"goal_facts">>, Task)),
        <<"effects">> => lists:reverse(maps:get(<<"effects">>, Task)),
        <<"requirements">> => lists:reverse(maps:get(<<"requirements">>, Task))
    },
    {ok, First} = alang_fidelity_representation:validate_control(Control),
    {ok, Second} = alang_fidelity_representation:validate_control(Control#{<<"task">> => ReorderedTask}),
    ?assertEqual(maps:get(<<"semantic_digest">>, First), maps:get(<<"semantic_digest">>, Second)).

unknown_ir_field_is_rejected_test() ->
    Control = control(),
    Task = maps:get(<<"task">>, Control),
    Mutant = Control#{<<"task">> => Task#{<<"ir_node">> => <<"call_remote">>}},
    ?assertMatch(
        {error, {invalid_control_semantics, {contract_error, [], {unknown_fields, [<<"ir_node">>]}}}},
        alang_fidelity_representation:validate_control(Mutant)
    ).

duplicate_control_field_is_rejected_test() ->
    Json = <<"{\"format\":\"alang-task-json-v1\",\"case_id\":\"case-a\",\"case_id\":\"case-b\",\"task\":{}}">>,
    ?assertEqual({error, {duplicate_key, <<"case_id">>}}, alang_fidelity_representation:decode_control(Json)).

control() ->
    #{
        <<"format">> => <<"alang-task-json-v1">>,
        <<"case_id">> => <<"single-model-simple">>,
        <<"task">> => #{
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
                #{<<"kind">> => <<"max-bytes">>, <<"target">> => <<"/workspace/release-note.md">>, <<"expected">> => 2048}
            ],
            <<"clarification_needs">> => [],
            <<"terminal_class">> => <<"complete">>
        }
    }.

schema(Name) ->
    {ok, Value} = alang_fidelity_json:decode_file(filename:join(["assets", "effectful-source-fidelity", "contracts", Name])),
    Value.

source_contract_path() ->
    filename:join(["assets", "effectful-source-fidelity", "contracts", "alang-source-v2-contract.json"]).

pairing_contract_path() ->
    filename:join(["assets", "effectful-source-fidelity", "contracts", "pairing-and-materialization-v1.json"]).
