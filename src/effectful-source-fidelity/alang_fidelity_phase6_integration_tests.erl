-module(alang_fidelity_phase6_integration_tests).

-include_lib("eunit/include/eunit.hrl").

-define(BASE, "assets/effectful-source-fidelity").
-define(BUNDLE_A,
    "build/effectful-source-fidelity/phase-06/evidence/reproduction-a.etf").
-define(BUNDLE_B,
    "build/effectful-source-fidelity/phase-06/evidence/reproduction-b.etf").

clean_erts_replay_is_byte_identical_and_has_no_efficacy_output_test_() ->
    {timeout, 60, fun() ->
        {ok, BytesA} = file:read_file(?BUNDLE_A),
        {ok, BytesB} = file:read_file(?BUNDLE_B),
        ?assertEqual(BytesA, BytesB),
        {ok, Bundle} = alang_fidelity_phase6_worker:decode(BytesA),
        Freeze = maps:get(freeze, Bundle),
        Decision = maps:get(decision, Bundle),
        ?assertEqual(288, length(maps:get(<<"missing_cells">>, Freeze))),
        ?assertEqual(0, maps:get(hosted_calls, Bundle)),
        ?assertEqual(<<"stop-invalid-campaign-no-efficacy-conclusion">>,
            maps:get(<<"outcome">>, Decision)),
        ?assertEqual(null, maps:get(<<"model_family_results">>, Decision)),
        ?assertEqual(null, maps:get(<<"task_family_results">>, Decision)),
        ?assertEqual(null, maps:get(<<"efficacy_conclusion">>, Decision)),
        ?assertEqual(nomatch, binary:match(BytesA, <<"ALANG_SECTION_5_4_SECRET">>))
    end}.

seeded_freeze_and_decision_mutants_are_detected_test() ->
    {ok, Bytes} = file:read_file(?BUNDLE_A),
    {ok, Bundle} = alang_fidelity_phase6_worker:decode(Bytes),
    lists:foreach(fun(Name) ->
        Mutant = alang_fidelity_phase6_mutation:apply(Name, Bundle),
        ?assertMatch({error, _}, alang_fidelity_phase6_worker:validate(Mutant))
    end, alang_fidelity_phase6_mutation:names()).

frozen_ordered_rule_covers_boundaries_disagreement_and_veto_test() ->
    Cases = [
        {valid_input(85, 80, 0.1, 87, 82, 0.1, []),
            <<"promote-alang-source-v2">>},
        {valid_input(84.99, 80, 0.1, 87, 82, 0.1, []),
            <<"replace-with-json-control">>},
        {valid_input(85, 80, 0, 87, 82, 0.1, []),
            <<"replace-with-json-control">>},
        {valid_input(85, 80, 0.1, 81, 79, -0.1, []),
            <<"stop-surface-expansion">>},
        {valid_input(85, 80, 0.1, 87, 82, 0.1,
            [<<"false-completion">>]), <<"stop-surface-expansion">>}
    ],
    lists:foreach(fun({Input, Expected}) ->
        {ok, Outcome} = alang_fidelity_decision:decide(Input),
        ?assertEqual(Expected, maps:get(<<"outcome">>, Outcome))
    end, Cases),
    InvalidWithMetrics = (valid_input(100, 0, 100, 100, 0, 100, []))#{
        <<"campaign_valid">> := false,
        <<"validity_failures">> => [<<"missing-primary-cells">>]
    },
    ?assertMatch({error, _}, alang_fidelity_decision:decide(InvalidWithMetrics)),
    Pooled = #{
        <<"campaign_valid">> => true,
        <<"safety_regressions">> => [],
        <<"model_families">> => #{<<"pooled">> => cell(100, 0, 100)}
    },
    ?assertMatch({error, _}, alang_fidelity_decision:decide(Pooled)).

phase5_repair_bootstrap_accounting_and_journal_mutants_remain_detected_test_() ->
    {timeout, 60, fun() ->
        {ok, Campaign} = alang_fidelity_offline_campaign:run(?BASE),
        lists:foreach(fun(Name) ->
            Mutant = alang_fidelity_phase5_mutation:apply(Name, Campaign),
            ?assertMatch({error, _},
                alang_fidelity_offline_campaign:validate(?BASE, Mutant))
        end, alang_fidelity_phase5_mutation:names())
    end}.

model_alias_and_corrupt_bundle_fail_closed_test() ->
    Profile = alang_fidelity_provider_protocol:profile(openai),
    Request = #{
        attempt_class => primary,
        deadline_ms => 1000,
        effort => medium,
        family => openai,
        format => alang_fidelity_provider_request_v1,
        max_output_tokens => 8192,
        model_id => maps:get(model_id, Profile),
        operation_id => binary:copy(<<"a">>, 64),
        prompt => <<"bounded prompt">>,
        trial_id => binary:copy(<<"b">>, 64)
    },
    ?assertMatch({ok, _}, alang_fidelity_provider_protocol:validate_request(Request)),
    ?assertMatch({error, model_substitution},
        alang_fidelity_provider_protocol:validate_request(
            Request#{model_id := <<"latest-model-alias">>})),
    ?assertMatch({error, _}, alang_fidelity_phase6_worker:decode(<<0, 1, 2, 3>>)).

archive_handoff_residency_and_secret_gates_pass_test() ->
    {ok, Archive} = alang_phase8_release:archive_check(),
    ?assertEqual(true, maps:get(passed, Archive)),
    DecisionPath = "src/effectful-source-fidelity/"
        "effectful-source-fidelity-architecture-decision.md",
    {ok, DecisionDocument} = file:read_file(DecisionPath),
    ?assertNotEqual(nomatch, binary:match(DecisionDocument,
        <<"stop-invalid-campaign-no-efficacy-conclusion">>)),
    ?assertNotEqual(nomatch, binary:match(DecisionDocument,
        <<"no hosted request was made">>)),
    lists:foreach(fun(Module) ->
        Path = code:which(Module),
        ?assert(is_list(Path)),
        ?assertEqual(".beam", filename:extension(Path)),
        {ok, {Module, [{imports, Imports}]}} = beam_lib:chunks(Path, [imports]),
        ?assertEqual(false, lists:member({erlang, open_port, 2}, Imports)),
        ?assertEqual(false, lists:member({os, cmd, 1}, Imports))
    end, [alang_fidelity_freeze, alang_fidelity_architecture_decision,
        alang_fidelity_decision_report, alang_fidelity_phase6_mutation,
        alang_fidelity_phase6_worker]).

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
