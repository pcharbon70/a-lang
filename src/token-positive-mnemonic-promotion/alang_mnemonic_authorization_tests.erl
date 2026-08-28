-module(alang_mnemonic_authorization_tests).

-include_lib("eunit/include/eunit.hrl").

exact_digest_and_explicit_opt_in_authorize_test_() ->
    {timeout, 300, fun() ->
        {ok, Evidence} = alang_fidelity_json:decode_file(evidence_path()),
        {ok, Token} = alang_mnemonic_authorization:authorize(Evidence, ".", #{
            <<"ALANG_ALLOW_MNEMONIC_MODEL_CALLS">> => <<"1">>}),
        ?assertEqual(true, maps:get(<<"authorized">>, Token)),
        ?assertEqual(maps:get(<<"qualification_digest">>, Evidence),
            maps:get(<<"qualification_digest">>, Token))
    end}.

missing_or_wrong_opt_in_fails_before_authorization_test() ->
    {ok, Evidence} = alang_fidelity_json:decode_file(evidence_path()),
    ?assertMatch({error, _}, alang_mnemonic_authorization:authorize(Evidence, ".", #{})),
    ?assertMatch({error, _}, alang_mnemonic_authorization:authorize(Evidence, ".", #{
        <<"ALANG_ALLOW_MNEMONIC_MODEL_CALLS">> => <<"true">>})).

authorization_contract_is_closed_test() ->
    {ok, Contract} = alang_mnemonic_authorization:load(contract_path()),
    ?assertMatch({error, _}, alang_mnemonic_authorization:validate(
        Contract#{<<"drift_policy">> := <<"warn">>})),
    ?assertMatch({error, _}, alang_mnemonic_authorization:validate(
        Contract#{<<"qualification_digest">> := zeros()})).

contract_path() -> filename:join(["assets", "token-positive-mnemonic-promotion",
    "phase-02", "contracts", "authorization-v1.json"]).
evidence_path() -> filename:join(["build", "token-positive-mnemonic-promotion",
    "phase-02", "evidence", "qualification-a.json"]).
zeros() -> <<"0000000000000000000000000000000000000000000000000000000000000000">>.
