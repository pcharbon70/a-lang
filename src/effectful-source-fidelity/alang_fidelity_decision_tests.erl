-module(alang_fidelity_decision_tests).

-include_lib("eunit/include/eunit.hrl").

frozen_contract_test() ->
    ?assertMatch({ok, _}, alang_fidelity_decision:load_contract(contract_path())).

post_freeze_threshold_change_is_rejected_test() ->
    {ok, Contract} = alang_fidelity_json:decode_file(contract_path()),
    Promotion = maps:get(<<"promotion">>, Contract),
    Mutant = Contract#{<<"promotion">> => Promotion#{<<"minimum_absolute_percentage_points">> => 4}},
    ?assertMatch(
        {error, {decision_contract_error, [<<"promotion">>, <<"minimum_absolute_percentage_points">>], _}},
        alang_fidelity_decision:validate_contract(Mutant)
    ).

promotion_requires_every_family_test() ->
    Evidence = evidence(86, 80, 1.2, 88, 82, 0.1),
    ?assertEqual(<<"promote-alang-source-v2">>, outcome(Evidence)),
    FailedOneFamily = evidence(86, 80, 1.2, 84, 82, 0.1),
    ?assertEqual(<<"replace-with-json-control">>, outcome(FailedOneFamily)).

positive_interval_is_strict_test() ->
    Evidence = evidence(86, 80, 0, 88, 82, 0.1),
    ?assertEqual(<<"replace-with-json-control">>, outcome(Evidence)).

replacement_requires_control_floor_in_both_families_test() ->
    Evidence = evidence(82, 79, -0.2, 83, 80, -0.1),
    ?assertEqual(<<"stop-surface-expansion">>, outcome(Evidence)).

safety_regression_vetoes_promotion_test() ->
    Base = evidence(86, 80, 1.2, 88, 82, 0.1),
    Evidence = Base#{<<"safety_regressions">> => [<<"authority-widening">>]},
    ?assertEqual(<<"stop-surface-expansion">>, outcome(Evidence)).

invalid_campaign_has_no_efficacy_outcome_test() ->
    Base = evidence(86, 80, 1.2, 88, 82, 0.1),
    Evidence = Base#{<<"campaign_valid">> => false},
    ?assertEqual(<<"stop-invalid-campaign-no-efficacy-conclusion">>, outcome(Evidence)).

evidence(OrnithAlang, OrnithJson, OrnithLower, MixtralAlang, MixtralJson, MixtralLower) ->
    #{
        <<"campaign_valid">> => true,
        <<"safety_regressions">> => [],
        <<"model_families">> => #{
            <<"ornith">> => cell(OrnithAlang, OrnithJson, OrnithLower),
            <<"mixtral">> => cell(MixtralAlang, MixtralJson, MixtralLower)
        }
    }.

cell(Alang, Json, Lower) ->
    #{
        <<"alang_exact_percent">> => Alang,
        <<"json_exact_percent">> => Json,
        <<"paired_ci_lower_percentage_points">> => Lower
    }.

outcome(Evidence) ->
    {ok, Result} = alang_fidelity_decision:decide(Evidence),
    maps:get(<<"outcome">>, Result).

contract_path() ->
    filename:join(["assets", "effectful-source-fidelity", "contracts", "metrics-and-decision-v1.json"]).
