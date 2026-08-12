-module(alang_compact_model_tests).

-include_lib("eunit/include/eunit.hrl").

model_contract_is_exact_and_closed_test() ->
    ?assertMatch({ok, _}, alang_compact_model:load_contract(contract_path())),
    {ok, Contract} = alang_fidelity_json:decode_file(contract_path()),
    ?assertMatch({error, {model_contract_mismatch, _, _}},
        alang_compact_model:validate_contract(Contract#{<<"positional_security_fields">> := true})).

all_corpus_cases_round_trip_checked_semantics_test_() ->
    {timeout, 30, fun() ->
        lists:foreach(fun(Oracle) ->
            {ok, First} = alang_compact_model:encode(Oracle),
            {ok, Second} = alang_compact_model:encode(maps:from_list(lists:reverse(maps:to_list(Oracle)))),
            ?assertEqual(maps:get(bytes, First), maps:get(bytes, Second)),
            {ok, Decoded} = alang_compact_model:decode(maps:get(bytes, First)),
            ?assertEqual(alang_fidelity_contract:semantic_digest(Oracle), maps:get(semantic_digest, Decoded)),
            ?assertEqual(maps:get(semantic_digest, First), maps:get(semantic_digest, Decoded))
        end, all_oracles())
    end}.

generated_valid_tasks_round_trip_property_test() ->
    Base = first_executable_oracle(),
    lists:foreach(fun(Index) ->
        Bytes = 512 + Index * 64,
        Budgets = (maps:get(<<"budgets">>, Base))#{<<"output_bytes">> := Bytes},
        Predicates = [case maps:get(<<"kind">>, Predicate) of
            <<"max-bytes">> -> Predicate#{<<"expected">> := Bytes};
            _ -> Predicate
        end || Predicate <- maps:get(<<"completion_predicates">>, Base)],
        Oracle = Base#{<<"case_id">> := <<"generated-", (integer_to_binary(Index))/binary>>,
            <<"budgets">> := Budgets, <<"completion_predicates">> := Predicates,
            <<"goal_facts">> := [<<"Generated constraint ", (integer_to_binary(Index))/binary>> |
                maps:get(<<"goal_facts">>, Base)]},
        ?assertMatch({ok, _}, alang_fidelity_contract:validate_comprehension(Oracle)),
        {ok, Encoded} = alang_compact_model:encode(Oracle),
        {ok, Decoded} = alang_compact_model:decode(maps:get(bytes, Encoded)),
        ?assertEqual(alang_fidelity_contract:semantic_digest(Oracle), maps:get(semantic_digest, Decoded))
    end, lists:seq(1, 32)).

only_exact_effects_and_requirements_are_derived_test() ->
    Oracle = first_executable_oracle(),
    {ok, Encoded} = alang_compact_model:encode(Oracle),
    Compact = compact_value(maps:get(bytes, Encoded)),
    ?assertEqual([<<"effects">>, <<"requirements">>], maps:get(<<"derived">>, Compact)),
    ?assertEqual(false, maps:is_key(<<"effects">>, Compact)),
    ?assertEqual(false, maps:is_key(<<"use">>, Compact)),
    ExplicitOracle = Oracle#{<<"effects">> := [], <<"requirements">> := []},
    ?assertMatch({ok, _}, alang_fidelity_contract:validate_comprehension(ExplicitOracle)),
    {ok, ExplicitEncoded} = alang_compact_model:encode(ExplicitOracle),
    Explicit = compact_value(maps:get(bytes, ExplicitEncoded)),
    ?assertEqual([], maps:get(<<"derived">>, Explicit)),
    ?assertEqual([], maps:get(<<"effects">>, Explicit)),
    ?assertEqual([], maps:get(<<"use">>, Explicit)),
    {ok, ExplicitDecoded} = alang_compact_model:decode(maps:get(bytes, ExplicitEncoded)),
    ?assertEqual(alang_fidelity_contract:semantic_digest(ExplicitOracle),
        maps:get(semantic_digest, ExplicitDecoded)).

alias_maps_are_bounded_reversible_and_collision_safe_test() ->
    Oracle = first_executable_oracle(),
    {ok, Encoded} = alang_compact_model:encode(Oracle),
    Compact = compact_value(maps:get(bytes, Encoded)),
    Aliases = maps:get(<<"aliases">>, Compact),
    ?assert(maps:size(Aliases) > 0),
    ?assert(maps:size(Aliases) =< 64),
    ?assert(lists:all(fun(Key) -> binary:match(Key, <<"n">>) =:= {0, 1} end, maps:keys(Aliases))),
    ?assertMatch({error, {compact_model_error, [<<"aliases">> | _], _}},
        alang_compact_model:decode(compact_binary(Compact#{<<"aliases">> := maps:remove(<<"n0">>, Aliases)}))),
    Swapped = swap_first_two(Aliases),
    assert_rejected_or_changed(alang_fidelity_contract:semantic_digest(Oracle),
        alang_compact_model:decode(compact_binary(Compact#{<<"aliases">> := Swapped}))),
    Collision = resource_alias_collision(Oracle),
    ?assertMatch({error, {compact_model_error, [<<"aliases">>], {literal_alias_collision, <<"@n0">>}}},
        alang_compact_model:encode(Collision)).

derivation_authority_and_meaning_mutants_fail_or_change_digest_test() ->
    Oracle = delegated_oracle(),
    Digest = alang_fidelity_contract:semantic_digest(Oracle),
    {ok, Encoded} = alang_compact_model:encode(Oracle),
    Compact = compact_value(maps:get(bytes, Encoded)),
    Derived = maps:get(<<"derived">>, Compact),
    ?assertMatch({error, {compact_model_error, [<<"effects">>], missing_without_derivation}},
        alang_compact_model:decode(compact_binary(Compact#{<<"derived">> :=
            lists:delete(<<"effects">>, Derived)}))),
    ?assertMatch({error, {compact_model_error, [<<"use">>], present_with_derivation}},
        alang_compact_model:decode(compact_binary(Compact#{<<"use">> => [],
            <<"derived">> := Derived}))),
    assert_rejected_or_changed(Digest, alang_compact_model:decode(compact_binary(
        mutate_budget(Compact, <<"t">>, fun(Value) -> Value - 1 end)))),
    assert_rejected_or_changed(Digest, alang_compact_model:decode(compact_binary(
        widen_model_scope(Compact)))),
    assert_rejected_or_changed(Digest, alang_compact_model:decode(compact_binary(
        weaken_completion(Compact)))),
    assert_rejected_or_changed(Digest, alang_compact_model:decode(compact_binary(
        mutate_fact(Compact)))),
    ChildMutant = widen_child_effect(Compact),
    assert_rejected_or_changed(Digest, alang_compact_model:decode(compact_binary(ChildMutant))),
    ?assertMatch({error, {compact_model_error, [], {unknown_fields, [<<"unknown">>]}}},
        alang_compact_model:decode(compact_binary(Compact#{<<"unknown">> => true}))).

r3_surface_dispatch_is_versioned_and_semantically_checked_test() ->
    Oracle = first_executable_oracle(),
    {ok, Surface} = alang_compact_surface:render(<<"R3">>, <<"alang-model-v1">>, Oracle,
        registry_path()),
    ?assertMatch(<<"#!alang-model-v1\n", _/binary>>, maps:get(bytes, Surface)),
    {ok, Decoded} = alang_compact_surface:decode(<<"R3">>, <<"alang-model-v1">>,
        maps:get(bytes, Surface)),
    ?assertEqual(maps:get(semantic_digest, Surface), maps:get(semantic_digest, Decoded)),
    ?assertMatch({error, {surface_version_mismatch, <<"R3">>, _, _}},
        alang_compact_surface:decode(<<"R3">>, <<"alang-model-v2">>, maps:get(bytes, Surface))).

mutate_budget(Compact, Key, Fun) ->
    Cap = maps:get(<<"cap">>, Compact),
    Compact#{<<"cap">> := Cap#{Key := Fun(maps:get(Key, Cap))}}.

widen_model_scope(Compact) ->
    At = maps:get(<<"at">>, Compact),
    Models = maps:get(<<"m">>, At, []),
    Compact#{<<"at">> := At#{<<"m">> => Models ++ [<<"model/expanded">>]}}.

weaken_completion(Compact) ->
    [_ | Rest] = maps:get(<<"ok">>, Compact),
    Compact#{<<"ok">> := Rest}.

mutate_fact(Compact) ->
    [First | Rest] = maps:get(<<"f">>, Compact),
    Compact#{<<"f">> := [<<First/binary, " not">> | Rest]}.

widen_child_effect(Compact) ->
    Child = maps:get(<<"kid">>, Compact),
    Effects = maps:get(<<"effects">>, Child),
    Compact#{<<"kid">> := Child#{<<"effects">> := lists:usort([<<"put">> | Effects])}}.

resource_alias_collision(Oracle) ->
    Scopes = maps:get(<<"scopes">>, Oracle),
    Requirements = maps:get(<<"requirements">>, Oracle),
    UpdatedRequirements = [case maps:get(<<"kind">>, Requirement) of
        <<"model">> -> Requirement#{<<"resource">> := <<"@n0">>};
        _ -> Requirement
    end || Requirement <- Requirements],
    Oracle#{<<"requirements">> := UpdatedRequirements,
        <<"scopes">> := Scopes#{<<"models">> := [<<"@n0">>]}}.

swap_first_two(Aliases) ->
    First = maps:get(<<"n0">>, Aliases),
    Second = maps:get(<<"n1">>, Aliases),
    Aliases#{<<"n0">> := Second, <<"n1">> := First}.

assert_rejected_or_changed(_Digest, {error, _}) -> ok;
assert_rejected_or_changed(Digest, {ok, Decoded}) ->
    ?assertNotEqual(Digest, maps:get(semantic_digest, Decoded)).

compact_value(<<"#!alang-model-v1\n", Json/binary>>) ->
    {ok, Value} = alang_fidelity_json:decode(Json),
    Value.

compact_binary(Value) ->
    {ok, Json} = alang_fidelity_json:encode_canonical(Value),
    <<"#!alang-model-v1\n", Json/binary>>.

first_executable_oracle() ->
    hd([Oracle || Oracle <- all_oracles(), maps:get(<<"terminal_class">>, Oracle) =:= <<"complete">>]).

delegated_oracle() ->
    hd([Oracle || Oracle <- all_oracles(), is_map(maps:get(<<"child_attenuation">>, Oracle))]).

all_oracles() ->
    {ok, Corpus} = alang_fidelity_json:decode_file(corpus_path()),
    [alang_compact_corpus:oracle(Case) || Case <- maps:get(<<"cases">>, Corpus)].

contract_path() -> filename:join([phase2_dir(), "contracts", "model-format-v1.json"]).
registry_path() -> filename:join([phase2_dir(), "contracts", "surface-registry-v1.json"]).
phase2_dir() -> filename:join(["assets", "compact-projection-fidelity", "phase-02"]).
corpus_path() -> filename:join(["assets", "compact-projection-fidelity", "corpus", "confirmatory-corpus-v1.json"]).
