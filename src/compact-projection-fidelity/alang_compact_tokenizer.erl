-module(alang_compact_tokenizer).

-export([
    clear_cache/0,
    encode/3,
    load_runtime/1,
    profile/1,
    validate_runtime/1
]).

-define(MAX_DOCUMENT_BYTES, 32768).
-define(CACHE_KEY, {?MODULE, vocabularies}).

-spec profile(binary()) -> {ok, map()} | {error, term()}.
profile(<<"tiktoken-0.12.0-cl100k-base">>) ->
    {ok, cl100k_profile()};
profile(<<"tiktoken-0.12.0-o200k-base">>) ->
    {ok, o200k_profile()};
profile(ProfileId) ->
    {error, {unknown_tokenizer_profile, ProfileId}}.

-spec load_runtime(file:filename()) -> {ok, map()} | {error, term()}.
load_runtime(Path) ->
    case alang_fidelity_json:decode_file(Path) of
        {ok, Value} -> validate_runtime(Value);
        {error, Reason} -> {error, {tokenizer_runtime_read_failed, Reason}}
    end.

-spec validate_runtime(term()) -> {ok, map()} | {error, term()}.
validate_runtime(Value) when is_map(Value) ->
    Expected = expected_runtime(),
    case Value =:= Expected of
        true -> {ok, Value};
        false -> {error, {tokenizer_runtime_mismatch,
            alang_fidelity_json:digest(Expected),
            alang_fidelity_json:digest(Value)}}
    end;
validate_runtime(Value) ->
    {error, {invalid_tokenizer_runtime, Value}}.

-spec encode(binary(), binary(), file:filename()) -> {ok, map()} | {error, term()}.
encode(ProfileId, Binary, TokenizerDirectory)
  when is_binary(Binary), byte_size(Binary) =< ?MAX_DOCUMENT_BYTES ->
    case valid_utf8(Binary) of
        true ->
            case profile(ProfileId) of
                {ok, Profile} -> encode_registered(Profile, Binary, TokenizerDirectory);
                {error, _} = Error -> Error
            end;
        false ->
            {error, invalid_utf8}
    end;
encode(_ProfileId, Binary, _TokenizerDirectory) when is_binary(Binary) ->
    {error, {tokenizer_document_too_large, byte_size(Binary), ?MAX_DOCUMENT_BYTES}};
encode(_ProfileId, _Binary, _TokenizerDirectory) ->
    {error, expected_binary}.

-spec clear_cache() -> ok.
clear_cache() ->
    persistent_term:erase(?CACHE_KEY),
    ok.

encode_registered(Profile, Binary, TokenizerDirectory) ->
    Pattern = maps:get(pretokenizer, Profile),
    PatternDigest = hex(crypto:hash(sha256, Pattern)),
    case PatternDigest =:= maps:get(pretokenizer_sha256, Profile) of
        true ->
            case vocabulary(Profile, TokenizerDirectory) of
                {ok, Ranks} ->
            case pretokenize(Binary, Pattern) of
                {ok, Pieces} ->
                    TokenIds = lists:append([encode_piece(Piece, Ranks) || Piece <- Pieces]),
                    {ok, #{
                        profile_id => maps:get(id, Profile),
                        implementation => <<"beam-byte-pair-encoding-v1">>,
                        count_provenance => exact_registered_tokenizer,
                        token_count => length(TokenIds),
                        token_ids => TokenIds
                    }};
                {error, _} = Error -> Error
                    end;
                {error, _} = Error -> Error
            end;
        false ->
            {error, {pretokenizer_digest_mismatch,
                maps:get(pretokenizer_sha256, Profile), PatternDigest}}
    end.

