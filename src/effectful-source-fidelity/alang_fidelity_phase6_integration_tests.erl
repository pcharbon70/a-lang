-module(alang_fidelity_phase6_integration_tests).

-include_lib("eunit/include/eunit.hrl").

%% Phase 6 integration tests: verify decision module robustness
%% against mutation, evidence defects, and boundary conditions.

boundary_threshold_promotion_test() ->
    %% Exactly 5 percentage points advantage with positive lower bound
    Evidence = build_evidence_data(true, [], 85, 80, 0.1, 85, 80, 0.1),
    Report = alang_fidelity_decision_report:generate(#{}, Evidence),
    ?assertEqual(<<"promote-alang-source-v2">>, maps:get(outcome, Report)).

boundary_threshold_stop_test() ->
    %% Exactly 4 percentage points advantage (below 5-point threshold)
    Evidence = build_evidence_data(true, [], 84, 80, 0.1, 84, 80, 0.1),
    Report = alang_fidelity_decision_report:generate(#{}, Evidence),
    ?assertEqual(<<"replace-with-json-control">>, maps:get(outcome, Report)).

boundary_interval_zero_test() ->
    %% Promotion advantage met but interval exactly at zero (not strictly above)
    Evidence = build_evidence_data(true, [], 90, 80, 0.0, 90, 80, 0.0),
    Report = alang_fidelity_decision_report:generate(#{}, Evidence),
    ?assertEqual(<<"replace-with-json-control">>, maps:get(outcome, Report)).

boundary_control_floor_exactly_80_test() ->
    %% JSON exactly at 80% floor in both families
    Evidence = build_evidence_data(true, [], 70, 80, -5.0, 70, 80, -5.0),
    Report = alang_fidelity_decision_report:generate(#{}, Evidence),
    ?assertEqual(<<"replace-with-json-control">>, maps:get(outcome, Report)).

boundary_control_floor_below_80_test() ->
    %% JSON below 80% floor in one family
    Evidence = build_evidence_data(true, [], 70, 79, -5.0, 70, 80, -5.0),
    Report = alang_fidelity_decision_report:generate(#{}, Evidence),
    ?assertEqual(<<"stop-surface-expansion">>, maps:get(outcome, Report)).

family_disagreement_promotion_fails_test() ->
    %% One family passes promotion, other fails promotion → no promotion
    Evidence = build_evidence_data(true, [], 90, 80, 1.0, 82, 80, -1.0),
    Report = alang_fidelity_decision_report:generate(#{}, Evidence),
    %% Both families meet 80% JSON floor but only one passes promotion → replace
    ?assertEqual(<<"replace-with-json-control">>, maps:get(outcome, Report)).

safety_veto_single_family_test() ->
    %% Safety veto should stop even if both families would promote
    Evidence = build_evidence_data(true, [<<"false-completion">>, <<"unauthorized-effect">>], 90, 80, 1.0, 90, 80, 1.0),
    Report = alang_fidelity_decision_report:generate(#{}, Evidence),
    ?assertEqual(<<"stop-surface-expansion">>, maps:get(outcome, Report)),
    ?assertEqual(2, length(maps:get(safety_regressions, Report))).

invalid_campaign_with_safety_veto_test() ->
    %% Invalid campaign with safety vetoes → invalid campaign outcome (not safety stop)
    Evidence = build_evidence_data(false, [<<"false-completion">>], 90, 80, 1.0, 90, 80, 1.0),
    Report = alang_fidelity_decision_report:generate(#{}, Evidence),
    ?assertEqual(<<"stop-invalid-campaign-no-efficacy-conclusion">>, maps:get(outcome, Report)),
    ?assertEqual(false, maps:get(campaign_valid, Report)).

report_contains_all_required_fields_test() ->
    Evidence = build_evidence_data(true, [], 90, 80, 1.0, 90, 80, 1.0),
    Report = alang_fidelity_decision_report:generate(#{}, Evidence),
    ?assertEqual(alang_fidelity_decision_report_v1, maps:get(format, Report)),
    ?assert(is_map_key(outcome, Report)),
    ?assert(is_map_key(basis, Report)),
    ?assert(is_map_key(campaign_valid, Report)),
    ?assert(is_map_key(safety_regressions, Report)),
    ?assert(is_map_key(model_families, Report)),
    ?assert(is_map_key(predicate_summary, Report)),
    ?assert(is_map_key(registered_inference, Report)),
    ?assert(is_map_key(sensitivity_analysis, Report)),
    ?assert(is_map_key(generated_at, Report)).

format_outcome_unknown_test() ->
    Result = alang_fidelity_decision_report:format_outcome(#{outcome => <<"unknown-outcome">>}),
    ?assertEqual(1, string:str(Result, "UNKNOWN_OUTCOME")).

sensitivity_context_structure_test() ->
    Evidence = build_evidence_data(true, [], 90, 80, 1.0, 90, 80, 1.0),
    Context = alang_fidelity_decision_report:sensitivity_context(#{}, Evidence),
    ?assertEqual(alang_fidelity_sensitivity_context_v1, maps:get(format, Context)),
    ?assertEqual(true, maps:get(cannot_override_canonical_disposition, Context)),
    ?assertEqual(1, string:str(maps:get(note, Context), "descriptive")).

%% Helper functions

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

cell(Alang, Json, Lower) ->
    #{
        <<"alang_exact_percent">> => Alang,
        <<"json_exact_percent">> => Json,
        <<"paired_ci_lower_percentage_points">> => Lower
    }.
