-module(alang_phase7_campaign_tests).

-include_lib("eunit/include/eunit.hrl").

aggregate_campaign_test_() ->
    {timeout, 90, fun() ->
        Evidence = alang_phase7_campaign:run(),
        ?assertEqual(true, maps:get(passed, Evidence)),
        Counts = maps:get(counts, Evidence),
        ?assertEqual(1468, maps:get(generated_cases, Counts)),
        ?assertEqual(30, maps:get(fixed_attacks, Counts)),
        ?assertEqual(63, maps:get(fault_cases, Counts)),
        ?assertEqual(17, maps:get(seeded_defects, Counts)),
        ?assertEqual(10, maps:get(performance_metrics, Counts)),
        ?assertEqual(2, maps:get(comparison_baselines, Counts)),
        ?assertEqual(1578, maps:get(total_validation_cases, Counts)),
        ?assertEqual(<<"29.0.4">>, maps:get(erlang, maps:get(tools, Evidence))),
        ?assertEqual(<<"1.5.0">>, maps:get(proper, maps:get(tools, Evidence))),
        ?assert(alang_phase7_adversarial:surface_clean([Evidence], []))
    end}.

campaign_commands_are_explicit_test() ->
    Commands = alang_phase7_campaign:commands(),
    ?assert(lists:member(<<"make test-section-7-5">>, Commands)),
    ?assert(lists:member(<<"make test">>, Commands)).
