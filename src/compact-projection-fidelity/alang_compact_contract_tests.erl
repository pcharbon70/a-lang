-module(alang_compact_contract_tests).

-include_lib("eunit/include/eunit.hrl").

contract_loads_test() ->
    ?assertMatch({ok, _}, alang_compact_contract:load(contract_path())).

condition_roles_are_frozen_test() ->
    {ok, Contract} = contract(),
    Conditions = maps:get(<<"conditions">>, Contract),
    ?assertEqual([<<"R3">>], [
        maps:get(<<"id">>, C) || C <- Conditions,
        maps:get(<<"promotable">>, C)
    ]),
    Opaque = hd([C || C <- Conditions, maps:get(<<"id">>, C) =:= <<"R4">>]),
    ?assertEqual(false, maps:get(<<"promotable">>, Opaque)).

threshold_mutation_is_rejected_test() ->
    {ok, Contract} = contract(),
    Promotion = maps:get(<<"promotion">>, Contract),
    Mutant = Contract#{<<"promotion">> => Promotion#{<<"minimum_document_token_reduction">> => 0.19}},
    ?assertMatch(
        {error, {compact_contract_error, [<<"promotion">>], _}},
        alang_compact_contract:validate(Mutant)
    ).

invalid_campaign_precedes_efficacy_test() ->
    ?assertEqual(<<"stop-invalid-campaign">>, outcome((passing_evidence())#{<<"campaign_valid">> => false})).

round_trip_and_safety_vetoes_precede_tokens_test() ->
    ?assertEqual(<<"reject-unsafe-compact-projection">>, outcome((passing_evidence())#{<<"round_trip_pass">> => false})),
    Base = passing_evidence(),
    Families = maps:get(<<"model_families">>, Base),
    Ornith = maps:get(<<"ornith">>, Families),
    Unsafe = Base#{<<"model_families">> => Families#{<<"ornith">> => Ornith#{<<"compact_only_safety_events">> => 1}}},
    ?assertEqual(<<"reject-unsafe-compact-projection">>, outcome(Unsafe)).

all_gates_promote_only_r3_test() ->
    {ok, Contract} = contract(),
    {ok, Decision} = alang_compact_contract:decide(Contract, passing_evidence()),
    ?assertEqual(<<"promote-alang-model-v1">>, maps:get(<<"outcome">>, Decision)),
    ?assertEqual(<<"R3">>, maps:get(<<"candidate">>, Decision)),
    ?assertEqual(<<"alang-source-v2">>, maps:get(<<"canonical_source">>, Decision)).

strict_noninferiority_boundary_retains_readable_test() ->
    Base = passing_evidence(),
    Families = maps:get(<<"model_families">>, Base),
    Mixtral = maps:get(<<"mixtral">>, Families),
    Boundary = Base#{<<"model_families">> => Families#{<<"mixtral">> => Mixtral#{<<"pooled_exact_fidelity_lower">> => -0.05}}},
    ?assertEqual(<<"retain-readable-insufficient-evidence">>, outcome(Boundary)).

unknown_evidence_field_is_rejected_test() ->
    {ok, Contract} = contract(),
    ?assertMatch(
        {error, {compact_evidence_error, [], _}},
        alang_compact_contract:decide(Contract, (passing_evidence())#{<<"post_hoc_score">> => 1})
    ).

passing_evidence() ->
    #{
        <<"campaign_valid">> => true,
        <<"round_trip_pass">> => true,
        <<"inherited_gates_pass">> => true,
        <<"tokenizers">> => #{<<"cl100k_base">> => 0.21, <<"o200k_base">> => 0.20},
        <<"model_families">> => #{<<"mixtral">> => passing_model(), <<"ornith">> => passing_model()}
    }.

passing_model() ->
    #{
        <<"full_request_input_reduction">> => 0.15,
        <<"aggregate_provider_token_reduction">> => 0.16,
        <<"pooled_exact_fidelity_lower">> => -0.049,
        <<"task_exact_differences">> => #{
            <<"action-completion">> => -0.05,
            <<"comprehension">> => 0.0,
            <<"diagnostic-repair">> => -0.01,
            <<"generation">> => 0.01
        },
        <<"parse_check_difference">> => -0.05,
        <<"repair_success_difference">> => -0.05,
        <<"robustness_pass">> => true,
        <<"compact_only_safety_events">> => 0
    }.

outcome(Evidence) ->
    {ok, Contract} = contract(),
    {ok, Decision} = alang_compact_contract:decide(Contract, Evidence),
    maps:get(<<"outcome">>, Decision).

contract() -> alang_compact_contract:load(contract_path()).
contract_path() -> filename:join(["assets", "compact-projection-fidelity", "contracts", "campaign-contract-v1.json"]).
