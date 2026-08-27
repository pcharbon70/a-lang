-module(alang_compact_opaque_tests).

-include_lib("eunit/include/eunit.hrl").

opaque_contract_is_exact_and_nonpromotable_test() ->
    ?assertMatch({ok, _}, alang_compact_opaque:load_contract(opaque_contract_path())),
    ?assertEqual(false, alang_compact_opaque:promotable()),
    {ok, Contract} = alang_fidelity_json:decode_file(opaque_contract_path()),
    ?assertMatch({error, {opaque_contract_mismatch, _, _}},
        alang_compact_opaque:validate_contract(Contract#{<<"promotable">> := true})),
    {ok, Campaign} = alang_compact_contract:load(campaign_contract_path()),
    [R4] = [Condition || Condition <- maps:get(<<"conditions">>, Campaign),
        maps:get(<<"id">>, Condition) =:= <<"R4">>],
    ?assertEqual(false, maps:get(<<"promotable">>, R4)),
    ?assertEqual(<<"R3">>, maps:get(<<"candidate_condition">>, Campaign)).

all_opaque_cases_round_trip_with_external_reverse_context_test_() ->
    {timeout, 30, fun() ->
        lists:foreach(fun(Oracle) ->
            {ok, First} = alang_compact_opaque:encode(Oracle),
            {ok, Second} = alang_compact_opaque:encode(Oracle),
            ?assertEqual(maps:get(bytes, First), maps:get(bytes, Second)),
            ?assertEqual(maps:get(reverse_map, First), maps:get(reverse_map, Second)),
            ?assertEqual(false, maps:get(promotable, First)),
            {ok, Decoded} = alang_compact_opaque:decode(maps:get(bytes, First),
                maps:get(reverse_map, First)),
            ?assertEqual(alang_fidelity_contract:semantic_digest(Oracle),
                maps:get(semantic_digest, Decoded)),
            ?assertEqual(false, maps:get(promotable, Decoded))
        end, all_oracles())
    end}.

eligible_identifiers_are_opaque_and_protected_values_are_exact_test() ->
    Oracle = first_oracle(),
    {ok, Encoded} = alang_compact_opaque:encode(Oracle),
    Compact = compact_value(maps:get(bytes, Encoded)),
    Local = maps:get(<<"aliases">>, Compact),
    Eligible = compact_eligible_values(Compact),
    Resolved = [resolve_local(Value, Local) || Value <- Eligible],
    ?assert(lists:all(fun(Value) ->
        re:run(Value, <<"^o[0-9]+$">>, [{capture, none}]) =:= match orelse protected_profile(Value)
    end, Resolved)),
    ?assertEqual(lists:sort(maps:get(<<"goal_facts">>, Oracle)), maps:get(<<"f">>, Compact)),
    ?assertEqual(maps:get(<<"paths">>, maps:get(<<"scopes">>, Oracle)),
        maps:get(<<"p">>, maps:get(<<"at">>, Compact))),
    ?assertEqual(false, maps:is_key(<<"reverse_map">>, Compact)),
    ?assert(maps:size(maps:get(reverse_map, Encoded)) > 0).

reverse_map_tampering_missing_context_and_collisions_fail_test() ->
    Oracle = first_oracle(),
    {ok, Encoded} = alang_compact_opaque:encode(Oracle),
    Bytes = maps:get(bytes, Encoded),
    Reverse = maps:get(reverse_map, Encoded),
    ?assertMatch({error, {compact_opaque_error, [<<"reverse_map">>], noncontiguous_opaque_aliases}},
        alang_compact_opaque:decode(Bytes, maps:remove(<<"o0">>, Reverse))),
    {ActionAlias, ActionEntry} = hd([{Key, Entry} || {Key, Entry} <- maps:to_list(Reverse),
        maps:get(<<"kind">>, Entry) =:= <<"action">>]),
    Changed = Reverse#{ActionAlias := ActionEntry#{<<"original">> := <<"changed-action">>}},
    assert_rejected_or_changed(maps:get(semantic_digest, Encoded),
        alang_compact_opaque:decode(Bytes, Changed)),
    ?assertMatch({error, {opaque_reverse_map_required, <<"R4">>}},
        alang_compact_surface:decode(<<"R4">>, <<"alang-model-v1-opaque-control">>, Bytes)),
    Collision = Oracle#{<<"case_id">> := <<"o0">>},
    ?assertMatch({error, {compact_opaque_error, [<<"reverse_map">>],
        {opaque_alias_collision, <<"o0">>}}}, alang_compact_opaque:encode(Collision)).

provider_model_profiles_remain_protected_test() ->
    Oracle = first_oracle(),
    Profile = <<"mixtral:8x7b">>,
    Scopes = maps:get(<<"scopes">>, Oracle),
    Requirements = [case maps:get(<<"kind">>, Requirement) of
        <<"model">> -> Requirement#{<<"resource">> := Profile};
        _ -> Requirement
    end || Requirement <- maps:get(<<"requirements">>, Oracle)],
    Protected = Oracle#{<<"requirements">> := Requirements,
        <<"scopes">> := Scopes#{<<"models">> := [Profile]}},
    {ok, Encoded} = alang_compact_opaque:encode(Protected),
    ?assert(binary:match(maps:get(bytes, Encoded), Profile) =/= nomatch),
    ?assertEqual(false, lists:any(fun(Entry) -> maps:get(<<"original">>, Entry) =:= Profile end,
        maps:values(maps:get(reverse_map, Encoded)))),
    {ok, Decoded} = alang_compact_opaque:decode(maps:get(bytes, Encoded), maps:get(reverse_map, Encoded)),
    ?assertEqual(alang_fidelity_contract:semantic_digest(Protected), maps:get(semantic_digest, Decoded)).

r4_surface_requires_exact_context_and_carries_nonpromotion_test() ->
    Oracle = first_oracle(),
    {ok, Surface} = alang_compact_surface:render(<<"R4">>,
        <<"alang-model-v1-opaque-control">>, Oracle, registry_path()),
    Provenance = maps:get(provenance, Surface),
    ?assertEqual(false, maps:get(promotable, Provenance)),
    ?assertEqual(true, maps:get(ablation_only, Provenance)),
    Context = #{opaque_reverse_map => maps:get(opaque_reverse_map, Provenance)},
    {ok, Decoded} = alang_compact_surface:decode(<<"R4">>,
        <<"alang-model-v1-opaque-control">>, maps:get(bytes, Surface), Context),
    ?assertEqual(maps:get(semantic_digest, Surface), maps:get(semantic_digest, Decoded)),
    ?assertMatch({error, {invalid_decode_context, <<"R4">>}},
        alang_compact_surface:decode(<<"R4">>, <<"alang-model-v1-opaque-control">>,
            maps:get(bytes, Surface), #{})).

compact_eligible_values(Compact) ->
    Inputs = [maps:get(<<"name">>, Input) || Input <- maps:get(<<"i">>, Compact)],
    Steps = lists:append([[maps:get(<<"id">>, Step) | maps:get(<<"<-">>, Step)] ||
        Step <- maps:get(<<"step">>, Compact)]),
    At = maps:get(<<"at">>, Compact),
    Resources = maps:get(<<"m">>, At, []) ++ maps:get(<<"w">>, At, []),
    Errors = [maps:get(<<"action">>, Error) || Error <- maps:get(<<"err">>, Compact, [])],
    PredicateTargets = [maps:get(<<"target">>, Predicate) || Predicate <- maps:get(<<"ok">>, Compact),
        lists:member(maps:get(<<"kind">>, Predicate), [<<"journal">>, <<"asked">>])],
    [maps:get(<<"task">>, Compact) | Inputs ++ Steps ++ Resources ++ Errors ++ PredicateTargets].

resolve_local(<<"@", Key/binary>>, Local) -> maps:get(Key, Local);
resolve_local(Value, _Local) -> Value.

protected_profile(Value) -> lists:member(Value,
    [<<"hf.co/unsloth/Ornith-1.0-35B-GGUF:UD-Q5_K_M">>, <<"mixtral:8x7b">>]).

assert_rejected_or_changed(_Digest, {error, _}) -> ok;
assert_rejected_or_changed(Digest, {ok, Decoded}) ->
    ?assertNotEqual(Digest, maps:get(semantic_digest, Decoded)).

compact_value(<<"#!alang-model-v1-opaque-control\n", Json/binary>>) ->
    {ok, Value} = alang_fidelity_json:decode(Json), Value.

first_oracle() -> hd([Oracle || Oracle <- all_oracles(), maps:get(<<"terminal_class">>, Oracle) =:= <<"complete">>]).
all_oracles() ->
    {ok, Corpus} = alang_fidelity_json:decode_file(corpus_path()),
    [alang_compact_corpus:oracle(Case) || Case <- maps:get(<<"cases">>, Corpus)].

opaque_contract_path() -> filename:join([phase2_dir(), "contracts", "opaque-control-v1.json"]).
registry_path() -> filename:join([phase2_dir(), "contracts", "surface-registry-v1.json"]).
campaign_contract_path() -> filename:join(["assets", "compact-projection-fidelity", "contracts", "campaign-contract-v1.json"]).
phase2_dir() -> filename:join(["assets", "compact-projection-fidelity", "phase-02"]).
corpus_path() -> filename:join(["assets", "compact-projection-fidelity", "corpus", "confirmatory-corpus-v1.json"]).
