-module(alang_fidelity_lexer).

-export([scan/1]).

-define(MAX_SOURCE_BYTES, 1048576).
-define(MAX_IDENTIFIER_BYTES, 128).
-define(MAX_STRING_BYTES, 4096).

-type origin() :: #{byte := non_neg_integer(), line := pos_integer(), column := pos_integer()}.
-type token() :: {atom(), term(), origin()}.

-spec scan(binary()) -> {ok, [token()]} | {error, [map()]}.
scan(Source) when is_binary(Source), byte_size(Source) =< ?MAX_SOURCE_BYTES ->
    case validate_utf8(Source) of
        ok -> scan_initial(Source);
        {error, Byte, Line, Column} ->
            {error, [diagnostic(invalid_utf8, Byte, Line, Column, <<"source is not valid UTF-8">>)]}
    end;
scan(Source) when is_binary(Source) ->
    {error, [diagnostic(source_too_large, 0, 1, 1, <<"source exceeds 1 MiB">>)]};
scan(_) ->
    {error, [diagnostic(invalid_source, 0, 1, 1, <<"source must be UTF-8 binary data">>)]}.

scan_initial(<<"#!alang-source-v2", Rest/binary>>) ->
    Header = <<"#!alang-source-v2">>,
    Size = byte_size(Header),
    scan(Rest, Size, 1, Size + 1, [{source_version, <<"alang-source-v2">>, origin(0, 1, 1)}]);
scan_initial(Source) ->
    scan(Source, 0, 1, 1, []).

scan(<<>>, Byte, Line, Column, Acc) ->
    {ok, lists:reverse([{eof, none, origin(Byte, Line, Column)} | Acc])};
scan(<<C, Rest/binary>>, Byte, Line, Column, Acc) when C =:= $ ; C =:= $\t; C =:= $\r ->
    scan(Rest, Byte + 1, Line, Column + 1, Acc);
scan(<<$\n, Rest/binary>>, Byte, Line, _Column, Acc) ->
    scan(Rest, Byte + 1, Line + 1, 1, Acc);
scan(<<$/, $/, Rest/binary>>, Byte, Line, Column, Acc) ->
    {Tail, NextByte, NextLine, NextColumn} = skip_comment(Rest, Byte + 2, Line, Column + 2),
    scan(Tail, NextByte, NextLine, NextColumn, Acc);
scan(<<C, _/binary>> = Input, Byte, Line, Column, Acc) when
    (C >= $a andalso C =< $z) orelse
        (C >= $A andalso C =< $Z) orelse
        C =:= $_
->
    {Word, Rest} = take_identifier(Input, <<>>),
    Size = byte_size(Word),
    case Size =< ?MAX_IDENTIFIER_BYTES of
        true ->
            {Kind, Value} = keyword(Word),
            scan(Rest, Byte + Size, Line, Column + Size, [{Kind, Value, origin(Byte, Line, Column)} | Acc]);
        false ->
            {error, [diagnostic(identifier_too_long, Byte, Line, Column, <<"identifier exceeds 128 bytes">>)]}
    end;
scan(<<C, _/binary>> = Input, Byte, Line, Column, Acc) when C >= $0, C =< $9 ->
    {Digits, Rest} = take_digits(Input, <<>>),
    Size = byte_size(Digits),
    case Size =< 19 of
        true ->
            scan(
                Rest,
                Byte + Size,
                Line,
                Column + Size,
                [{integer, binary_to_integer(Digits), origin(Byte, Line, Column)} | Acc]
            );
        false ->
            {error, [diagnostic(integer_literal_too_long, Byte, Line, Column, <<"integer literal exceeds 19 digits">>)]}
    end;
