-module(alang_mnemonic_phase2_integration_tests).

-include_lib("eunit/include/eunit.hrl").

clean_process_evidence_is_identical_and_complete_test() ->
    {ok, A} = alang_fidelity_json:decode_file(evidence_a()),
    {ok, B} = alang_fidelity_json:decode_file(evidence_b()),
    ?assertEqual(A, B),
    ?assertEqual(<<"e00fe1b40807d052523a2999fc3584d9a4e5cf6736766cc4f0565f9c09c7417f">>,
        maps:get(<<"qualification_digest">>, A)),
    ?assertEqual(0, maps:get(<<"hosted_calls_observed">>, A)),
    ?assertEqual(false, maps:get(<<"network_authorized">>, A)),
    ?assertEqual(false, maps:get(<<"model_fidelity_claim">>, A)).

all_corpus_and_generated_replay_is_closed_test() ->
    {ok, Evidence} = alang_fidelity_json:decode_file(evidence_a()),
    Replay = maps:get(<<"replay">>, Evidence),
    ?assertEqual(24, maps:get(<<"development_cases">>, Replay)),
    ?assertEqual(48, maps:get(<<"prior_confirmatory_cases">>, Replay)),
    ?assertEqual(48, maps:get(<<"fresh_cases">>, Replay)),
    ?assertEqual(16, maps:get(<<"generated_cases">>, Replay)),
    ?assertEqual(136, maps:get(<<"valid_pair_count">>, Replay)),
    ?assertEqual(272, maps:get(<<"source_map_count">>, Replay)),
    ?assertEqual(6, maps:get(<<"invalid_conformance_inputs">>, Replay)),
    ?assertEqual(true, maps:get(<<"invalid_acceptance_classes_equal">>, Replay)).

all_named_mutants_are_detected_test() ->
    {ok, Qualification} = alang_fidelity_json:decode_file(qualification_path()),
    {ok, Mutation} = alang_mnemonic_phase2_mutation:run(".", Qualification),
    ?assertEqual(true, maps:get(<<"all_detected">>, Mutation)),
    ?assertEqual(18, maps:get(<<"detected">>, Mutation)),
    ?assertEqual(18, maps:get(<<"total">>, Mutation)),
    ?assertEqual(18, length(maps:get(<<"names">>, Mutation))).

trusted_residency_is_beam_only_test() ->
    {ok, Residency} = alang_mnemonic_phase2_residency:audit("."),
    ?assertEqual(<<"ERTS">>, maps:get(<<"engine">>, Residency)),
    ?assertEqual(16, maps:get(<<"module_count">>, Residency)),
    ?assertEqual(0, maps:get(<<"foreign_source_count">>, Residency)),
    ?assertEqual(0, maps:get(<<"forbidden_import_count">>, Residency)),
    ?assertEqual(false, maps:get(<<"ports">>, Residency)),
    ?assertEqual(false, maps:get(<<"nifs">>, Residency)),
    ?assertEqual(false, maps:get(<<"shell_commands">>, Residency)),
    ?assertEqual(false, maps:get(<<"interpreted_forms">>, Residency)).

qualification_and_authorization_digests_reconcile_test() ->
    {ok, Qualification} = alang_fidelity_json:decode_file(qualification_path()),
    {ok, Authorization} = alang_mnemonic_authorization:load(authorization_path()),
    ?assertEqual(maps:get(<<"qualification_digest">>, Qualification),
        maps:get(<<"qualification_digest">>, Authorization)),
    {ok, PhaseEvidence} = alang_fidelity_json:decode_file(evidence_a()),
    ?assertEqual(maps:get(<<"registration_digest">>, Qualification),
        maps:get(<<"registration_digest">>, PhaseEvidence)).

integration_modules_load_from_beam_test() ->
    lists:foreach(fun(Module) ->
        Path = code:which(Module), ?assert(is_list(Path)),
        ?assertEqual(".beam", filename:extension(Path))
    end, [alang_mnemonic_phase2_mutation, alang_mnemonic_phase2_residency,
        alang_mnemonic_phase2_evidence, alang_mnemonic_phase2_integration_worker]).

base() -> filename:join(["build", "token-positive-mnemonic-promotion", "phase-02", "evidence"]).
qualification_path() -> filename:join(base(), "qualification-a.json").
evidence_a() -> filename:join(base(), "phase-2-a.json").
evidence_b() -> filename:join(base(), "phase-2-b.json").
authorization_path() -> filename:join(["assets", "token-positive-mnemonic-promotion",
    "phase-02", "contracts", "authorization-v1.json"]).