vocabulary(Profile, TokenizerDirectory) ->
    ProfileId = maps:get(id, Profile),
    Path = filename:join(TokenizerDirectory, binary_to_list(maps:get(vocabulary_file, Profile))),
    Cache = persistent_term:get(?CACHE_KEY, #{}),
    case maps:find({ProfileId, Path}, Cache) of
        {ok, Ranks} ->
            {ok, Ranks};
        error ->
            load_vocabulary(Profile, Path, Cache)
    end.

load_vocabulary(Profile, Path, Cache) ->
    case file:read_file(Path) of
        {ok, Binary} ->
            ActualDigest = hex(crypto:hash(sha256, Binary)),
            ExpectedDigest = maps:get(vocabulary_sha256, Profile),
            case ActualDigest =:= ExpectedDigest of
                true ->
                    case parse_vocabulary(Binary, maps:get(mergeable_tokens, Profile)) of
                        {ok, Ranks} ->
                            Key = {maps:get(id, Profile), Path},
                            persistent_term:put(?CACHE_KEY, Cache#{Key => Ranks}),
                            {ok, Ranks};
                        {error, _} = Error -> Error
                    end;
                false ->
                    {error, {vocabulary_digest_mismatch, Path, ExpectedDigest, ActualDigest}}
            end;
        {error, Reason} ->
            {error, {vocabulary_read_failed, Path, Reason}}
    end.

parse_vocabulary(Binary, ExpectedCount) ->
    Lines = binary:split(Binary, <<"\n">>, [global, trim_all]),
    case length(Lines) =:= ExpectedCount of
        true -> parse_vocabulary_lines(Lines, 0, #{});
        false -> {error, {vocabulary_token_count_mismatch, ExpectedCount, length(Lines)}}
    end.

parse_vocabulary_lines([], _ExpectedRank, Ranks) ->
    {ok, Ranks};
parse_vocabulary_lines([Line | Rest], ExpectedRank, Ranks) ->
    case binary:split(Line, <<" ">>, [global]) of
        [EncodedToken, RankBinary] ->
            try {base64:decode(EncodedToken), binary_to_integer(RankBinary)} of
                {Token, ExpectedRank} when not is_map_key(Token, Ranks) ->
                    parse_vocabulary_lines(Rest, ExpectedRank + 1, Ranks#{Token => ExpectedRank});
                {_Token, Rank} ->
                    {error, {invalid_vocabulary_rank, ExpectedRank, Rank}}
            catch
                _:_ -> {error, {invalid_vocabulary_line, ExpectedRank}}
            end;
        _ ->
            {error, {invalid_vocabulary_line, ExpectedRank}}
    end.

pretokenize(<<>>, _Pattern) ->
    {ok, []};
pretokenize(Binary, Pattern) ->
    try re:run(Binary, Pattern, [unicode, global, {capture, first, binary}]) of
        {match, Captures} ->
            Pieces = [Piece || [Piece] <- Captures],
            case iolist_to_binary(Pieces) =:= Binary of
                true -> {ok, Pieces};
                false -> {error, pretokenizer_did_not_cover_input}
            end;
        nomatch ->
            {error, pretokenizer_did_not_match_input}
    catch
        error:Reason -> {error, {pretokenizer_failed, Reason}}
    end.

encode_piece(Piece, Ranks) ->
    case maps:find(Piece, Ranks) of
        {ok, Rank} -> [Rank];
        error ->
            Segments = merge_all(byte_segments(Piece), Ranks),
            [maps:get(Segment, Ranks) || Segment <- Segments]
    end.

byte_segments(Binary) ->
    [<<Byte>> || <<Byte>> <= Binary].

merge_all(Segments, Ranks) ->
    case best_pair(Segments, Ranks, 0, none) of
        none -> Segments;
        {Index, _Rank} -> merge_all(merge_at(Segments, Index, 0, []), Ranks)
    end.

best_pair([_Only], _Ranks, _Index, Best) ->
    Best;
best_pair([Left, Right | Rest], Ranks, Index, Best) ->
    Candidate = case maps:find(<<Left/binary, Right/binary>>, Ranks) of
        {ok, Rank} -> choose_pair({Index, Rank}, Best);
        error -> Best
    end,
    best_pair([Right | Rest], Ranks, Index + 1, Candidate);
best_pair([], _Ranks, _Index, Best) ->
    Best.

choose_pair(Candidate, none) ->
    Candidate;
choose_pair({_Index, Rank} = Candidate, {_BestIndex, BestRank}) when Rank < BestRank ->
    Candidate;
choose_pair(_Candidate, Best) ->
    Best.

merge_at([Left, Right | Rest], Target, Target, Acc) ->
    lists:reverse(Acc, [<<Left/binary, Right/binary>> | Rest]);
merge_at([Head | Rest], Target, Index, Acc) ->
    merge_at(Rest, Target, Index + 1, [Head | Acc]).

valid_utf8(Binary) ->
    case unicode:characters_to_binary(Binary, utf8, utf8) of
        Binary -> true;
        _ -> false
    end.

expected_runtime() ->
    #{
        <<"format">> => <<"alang-compact-tokenizer-runtime-v1">>,
        <<"implementation">> => <<"beam-byte-pair-encoding-v1">>,
        <<"provider_accounting">> => <<"authoritative-for-live-provider-and-full-request-metrics">>,
        <<"profiles">> => [public_profile(cl100k_profile()), public_profile(o200k_profile())],
        <<"bounds">> => #{<<"max_document_bytes">> => 32768, <<"max_pretoken_bytes">> => 32768},
        <<"unknown_profile">> => <<"reject">>,
        <<"aliases">> => []
    }.

public_profile(Profile) ->
    #{
        <<"id">> => maps:get(id, Profile),
        <<"encoding">> => maps:get(encoding, Profile),
        <<"vocabulary_file">> => maps:get(vocabulary_file, Profile),
        <<"vocabulary_sha256">> => maps:get(vocabulary_sha256, Profile),
        <<"mergeable_tokens">> => maps:get(mergeable_tokens, Profile),
        <<"pretokenizer">> => maps:get(pretokenizer, Profile),
        <<"pretokenizer_sha256">> => maps:get(pretokenizer_sha256, Profile)
    }.

cl100k_profile() ->
    #{
        id => <<"tiktoken-0.12.0-cl100k-base">>,
        encoding => <<"cl100k_base">>,
        vocabulary_file => <<"cl100k_base.tiktoken">>,
        vocabulary_sha256 => <<"223921b76ee99bde995b7ff738513eef100fb51d18c93597a113bcffe865b2a7">>,
        mergeable_tokens => 100256,
        pretokenizer => <<"'(?i:[sdmt]|ll|ve|re)|[^\\r\\n\\p{L}\\p{N}]?+\\p{L}++|\\p{N}{1,3}+| ?[^\\s\\p{L}\\p{N}]++[\\r\\n]*+|\\s++$|\\s*[\\r\\n]|\\s+(?!\\S)|\\s">>,
        pretokenizer_sha256 => <<"f021c3d976978e62ee64cdad150cc3405c2e3d6e3b40407850bb9e8d9eb65899">>
    }.

o200k_profile() ->
    #{
        id => <<"tiktoken-0.12.0-o200k-base">>,
        encoding => <<"o200k_base">>,
        vocabulary_file => <<"o200k_base.tiktoken">>,
        vocabulary_sha256 => <<"446a9538cb6c348e3516120d7c08b09f57c36495e2acfffe59a5bf8b0cfb1a2d">>,
        mergeable_tokens => 199998,
        pretokenizer => <<"[^\\r\\n\\p{L}\\p{N}]?[\\p{Lu}\\p{Lt}\\p{Lm}\\p{Lo}\\p{M}]*[\\p{Ll}\\p{Lm}\\p{Lo}\\p{M}]+(?i:'s|'t|'re|'ve|'m|'ll|'d)?|[^\\r\\n\\p{L}\\p{N}]?[\\p{Lu}\\p{Lt}\\p{Lm}\\p{Lo}\\p{M}]+[\\p{Ll}\\p{Lm}\\p{Lo}\\p{M}]*(?i:'s|'t|'re|'ve|'m|'ll|'d)?|\\p{N}{1,3}| ?[^\\s\\p{L}\\p{N}]+[\\r\\n/]*|\\s*[\\r\\n]+|\\s+(?!\\S)|\\s+">>,
        pretokenizer_sha256 => <<"2d1b8dc11e89af71459b36004f698ab3693f59fd84f63e8ec2b49564ab857420">>
    }.

hex(Binary) ->
    << <<(hex_digit(Byte bsr 4)), (hex_digit(Byte band 16#0f))>> || <<Byte>> <= Binary >>.

hex_digit(Value) when Value < 10 -> $0 + Value;
hex_digit(Value) -> $a + Value - 10.
