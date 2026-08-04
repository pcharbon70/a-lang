-module(alang_phase8_release_tests).

-include_lib("eunit/include/eunit.hrl").

archive_metadata_links_and_indexes_pass_test() ->
    {ok, Evidence} = alang_phase8_release:archive_check(),
    ?assertEqual(true, maps:get(passed, Evidence)),
    ?assert(maps:get(markdown_documents, Evidence) > 50),
    ?assert(maps:get(local_links, Evidence) > 100),
    ?assert(maps:get(readme_indexes, Evidence) > 20).

release_candidate_aggregates_all_gates_without_claiming_roadmap_completion_test_() ->
    {timeout, 120, fun() ->
        Output = filename:absname(filename:join(["build", "phase-08",
            "release-tests", integer_to_list(erlang:unique_integer([positive, monotonic]))])),
        try
            {ok, Evidence} = alang_phase8_release:run(Output),
            ?assertEqual(accepted_with_revised_roadmap, maps:get(status, Evidence)),
            ?assertEqual(revised_not_complete, maps:get(roadmap_status, Evidence)),
            ?assertEqual(not_approved, maps:get(production_status, Evidence)),
            ?assertEqual(<<"29.0.4">>, maps:get(otp_version,
                maps:get(supported_environment, Evidence))),
            ?assertEqual(<<"d1c693dba369ed6b39080b74fb18ad8f26d814cb88c563f8d5bd56a06f7bf21f">>,
                maps:get(demo_evidence_digest, Evidence)),
            ?assertEqual(true, maps:get(semantic_agreement,
                maps:get(comparison, Evidence))),
            ?assertEqual(1578, maps:get(total_validation_cases,
                maps:get(counts, maps:get(validation, Evidence)))),
            ?assertEqual(revise, maps:get(combined_architecture,
                maps:get(dispositions, maps:get(architecture_decision, Evidence)))),
            ?assertEqual([all_model_tool_storage_and_workspace_boundaries_are_os_bounded],
                maps:get(unmet_roadmap_items, Evidence)),
            ?assertEqual(true, alang_phase7_adversarial:surface_clean([Evidence], [])),
            ?assertMatch({ok, [_]}, file:consult(filename:join(Output,
                "release-evidence.config")))
        after
            _ = file:del_dir_r(Output)
        end
    end}.
