-module(alang_fidelity_integration_tests).

-include_lib("eunit/include/eunit.hrl").

phase_gate_validates_every_contract_test() ->
    {ok, Evidence} = alang_fidelity_preregister:validate_all(asset_root()),
    ?assertEqual(7, maps:get(<<"schemas_validated">>, Evidence)),
    ?assertEqual(24, maps:get(<<"semantic_cases">>, maps:get(<<"corpus">>, Evidence))),
    ?assertEqual(0, maps:get(<<"hosted_calls_observed">>, Evidence)),
    ?assertEqual(true, maps:get(<<"passed">>, maps:get(<<"scope_audit">>, Evidence))).

all_phase_modules_execute_as_beam_test() ->
    Modules = [
        alang_fidelity_json,
        alang_fidelity_contract,
        alang_fidelity_decision,
        alang_fidelity_representation,
        alang_fidelity_corpus,
        alang_fidelity_preregister,
        alang_fidelity_integration_tests
    ],
    lists:foreach(
        fun(Module) ->
            Path = code:which(Module),
            ?assert(is_list(Path)),
            ?assertEqual(".beam", filename:extension(Path))
        end,
        Modules
    ).

unknown_field_mutant_is_rejected_test() ->
    Expected = first_expected(),
    Mutant = Expected#{<<"surprise">> => true},
    ?assertMatch(
        {error, {contract_error, [], {unknown_fields, [<<"surprise">>]}}},
        alang_fidelity_contract:validate_comprehension(Mutant)
    ).

duplicate_case_mutant_is_rejected_test() ->
    Manifest = manifest(),
    [First, _Second | Rest] = maps:get(<<"cases">>, Manifest),
    Mutant = Manifest#{<<"cases">> => [First, First | Rest]},
    ?assertMatch(
        {error, {corpus_error, [<<"manifest">>, <<"cases">>], duplicate_case_id}},
        alang_fidelity_corpus:validate_manifest(Mutant, corpus_root())
    ).

missing_cell_mutant_is_rejected_test() ->
    Manifest = manifest(),
    [_First | Rest] = maps:get(<<"cases">>, Manifest),
    Mutant = Manifest#{<<"cases">> => Rest},
    ?assertMatch(
        {error, {corpus_error, [<<"manifest">>, <<"cases">>], {expected_case_count, 24, 23}}},
        alang_fidelity_corpus:validate_manifest(Mutant, corpus_root())
    ).

model_visible_answer_leak_mutant_is_rejected_test() ->
    Case = hd(maps:get(<<"cases">>, manifest())),
    Candidate = maps:get(<<"candidate">>, Case),
    Path = filename:join(corpus_root(), binary_to_list(maps:get(<<"path">>, Candidate))),
    {ok, Binary} = file:read_file(Path),
    Marker = <<"// model-visible-begin\n">>,
    Leaked = binary:replace(Binary, Marker, <<Marker/binary, "// alang-answer-key-v1\n">>),
    ?assertMatch(
        {error, {corpus_error, [<<"candidate">>], {model_visible_leak, <<"alang-answer-key-v1">>}}},
        alang_fidelity_corpus:validate_candidate_binary(
            Leaked,
            maps:get(<<"case_id">>, Case),
            maps:get(<<"semantic_digest">>, Case)
        )
    ).

unequal_semantics_mutant_is_rejected_test() ->
    Manifest = manifest(),
    [First | Rest] = maps:get(<<"cases">>, Manifest),
    Control = maps:get(<<"control">>, First),
    MutatedFirst = First#{<<"control">> => Control#{<<"semantic_digest">> => binary:copy(<<"0">>, 64)}},
    Mutant = Manifest#{<<"cases">> => [MutatedFirst | Rest]},
    ?assertMatch(
        {error, {corpus_error, _, {expected_exact_value, _, _}}},
        alang_fidelity_corpus:validate_manifest(Mutant, corpus_root())
    ).

unbounded_limit_mutant_is_rejected_test() ->
    Expected = first_expected(),
    Budgets = maps:get(<<"budgets">>, Expected),
    Mutant = Expected#{<<"budgets">> => Budgets#{<<"output_bytes">> => 8193}},
    ?assertMatch(
        {error, {contract_error, [<<"budgets">>, <<"output_bytes">>], _}},
        alang_fidelity_contract:validate_comprehension(Mutant)
    ).

