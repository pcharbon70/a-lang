-module(alang_compact_integration_tests).

-include_lib("eunit/include/eunit.hrl").

complete_registration_reconciles_test_() ->
    {timeout, 30, fun() ->
        {ok, Validation} = alang_compact_preregister:validate(assets_dir()),
        ?assertEqual(0, maps:get(<<"hosted_calls_observed">>, Validation)),
        ?assertEqual(0, maps:get(<<"efficacy_observations">>, Validation)),
        ?assertEqual(2304, length(maps:get(<<"cells">>, maps:get(<<"schedule">>, Validation)))),
        ?assertEqual(12, maps:get(<<"schema_count">>, maps:get(<<"schemas">>, Validation)))
    end}.

evidence_is_deterministic_and_matches_written_record_test_() ->
    {timeout, 30, fun() ->
        {ok, First} = alang_compact_preregister:build(assets_dir()),
        {ok, Second} = alang_compact_preregister:build(assets_dir()),
        ?assertEqual(First, Second),
        {ok, Written} = alang_fidelity_json:decode_file(evidence_path()),
        ?assertEqual(First, Written),
        ?assertEqual(23, maps:get(<<"registration_file_count">>, First)),
        ?assertEqual(0, maps:get(<<"hosted_calls_observed">>, First)),
        ?assertEqual(false, maps:get(<<"network_authorized">>, First))
    end}.

missing_cell_and_pseudoreplication_mutants_fail_test() ->
    {ok, Schedule} = alang_compact_schedule:materialize(campaign_dir()),
    {ok, Policy} = alang_fidelity_json:decode_file(filename:join([campaign_dir(), "schedule-policy-v1.json"])),
    {ok, Design} = alang_fidelity_json:decode_file(filename:join([campaign_dir(), "case-design-v1.json"])),
    Cells = maps:get(<<"cells">>, Schedule),
    ?assertMatch({error, _}, alang_compact_schedule:validate(Schedule#{<<"cells">> := tl(Cells)}, Policy, maps:get(<<"cases">>, Design))),
    ?assertMatch({error, _}, alang_compact_schedule:validate(Schedule, Policy#{<<"repetitions">> := 3}, maps:get(<<"cases">>, Design))),
    ?assertMatch({error, _}, alang_compact_schedule:validate(Schedule, Policy#{<<"seed">> := 2026081104}, maps:get(<<"cases">>, Design))).

corpus_duplicate_label_and_replacement_mutants_fail_test() ->
    {ok, Corpus} = alang_fidelity_json:decode_file(filename:join([assets_dir(), "corpus", "confirmatory-corpus-v1.json"])),
    {ok, Design} = alang_fidelity_json:decode_file(filename:join([campaign_dir(), "case-design-v1.json"])),
    [First, Second | Rest] = maps:get(<<"cases">>, Corpus),
    Duplicate = Corpus#{<<"cases">> := [First, First | Rest]},
    ?assertMatch({error, _}, alang_compact_corpus:validate(Duplicate, Design,
        filename:join(["assets", "effectful-source-fidelity", "corpus"]))),
    Leaked = First#{<<"request">> := <<(maps:get(<<"request">>, First))/binary, " Use R3.">>},
    ?assertMatch({error, _}, alang_compact_corpus:validate(Corpus#{<<"cases">> := [Leaked, Second | Rest]},
        Design, filename:join(["assets", "effectful-source-fidelity", "corpus"]))),
    {ok, Policy} = alang_fidelity_json:decode_file(filename:join([campaign_dir(), "campaign-policy-v1.json"])),
    Replacement = maps:get(<<"replacement">>, Policy),
    ?assertMatch({error, _}, alang_compact_registration:validate_policy(Policy#{<<"replacement">> :=
        Replacement#{<<"max_replacements_per_primary_cell">> := 2}})).

vocabulary_and_protocol_mutants_fail_test() ->
    {ok, Contract} = alang_compact_contract:load(filename:join([assets_dir(), "contracts", "campaign-contract-v1.json"])),
    {ok, Vocabulary} = alang_fidelity_json:decode_file(filename:join([campaign_dir(), "projection-vocabulary-v1.json"])),
    Security = maps:get(<<"security_policy">>, Vocabulary),
    ?assertThrow({compact_preregistration_error, _}, alang_compact_preregister:validate_vocabulary(
        Vocabulary#{<<"security_policy">> := Security#{<<"positional_security_fields">> := true}}, Contract)),
    {ok, Protocols} = alang_fidelity_json:decode_file(filename:join([campaign_dir(), "protocol-registry-v1.json"])),
    [First | Rest] = maps:get(<<"protocols">>, Protocols),
    Leaked = First#{<<"conditions">> := [<<"R0">>, <<"R1">>, <<"R3">>]},
    ?assertThrow({compact_preregistration_error, _}, alang_compact_preregister:validate_protocols(
        Protocols#{<<"protocols">> := [Leaked | Rest]}, Contract)).

traceability_and_prior_boundary_mutants_fail_test() ->
    {ok, Contract} = alang_compact_contract:load(filename:join([assets_dir(), "contracts", "campaign-contract-v1.json"])),
    {ok, Trace} = alang_fidelity_json:decode_file(filename:join([campaign_dir(), "traceability-v1.json"])),
    ?assertThrow({compact_preregistration_error, _}, alang_compact_preregister:validate_traceability(
        Trace#{<<"included_scope">> := maps:get(<<"included_scope">>, Trace) ++ [<<"compact-authored-surface">>]}, Contract, ".")),
    ?assertMatch({error, _}, alang_compact_preregister:prior_boundary(
        "assets/effectful-source-fidelity", <<"0000000000000000000000000000000000000000000000000000000000000000">>)).

contract_mutants_cannot_enter_registration_test() ->
    {ok, Contract} = alang_fidelity_json:decode_file(filename:join([assets_dir(), "contracts", "campaign-contract-v1.json"])),
    Inference = maps:get(<<"inference">>, Contract),
    ?assertMatch({error, _}, alang_compact_contract:validate(Contract#{<<"inference">> := Inference#{<<"model_families_separate">> := false}})),
    Promotion = maps:get(<<"promotion">>, Contract),
    ?assertMatch({error, _}, alang_compact_contract:validate(Contract#{<<"promotion">> :=
        Promotion#{<<"pooled_exact_fidelity_lower_strictly_above">> := -0.06}})),
    Conditions = maps:get(<<"conditions">>, Contract),
    R4 = hd([C || C <- Conditions, maps:get(<<"id">>, C) =:= <<"R4">>]),
    MutantConditions = [case maps:get(<<"id">>, C) of <<"R4">> -> R4#{<<"promotable">> := true}; _ -> C end || C <- Conditions],
    ?assertMatch({error, _}, alang_compact_contract:validate(Contract#{<<"conditions">> := MutantConditions})).

trusted_phase1_modules_load_from_beam_test() ->
    Modules = [alang_compact_contract, alang_compact_power, alang_compact_schedule,
        alang_compact_corpus, alang_compact_registration, alang_compact_preregister],
    lists:foreach(fun(Module) ->
        Path = code:which(Module),
        ?assert(is_list(Path)),
        ?assertEqual(".beam", filename:extension(Path))
    end, Modules).

assets_dir() -> filename:join(["assets", "compact-projection-fidelity"]).
campaign_dir() -> filename:join([assets_dir(), "campaign"]).
evidence_path() -> filename:join(["build", "compact-projection-fidelity", "phase-01", "evidence", "pre-registration-evidence.json"]).
