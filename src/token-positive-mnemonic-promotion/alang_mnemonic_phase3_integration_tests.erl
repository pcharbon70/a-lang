-module(alang_mnemonic_phase3_integration_tests).

-include_lib("eunit/include/eunit.hrl").

all_registered_faults_and_mutants_are_detected_test() ->
    {ok, Mutation} = alang_mnemonic_phase3_mutation:run("."),
    ?assertEqual(true, maps:get(<<"all_detected">>, Mutation)),
    ?assertEqual(21, maps:get(<<"detected">>, Mutation)),
    ?assertEqual(21, maps:get(<<"total">>, Mutation)).

network_is_confined_to_authorized_adapter_test() ->
    {ok, Residency} = alang_mnemonic_phase3_residency:audit("."),
    ?assertEqual(<<"ERTS">>, maps:get(<<"engine">>, Residency)),
    ?assertEqual(12, maps:get(<<"module_count">>, Residency)),
    ?assertEqual([<<"alang_mnemonic_ollama">>], maps:get(<<"network_modules">>, Residency)),
    ?assertEqual(0, maps:get(<<"foreign_source_count">>, Residency)),
    ?assertEqual(false, maps:get(<<"ports">>, Residency)),
    ?assertEqual(false, maps:get(<<"nifs">>, Residency)),
    ?assertEqual(false, maps:get(<<"shell_commands">>, Residency)).

registered_ceiling_arithmetic_and_boundaries_test() ->
    {ok, Policy} = alang_fidelity_json:decode_file(
        "assets/token-positive-mnemonic-promotion/campaign/campaign-policy-v1.json"),
    ?assertEqual(ok, alang_mnemonic_limits:validate_registered_bounds(Policy)),
    Projection = #{input_bytes => 32768, response_bytes => 8192,
        output_tokens => 8192, timeout_ms => 120000},
    ?assertEqual(ok, alang_mnemonic_limits:admit(Policy,
        #{calls => 3071, compute_ms => 0}, Projection)),
    ?assertMatch({error, _}, alang_mnemonic_limits:admit(Policy,
        #{calls => 3072, compute_ms => 0}, Projection)).

qualification_digest_remains_frozen_and_no_observations_are_claimed_test_() ->
    {timeout, 30, fun qualification_digest_remains_frozen_and_no_observations_are_claimed/0}.
qualification_digest_remains_frozen_and_no_observations_are_claimed() ->
    {ok, Q} = alang_mnemonic_qualification:build("."),
    ?assertEqual(<<"e00fe1b40807d052523a2999fc3584d9a4e5cf6736766cc4f0565f9c09c7417f">>,
        maps:get(<<"qualification_digest">>, Q)),
    ?assertEqual(0, maps:get(<<"hosted_calls_observed">>, Q)),
    ?assertEqual(0, maps:get(<<"efficacy_observations">>, Q)),
    ?assertEqual(false, maps:get(<<"model_fidelity_claim">>, Q)).

complete_evidence_is_observational_and_digest_closed_test() ->
    State = complete_state(), Replay = complete_replay(),
    Mutation = #{<<"all_detected">> => true, <<"detected">> => 21, <<"total">> => 21},
    Residency = #{<<"engine">> => <<"ERTS">>, <<"module_count">> => 12,
        <<"foreign_source_count">> => 0, <<"forbidden_import_count">> => 0},
    {ok, Evidence} = alang_mnemonic_evidence:build(
        State, Replay, Mutation, Residency),
    ?assertEqual(ok, alang_mnemonic_evidence:validate(Evidence)),
    ?assertEqual(true, maps:get(<<"observations_only">>, Evidence)),
    ?assertEqual(false, maps:get(<<"decision_applied">>, Evidence)),
    Incomplete = State#{observations := lists:duplicate(1535, #{})},
    ?assertMatch({error, _}, alang_mnemonic_evidence:build(
        Incomplete, Replay, Mutation, Residency)).

phase3_modules_load_from_beam_test() ->
    lists:foreach(fun(Module) ->
        Path = code:which(Module), ?assert(is_list(Path)),
        ?assertEqual(".beam", filename:extension(Path))
    end, [alang_mnemonic_live_gate, alang_mnemonic_journal, alang_mnemonic_runner,
        alang_mnemonic_ollama, alang_mnemonic_campaign, alang_mnemonic_observation,
        alang_mnemonic_replay, alang_mnemonic_limits, alang_mnemonic_evidence,
        alang_mnemonic_campaign_worker, alang_mnemonic_phase3_mutation,
        alang_mnemonic_phase3_residency]).

complete_state() ->
    {ok, Profiles} = alang_fidelity_json:decode_file(
        "assets/token-positive-mnemonic-promotion/campaign/provider-profiles-v1.json"),
    TokenProfiles = [maps:with([<<"family">>, <<"model_id">>,
        <<"manifest_sha256">>, <<"request_parameters">>, <<"accepted_output_bytes">>], P)
        || P <- maps:get(<<"profiles">>, Profiles)],
    #{runner => #{schedule_digest => zeros(), cursor => 1536, calls => 1536,
          replacements => #{}, compute_ms => 1, pending => none, invalid => false},
      journal => #{records => lists:duplicate(3072,
          #{kind => trial_result, record_digest => zeros()}), head_digest => zeros()},
      token => #{<<"profiles">> => TokenProfiles},
      qualification => #{<<"qualification_digest">> => zeros()},
      observations => lists:duplicate(1536, #{})}.
complete_replay() -> #{<<"replay_digest">> => zeros(), <<"usage_digest">> => zeros(),
    <<"score_digest">> => zeros(), <<"safety_digest">> => zeros(),
    <<"pairs">> => lists:duplicate(768, #{}),
    <<"candidate_only_safety_failures">> => 0, <<"complete">> => true}.
zeros() -> <<"0000000000000000000000000000000000000000000000000000000000000000">>.
