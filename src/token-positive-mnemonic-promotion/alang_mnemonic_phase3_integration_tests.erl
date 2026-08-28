-module(alang_mnemonic_phase3_integration_tests).

-include_lib("eunit/include/eunit.hrl").

all_registered_faults_and_mutants_are_detected_test() ->
    {ok, Mutation} = alang_mnemonic_phase3_mutation:run("."),
    ?assertEqual(true, maps:get(<<"all_detected">>, Mutation)),
    ?assertEqual(19, maps:get(<<"detected">>, Mutation)),
    ?assertEqual(19, maps:get(<<"total">>, Mutation)).

network_is_confined_to_authorized_adapter_test() ->
    {ok, Residency} = alang_mnemonic_phase3_residency:audit("."),
    ?assertEqual(<<"ERTS">>, maps:get(<<"engine">>, Residency)),
    ?assertEqual(9, maps:get(<<"module_count">>, Residency)),
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

phase3_modules_load_from_beam_test() ->
    lists:foreach(fun(Module) ->
        Path = code:which(Module), ?assert(is_list(Path)),
        ?assertEqual(".beam", filename:extension(Path))
    end, [alang_mnemonic_live_gate, alang_mnemonic_journal, alang_mnemonic_runner,
        alang_mnemonic_ollama, alang_mnemonic_observation, alang_mnemonic_replay,
        alang_mnemonic_limits, alang_mnemonic_phase3_mutation,
        alang_mnemonic_phase3_residency]).
