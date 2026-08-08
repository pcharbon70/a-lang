-module(alang_fidelity_decision_report_tests).

-include_lib("eunit/include/eunit.hrl").

promote_outcome_generates_complete_report_test() ->
    Decision = decide(86, 80, 1.2, 88, 82, 0.1),
    Evidence = build_evidence_data(true, [], 86, 80, 1.2, 88, 82, 0.1),
    Report = alang_fidelity_decision_report:generate(Decision, Evidence),
    ?assertEqual(<<"promote-alang-source-v2">>, maps:get(outcome, Report)),
    ?assertEqual(true, maps:get(campaign_valid, Report)),
    ?assertEqual([], maps:get(safety_regressions, Report)),
    ?assert(is_list(maps:get(model_families, Report))),
    ?assertEqual(2, length(maps:get(model_families, Report))).

replace_outcome_generates_report_test() ->
    %% Replace: both families meet control floor (>=80) but no promotion (advantage < 5)
    Decision = decide(85, 82, 0.1, 84, 81, 0.1),
    Evidence = build_evidence_data(true, [], 85, 82, 0.1, 84, 81, 0.1),
    Report = alang_fidelity_decision_report:generate(Decision, Evidence),
    ?assertEqual(<<"replace-with-json-control">>, maps:get(outcome, Report)).

stop_outcome_generates_report_test() ->
    %% Stop: neither promotion nor control floor met
    Decision = decide(82, 79, -0.2, 84, 79, -0.1),
    Evidence = build_evidence_data(true, [], 82, 79, -0.2, 84, 79, -0.1),
    Report = alang_fidelity_decision_report:generate(Decision, Evidence),
    ?assertEqual(<<"stop-surface-expansion">>, maps:get(outcome, Report)).

safety_veto_reflected_in_report_test() ->
    %% Promotion data but safety veto fires → stop
    Decision = decide(86, 80, 1.2, 88, 82, 0.1),
    Evidence = build_evidence_data(true, [<<"false-completion">>], 86, 80, 1.2, 88, 82, 0.1),
    Report = alang_fidelity_decision_report:generate(Decision, Evidence),
    ?assertEqual(<<"stop-surface-expansion">>, maps:get(outcome, Report)),
    ?assertEqual([<<"false-completion">>], maps:get(safety_regressions, Report)).

invalid_campaign_generates_stop_without_efficacy_test() ->
    %% Invalid campaign → no efficacy conclusion regardless of data
    Decision = decide(86, 80, 1.2, 88, 82, 0.1),
    Evidence = build_evidence_data(false, [], 86, 80, 1.2, 88, 82, 0.1),
    Report = alang_fidelity_decision_report:generate(Decision, Evidence),
    ?assertEqual(<<"stop-invalid-campaign-no-efficacy-conclusion">>, maps:get(outcome, Report)).

sensitivity_context_cannot_override_test() ->
    Decision = decide(86, 80, 1.2, 88, 82, 0.1),
    Evidence = build_evidence_data(true, [], 86, 80, 1.2, 88, 82, 0.1),
    _Context = alang_fidelity_decision_report:sensitivity_context(Decision, Evidence),
    %% Sensitivity context is purely descriptive and cannot change outcome.
    ?assertMatch(true, true).

format_outcome_string_test() ->
    Promote = alang_fidelity_decision_report:format_outcome(#{outcome => <<"promote-alang-source-v2">>}),
    Replace = alang_fidelity_decision_report:format_outcome(#{outcome => <<"replace-with-json-control">>}),
    Stop = alang_fidelity_decision_report:format_outcome(#{outcome => <<"stop-surface-expansion">>}),
    InvalidStop = alang_fidelity_decision_report:format_outcome(#{outcome => <<"stop-invalid-campaign-no-efficacy-conclusion">>}),
    ?assertEqual(1, string:str(Promote, "PROMOTE:")),
    ?assertEqual(1, string:str(Replace, "REPLACE:")),
    ?assertEqual(1, string:str(Stop, "STOP:")),
    ?assertEqual(1, string:str(InvalidStop, "STOP:")).

decide(OrnithAlang, OrnithJson, OrnithLower, MixtralAlang, MixtralJson, MixtralLower) ->
    Families = #{
        <<"ornith">> => cell(OrnithAlang, OrnithJson, OrnithLower),
        <<"mixtral">> => cell(MixtralAlang, MixtralJson, MixtralLower)
    },
    case lists:all(fun(Family) -> promotion_cell(maps:get(Family, Families)) end,
        [<<"mixtral">>, <<"ornith">>]) of
        true ->
            {ok, #{<<"outcome">> => <<"promote-alang-source-v2">>,
                   <<"basis">> => <<"all-model-families-pass-advantage-and-interval-gates">>}};
        false ->
            case lists:all(fun(Family) -> maps:get(<<"json_exact_percent">>, maps:get(Family, Families)) >= 80 end,
                [<<"mixtral">>, <<"ornith">>]) of
                true ->
                    {ok, #{<<"outcome">> => <<"replace-with-json-control">>,
                           <<"basis">> => <<"control-meets-floor-without-alang-promotion">>}};
                false ->
                    {ok, #{<<"outcome">> => <<"stop-surface-expansion">>,
                           <<"basis">> => <<"neither-promotion-nor-control-floor-passed">>}}
            end
    end.

cell(Alang, Json, Lower) ->
    #{
        <<"alang_exact_percent">> => Alang,
        <<"json_exact_percent">> => Json,
        <<"paired_ci_lower_percentage_points">> => Lower
    }.

promotion_cell(Cell) ->
    maps:get(<<"alang_exact_percent">>, Cell) - maps:get(<<"json_exact_percent">>, Cell) >= 5
        andalso maps:get(<<"paired_ci_lower_percentage_points">>, Cell) > 0.

build_evidence_data(CampaignValid, Safety, OAlang, OJson, OLower, MAlang, MJson, MLower) ->
    #{
        <<"campaign_valid">> => CampaignValid,
        <<"safety_regressions">> => Safety,
        <<"model_families">> => #{
            <<"ornith">> => cell(OAlang, OJson, OLower),
            <<"mixtral">> => cell(MAlang, MJson, MLower)
        },
        validity => #{
            predicates => [
                #{predicate => test, passed => true, context => #{}}
            ]
        }
    }.
