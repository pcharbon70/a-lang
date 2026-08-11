-module(alang_compact_registration_tests).

-include_lib("eunit/include/eunit.hrl").

held_out_corpus_is_balanced_and_neutral_test() ->
    {ok, Evidence} = alang_compact_corpus:load(assets_dir()),
    ?assertEqual(48, maps:get(<<"semantic_cases">>, Evidence)),
    ?assertEqual(48, maps:get(<<"representation_neutral_oracles">>, Evidence)),
    ?assertEqual(0, maps:get(<<"development_overlaps">>, Evidence)),
    ?assertEqual(0, maps:get(<<"condition_alias_mentions">>, Evidence)),
    ?assertEqual(48, length(maps:get(<<"semantic_digests">>, Evidence))).

all_oracles_validate_and_child_authority_is_attenuated_test() ->
    {ok, Corpus} = alang_fidelity_json:decode_file(corpus_path()),
    Oracles = [alang_compact_corpus:oracle(Case) || Case <- maps:get(<<"cases">>, Corpus)],
    ?assert(lists:all(fun(Oracle) -> element(1, alang_fidelity_contract:validate_comprehension(Oracle)) =:= ok end, Oracles)),
    Delegated = hd([O || O <- Oracles, is_map(maps:get(<<"child_attenuation">>, O))]),
    Child = maps:get(<<"child_attenuation">>, Delegated),
    ChildScopes = maps:get(<<"scopes">>, Child),
    Widened = Delegated#{<<"child_attenuation">> := Child#{<<"scopes">> :=
        ChildScopes#{<<"workspaces">> := [<<"workspace/rogue">>]}}},
    ?assertMatch({error, _}, alang_fidelity_contract:validate_comprehension(Widened)).

development_overlap_mutation_is_rejected_test() ->
    {ok, Corpus} = alang_fidelity_json:decode_file(corpus_path()),
    {ok, Design} = alang_fidelity_json:decode_file(design_path()),
    [First | Rest] = maps:get(<<"cases">>, Corpus),
    Mutant = First#{<<"request">> := <<"Create a concise release note from the supplied change summary">>},
    ?assertMatch({error, {compact_corpus_error, _, {development_corpus_overlap, _}}},
        alang_compact_corpus:validate(Corpus#{<<"cases">> := [Mutant | Rest]}, Design, development_dir())).

family_design_mutation_is_rejected_test() ->
    {ok, Corpus} = alang_fidelity_json:decode_file(corpus_path()),
    {ok, Design} = alang_fidelity_json:decode_file(design_path()),
    [First | Rest] = maps:get(<<"cases">>, Corpus),
    Mutant = First#{<<"runtime_family">> := <<"repair-and-publish">>},
    ?assertMatch({error, _}, alang_compact_corpus:validate(Corpus#{<<"cases">> := [Mutant | Rest]}, Design, development_dir())).

operational_registration_is_frozen_and_offline_test() ->
    {ok, Evidence} = alang_compact_registration:load(assets_dir()),
    ?assertEqual(0, maps:get(<<"hosted_calls_observed">>, Evidence)),
    ?assertEqual(false, maps:get(<<"network_authorized">>, Evidence)),
    Policy = maps:get(<<"policy">>, Evidence),
    ?assertEqual(2304, maps:get(<<"primary_requests">>, Policy)),
    ?assertEqual(4608, maps:get(<<"hard_request_ceiling">>, Policy)),
    Profiles = maps:get(<<"profiles">>, Evidence),
    ?assertEqual(true, maps:get(<<"manifest_match_required">>, Profiles)).

profile_digest_mutation_is_rejected_test() ->
    {ok, Profiles} = alang_fidelity_json:decode_file(filename:join([campaign_dir(), "provider-profiles-v1.json"])),
    [First | Rest] = maps:get(<<"profiles">>, Profiles),
    Mutant = First#{<<"manifest_sha256">> := <<"0000000000000000000000000000000000000000000000000000000000000000">>},
    ?assertMatch({error, _}, alang_compact_registration:validate_profiles(Profiles#{<<"profiles">> := [Mutant | Rest]})).

network_and_request_ceiling_mutations_are_rejected_test() ->
    {ok, Policy} = alang_fidelity_json:decode_file(filename:join([campaign_dir(), "campaign-policy-v1.json"])),
    ?assertMatch({error, _}, alang_compact_registration:validate_policy(Policy#{<<"network_default">> := <<"enabled">>})),
    Ceilings = maps:get(<<"campaign_ceilings">>, Policy),
    ?assertMatch({error, _}, alang_compact_registration:validate_policy(
        Policy#{<<"campaign_ceilings">> := Ceilings#{<<"all_requests">> := 4609}})).

assets_dir() -> filename:join(["assets", "compact-projection-fidelity"]).
campaign_dir() -> filename:join([assets_dir(), "campaign"]).
corpus_path() -> filename:join([assets_dir(), "corpus", "confirmatory-corpus-v1.json"]).
design_path() -> filename:join([campaign_dir(), "case-design-v1.json"]).
development_dir() -> filename:join(["assets", "effectful-source-fidelity", "corpus"]).
