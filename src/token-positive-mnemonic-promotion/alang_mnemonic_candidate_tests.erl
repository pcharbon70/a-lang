-module(alang_mnemonic_candidate_tests).

-include_lib("eunit/include/eunit.hrl").

contract_and_exact_references_validate_test() ->
    ?assertMatch({ok, _}, alang_mnemonic_candidate:load(contract_path(), ".")),
    {ok, Contract} = alang_fidelity_json:decode_file(contract_path()),
    [Renderer | References] = maps:get(<<"references">>, Contract),
    ?assertMatch({error, _}, alang_mnemonic_candidate:validate(
        Contract#{<<"references">> := [Renderer#{<<"sha256">> := zeros()} | References]}, ".")).

fresh_and_generated_pairs_match_r2_and_semantics_test_() ->
    {timeout, 60, fun() ->
        Oracles = development_oracles() ++ prior_confirmatory_oracles() ++
            fresh_oracles() ++ generated_oracles(),
        lists:foreach(fun(Oracle) ->
            {ok, Pair} = alang_mnemonic_candidate:compare(Oracle, "."),
            P1 = maps:get(<<"p1">>, Pair),
            {ok, R2} = alang_compact_surface:render(<<"R2">>,
                <<"alang-source-v2-alias-v1">>, Oracle, registry_path()),
            ?assertEqual(maps:get(bytes, R2), maps:get(bytes, P1)),
            ?assertEqual(true, maps:get(<<"p1_r2_byte_equal">>, Pair))
        end, Oracles),
        ?assertEqual(136, length(Oracles))
    end}.

acceptance_and_decode_are_exact_r2_delegations_test() ->
    Oracle = hd(fresh_oracles()),
    {ok, P1} = alang_mnemonic_candidate:render(<<"P1">>, Oracle, "."),
    Bytes = maps:get(bytes, P1),
    Inputs = [Bytes, binary:replace(Bytes, <<"cap{">>, <<"at{">>),
        binary:replace(Bytes, <<"~s=">>, <<"~zz=">>),
        <<"#!alang-source-v2-alias-v1\ntask broken{wat[]}">>,
        <<16#ff, 16#fe>>, binary:copy(<<"x">>, 32769)],
    lists:foreach(fun(Input) ->
        Candidate = alang_mnemonic_candidate:decode(<<"P1">>, Input, "."),
        R2 = alang_compact_surface:decode(<<"R2">>,
            <<"alang-source-v2-alias-v1">>, Input),
        ?assertEqual(classify(R2), classify(Candidate)),
        case {R2, Candidate} of
            {{ok, R}, {ok, C}} -> ?assertEqual(maps:get(semantic_digest, R),
                maps:get(semantic_digest, C));
            _ -> ok
        end
    end, Inputs),
    ?assertMatch({error, {surface_version_mismatch, _, _, _}},
        alang_mnemonic_candidate:decode_versioned(<<"P1">>,
            <<"alang-source-v2">>, Bytes, ".")).

source_maps_are_complete_stable_and_readable_test_() ->
    {timeout, 60, fun() ->
        lists:foreach(fun(Oracle) ->
            {ok, P1} = alang_mnemonic_candidate:render(<<"P1">>, Oracle, "."),
            Map = maps:get(source_map, P1),
            ?assertMatch({ok, _}, alang_compact_source_map:validate(Map, P1, Oracle)),
            Tokens = maps:get(<<"tokens">>, Map),
            ?assertEqual(0, maps:get(<<"from">>, hd(Tokens))),
            ?assertEqual(maps:get(byte_count, P1), maps:get(<<"to">>, lists:last(Tokens))),
            ?assert(lists:all(fun(F) -> maps:get(<<"readable_spans">>, F) =/= [] end,
                maps:get(<<"fields">>, Map))),
            {ok, Shuffled} = alang_mnemonic_candidate:render(<<"P1">>, reverse_maps(Oracle), "."),
            ?assertEqual(maps:get(bytes, P1), maps:get(bytes, Shuffled)),
            ?assertEqual(Map, maps:get(source_map, Shuffled))
        end, lists:sublist(fresh_oracles(), 8))
    end}.

diagnostics_target_readable_source_test() ->
    Oracle = hd(fresh_oracles()),
    {ok, P1} = alang_mnemonic_candidate:render(<<"P1">>, Oracle, "."),
    Map = maps:get(source_map, P1),
    Diagnostic = alang_compact_source_map:diagnostic(Map, <<"/budgets/steps">>,
        <<"invalid-budget">>, <<"steps exceeds the checked limit">>),
    Readable = maps:get(<<"readable_source">>, Diagnostic),
    ?assertEqual(<<"readable-source">>, maps:get(<<"edit_target">>, Readable)),
    ?assert(maps:get(<<"spans">>, Readable) =/= []).

trusted_candidate_modules_load_from_beam_test() ->
    lists:foreach(fun(Module) ->
        Path = code:which(Module),
        ?assert(is_list(Path)),
        ?assertEqual(".beam", filename:extension(Path))
    end, [alang_mnemonic_candidate, alang_compact_surface,
        alang_compact_source_map, alang_fidelity_source]).

classify({ok, _}) -> ok;
classify({error, _}) -> error.

fresh_oracles() ->
    {ok, Corpus} = alang_fidelity_json:decode_file(filename:join([
        "assets", "token-positive-mnemonic-promotion", "corpus",
        "confirmatory-corpus-v1.json"])),
    [alang_mnemonic_corpus:oracle(Case) || Case <- maps:get(<<"cases">>, Corpus)].

generated_oracles() ->
    [Oracle#{<<"case_id">> := <<"tp-generated-", (integer_to_binary(I))/binary>>}
        || {Oracle, I} <- lists:zip(lists:sublist(fresh_oracles(), 16), lists:seq(1, 16))].

prior_confirmatory_oracles() ->
    {ok, Corpus} = alang_fidelity_json:decode_file(filename:join([
        "assets", "compact-projection-fidelity", "corpus",
        "confirmatory-corpus-v1.json"])),
    [alang_compact_corpus:oracle(Case) || Case <- maps:get(<<"cases">>, Corpus)].

development_oracles() ->
    Directory = filename:join(["assets", "effectful-source-fidelity", "corpus"]),
    {ok, Manifest} = alang_fidelity_json:decode_file(filename:join(Directory,
        "corpus-manifest-v1.json")),
    [begin
        ControlPath = filename:join(Directory,
            binary_to_list(maps:get(<<"path">>, maps:get(<<"control">>, Case)))),
        {ok, Control} = alang_fidelity_json:decode_file(ControlPath),
        {ok, Decoded} = alang_fidelity_representation:validate_control(Control),
        (maps:get(<<"semantic">>, Decoded))#{
            <<"format">> => <<"alang_task_comprehension_v1">>,
            <<"case_id">> => maps:get(<<"case_id">>, Control)}
    end || Case <- maps:get(<<"cases">>, Manifest)].

reverse_maps(Value) when is_map(Value) ->
    maps:from_list(lists:reverse([{Key, reverse_maps(Child)} || {Key, Child} <- maps:to_list(Value)]));
reverse_maps(Value) when is_list(Value) -> [reverse_maps(Child) || Child <- Value];
reverse_maps(Value) -> Value.

contract_path() -> filename:join(["assets", "token-positive-mnemonic-promotion",
    "phase-02", "contracts", "candidate-contract-v1.json"]).
registry_path() -> filename:join(["assets", "compact-projection-fidelity",
    "phase-02", "contracts", "surface-registry-v1.json"]).
zeros() -> <<"0000000000000000000000000000000000000000000000000000000000000000">>.
