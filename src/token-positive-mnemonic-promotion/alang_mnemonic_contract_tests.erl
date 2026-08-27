-module(alang_mnemonic_contract_tests).

-include_lib("eunit/include/eunit.hrl").

contract_and_exact_r2_references_load_test() ->
    {ok, Contract} = contract(),
    ?assertMatch({ok, #{<<"all_match">> := true}},
        alang_mnemonic_contract:validate_reference(Contract, ".")).

only_p1_is_promotable_and_it_reuses_r2_test() ->
    {ok, Contract} = contract(),
    Conditions = maps:get(<<"conditions">>, Contract),
    ?assertEqual([<<"P1">>], [maps:get(<<"id">>, C) || C <- Conditions,
        maps:get(<<"promotable">>, C)]),
    P1 = hd([C || C <- Conditions, maps:get(<<"id">>, C) =:= <<"P1">>]),
    ?assertEqual(<<"R2">>, maps:get(<<"source_condition">>, P1)),
    ?assertEqual(<<"alang-source-v2-alias-v1">>, maps:get(<<"version">>, P1)).

historical_role_and_threshold_mutants_fail_test() ->
    {ok, Contract} = contract(),
    Historical = maps:get(<<"historical_registration">>, Contract),
    ?assertMatch({error, _}, alang_mnemonic_contract:validate(Contract#{
        <<"historical_registration">> := Historical#{<<"r2_promotable">> := true}})),
    Promotion = maps:get(<<"promotion">>, Contract),
    Offline = maps:get(<<"offline">>, Promotion),
    ?assertMatch({error, _}, alang_mnemonic_contract:validate(Contract#{
        <<"promotion">> := Promotion#{<<"offline">> := Offline#{
            <<"minimum_aggregate_document_savings">> := 0.04}}})).

reference_digest_mutant_fails_test() ->
    {ok, Contract} = contract(),
    Reference = maps:get(<<"r2_reference">>, Contract),
    Mutant = Contract#{<<"r2_reference">> := Reference#{
        <<"renderer_sha256">> := <<"0000000000000000000000000000000000000000000000000000000000000000">>}},
    ?assertMatch({error, _}, alang_mnemonic_contract:validate_reference(Mutant, ".")).

invalid_campaign_precedes_other_outcomes_test() ->
    Evidence = (passing_evidence())#{<<"campaign_valid">> := false,
        <<"offline_token">> := failing_offline()},
    ?assertEqual(<<"stop-invalid-token-positive-campaign">>, outcome(Evidence)).

token_failure_precedes_safety_and_fidelity_test() ->
    Base = passing_evidence(),
    Unsafe = (maps:get(<<"safety">>, Base))#{<<"candidate_only_events">> := 1},
    Evidence = Base#{<<"offline_token">> := failing_offline(), <<"safety">> := Unsafe},
    ?assertEqual(<<"ineligible-token-negative-candidate">>, outcome(Evidence)).

