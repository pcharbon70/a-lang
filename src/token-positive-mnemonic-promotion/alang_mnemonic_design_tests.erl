-module(alang_mnemonic_design_tests).

-include_lib("eunit/include/eunit.hrl").

power_audit_selects_registered_minimum_test_() ->
    {timeout, 30, fun() ->
        {ok, Audit} = alang_mnemonic_power:load(power_path()),
        ?assertEqual(48, maps:get(<<"selected_cases">>, Audit)),
        ?assertEqual(48, maps:get(<<"minimum_confirmatory_cases">>, Audit)),
        ?assertEqual(true, maps:get(<<"expansion_only_before_observation">>, Audit))
    end}.

power_audit_is_deterministic_and_rejects_seed_drift_test_() ->
    {timeout, 30, fun() ->
        {ok, Design} = alang_fidelity_json:decode_file(power_path()),
        ?assertEqual(alang_mnemonic_power:audit(Design), alang_mnemonic_power:audit(Design)),
        ?assertMatch({error, _}, alang_mnemonic_power:audit(Design#{<<"seed">> := 2026082505}))
    end}.

fresh_corpus_is_balanced_neutral_and_separate_test() ->
    {ok, Evidence} = alang_mnemonic_corpus:load(assets_dir()),
    ?assertEqual(48, maps:get(<<"semantic_cases">>, Evidence)),
    ?assertEqual(72, maps:get(<<"previous_design_cases">>, Evidence)),
    ?assertEqual(0, maps:get(<<"design_input_overlaps">>, Evidence)),
    ?assertEqual(48, length(maps:get(<<"semantic_digests">>, Evidence))),
    ?assert(lists:all(fun(V) -> V end, maps:values(maps:get(<<"coverage">>, Evidence)))).

all_oracles_validate_and_child_authority_is_attenuated_test() ->
    {ok, Corpus} = alang_fidelity_json:decode_file(corpus_path()),
    Oracles = [alang_mnemonic_corpus:oracle(C) || C <- maps:get(<<"cases">>, Corpus)],
    ?assert(lists:all(fun(O) -> element(1, alang_fidelity_contract:validate_comprehension(O)) =:= ok end, Oracles)),
    Delegated = hd([O || O <- Oracles, is_map(maps:get(<<"child_attenuation">>, O))]),
    Child = maps:get(<<"child_attenuation">>, Delegated),
    Scopes = maps:get(<<"scopes">>, Child),
    Widened = Delegated#{<<"child_attenuation">> := Child#{<<"scopes">> :=
        Scopes#{<<"workspaces">> := [<<"workspace/rogue">>]}}},
    ?assertMatch({error, _}, alang_fidelity_contract:validate_comprehension(Widened)).

prior_overlap_and_condition_leak_mutants_fail_test() ->
    {ok, Corpus} = alang_fidelity_json:decode_file(corpus_path()),
    {ok, Design} = alang_fidelity_json:decode_file(design_path()),
    {ok, Prior} = alang_fidelity_json:decode_file(filename:join(["assets", "compact-projection-fidelity", "corpus", "confirmatory-corpus-v1.json"])),
    [First | Rest] = maps:get(<<"cases">>, Corpus),
    [PriorFirst | _] = maps:get(<<"cases">>, Prior),
    Overlap = First#{<<"request">> := maps:get(<<"request">>, PriorFirst)},
    ?assertMatch({error, _}, alang_mnemonic_corpus:validate(Corpus#{<<"cases">> := [Overlap | Rest]}, Design, ".")),
    Leaked = First#{<<"request">> := <<(maps:get(<<"request">>, First))/binary, " Prefer P1.">>},
    ?assertMatch({error, _}, alang_mnemonic_corpus:validate(Corpus#{<<"cases">> := [Leaked | Rest]}, Design, ".")).

schedule_has_registered_shape_and_balance_test() ->
    {ok, Schedule} = alang_mnemonic_schedule:materialize(campaign_dir()),
    Cells = maps:get(<<"cells">>, Schedule),
    ?assertEqual(1536, length(Cells)),
    ?assertEqual(768, count(<<"condition">>, <<"P0">>, Cells)),
    ?assertEqual(768, count(<<"condition">>, <<"P1">>, Cells)),
    ?assertEqual(384, count(<<"protocol">>, <<"generation">>, Cells)),
    ?assertEqual(768, count(<<"model_family">>, <<"ornith">>, Cells)).

schedule_is_deterministic_opaque_and_nonadjacent_test() ->
    {ok, First} = alang_mnemonic_schedule:materialize(campaign_dir()),
    {ok, Second} = alang_mnemonic_schedule:materialize(campaign_dir()),
    ?assertEqual(First, Second),
    Cells = maps:get(<<"cells">>, First),
    ?assert(lists:all(fun(C) -> byte_size(maps:get(<<"trial_id">>, C)) =:= 24 end, Cells)),
    Pairs = lists:zip(lists:sublist(Cells, length(Cells) - 1), tl(Cells)),
    ?assert(lists:all(fun({A, B}) -> maps:get(<<"case_id">>, A) =/= maps:get(<<"case_id">>, B) end, Pairs)).

schedule_mutants_fail_test() ->
    {ok, Schedule} = alang_mnemonic_schedule:materialize(campaign_dir()),
    {ok, Policy} = alang_fidelity_json:decode_file(filename:join([campaign_dir(), "schedule-policy-v1.json"])),
    {ok, Design} = alang_fidelity_json:decode_file(design_path()),
    Cases = maps:get(<<"cases">>, Design), Cells = maps:get(<<"cells">>, Schedule),
    ?assertMatch({error, _}, alang_mnemonic_schedule:validate(Schedule#{<<"cells">> := tl(Cells)}, Policy, Cases)),
    ?assertMatch({error, _}, alang_mnemonic_schedule:validate(Schedule, Policy#{<<"seed">> := 2026082505}, Cases)).

registration_is_frozen_offline_and_prompt_digested_test() ->
    {ok, Evidence} = alang_mnemonic_registration:load(assets_dir()),
    ?assertEqual(0, maps:get(<<"hosted_calls_observed">>, Evidence)),
    ?assertEqual(false, maps:get(<<"network_authorized">>, Evidence)),
    ?assertEqual(1536, maps:get(<<"primary_requests">>, maps:get(<<"policy">>, Evidence))),
    ?assertEqual(64, byte_size(maps:get(<<"sha256">>, maps:get(<<"prompts">>, Evidence)))).

profile_policy_and_prompt_mutants_fail_test() ->
    {ok, Profiles} = alang_fidelity_json:decode_file(filename:join([campaign_dir(), "provider-profiles-v1.json"])),
    [First | Rest] = maps:get(<<"profiles">>, Profiles),
    Mutant = First#{<<"manifest_sha256">> := <<"0000000000000000000000000000000000000000000000000000000000000000">>},
    ?assertMatch({error, _}, alang_mnemonic_registration:validate_profiles(Profiles#{<<"profiles">> := [Mutant | Rest]})),
    {ok, Policy} = alang_fidelity_json:decode_file(filename:join([campaign_dir(), "campaign-policy-v1.json"])),
    ?assertMatch({error, _}, alang_mnemonic_registration:validate_policy(Policy#{<<"network_default">> := <<"enabled">>})),
    {ok, Prompts} = alang_fidelity_json:decode_file(filename:join([campaign_dir(), "prompt-policy-v1.json"])),
    [Protocol | ProtocolRest] = maps:get(<<"protocols">>, Prompts),
    ?assertMatch({error, _}, alang_mnemonic_registration:validate_prompts(Prompts#{<<"protocols">> :=
        [Protocol#{<<"conditions">> := [<<"P0">>]} | ProtocolRest]})).

trusted_design_modules_load_from_beam_test() ->
    Modules = [alang_mnemonic_power, alang_mnemonic_schedule, alang_mnemonic_corpus,
        alang_mnemonic_registration, alang_compact_power, alang_compact_corpus,
        alang_compact_registration],
    lists:foreach(fun(Module) ->
        Path = code:which(Module), ?assert(is_list(Path)),
        ?assertEqual(".beam", filename:extension(Path))
    end, Modules).

count(Key, Value, Cells) -> length([C || C <- Cells, maps:get(Key, C) =:= Value]).
assets_dir() -> filename:join(["assets", "token-positive-mnemonic-promotion"]).
campaign_dir() -> filename:join([assets_dir(), "campaign"]).
corpus_path() -> filename:join([assets_dir(), "corpus", "confirmatory-corpus-v1.json"]).
design_path() -> filename:join([campaign_dir(), "case-design-v1.json"]).
power_path() -> filename:join([campaign_dir(), "power-design-v1.json"]).
