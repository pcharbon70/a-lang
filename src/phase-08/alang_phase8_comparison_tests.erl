-module(alang_phase8_comparison_tests).

-include_lib("eunit/include/eunit.hrl").

comparison_matrix_is_matched_and_reports_ablation_effects_test_() ->
    {timeout, 120, fun() ->
        Output = output(),
        try
            {ok, Evidence} = alang_phase8_comparison:run(Output),
            ?assertEqual(true, maps:get(semantic_agreement, Evidence)),
            Execution = maps:get(execution, Evidence),
            ?assertEqual(true, maps:get(matched, maps:get(pure_task, Execution))),
            ?assertEqual(true, maps:get(matched, maps:get(effect_task, Execution))),
            Authority = maps:get(authority, Evidence),
            Broker = maps:get(broker_enforced, Authority),
            Direct = maps:get(direct_runtime_handler, Authority),
            ?assertEqual([denied, succeeded, succeeded, denied],
                statuses(Broker)),
            ?assertEqual([succeeded, succeeded, succeeded, succeeded],
                statuses(Direct)),
            ?assertEqual(2, maps:get(denial_records, Broker)),
            ?assertEqual(0, maps:get(denial_records, Direct)),
            Validation = maps:get(correctness_and_recovery, Evidence),
            ?assertEqual(17, maps:get(detected,
                maps:get(semantic_defects, Validation))),
            ?assertEqual(63, maps:get(fault_cases, maps:get(recovery, Validation))),
            Summary = maps:get(summary, Evidence),
            ?assertEqual(2, maps:get(broker_denials, Summary)),
            ?assertEqual(2, maps:get(direct_unauthorized_successes, Summary)),
            ?assertEqual(not_established, maps:get(human_usability_claim, Summary)),
            ?assertMatch({ok, [_]}, file:consult(filename:join(Output,
                "comparison.config")))
        after
            _ = file:del_dir_r(Output)
        end
    end}.

statuses(Condition) -> [maps:get(status, Result) || Result <- maps:get(results, Condition)].

output() -> filename:absname(filename:join(["build", "phase-08", "comparison-tests",
    integer_to_list(erlang:unique_integer([positive, monotonic]))])).
