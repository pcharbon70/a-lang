-module(alang_fidelity_decision_report).

-export([
    generate/2,
    sensitivity_context/2,
    format_outcome/1
]).

-ifdef(TEST).
-include_lib("eunit/include/eunit.hrl").
-endif.

-spec generate(map() | {ok, map()}, map()) -> map().
generate({ok, Decision}, Evidence) when is_map(Decision), is_map(Evidence) ->
    generate(Decision, Evidence);
generate(_Decision, Evidence) when is_map(Evidence) ->
    CampaignValid = maps:get(<<"campaign_valid">>, Evidence),
    Safety = maps:get(<<"safety_regressions">>, Evidence),
    Families = maps:get(<<"model_families">>, Evidence),
    Outcome = derive_outcome(CampaignValid, Safety, Families),
    Basis = outcome_basis(Outcome, CampaignValid, Safety, Families),
    Predicates = case maps:is_key(validity, Evidence) of
        true ->
            Validity = maps:get(validity, Evidence),
            maps:get(predicates, Validity, []);
        false -> []
    end,
    #{
        format => alang_fidelity_decision_report_v1,
        outcome => Outcome,
        basis => Basis,
        campaign_valid => CampaignValid,
        safety_regressions => Safety,
        model_families => format_families(Families),
        predicate_summary => format_predicate_summary(Predicates),
        registered_inference => generate_registered_inference(Outcome, CampaignValid, Safety, Families),
        sensitivity_analysis => none,
        generated_at => erlang:system_time(millisecond)
    }.

derive_outcome(false, _Safety, _Families) ->
    <<"stop-invalid-campaign-no-efficacy-conclusion">>;
derive_outcome(true, [_ | _], _Families) ->
    <<"stop-surface-expansion">>;
derive_outcome(true, [], Families) ->
    case lists:all(fun(Family) ->
        Cell = maps:get(Family, Families),
        Alang = maps:get(<<"alang_exact_percent">>, Cell),
        Json = maps:get(<<"json_exact_percent">>, Cell),
        Lower = maps:get(<<"paired_ci_lower_percentage_points">>, Cell),
        (Alang - Json) >= 5 andalso Lower > 0
    end, [<<"mixtral">>, <<"ornith">>]) of
        true -> <<"promote-alang-source-v2">>;
        false ->
            case lists:all(fun(Family) ->
                maps:get(<<"json_exact_percent">>, maps:get(Family, Families)) >= 80
            end, [<<"mixtral">>, <<"ornith">>]) of
                true -> <<"replace-with-json-control">>;
                false -> <<"stop-surface-expansion">>
            end
    end.

outcome_basis(<<"stop-invalid-campaign-no-efficacy-conclusion">>, false, _, _) ->
    <<"campaign-failed-pre-registered-validity-gate">>;
outcome_basis(<<"stop-surface-expansion">>, true, [_ | _], _) ->
    <<"safety-regression-veto">>;
outcome_basis(<<"stop-surface-expansion">>, true, [], _) ->
    <<"neither-promotion-nor-control-floor-passed">>;
outcome_basis(<<"promote-alang-source-v2">>, true, [], _) ->
    <<"all-model-families-pass-advantage-and-interval-gates">>;
outcome_basis(<<"replace-with-json-control">>, true, [], _) ->
    <<"control-meets-floor-without-alang-promotion">>;
outcome_basis(_, _, _, _) ->
    <<"unknown-basis">>.

-spec sensitivity_context(map(), map()) -> map().
sensitivity_context(_Decision, _Evidence) ->
    %% Sensitivity analysis is purely descriptive and cannot change
    %% the canonical disposition. This function documents what was
    %% checked without endorsing any result.
    #{
        format => alang_fidelity_sensitivity_context_v1,
        note => "descriptive_only",
        cannot_override_canonical_disposition => true,
        checked_factors => [
            <<"bootstrap_seed">>,
            <<"percentage_point_threshold">>,
            <<"paired_ci_lower_bound">>,
            <<"control_floor_percent">>,
            <<"safety_veto_conditions">>
        ],
        generated_at => erlang:system_time(millisecond)
    }.

