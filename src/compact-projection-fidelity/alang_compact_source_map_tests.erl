-module(alang_compact_source_map_tests).

-include_lib("eunit/include/eunit.hrl").

source_map_contract_is_exact_test() ->
    ?assertMatch({ok, _}, alang_compact_source_map:load_contract(contract_path())),
    {ok, Contract} = alang_fidelity_json:decode_file(contract_path()),
    ?assertMatch({error, {source_map_contract_mismatch, _, _}},
        alang_compact_source_map:validate_contract(Contract#{<<"coverage">> := <<"partial">>})).

r3_and_r4_maps_cover_every_byte_and_security_field_test_() ->
    {timeout, 30, fun() ->
        lists:foreach(fun(Oracle) ->
            lists:foreach(fun({SurfaceId, Version}) ->
                {ok, Surface} = alang_compact_surface:render(SurfaceId, Version, Oracle, registry_path()),
                Map = maps:get(source_map, maps:get(provenance, Surface)),
                ?assertMatch({ok, _}, alang_compact_source_map:validate(Map, Surface, Oracle)),
                Tokens = maps:get(<<"tokens">>, Map),
                ?assertEqual(0, maps:get(<<"from">>, hd(Tokens))),
                ?assertEqual(maps:get(byte_count, Surface), maps:get(<<"to">>, lists:last(Tokens))),
                ?assert(lists:all(fun(Token) ->
                    lists:member(maps:get(<<"kind">>, maps:get(<<"origin">>, Token)),
                        [<<"generated">>, <<"semantic">>])
                end, Tokens)),
                ?assert(lists:all(fun(Field) ->
                    maps:get(<<"readable_spans">>, Field) =/= []
                end, maps:get(<<"fields">>, Map)))
            end, [{<<"R3">>, <<"alang-model-v1">>},
                {<<"R4">>, <<"alang-model-v1-opaque-control">>}])
        end, all_oracles())
    end}.

derived_and_empty_fields_have_explicit_witnesses_test() ->
    Oracle = first_oracle(),
    {ok, Surface} = alang_compact_surface:render(<<"R3">>, <<"alang-model-v1">>,
        Oracle, registry_path()),
    Fields = maps:get(<<"fields">>, maps:get(source_map, maps:get(provenance, Surface))),
    Effects = [Field || Field <- Fields, maps:get(<<"path">>, Field) =:= <<"/effects/0">>],
    ?assertMatch([#{<<"status">> := <<"derived">>, <<"witness">> := #{<<"rule">> := _}}], Effects),
    EmptyErrors = [Field || Field <- Fields,
        maps:get(<<"path">>, Field) =:= <<"/error_branches">>],
    ?assertMatch([#{<<"status">> := <<"versioned-empty-elision">>}], EmptyErrors).

opaque_aliases_map_to_original_names_and_diagnostics_are_readable_test() ->
    Oracle = first_oracle(),
    [FirstAction | _] = maps:get(<<"actions">>, Oracle),
    Original = maps:get(<<"id">>, FirstAction),
    {ok, Surface} = alang_compact_surface:render(<<"R4">>,
        <<"alang-model-v1-opaque-control">>, Oracle, registry_path()),
    Provenance = maps:get(provenance, Surface),
    Map = maps:get(source_map, Provenance),
    Opaque = maps:get(opaque_reverse_map, Provenance),
    [Alias] = [Key || {Key, Entry} <- maps:to_list(Opaque),
        maps:get(<<"kind">>, Entry) =:= <<"action">> andalso
        maps:get(<<"original">>, Entry) =:= Original],
    [AliasEntry] = [Entry || Entry <- maps:get(<<"aliases">>, Map),
        maps:get(<<"alias">>, Entry) =:= Alias],
    ?assertEqual(Original, maps:get(<<"original">>, AliasEntry)),
    ?assert(maps:get(<<"ranges">>, AliasEntry) =/= []),
    Diagnostic = alang_compact_source_map:diagnostic(Map, <<"/actions/0/id">>,
        <<"invalid-action">>, <<"operation is not permitted">>),
    Message = maps:get(<<"message">>, Diagnostic),
    ?assert(binary:match(Message, Original) =/= nomatch),
    ?assertEqual(nomatch, binary:match(Message, Alias)),
    Readable = maps:get(<<"readable_source">>, Diagnostic),
    ?assertEqual(<<"readable-source">>, maps:get(<<"edit_target">>, Readable)),
    ?assert(maps:get(<<"spans">>, Readable) =/= []),
    ?assert(maps:get(<<"compact_spans">>, Diagnostic) =/= []).

coverage_and_field_mutations_are_rejected_test() ->
    Oracle = first_oracle(),
    {ok, Surface} = alang_compact_surface:render(<<"R3">>, <<"alang-model-v1">>,
        Oracle, registry_path()),
    Map = maps:get(source_map, maps:get(provenance, Surface)),
    [First | Rest] = maps:get(<<"tokens">>, Map),
    BrokenFirst = First#{<<"from">> := 1},
    ?assertMatch({error, {source_map_error, [<<"tokens">>], _}},
        alang_compact_source_map:validate(Map#{<<"tokens">> := [BrokenFirst | Rest]}, Surface, Oracle)),
    [_Field | Fields] = maps:get(<<"fields">>, Map),
    ?assertMatch({error, {source_map_error, [<<"fields">>], _}},
        alang_compact_source_map:validate(Map#{<<"fields">> := Fields}, Surface, Oracle)).

first_oracle() -> hd([Oracle || Oracle <- all_oracles(), maps:get(<<"terminal_class">>, Oracle) =:= <<"complete">>]).
all_oracles() ->
    {ok, Corpus} = alang_fidelity_json:decode_file(corpus_path()),
    [alang_compact_corpus:oracle(Case) || Case <- maps:get(<<"cases">>, Corpus)].

contract_path() -> filename:join([phase2_dir(), "contracts", "source-map-v1.json"]).
registry_path() -> filename:join([phase2_dir(), "contracts", "surface-registry-v1.json"]).
phase2_dir() -> filename:join(["assets", "compact-projection-fidelity", "phase-02"]).
corpus_path() -> filename:join(["assets", "compact-projection-fidelity", "corpus", "confirmatory-corpus-v1.json"]).