safety_failure_precedes_fidelity_test() ->
    Base = passing_evidence(),
    Unsafe = (maps:get(<<"safety">>, Base))#{<<"round_trip_pass">> := false},
    Fidelity = mutate_one_fidelity(maps:get(<<"fidelity">>, Base), <<"exact_lower">>, -0.2),
    ?assertEqual(<<"reject-unsafe-mnemonic-candidate">>,
        outcome(Base#{<<"safety">> := Unsafe, <<"fidelity">> := Fidelity})).

all_gates_promote_exact_p1_test() ->
    {ok, Contract} = contract(),
    {ok, Decision} = alang_mnemonic_contract:decide(Contract, passing_evidence()),
    ?assertEqual(<<"promote-token-positive-mnemonic-view">>, maps:get(<<"outcome">>, Decision)),
    ?assertEqual(<<"P1">>, maps:get(<<"candidate">>, Decision)),
    ?assertEqual(<<"R2">>, maps:get(<<"reference_condition">>, Decision)).

strict_fidelity_boundary_retains_readable_test() ->
    Base = passing_evidence(),
    Fidelity = mutate_one_fidelity(maps:get(<<"fidelity">>, Base), <<"exact_lower">>, -0.05),
    ?assertEqual(<<"retain-readable-insufficient-fidelity">>, outcome(Base#{<<"fidelity">> := Fidelity})).

provider_pair_regression_is_token_negative_test() ->
    Base = passing_evidence(),
    Provider = maps:get(<<"provider_token">>, Base),
    ?assertEqual(<<"ineligible-token-negative-candidate">>, outcome(Base#{
        <<"provider_token">> := Provider#{<<"no_higher_input_pair">> := false}})).

unknown_evidence_field_is_rejected_test() ->
    {ok, Contract} = contract(),
    ?assertMatch({error, {mnemonic_evidence_error, [], _}},
        alang_mnemonic_contract:decide(Contract, (passing_evidence())#{<<"weighted_score">> => 1})).

trusted_contract_loads_from_beam_test() ->
    Path = code:which(alang_mnemonic_contract),
    ?assert(is_list(Path)),
    ?assertEqual(".beam", filename:extension(Path)).

passing_evidence() -> #{
    <<"campaign_valid">> => true,
    <<"offline_token">> => passing_offline(),
    <<"provider_token">> => #{
        <<"usage_complete_and_unestimated">> => true,
        <<"no_higher_input_pair">> => true,
        <<"strata">> => strata(fun() -> #{<<"input_savings">> => 0.06,
            <<"total_token_delta">> => -0.01} end)},
    <<"safety">> => #{<<"round_trip_pass">> => true,
        <<"inherited_gates_pass">> => true, <<"candidate_only_events">> => 0},
    <<"fidelity">> => #{<<"strata">> => strata(fun passing_fidelity/0)}
}.

passing_offline() -> #{
    <<"every_document_strictly_cheaper">> => true,
    <<"every_full_request_strictly_cheaper">> => true,
    <<"tokenizers">> => #{
        <<"cl100k_base">> => savings(), <<"o200k_base">> => savings()}
}.

failing_offline() -> (passing_offline())#{<<"every_document_strictly_cheaper">> := false}.

savings() -> #{
    <<"document_aggregate_savings">> => 0.08,
    <<"document_median_savings">> => 0.08,
    <<"request_aggregate_savings">> => 0.07,
    <<"request_median_savings">> => 0.07
}.

passing_fidelity() -> #{
    <<"exact_lower">> => -0.049,
    <<"point_difference">> => -0.01,
    <<"validity_difference">> => 0.0,
    <<"repair_difference">> => 0.0,
    <<"robustness_pass">> => true
}.

strata(Fun) -> maps:from_list([{Model,
    maps:from_list([{Protocol, Fun()} || Protocol <- protocols()])}
    || Model <- [<<"mixtral">>, <<"ornith">>]]).

mutate_one_fidelity(Fidelity, Key, Value) ->
    Strata = maps:get(<<"strata">>, Fidelity),
    Mixtral = maps:get(<<"mixtral">>, Strata),
    Comprehension = maps:get(<<"comprehension">>, Mixtral),
    Fidelity#{<<"strata">> := Strata#{<<"mixtral">> := Mixtral#{
        <<"comprehension">> := Comprehension#{Key := Value}}}}.

protocols() -> [<<"action-completion">>, <<"comprehension">>,
    <<"diagnostic-repair">>, <<"generation">>].

outcome(Evidence) ->
    {ok, Contract} = contract(),
    {ok, Decision} = alang_mnemonic_contract:decide(Contract, Evidence),
    maps:get(<<"outcome">>, Decision).

contract() -> alang_mnemonic_contract:load(contract_path()).
contract_path() -> filename:join(["assets", "token-positive-mnemonic-promotion",
    "contracts", "campaign-contract-v1.json"]).