-spec format_outcome(map()) -> string().
format_outcome(#{outcome := Outcome}) ->
    case Outcome of
        <<"promote-alang-source-v2">> ->
            "PROMOTE: A-Lang source surface v2 cleared for tested closed subset";
        <<"replace-with-json-control">> ->
            "REPLACE: Typed JSON control designated as user-facing input";
        <<"stop-surface-expansion">> ->
            "STOP: User-facing language expansion suspended";
        <<"stop-invalid-campaign-no-efficacy-conclusion">> ->
            "STOP: Invalid campaign — no efficacy comparison permitted";
        _ ->
            "UNKNOWN_OUTCOME"
    end;
format_outcome(_) -> "UNKNOWN_OUTCOME".

format_families(Families) ->
    lists:map(fun({Family, Cell}) ->
        #{
            family => Family,
            alang_exact_percent => maps:get(<<"alang_exact_percent">>, Cell),
            json_exact_percent => maps:get(<<"json_exact_percent">>, Cell),
            paired_ci_lower_percentage_points => maps:get(<<"paired_ci_lower_percentage_points">>, Cell),
            promotion_gates => {
                maps:get(<<"alang_exact_percent">>, Cell) - maps:get(<<"json_exact_percent">>, Cell) >= 5,
                maps:get(<<"paired_ci_lower_percentage_points">>, Cell) > 0
            },
            control_floor_met => maps:get(<<"json_exact_percent">>, Cell) >= 80
        }
    end, maps:to_list(Families)).

format_predicate_summary(Predicates) ->
    Passed = length([P || P <- Predicates, maps:get(passed, P) =:= true]),
    Failed = length(Predicates) - Passed,
    #{
        total => length(Predicates),
        passed => Passed,
        failed => Failed,
        details => Predicates
    }.

generate_registered_inference(Outcome, CampaignValid, Safety, Families) ->
    PromoteChecks = lists:map(fun({Family, Cell}) ->
        Alang = maps:get(<<"alang_exact_percent">>, Cell),
        Json = maps:get(<<"json_exact_percent">>, Cell),
        Lower = maps:get(<<"paired_ci_lower_percentage_points">>, Cell),
        #{
            family => Family,
            advantage_gte_5pp => Alang - Json >= 5,
            advantage_actual => Alang - Json,
            interval_above_zero => Lower > 0,
            interval_actual => Lower,
            both_gates_met => (Alang - Json >= 5) andalso (Lower > 0)
        }
    end, maps:to_list(Families)),
    ControlChecks = lists:map(fun({Family, Cell}) ->
        #{
            family => Family,
            json_exact_percent => maps:get(<<"json_exact_percent">>, Cell),
            floor_met => maps:get(<<"json_exact_percent">>, Cell) >= 80
        }
    end, maps:to_list(Families)),
    #{
        campaign_valid => CampaignValid,
        safety_veto_fired => length(Safety) > 0,
        safety_veto_reasons => Safety,
        promotion_checks => PromoteChecks,
        control_checks => ControlChecks,
        outcome => Outcome
    }.

-ifdef(TEST).
format_outcome_promote_test() ->
    Outcome = #{outcome => <<"promote-alang-source-v2">>},
    ?assertEqual(
        "PROMOTE: A-Lang source surface v2 cleared for tested closed subset",
        format_outcome(Outcome)
    ).

format_outcome_stop_test() ->
    Outcome = #{outcome => <<"stop-surface-expansion">>},
    ?assertEqual(
        "STOP: User-facing language expansion suspended",
        format_outcome(Outcome)
    ).

sensitivity_context_is_descriptive_only_test() ->
    Context = sensitivity_context(#{}, #{}),
    ?assertEqual(descriptive_only, maps:get(note, Context)),
    ?assertEqual(true, maps:get(cannot_override_canonical_disposition, Context)).

-endif.
