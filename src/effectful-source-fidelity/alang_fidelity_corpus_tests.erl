-module(alang_fidelity_corpus_tests).

-include_lib("eunit/include/eunit.hrl").

complete_registration_validates_test() ->
    {ok, Evidence} = alang_fidelity_corpus:validate(asset_root()),
    Corpus = maps:get(<<"corpus">>, Evidence),
    Campaign = maps:get(<<"campaign">>, Evidence),
    ?assertEqual(24, maps:get(<<"semantic_cases">>, Corpus)),
    ?assertEqual(24, maps:get(<<"candidate_documents">>, Corpus)),
    ?assertEqual(24, maps:get(<<"control_documents">>, Corpus)),
    ?assertEqual(24, maps:get(<<"answer_keys">>, Corpus)),
    ?assertEqual(true, maps:get(<<"balanced">>, Corpus)),
    ?assertEqual(2, maps:get(<<"model_profiles">>, Campaign)),
    ?assertEqual(0, maps:get(<<"hosted_calls_observed">>, Evidence)).

every_family_variant_cell_exists_once_test() ->
    {ok, Manifest} = alang_fidelity_json:decode_file(manifest_path()),
    Cases = maps:get(<<"cases">>, Manifest),
    Cells = [{maps:get(<<"family">>, Case), maps:get(<<"variant">>, Case)} || Case <- Cases],
    ?assertEqual(24, length(Cells)),
    ?assertEqual(24, length(lists:usort(Cells))).

paired_semantic_digests_are_equal_test() ->
    {ok, Manifest} = alang_fidelity_json:decode_file(manifest_path()),
    lists:foreach(
        fun(Case) ->
            Digest = maps:get(<<"semantic_digest">>, Case),
            ?assertEqual(Digest, maps:get(<<"semantic_digest">>, maps:get(<<"candidate">>, Case))),
            ?assertEqual(Digest, maps:get(<<"semantic_digest">>, maps:get(<<"control">>, Case)))
        end,
        maps:get(<<"cases">>, Manifest)
    ).

provider_profiles_are_exact_and_bounded_test() ->
    {ok, Profiles} = alang_fidelity_json:decode_file(profiles_path()),
    ?assertMatch({ok, _}, alang_fidelity_corpus:validate_provider_profiles(Profiles)),
    [Ornith, Mixtral] = maps:get(<<"profiles">>, Profiles),
    ?assertEqual(<<"ornith-1.0">>, maps:get(<<"model_id">>, Ornith)),
    ?assertEqual(<<"mixtral-8x7b">>, maps:get(<<"model_id">>, Mixtral)),
    lists:foreach(
        fun(Profile) ->
            ?assertEqual(<<"medium">>, maps:get(<<"effort">>, Profile)),
            ?assertEqual(1, maps:get(<<"turns">>, Profile)),
            ?assertEqual(false, maps:get(<<"tools_enabled">>, Profile)),
            ?assertEqual(false, maps:get(<<"provider_schema_constraint">>, Profile)),
            ?assertEqual(8192, maps:get(<<"max_output_tokens">>, Profile)),
            ?assertEqual(8192, maps:get(<<"accepted_output_bytes">>, Profile))
        end,
        [Ornith, Mixtral]
    ).

alias_model_identifier_is_rejected_test() ->
    {ok, Profiles} = alang_fidelity_json:decode_file(profiles_path()),
    [Ornith, Mixtral] = maps:get(<<"profiles">>, Profiles),
    Mutant = Profiles#{<<"profiles">> => [Ornith#{<<"model_id">> => <<"ornith-latest">>}, Mixtral]},
    ?assertMatch(
        {error, {campaign_error, [<<"profiles">>], {frozen_contract_mismatch, _, _}}},
        alang_fidelity_corpus:validate_provider_profiles(Mutant)
    ).

campaign_is_offline_and_ceiling_bounded_test() ->
    {ok, Policy} = alang_fidelity_json:decode_file(policy_path()),
    ?assertMatch({ok, _}, alang_fidelity_corpus:validate_campaign_policy(Policy)),
    ?assertEqual(<<"disabled">>, maps:get(<<"network_default">>, Policy)),
    Ceilings = maps:get(<<"ceilings">>, Policy),
    ?assertEqual(288, maps:get(<<"primary_calls">>, Ceilings)),
    ?assertEqual(576, maps:get(<<"all_calls">>, Ceilings)),
    ?assertEqual(200, maps:get(<<"cost_usd">>, Ceilings)),
    Replacement = maps:get(<<"replacement">>, Policy),
    ?assertEqual(false, maps:get(<<"blind_retry">>, Replacement)).

retention_excludes_credentials_test() ->
    {ok, Policy} = alang_fidelity_json:decode_file(policy_path()),
    Retention = maps:get(<<"retention">>, Policy),
    ?assert(lists:member(<<"credential">>, maps:get(<<"exclude">>, Retention))),
    ?assert(lists:member(<<"redacted-prompt">>, maps:get(<<"retain">>, Retention))).

asset_root() ->
    filename:join(["assets", "effectful-source-fidelity"]).

manifest_path() ->
    filename:join([asset_root(), "corpus", "corpus-manifest-v1.json"]).

profiles_path() ->
    filename:join([asset_root(), "campaign", "provider-profiles-v1.json"]).

policy_path() ->
    filename:join([asset_root(), "campaign", "campaign-policy-v1.json"]).
