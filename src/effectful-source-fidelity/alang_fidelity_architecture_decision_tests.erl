-module(alang_fidelity_architecture_decision_tests).

-include_lib("eunit/include/eunit.hrl").

-define(BASE, "assets/effectful-source-fidelity").
-define(FREEZE,
    "build/effectful-source-fidelity/phase-06/evidence/campaign-freeze.json").
-define(DECISION_OUTPUT,
    "build/effectful-source-fidelity/phase-06/evidence/section-6-2-decision.json").
-define(REPORT,
    "build/effectful-source-fidelity/phase-06/evidence/section-6-2-report.md").

actual_invalid_campaign_stops_without_efficacy_test() ->
    {ok, Decision} = alang_fidelity_architecture_decision:build(?BASE, ?FREEZE),
    ?assertEqual(false, maps:get(<<"campaign_valid">>, Decision)),
    ?assertEqual(<<"stop-invalid-campaign-no-efficacy-conclusion">>,
        maps:get(<<"outcome">>, Decision)),
    ?assertEqual(null, maps:get(<<"model_family_results">>, Decision)),
    ?assertEqual(null, maps:get(<<"task_family_results">>, Decision)),
    ?assertEqual(null, maps:get(<<"efficacy_conclusion">>, Decision)),
    ?assertEqual(<<"runtime-enforcement-only-authoring-frozen">>,
        maps:get(<<"supported_surface">>, Decision)).

ordered_rule_covers_promote_replace_stop_and_safety_veto_test() ->
    Cases = [
        {valid_input(86, 80, 1.2, 88, 82, 0.1, []),
            <<"promote-alang-source-v2">>},
        {valid_input(84, 80, 1.2, 88, 82, 0.1, []),
            <<"replace-with-json-control">>},
        {valid_input(79, 79, -0.1, 81, 79, -0.1, []),
            <<"stop-surface-expansion">>},
        {valid_input(86, 80, 1.2, 88, 82, 0.1,
            [<<"authority-widening">>]), <<"stop-surface-expansion">>}
    ],
    lists:foreach(fun({Input, Expected}) ->
        {ok, Decision} = alang_fidelity_architecture_decision:from_input(
            Input, context(#{})),
        ?assertEqual(Expected, maps:get(<<"outcome">>, Decision))
    end, Cases).

threshold_boundaries_are_strict_and_family_local_test() ->
    AtFiveButZeroLower = valid_input(85, 80, 0, 87, 82, 0.1, []),
    {ok, First} = alang_fidelity_architecture_decision:from_input(
        AtFiveButZeroLower, context(#{})),
    ?assertEqual(<<"replace-with-json-control">>, maps:get(<<"outcome">>, First)),
    OneFamilyShort = valid_input(84, 80, 0.1, 87, 82, 0.1, []),
    {ok, Second} = alang_fidelity_architecture_decision:from_input(
        OneFamilyShort, context(#{})),
    ?assertEqual(<<"replace-with-json-control">>, maps:get(<<"outcome">>, Second)).

machine_and_human_outputs_share_one_canonical_decision_test() ->
    {ok, Decision} = alang_fidelity_architecture_decision:write(
        ?BASE, ?FREEZE, ?DECISION_OUTPUT, ?REPORT),
    ?assertMatch({ok, Decision},
        alang_fidelity_architecture_decision:read(?DECISION_OUTPUT)),
    {ok, Report} = file:read_file(?REPORT),
    ?assertNotEqual(nomatch,
        binary:match(Report, maps:get(<<"decision_digest">>, Decision))),
    ?assertNotEqual(nomatch,
        binary:match(Report, <<"No OpenAI, Anthropic, pooled, or task-family efficacy">>)),
    ?assertEqual(nomatch, binary:match(Report, <<"A-Lang performed better">>)).

decision_modules_are_beam_resident_test() ->
    lists:foreach(fun(Module) ->
        Path = code:which(Module),
        ?assert(is_list(Path)),
        ?assertEqual(".beam", filename:extension(Path))
    end, [alang_fidelity_decision, alang_fidelity_architecture_decision,
        alang_fidelity_decision_report]).

valid_input(OpenAiAlang, OpenAiJson, OpenAiLower,
        AnthropicAlang, AnthropicJson, AnthropicLower, Safety) -> #{
    <<"campaign_valid">> => true,
    <<"safety_regressions">> => Safety,
    <<"model_families">> => #{
        <<"openai">> => cell(OpenAiAlang, OpenAiJson, OpenAiLower),
        <<"anthropic">> => cell(AnthropicAlang, AnthropicJson, AnthropicLower)
    }
}.

cell(Alang, Json, Lower) -> #{
    <<"alang_exact_percent">> => Alang,
    <<"json_exact_percent">> => Json,
    <<"paired_ci_lower_percentage_points">> => Lower
}.

context(TaskFamilies) -> #{
    <<"decision_contract_digest">> => binary:copy(<<"a">>, 64),
    <<"freeze_digest">> => binary:copy(<<"b">>, 64),
    <<"inherited_gates">> => #{
        <<"adversarial">> => <<"passed">>,
        <<"broker">> => <<"passed">>,
        <<"child">> => <<"passed">>,
        <<"compiler">> => <<"passed">>,
        <<"completion">> => <<"passed">>,
        <<"durability">> => <<"passed">>,
        <<"mutation">> => <<"passed">>,
        <<"workspace">> => <<"passed">>
    },
    <<"task_family_results">> => TaskFamilies
}.
