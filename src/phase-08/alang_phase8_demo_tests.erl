-module(alang_phase8_demo_tests).

-include_lib("eunit/include/eunit.hrl").

offline_demo_is_reproducible_and_inspectable_test_() ->
    {timeout, 60, fun() ->
        First = output("first"),
        Second = output("second"),
        try
            {ok, Evidence1} = alang_phase8_demo:run(First),
            {ok, Evidence2} = alang_phase8_demo:run(Second),
            ?assertEqual(maps:get(evidence_digest, Evidence1),
                maps:get(evidence_digest, Evidence2)),
            ?assertEqual(42, maps:get(result, maps:get(source, Evidence1))),
            ?assertEqual(complete,
                maps:get(status, maps:get(completion_witness, Evidence1))),
            ?assertEqual(#{network => disabled, secrets => none,
                capability_references_serialized => false}, maps:get(security, Evidence1)),
            ?assertMatch({ok, #{status := accepted}}, alang_phase8_inspect:verify(First)),
            ?assertMatch({ok, #{status := accepted}}, alang_phase8_inspect:verify(Second)),
            {ok, ExpectedOutput} = file:read_file(
                "src/phase-08/fixtures/expected-output.txt"),
            ?assertEqual({ok, ExpectedOutput}, file:read_file(
                filename:join(First, "workspace/reports/poc-result.md")))
        after
            _ = file:del_dir_r(First),
            _ = file:del_dir_r(Second)
        end
    end}.

inspector_rejects_tampered_artifact_test_() ->
    {timeout, 30, fun() ->
        Output = output("tamper"),
        try
            {ok, _Evidence} = alang_phase8_demo:run(Output),
            Path = filename:join(Output, "source.beam"),
            {ok, Beam} = file:read_file(Path),
            ok = file:write_file(Path, <<Beam/binary, 0>>),
            ?assertMatch({error, _}, alang_phase8_inspect:verify(Output))
        after
            _ = file:del_dir_r(Output)
        end
    end}.

output(Name) -> filename:absname(filename:join(["build", "phase-08", "demo-tests",
    Name ++ "-" ++ integer_to_list(erlang:unique_integer([positive, monotonic]))])).
