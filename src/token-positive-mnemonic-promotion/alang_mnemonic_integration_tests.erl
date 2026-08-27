-module(alang_mnemonic_integration_tests).

-include_lib("eunit/include/eunit.hrl").

complete_registration_reconciles_test_() ->
    {timeout, 60, fun() ->
        {ok, Validation} = alang_mnemonic_preregister:validate(assets_dir()),
        ?assertEqual(0, maps:get(<<"hosted_calls_observed">>, Validation)),
        ?assertEqual(0, maps:get(<<"efficacy_observations">>, Validation)),
        ?assertEqual(1536, length(maps:get(<<"cells">>, maps:get(<<"schedule">>, Validation)))),
        ?assertEqual(11, maps:get(<<"schema_count">>, maps:get(<<"schemas">>, Validation)))
    end}.

evidence_is_deterministic_and_matches_written_record_test_() ->
    {timeout, 60, fun() ->
        {ok, First} = alang_mnemonic_preregister:build(assets_dir()),
        {ok, Second} = alang_mnemonic_preregister:build(assets_dir()),
        ?assertEqual(First, Second),
        {ok, WrittenA} = alang_fidelity_json:decode_file(evidence_a()),
        {ok, WrittenB} = alang_fidelity_json:decode_file(evidence_b()),
        ?assertEqual(First, WrittenA),
        ?assertEqual(WrittenA, WrittenB),
        ?assertEqual(21, maps:get(<<"registration_file_count">>, First)),
        ?assertEqual(false, maps:get(<<"network_authorized">>, First))
    end}.

design_evidence_cannot_claim_fidelity_test() ->
    {ok, Evidence} = alang_mnemonic_preregister:build(assets_dir()),
    Design = maps:get(<<"design_evidence">>, Evidence),
    ?assertEqual(<<"candidate-selection-and-threshold-design-only">>, maps:get(<<"role">>, Design)),
    ?assertEqual(false, maps:get(<<"model_fidelity_claim">>, Design)),
    ?assertEqual(0, maps:get(<<"model_calls_observed">>, Design)),
    ?assertEqual(72, maps:get(<<"previous_semantic_cases">>, Design)).

seeded_mutation_campaign_detects_every_named_defect_test_() ->
    {timeout, 60, fun() ->
        {ok, Mutation} = alang_mnemonic_mutation:run(assets_dir()),
        ?assertEqual(true, maps:get(<<"all_detected">>, Mutation)),
        ?assertEqual(19, maps:get(<<"detected">>, Mutation)),
        ?assertEqual(19, maps:get(<<"total">>, Mutation)),
        ?assertEqual(19, length(maps:get(<<"names">>, Mutation)))
    end}.

traceability_scope_mutant_is_rejected_test() ->
    {ok, Trace} = alang_fidelity_json:decode_file(filename:join([campaign_dir(),
        "traceability-v1.json"])),
    Included = maps:get(<<"included_scope">>, Trace),
    ?assertThrow({mnemonic_preregistration_error, _},
        alang_mnemonic_preregister:validate_traceability(
            Trace#{<<"included_scope">> := Included ++ [<<"historical-r2-role-rewrite">>]}, ".")).

trusted_phase1_modules_load_from_beam_test() ->
    Modules = [alang_mnemonic_contract, alang_mnemonic_power,
        alang_mnemonic_schedule, alang_mnemonic_corpus,
        alang_mnemonic_registration, alang_mnemonic_mutation,
        alang_mnemonic_preregister, alang_mnemonic_phase1_worker],
    lists:foreach(fun(Module) ->
        Path = code:which(Module),
        ?assert(is_list(Path)),
        ?assertEqual(".beam", filename:extension(Path))
    end, Modules).

assets_dir() -> filename:join(["assets", "token-positive-mnemonic-promotion"]).
campaign_dir() -> filename:join([assets_dir(), "campaign"]).
evidence_a() -> filename:join(["build", "token-positive-mnemonic-promotion",
    "phase-01", "evidence", "reproduction-a.json"]).
evidence_b() -> filename:join(["build", "token-positive-mnemonic-promotion",
    "phase-01", "evidence", "reproduction-b.json"]).
