-module(alang_mnemonic_qualification_tests).

-include_lib("eunit/include/eunit.hrl").

offline_gate_is_exact_complete_and_token_positive_test_() ->
    {timeout, 300, fun() ->
        {ok, Evidence} = alang_fidelity_json:decode_file(evidence_path()),
        ?assertEqual(48, maps:get(<<"semantic_cases">>, Evidence)),
        ?assertEqual(96, maps:get(<<"document_pairs">>, Evidence)),
        ?assertEqual(384, maps:get(<<"full_request_pairs">>, Evidence)),
        ?assertEqual(true, maps:get(<<"pass">>, maps:get(<<"gate">>, Evidence))),
        ?assertEqual(0, maps:get(<<"hosted_calls_observed">>, Evidence)),
        ?assertEqual(false, maps:get(<<"network_authorized">>, Evidence)),
        ?assertEqual(false, maps:get(<<"model_fidelity_claim">>, Evidence)),
        lists:foreach(fun(Profile) ->
            ?assert(maps:get(<<"document_aggregate_savings_basis_points">>, Profile) >= 500),
            ?assert(maps:get(<<"document_median_savings_basis_points">>, Profile) >= 500),
            ?assert(maps:get(<<"request_aggregate_savings_basis_points">>, Profile) >= 500),
            ?assert(maps:get(<<"request_median_savings_basis_points">>, Profile) >= 500)
        end, maps:get(<<"profiles">>, Evidence))
    end}.

threshold_and_vocabulary_drift_fail_test() ->
    {ok, Contract} = alang_fidelity_json:decode_file(contract_path()),
    Thresholds = maps:get(<<"thresholds">>, Contract),
    ?assertThrow({mnemonic_qualification_error, _},
        alang_mnemonic_qualification:validate_contract(Contract#{<<"thresholds">> :=
            Thresholds#{<<"minimum_median_request_savings_basis_points">> := 0}}, ".")),
    [First | Rest] = maps:get(<<"tokenizers">>, Contract),
    ?assertThrow({mnemonic_qualification_error, _},
        alang_mnemonic_qualification:validate_contract(Contract#{<<"tokenizers">> :=
            [First#{<<"vocabulary_sha256">> := zeros()} | Rest]}, ".")).

trusted_qualification_modules_load_from_beam_test() ->
    lists:foreach(fun(Module) ->
        Path = code:which(Module), ?assert(is_list(Path)),
        ?assertEqual(".beam", filename:extension(Path))
    end, [alang_mnemonic_qualification, alang_mnemonic_authorization,
        alang_compact_tokenizer]).

contract_path() -> filename:join(["assets", "token-positive-mnemonic-promotion",
    "phase-02", "contracts", "qualification-contract-v1.json"]).
zeros() -> <<"0000000000000000000000000000000000000000000000000000000000000000">>.
evidence_path() -> filename:join(["build", "token-positive-mnemonic-promotion",
    "phase-02", "evidence", "qualification-a.json"]).
