-module(alang_compact_tokenizer_tests).

-include_lib("eunit/include/eunit.hrl").

runtime_registration_is_exact_and_aliases_are_rejected_test() ->
    Runtime = filename:join(tokenizer_dir(), "tokenizer-runtime-v1.json"),
    ?assertMatch({ok, _}, alang_compact_tokenizer:load_runtime(Runtime)),
    ?assertMatch({error, {unknown_tokenizer_profile, <<"cl100k_base">>}},
        alang_compact_tokenizer:profile(<<"cl100k_base">>)),
    {ok, Value} = alang_fidelity_json:decode_file(Runtime),
    ?assertMatch({error, {tokenizer_runtime_mismatch, _, _}},
        alang_compact_tokenizer:validate_runtime(Value#{<<"aliases">> := [<<"cl100k">>]})).

reference_token_vectors_match_exactly_test_() ->
    {timeout, 60, fun() ->
        alang_compact_tokenizer:clear_cache(),
        {ok, Fixture} = alang_fidelity_json:decode_file(
            filename:join(tokenizer_dir(), "tokenizer-conformance-v1.json")),
        lists:foreach(fun(Vector) ->
            Text = maps:get(<<"text">>, Vector),
            Expected = maps:get(<<"tokens">>, Vector),
            lists:foreach(fun(ProfileId) ->
                {ok, Encoded} = alang_compact_tokenizer:encode(ProfileId, Text, tokenizer_dir()),
                ?assertEqual(maps:get(ProfileId, Expected), maps:get(token_ids, Encoded)),
                ?assertEqual(exact_registered_tokenizer, maps:get(count_provenance, Encoded))
            end, profile_ids())
        end, maps:get(<<"vectors">>, Fixture))
    end}.

digest_bounds_and_encoding_fail_closed_test() ->
    ?assertMatch({error, invalid_utf8},
        alang_compact_tokenizer:encode(hd(profile_ids()), <<16#ff>>, tokenizer_dir())),
    ?assertMatch({error, {tokenizer_document_too_large, _, 32768}},
        alang_compact_tokenizer:encode(hd(profile_ids()), binary:copy(<<"x">>, 32769), tokenizer_dir())),
    alang_compact_tokenizer:clear_cache(),
    ?assertMatch({error, {vocabulary_read_failed, _, _}},
        alang_compact_tokenizer:encode(hd(profile_ids()), <<"hello">>, "/not/a/tokenizer/directory")).

profile_ids() ->
    [<<"tiktoken-0.12.0-cl100k-base">>, <<"tiktoken-0.12.0-o200k-base">>].

tokenizer_dir() ->
    filename:join(["assets", "compact-projection-fidelity", "phase-02", "tokenizers"]).