scan(<<$\", Rest/binary>>, Byte, Line, Column, Acc) ->
    case take_string(Rest, <<>>, Byte + 1, Line, Column + 1) of
        {ok, String, Tail, NextByte, NextLine, NextColumn} ->
            scan(
                Tail,
                NextByte,
                NextLine,
                NextColumn,
                [{string, String, origin(Byte, Line, Column)} | Acc]
            );
        {error, Diagnostic} ->
            {error, [Diagnostic]}
    end;
scan(<<$=, $>, Rest/binary>>, Byte, Line, Column, Acc) ->
    scan(Rest, Byte + 2, Line, Column + 2, [{fat_arrow, none, origin(Byte, Line, Column)} | Acc]);
scan(<<C, Rest/binary>>, Byte, Line, Column, Acc) ->
    case punctuation(C) of
        unknown ->
            {error, [
                diagnostic(
                    invalid_character,
                    Byte,
                    Line,
                    Column,
                    <<"unsupported character in A-Lang source">>
                )
            ]};
        Kind ->
            scan(Rest, Byte + 1, Line, Column + 1, [{Kind, none, origin(Byte, Line, Column)} | Acc])
    end.

take_identifier(<<C, Rest/binary>>, Acc) when
    (C >= $a andalso C =< $z) orelse
        (C >= $A andalso C =< $Z) orelse
        (C >= $0 andalso C =< $9) orelse
        C =:= $_ orelse
        C =:= $-
->
    take_identifier(Rest, <<Acc/binary, C>>);
take_identifier(Rest, Acc) ->
    {Acc, Rest}.

take_digits(<<C, Rest/binary>>, Acc) when C >= $0, C =< $9 ->
    take_digits(Rest, <<Acc/binary, C>>);
take_digits(Rest, Acc) ->
    {Acc, Rest}.

take_string(<<>>, _Acc, Byte, Line, Column) ->
    {error, diagnostic(unterminated_string, Byte, Line, Column, <<"unterminated string literal">>)};
take_string(<<$\n, _/binary>>, _Acc, Byte, Line, Column) ->
    {error, diagnostic(unterminated_string, Byte, Line, Column, <<"string literal cannot cross a line">>)};
take_string(<<$\", Rest/binary>>, Acc, Byte, Line, Column) ->
    {ok, Acc, Rest, Byte + 1, Line, Column + 1};
take_string(<<$\\, $\", Rest/binary>>, Acc, Byte, Line, Column) ->
    append_string(Rest, Acc, <<$\">>, Byte + 2, Line, Column + 2);
take_string(<<$\\, $\\, Rest/binary>>, Acc, Byte, Line, Column) ->
    append_string(Rest, Acc, <<$\\>>, Byte + 2, Line, Column + 2);
take_string(<<$\\, _/binary>>, _Acc, Byte, Line, Column) ->
    {error, diagnostic(invalid_string_escape, Byte, Line, Column, <<"only quote and backslash escapes are accepted">>)};
take_string(<<$$, ${, _/binary>>, _Acc, Byte, Line, Column) ->
    {error, diagnostic(string_interpolation_forbidden, Byte, Line, Column, <<"string interpolation is not accepted">>)};
take_string(<<C, _/binary>>, _Acc, Byte, Line, Column) when C < 32 ->
    {error, diagnostic(invalid_string_character, Byte, Line, Column, <<"string contains a control character">>)};
take_string(<<Codepoint/utf8, Rest/binary>>, Acc, Byte, Line, Column) ->
    Encoded = unicode:characters_to_binary([Codepoint]),
    append_string(Rest, Acc, Encoded, Byte + byte_size(Encoded), Line, Column + 1).

append_string(Rest, Acc, Encoded, Byte, Line, Column) ->
    case byte_size(Acc) + byte_size(Encoded) =< ?MAX_STRING_BYTES of
        true -> take_string(Rest, <<Acc/binary, Encoded/binary>>, Byte, Line, Column);
        false ->
            {error, diagnostic(string_literal_too_long, Byte, Line, Column, <<"string literal exceeds 4096 bytes">>)}
    end.

skip_comment(<<>>, Byte, Line, Column) ->
    {<<>>, Byte, Line, Column};
skip_comment(<<$\n, Rest/binary>>, Byte, Line, _Column) ->
    {Rest, Byte + 1, Line + 1, 1};
skip_comment(<<Codepoint/utf8, Rest/binary>>, Byte, Line, Column) ->
    Encoded = unicode:characters_to_binary([Codepoint]),
    skip_comment(Rest, Byte + byte_size(Encoded), Line, Column + 1).

keyword(<<"task">>) -> {task_kw, none};
keyword(<<"facts">>) -> {facts_kw, none};
keyword(<<"input">>) -> {input_kw, none};
keyword(<<"effects">>) -> {effects_kw, none};
keyword(<<"requirements">>) -> {requirements_kw, none};
keyword(<<"scopes">>) -> {scopes_kw, none};
keyword(<<"limits">>) -> {limits_kw, none};
keyword(<<"step">>) -> {step_kw, none};
keyword(<<"depends">>) -> {depends_kw, none};
keyword(<<"on-error">>) -> {on_error_kw, none};
keyword(<<"child">>) -> {child_kw, none};
keyword(<<"none">>) -> {none_kw, none};
keyword(<<"complete">>) -> {complete_kw, none};
keyword(<<"clarify">>) -> {clarify_kw, none};
keyword(<<"terminal">>) -> {terminal_kw, none};
keyword(<<"required">>) -> {required_kw, none};
keyword(<<"optional">>) -> {optional_kw, none};
keyword(<<"true">>) -> {true_kw, true};
keyword(<<"false">>) -> {false_kw, false};
keyword(Word) -> {identifier, Word}.

punctuation(${) -> lbrace;
punctuation($}) -> rbrace;
punctuation($[) -> lbracket;
punctuation($]) -> rbracket;
punctuation($:) -> colon;
punctuation($;) -> semicolon;
punctuation($,) -> comma;
punctuation($.) -> dot;
punctuation(_) -> unknown.

validate_utf8(Binary) ->
    case unicode:characters_to_binary(Binary, utf8, utf8) of
        Binary -> ok;
        {error, Prefix, _Rest} -> invalid_utf8_origin(Prefix);
        {incomplete, Prefix, _Rest} -> invalid_utf8_origin(Prefix)
    end.

invalid_utf8_origin(Prefix) ->
    {Line, Column} = position(Prefix, 1, 1),
    {error, byte_size(Prefix), Line, Column}.

position(<<>>, Line, Column) ->
    {Line, Column};
position(<<$\n, Rest/binary>>, Line, _Column) ->
    position(Rest, Line + 1, 1);
position(<<_Codepoint/utf8, Rest/binary>>, Line, Column) ->
    position(Rest, Line, Column + 1).

origin(Byte, Line, Column) ->
    #{byte => Byte, line => Line, column => Column}.

diagnostic(Code, Byte, Line, Column, Message) ->
    #{
        code => Code,
        severity => error,
        origin => origin(Byte, Line, Column),
        message => Message
    }.
