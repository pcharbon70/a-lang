-module(alang_fidelity_phase4_integration_tests).

-include_lib("eunit/include/eunit.hrl").

-define(EVIDENCE,
    "build/effectful-source-fidelity/phase-04/evidence/source-to-beam-evidence.etf").
-define(REPRODUCTION_A,
    "build/effectful-source-fidelity/phase-04/evidence/reproduction-a.etf").
-define(REPRODUCTION_B,
    "build/effectful-source-fidelity/phase-04/evidence/reproduction-b.etf").
-define(EVIDENCE_SHA256,
    <<"bfc3d737c6ee66410533183ae204ac14ebdd2bfac0959bc310fb1495c26b1dc7">>).
-define(EVIDENCE_ARTIFACT_SHA256,
    <<"592921b7f60b55bed14216e122d22202ef172c7cfefeafbf90c1e37958ebb009">>).
-define(REPRODUCTION_SHA256,
    <<"d6e644bec7e162fade2d84e2a37715dc03847ada0e0f4e09f2df45e7a66a308d">>).
-define(REPRODUCTION_ARTIFACT_SHA256,
    <<"4aa20131fc2d7401d2276b3210b6978a8223aed89658824f7522d465771d227f">>).

published_evidence_covers_the_complete_offline_gate_test() ->
    Evidence = read_term(?EVIDENCE),
    ?assertEqual(ok, alang_fidelity_phase4_evidence:validate(Evidence)),
    ?assertEqual(?EVIDENCE_SHA256, maps:get(evidence_sha256, Evidence)),
    {ok, EvidenceBinary} = file:read_file(?EVIDENCE),
    ?assertEqual(?EVIDENCE_ARTIFACT_SHA256, digest_binary(EvidenceBinary)),
    Body = maps:get(evidence, Evidence),
    ?assertEqual(24, maps:get(case_count, Body)),
    ?assertEqual(48, maps:get(representation_count, Body)),
    ?assertEqual(48, maps:get(inspected_artifact_count, Body)),
    ?assertEqual(8, maps:get(fault_case_count, Body)),
    ?assertEqual(24, length(maps:get(pair_evidence, Body))),
    ?assert(lists:all(fun(Pair) ->
        maps:get(raw_artifacts_distinct, Pair) andalso
            maps:get(accounting_valid, Pair)
    end, maps:get(pair_evidence, Body))),
    ?assert(lists:all(fun(#{equal := Equal}) -> Equal end,
        maps:get(fault_cases, Body))),
    Faults = maps:from_list([{maps:get(scenario, Fault),
        maps:get(source_class, Fault)} || Fault <- maps:get(fault_cases, Body)]),
    ?assertEqual(#{
        denied_scope => scope_mismatch,
        exhausted_budget => budget_exhausted,
        malformed_response => repair_budget_exhausted,
        repair_failure => repair_failed,
        cancellation => cancelled,
        uncertain_workspace => outcome_unknown,
        wrong_digest => incomplete,
        missing_information => incomplete
    }, Faults).

separate_erts_processes_are_byte_reproducible_test() ->
    {ok, First} = file:read_file(?REPRODUCTION_A),
    {ok, Second} = file:read_file(?REPRODUCTION_B),
    ?assertEqual(First, Second),
    {ok, Reproduction} = alang_fidelity_phase4_worker:decode(First),
    ?assertEqual(?REPRODUCTION_SHA256,
        maps:get(bundle_sha256, Reproduction)),
    ?assertEqual(?REPRODUCTION_ARTIFACT_SHA256, digest_binary(First)),
    Body = maps:get(evidence, Reproduction),
    ?assertEqual(3, maps:get(case_count, Body)),
    ?assertEqual(6, maps:get(representation_count, Body)),
    lists:foreach(fun(Case) ->
        Source = maps:get(source, Case),
        Json = maps:get(json, Case),
        ?assertNotEqual(maps:get(beam, Source), maps:get(beam, Json)),
        ?assertEqual(maps:get(normalized_etf, Source),
            maps:get(normalized_etf, Json)),
        ?assertEqual(maps:get(artifact_content, Source),
            maps:get(artifact_content, Json)),
        ?assertEqual(maps:get(completion_witness_sha256, Source),
            maps:get(completion_witness_sha256, Json))
    end, maps:get(cases, Body)).

trusted_compiler_and_runtime_are_beam_resident_without_interpreter_test() ->
    Evidence = read_term(?EVIDENCE),
    Body = maps:get(evidence, Evidence),
    ?assert(lists:all(fun(#{is_beam := IsBeam}) -> IsBeam end,
        maps:get(module_residency, Body))),
    Boundary = maps:get(compiler_boundary, Body),
    ?assert(lists:all(fun(Value) -> Value end, maps:values(Boundary))),
    ?assertEqual(beam, maps:get(generated_execution, Body)),
    ?assertEqual(disabled, maps:get(network, Body)),
    ?assertEqual(0, maps:get(hosted_calls, Body)).

evidence_writers_reject_paths_outside_owned_build_root_test() ->
    ?assertEqual({error, evidence_path_outside_owned_root},
        alang_fidelity_phase4_evidence:write("/tmp/phase4-evidence.etf")),
    ?assertEqual({error, reproduction_path_outside_owned_root},
        alang_fidelity_phase4_worker:write("/tmp/phase4-reproduction.etf")).

read_term(Path) ->
    {ok, Binary} = file:read_file(Path),
    {ok, Evidence} = alang_fidelity_phase4_evidence:decode(Binary),
    Evidence.

digest_binary(Binary) ->
    hex(crypto:hash(sha256, Binary)).

hex(Binary) -> << <<(hex_digit(Nibble))>> || <<Nibble:4>> <= Binary >>.
hex_digit(Nibble) when Nibble < 10 -> $0 + Nibble;
hex_digit(Nibble) -> $a + Nibble - 10.