alias_model_mutant_is_rejected_test() ->
    {ok, Profiles} = alang_fidelity_json:decode_file(profiles_path()),
    [Ornith, Mixtral] = maps:get(<<"profiles">>, Profiles),
    Mutant = Profiles#{<<"profiles">> => [Ornith, Mixtral#{<<"model_id">> => <<"mixtral-latest">>}]},
    ?assertMatch(
        {error, {campaign_error, [<<"profiles">>], {frozen_contract_mismatch, _, _}}},
        alang_fidelity_corpus:validate_provider_profiles(Mutant)
    ).

threshold_change_mutant_is_rejected_test() ->
    {ok, Decision} = alang_fidelity_json:decode_file(decision_path()),
    Promotion = maps:get(<<"promotion">>, Decision),
    Mutant = Decision#{<<"promotion">> => Promotion#{<<"minimum_absolute_percentage_points">> => 4}},
    ?assertMatch(
        {error, {decision_contract_error, [<<"promotion">>, <<"minimum_absolute_percentage_points">>], _}},
        alang_fidelity_decision:validate_contract(Mutant)
    ).

preregistration_digest_reproduces_byte_for_byte_test_() ->
    {timeout, 60, fun() ->
        Root = filename:join(["build", "effectful-source-fidelity", "phase-01", "reproduction-test"]),
        FirstPath = filename:join(Root, "first.json"),
        SecondPath = filename:join(Root, "second.json"),
        _ = file:del_dir_r(Root),
        try
            {ok, First} = alang_fidelity_preregister:write(asset_root(), FirstPath),
            {ok, Second} = alang_fidelity_preregister:write(asset_root(), SecondPath),
            ?assertEqual(86, maps:get(<<"registration_file_count">>, First)),
            ?assertEqual(maps:get(<<"registration_digest">>, First), maps:get(<<"registration_digest">>, Second)),
            ?assertEqual(maps:get(<<"evidence_digest">>, First), maps:get(<<"evidence_digest">>, Second)),
            {ok, FirstBytes} = file:read_file(FirstPath),
            {ok, SecondBytes} = file:read_file(SecondPath),
            ?assertEqual(FirstBytes, SecondBytes)
        after
            _ = file:del_dir_r(Root)
        end
    end}.

published_evidence_matches_generated_digest_test() ->
    {ok, Evidence} = alang_fidelity_preregister:build(asset_root()),
    {ok, Document} = file:read_file(filename:join(["src", "effectful-source-fidelity", "phase-01-integration-evidence.md"])),
    RegistrationDigest = maps:get(<<"registration_digest">>, Evidence),
    EvidenceDigest = maps:get(<<"evidence_digest">>, Evidence),
    ?assertNotEqual(nomatch, binary:match(Document, RegistrationDigest)),
    ?assertNotEqual(nomatch, binary:match(Document, EvidenceDigest)).

frozen_scope_audit_test() ->
    {ok, Audit} = alang_fidelity_preregister:scope_audit(asset_root()),
    ?assertEqual(true, maps:get(<<"passed">>, Audit)),
    ?assertEqual(0, maps:get(<<"foreign_trusted_sources">>, Audit)),
    Frozen = maps:get(<<"frozen_features_absent">>, Audit),
    ?assert(lists:member(<<"recursion">>, Frozen)),
    ?assert(lists:member(<<"parallelism">>, Frozen)),
    ?assert(lists:member(<<"categorical-surface-syntax">>, Frozen)).

first_expected() ->
    Case = hd(maps:get(<<"cases">>, manifest())),
    Answer = maps:get(<<"answer_key">>, Case),
    Path = filename:join(corpus_root(), binary_to_list(maps:get(<<"path">>, Answer))),
    {ok, Value} = alang_fidelity_json:decode_file(Path),
    maps:get(<<"expected">>, Value).

manifest() ->
    {ok, Manifest} = alang_fidelity_json:decode_file(filename:join(corpus_root(), "corpus-manifest-v1.json")),
    Manifest.

asset_root() ->
    filename:join(["assets", "effectful-source-fidelity"]).

corpus_root() ->
    filename:join(asset_root(), "corpus").

profiles_path() ->
    filename:join([asset_root(), "campaign", "provider-profiles-v1.json"]).

decision_path() ->
    filename:join([asset_root(), "contracts", "metrics-and-decision-v1.json"]).
