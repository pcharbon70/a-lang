-module(alang_fidelity_json_pointer).

-export([lookup/2, scan/1]).

-define(MAX_DEPTH, 32).
-define(MAX_ITEMS, 4096).

-spec scan(binary()) -> {ok, [map()]} | {error, term()}.
scan(Binary) when is_binary(Binary) ->
    try
        {Rest, Offset, Origins} = parse_value(Binary, 0, <<>>, 0, []),
        {Tail, _TailOffset} = skip_whitespace(Rest, Offset),
        case Tail of
            <<>> -> {ok, lists:sort(fun origin_before/2, Origins)};
            _ -> {error, trailing_json_data}
        end
    catch
        throw:{json_pointer_error, Reason} -> {error, Reason}
    end;
scan(_) ->
    {error, expected_binary}.

-spec lookup([map()], binary()) -> map().
lookup(Origins, Pointer) ->
    case [Origin || #{pointer := Candidate} = Origin <- Origins, Candidate =:= Pointer] of
        [Origin | _] -> Origin;
        [] -> lookup_parent(Origins, Pointer)
    end.

parse_value(_Binary, _Offset, _Pointer, Depth, _Origins) when Depth > ?MAX_DEPTH ->
    fail({json_depth_exceeded, ?MAX_DEPTH});
parse_value(Binary0, Offset0, Pointer, Depth, Origins) ->
    {Binary, Offset} = skip_whitespace(Binary0, Offset0),
    case Binary of
        <<${, Rest/binary>> ->
            parse_object(Rest, Offset + 1, Pointer, Depth + 1, #{}, 0,
                [origin(Pointer, Offset, object) | Origins]);
        <<$[, Rest/binary>> ->
            parse_array(Rest, Offset + 1, Pointer, Depth + 1, 0,
                [origin(Pointer, Offset, array) | Origins]);
        <<$", _/binary>> ->
            {_Raw, Rest, NextOffset} = take_string(Binary, Offset),
            {Rest, NextOffset, [origin(Pointer, Offset, value) | Origins]};
        <<"true", Rest/binary>> ->
            {Rest, Offset + 4, [origin(Pointer, Offset, value) | Origins]};
        <<"false", Rest/binary>> ->
            {Rest, Offset + 5, [origin(Pointer, Offset, value) | Origins]};
        <<"null", Rest/binary>> ->
            {Rest, Offset + 4, [origin(Pointer, Offset, value) | Origins]};
        <<Character, _/binary>> when Character =:= $-; Character >= $0, Character =< $9 ->
            {Rest, NextOffset} = take_number(Binary, Offset),
            {Rest, NextOffset, [origin(Pointer, Offset, value) | Origins]};
        _ ->
            fail({invalid_json_value, Offset})
    end.

parse_object(Binary0, Offset0, Pointer, Depth, Seen, Count, Origins) ->
    ensure_item_bound(Count),
    {Binary, Offset} = skip_whitespace(Binary0, Offset0),
    case Binary of
        <<$}, Rest/binary>> ->
            {Rest, Offset + 1, Origins};
        <<$", _/binary>> ->
            KeyOffset = Offset,
            {RawKey, AfterKey0, AfterKeyOffset0} = take_string(Binary, Offset),
            Key = decode_key(RawKey, KeyOffset),
            {AfterKey, AfterKeyOffset} = skip_whitespace(AfterKey0, AfterKeyOffset0),
            case AfterKey of
                <<$:, AfterColon/binary>> ->
                    ChildPointer = join(Pointer, escape(Key)),
                    case maps:is_key(Key, Seen) of
                        true -> fail({duplicate_key, Key, ChildPointer, KeyOffset});
                        false -> ok
                    end,
                    {AfterValue, ValueOffset, NextOrigins} = parse_value(
                        AfterColon, AfterKeyOffset + 1, ChildPointer, Depth, Origins
                    ),
                    {Delimiter, DelimiterOffset} = skip_whitespace(AfterValue, ValueOffset),
                    case Delimiter of
                        <<$,, Rest/binary>> ->
                            parse_object(Rest, DelimiterOffset + 1, Pointer, Depth,
                                Seen#{Key => true}, Count + 1, NextOrigins);
                        <<$}, Rest/binary>> ->
                            {Rest, DelimiterOffset + 1, NextOrigins};
                        _ ->
                            fail({expected_object_delimiter, DelimiterOffset})
                    end;
                _ ->
                    fail({expected_name_separator, AfterKeyOffset})
            end;
        _ ->
            fail({expected_object_member, Offset})
    end.

parse_array(Binary0, Offset0, Pointer, Depth, Index, Origins) ->
    ensure_item_bound(Index),
    {Binary, Offset} = skip_whitespace(Binary0, Offset0),
    case Binary of
        <<$], Rest/binary>> ->
            {Rest, Offset + 1, Origins};
        _ ->
            ChildPointer = join(Pointer, integer_to_binary(Index)),
            {AfterValue, ValueOffset, NextOrigins} = parse_value(
                Binary, Offset, ChildPointer, Depth, Origins
            ),
            {Delimiter, DelimiterOffset} = skip_whitespace(AfterValue, ValueOffset),
            case Delimiter of
                <<$,, Rest/binary>> ->
                    parse_array(Rest, DelimiterOffset + 1, Pointer, Depth,
                        Index + 1, NextOrigins);
                <<$], Rest/binary>> ->
                    {Rest, DelimiterOffset + 1, NextOrigins};
                _ ->
                    fail({expected_array_delimiter, DelimiterOffset})
            end
    end.

