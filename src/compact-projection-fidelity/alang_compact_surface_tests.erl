-module(alang_compact_surface_tests).

-include_lib("eunit/include/eunit.hrl").

registry_is_closed_and_all_surface_ids_are_exact_test() ->
    ?assertMatch({ok, _}, alang_compact_surface:load_registry(registry_path())),
    {ok, Registry} = alang_fidelity_json:decode_file(registry_path()),
    ?assertMatch({error, {surface_registry_mismatch, _, _}},
        alang_compact_surface:validate_registry(Registry#{<<"unknown_surface">> := <<"accept">>})),
    ?assertEqual([<<"R0">>, <<"R1">>, <<"R2">>, <<"R3">>, <<"R4">>, <<"R5">>],
        [maps:get(<<"id">>, Surface) || Surface <- maps:get(<<"surfaces">>, Registry)]).

implemented_surfaces_are_canonical_and_round_trip_all_cases_test_() ->
    {timeout, 30, fun() ->
        lists:foreach(fun(Oracle) ->
            Digest = alang_fidelity_contract:semantic_digest(Oracle),
            lists:foreach(fun({SurfaceId, Version}) ->
                {ok, First} = alang_compact_surface:render(SurfaceId, Version, Oracle, registry_path()),
                {ok, Second} = alang_compact_surface:render(SurfaceId, Version, Oracle, registry_path()),
                ?assertEqual(maps:get(bytes, First), maps:get(bytes, Second)),
                ?assertEqual(Digest, maps:get(semantic_digest, First)),
                {ok, Decoded} = alang_compact_surface:decode(SurfaceId, Version, maps:get(bytes, First)),
                ?assertEqual(Digest, maps:get(semantic_digest, Decoded))
            end, implemented_surfaces())
        end, all_oracles())
    end}.

minified_and_alias_surfaces_reduce_the_readable_fixture_test() ->
    Oracle = first_oracle(),
    {ok, Readable} = render(<<"R0">>, <<"alang-source-v2">>, Oracle),
    {ok, Minified} = render(<<"R1">>, <<"alang-source-v2">>, Oracle),
    {ok, Alias} = render(<<"R2">>, <<"alang-source-v2-alias-v1">>, Oracle),
    ?assert(maps:get(byte_count, Minified) < maps:get(byte_count, Readable)),
    ?assert(maps:get(byte_count, Alias) < maps:get(byte_count, Minified)),
    AliasBytes = maps:get(bytes, Alias),
    ?assertMatch(<<"#!alang-source-v2-alias-v1", _/binary>>, AliasBytes),
    ?assert(binary:match(AliasBytes, <<"cap{~s=">>) =/= nomatch),
    ?assert(binary:match(AliasBytes, <<":gen<-">>) =/= nomatch).

surface_versions_bounds_and_unknown_fields_fail_closed_test() ->
    Oracle = first_oracle(),
    ?assertMatch({error, {unknown_surface, <<"R6">>}},
        render(<<"R6">>, <<"alang-model-v1">>, Oracle)),
    ?assertMatch({error, {surface_version_mismatch, <<"R2">>, _, _}},
        render(<<"R2">>, <<"alang-source-v2">>, Oracle)),
    ?assertMatch({error, {surface_version_mismatch, <<"R5">>, _, _}},
        alang_compact_surface:decode(<<"R5">>, <<"json">>, <<"{}">>)),
    ?assertMatch({error, {representation_too_large, 32769, 32768}},
        alang_compact_surface:decode(<<"R0">>, <<"alang-source-v2">>, binary:copy(<<"x">>, 32769))),
    Duplicate = <<"{\"format\":\"alang-task-json-v1\",\"format\":\"alang-task-json-v1\"}">>,
    ?assertMatch({error, {surface_decode_failed, <<"R5">>, {duplicate_key, <<"format">>}}},
        alang_compact_surface:decode(<<"R5">>, <<"alang-task-json-v1">>, Duplicate)),
    ?assertMatch({error, _}, alang_compact_surface:decode(<<"R2">>,
        <<"alang-source-v2-alias-v1">>, <<"#!alang-source-v2-alias-v1\ntask x{wat[]}">>)).

slash_qualified_resources_and_safe_absolute_paths_are_source_representable_test() ->
    Oracle = first_oracle(),
    {ok, Rendered} = render(<<"R0">>, <<"alang-source-v2">>, Oracle),
    Bytes = maps:get(bytes, Rendered),
    ?assert(binary:match(Bytes, <<"model/">>) =/= nomatch),
    ?assert(binary:match(Bytes, <<"paths [\"/field-notes/">>) =/= nomatch),
    {ok, Decoded} = alang_compact_surface:decode(<<"R0">>, <<"alang-source-v2">>, Bytes),
    ?assertEqual(maps:get(semantic_digest, Rendered), maps:get(semantic_digest, Decoded)).

render(SurfaceId, Version, Oracle) ->
    alang_compact_surface:render(SurfaceId, Version, Oracle, registry_path()).

implemented_surfaces() ->
    [{<<"R0">>, <<"alang-source-v2">>},
        {<<"R1">>, <<"alang-source-v2">>},
        {<<"R2">>, <<"alang-source-v2-alias-v1">>},
        {<<"R5">>, <<"alang-task-json-v1">>}].

first_oracle() -> hd(all_oracles()).

all_oracles() ->
    {ok, Corpus} = alang_fidelity_json:decode_file(corpus_path()),
    [alang_compact_corpus:oracle(Case) || Case <- maps:get(<<"cases">>, Corpus)].

registry_path() ->
    filename:join(["assets", "compact-projection-fidelity", "phase-02", "contracts", "surface-registry-v1.json"]).
corpus_path() ->
    filename:join(["assets", "compact-projection-fidelity", "corpus", "confirmatory-corpus-v1.json"]).
