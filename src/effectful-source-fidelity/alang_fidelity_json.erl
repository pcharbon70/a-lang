-module(alang_fidelity_json).

-export([decode/1, decode_file/1, digest/1, encode_canonical/1, hex/1]).

-define(MAX_DOCUMENT_BYTES, 1048576).
-define(MAX_DEPTH, 32).
-define(MAX_COLLECTION_ITEMS, 4096).
-define(MAX_STRING_BYTES, 65536).

-spec decode(binary()) -> {ok, term()} | {error, term()}.
decode(Binary) when is_binary(Binary), byte_size(Binary) =< ?MAX_DOCUMENT_BYTES ->
    Decoders = #{
        object_start => fun object_start/1,
        object_push => fun object_push/3,
        object_finish => fun object_finish/2
    },
    try json:decode(Binary, ok, Decoders) of
        {Value, ok, Rest} ->
            case trim_ascii(Rest) of
                <<>> ->
                    case bounded(Value, 0) of
                        ok -> {ok, Value};
                        {error, _} = Error -> Error
                    end;
                _ ->
                    {error, trailing_json_data}
            end
    catch
        error:{duplicate_key, Key} ->
            {error, {duplicate_key, Key}};
        Class:Reason ->
            {error, {invalid_json, Class, Reason}}
    end;
decode(Binary) when is_binary(Binary) ->
    {error, {document_too_large, byte_size(Binary), ?MAX_DOCUMENT_BYTES}};
decode(_) ->
    {error, expected_binary}.

-spec decode_file(file:filename()) -> {ok, term()} | {error, term()}.
decode_file(Path) ->
    case file:read_file(Path) of
        {ok, Binary} -> decode(Binary);
        {error, Reason} -> {error, {read_failed, Path, Reason}}
    end.

-spec digest(term()) -> binary().
digest(Term) ->
    hex(crypto:hash(sha256, term_to_binary(Term, [deterministic]))).

-spec encode_canonical(term()) -> {ok, binary()} | {error, term()}.
encode_canonical(Value) ->
    case bounded(Value, 0) of
        ok ->
            try iolist_to_binary(canonical(Value)) of
                Binary -> {ok, Binary}
            catch
                throw:{canonical_json_error, Reason} -> {error, Reason};
                Class:Reason -> {error, {json_encode_failed, Class, Reason}}
            end;
        {error, _} = Error -> Error
    end.

-spec hex(binary()) -> binary().
hex(Binary) ->
    << <<(hex_digit(Byte bsr 4)), (hex_digit(Byte band 16#0f))>>
       || <<Byte>> <= Binary >>.

object_start(_OldAcc) ->
    #{}.

object_push(Key, Value, Object) ->
    case maps:is_key(Key, Object) of
        true -> error({duplicate_key, Key});
        false -> Object#{Key => Value}
    end.

object_finish(Object, OldAcc) ->
    {Object, OldAcc}.

bounded(_Value, Depth) when Depth > ?MAX_DEPTH ->
    {error, {json_depth_exceeded, ?MAX_DEPTH}};
bounded(Value, _Depth) when is_binary(Value), byte_size(Value) > ?MAX_STRING_BYTES ->
    {error, {json_string_too_large, byte_size(Value), ?MAX_STRING_BYTES}};
bounded(Value, _Depth) when is_binary(Value) ->
    ok;
bounded(Value, Depth) when is_map(Value) ->
    case maps:size(Value) =< ?MAX_COLLECTION_ITEMS of
        true -> bounded_pairs(maps:to_list(Value), Depth + 1);
        false -> {error, {json_object_too_large, maps:size(Value), ?MAX_COLLECTION_ITEMS}}
    end;
bounded(Value, Depth) when is_list(Value) ->
    case length(Value) =< ?MAX_COLLECTION_ITEMS of
        true -> bounded_list(Value, Depth + 1);
        false -> {error, {json_array_too_large, length(Value), ?MAX_COLLECTION_ITEMS}}
    end;
bounded(Value, _Depth)
  when is_integer(Value); is_float(Value); is_boolean(Value); Value =:= null ->
    ok;
bounded(Value, _Depth) ->
    {error, {unsupported_json_value, Value}}.

bounded_pairs([], _Depth) ->
    ok;
bounded_pairs([{Key, Value} | Rest], Depth) ->
    case bounded(Key, Depth) of
        ok ->
            case bounded(Value, Depth) of
                ok -> bounded_pairs(Rest, Depth);
                {error, _} = Error -> Error
            end;
        {error, _} = Error -> Error
    end.

bounded_list([], _Depth) ->
    ok;
bounded_list([Value | Rest], Depth) ->
    case bounded(Value, Depth) of
        ok -> bounded_list(Rest, Depth);
        {error, _} = Error -> Error
    end.

trim_ascii(<<Character, Rest/binary>>)
  when Character =:= $\s; Character =:= $\t; Character =:= $\n; Character =:= $\r ->
    trim_ascii(Rest);
trim_ascii(Binary) ->
    Binary.

hex_digit(Value) when Value < 10 -> $0 + Value;
hex_digit(Value) -> $a + Value - 10.

canonical(Value) when is_map(Value) ->
    Pairs = lists:sort(maps:to_list(Value)),
    [${, join([
        begin
            ensure_binary_key(Key),
            [json:encode(Key), $:, canonical(Item)]
        end
        || {Key, Item} <- Pairs
    ], $,), $}];
canonical(Value) when is_list(Value) ->
    [$[, join([canonical(Item) || Item <- Value], $,), $]];
canonical(Value) when is_binary(Value) -> json:encode(Value);
canonical(Value) when is_integer(Value); is_float(Value);
                           is_boolean(Value); Value =:= null ->
    json:encode(Value);
canonical(Value) -> throw({canonical_json_error, {unsupported_json_value, Value}}).

join([], _Separator) -> [];
join([Only], _Separator) -> Only;
join([Head | Rest], Separator) -> [Head, Separator, join(Rest, Separator)].

ensure_binary_key(Key) when is_binary(Key) -> ok;
ensure_binary_key(Key) -> throw({canonical_json_error, {invalid_json_key, Key}}).