take_string(<<$", Rest/binary>> = Binary, Offset) ->
    {Tail, NextOffset} = scan_string(Rest, Offset + 1),
    Size = byte_size(Binary) - byte_size(Tail),
    {binary:part(Binary, 0, Size), Tail, NextOffset};
take_string(_Binary, Offset) ->
    fail({expected_json_string, Offset}).

scan_string(<<$", Rest/binary>>, Offset) ->
    {Rest, Offset + 1};
scan_string(<<$\\, Escape, Rest/binary>>, Offset) when
    Escape =:= $"; Escape =:= $\\; Escape =:= $/;
    Escape =:= $b; Escape =:= $f; Escape =:= $n;
    Escape =:= $r; Escape =:= $t
->
    scan_string(Rest, Offset + 2);
scan_string(<<$\\, $u, A, B, C, D, Rest/binary>>, Offset) ->
    case lists:all(fun is_hex/1, [A, B, C, D]) of
        true -> scan_string(Rest, Offset + 6);
        false -> fail({invalid_unicode_escape, Offset})
    end;
scan_string(<<Character, _/binary>>, Offset) when Character < 16#20 ->
    fail({unescaped_control_character, Offset});
scan_string(<<_Character, Rest/binary>>, Offset) ->
    scan_string(Rest, Offset + 1);
scan_string(<<>>, Offset) ->
    fail({unterminated_json_string, Offset}).

take_number(Binary, Offset) ->
    take_number(Binary, Offset, 0).

take_number(<<Character, Rest/binary>>, Offset, Count) when
    Character =:= $-; Character =:= $+; Character =:= $.;
    Character =:= $e; Character =:= $E;
    Character >= $0, Character =< $9
->
    take_number(Rest, Offset + 1, Count + 1);
take_number(Rest, Offset, Count) when Count > 0 ->
    {Rest, Offset};
take_number(_Rest, Offset, _Count) ->
    fail({invalid_json_number, Offset}).

decode_key(Raw, Offset) ->
    try json:decode(Raw) of
        Key when is_binary(Key) -> Key;
        _ -> fail({invalid_object_key, Offset})
    catch
        _:_ -> fail({invalid_object_key, Offset})
    end.

skip_whitespace(<<Character, Rest/binary>>, Offset) when
    Character =:= $\s; Character =:= $\t; Character =:= $\n; Character =:= $\r
->
    skip_whitespace(Rest, Offset + 1);
skip_whitespace(Binary, Offset) ->
    {Binary, Offset}.

lookup_parent(Origins, <<>>) ->
    case Origins of
        [Origin | _] -> Origin;
        [] -> origin(<<>>, 0, value)
    end;
lookup_parent(Origins, Pointer) ->
    Segments = binary:split(Pointer, <<"/">>, [global]),
    ParentSegments = lists:sublist(Segments, length(Segments) - 1),
    Parent = iolist_to_binary(lists:join(<<"/">>, ParentSegments)),
    lookup(Origins, Parent).

origin(Pointer, Byte, Kind) ->
    #{source => typed_json, pointer => Pointer, byte => Byte, kind => Kind}.

origin_before(Left, Right) ->
    {maps:get(pointer, Left), maps:get(byte, Left)} =<
        {maps:get(pointer, Right), maps:get(byte, Right)}.

join(<<>>, Segment) -> <<"/", Segment/binary>>;
join(Pointer, Segment) -> <<Pointer/binary, "/", Segment/binary>>.

escape(Key) ->
    binary:replace(binary:replace(Key, <<"~">>, <<"~0">>, [global]),
        <<"/">>, <<"~1">>, [global]).

ensure_item_bound(Count) when Count =< ?MAX_ITEMS -> ok;
ensure_item_bound(_Count) -> fail({json_collection_too_large, ?MAX_ITEMS}).

is_hex(Character) ->
    (Character >= $0 andalso Character =< $9) orelse
    (Character >= $a andalso Character =< $f) orelse
    (Character >= $A andalso Character =< $F).

fail(Reason) ->
    throw({json_pointer_error, Reason}).
