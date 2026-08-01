-module(alang_phase2_lexer).

-export([scan/1]).

-define(MAX_SOURCE_BYTES, 1048576).

-type origin() :: #{byte := non_neg_integer(), line := pos_integer(), column := pos_integer()}.
-type token() :: {atom(), term(), origin()}.

-spec scan(binary()) -> {ok, [token()]} | {error, [map()]}.
scan(Source) when is_binary(Source), byte_size(Source) =< ?MAX_SOURCE_BYTES ->
    scan(Source, 0, 1, 1, []);
scan(Source) when is_binary(Source) ->
    {error, [diagnostic(source_too_large, 0, 1, 1, <<"source exceeds 1 MiB">>)]};
scan(_) ->
    {error, [diagnostic(invalid_source, 0, 1, 1, <<"source must be UTF-8 binary data">>)]}.

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
    Kind = keyword(Word),
    Value = case Kind of identifier -> Word; _ -> none end,
    scan(Rest, Byte + Size, Line, Column + Size, [{Kind, Value, origin(Byte, Line, Column)} | Acc]);
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
scan(<<$-, $>, Rest/binary>>, Byte, Line, Column, Acc) ->
    scan(Rest, Byte + 2, Line, Column + 2, [{arrow, none, origin(Byte, Line, Column)} | Acc]);
scan(<<$=, $=, Rest/binary>>, Byte, Line, Column, Acc) ->
    scan(Rest, Byte + 2, Line, Column + 2, [{equal_equal, none, origin(Byte, Line, Column)} | Acc]);
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
        C =:= $_
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
    take_string(Rest, <<Acc/binary, $\">>, Byte + 2, Line, Column + 2);
take_string(<<$\\, $\\, Rest/binary>>, Acc, Byte, Line, Column) ->
    take_string(Rest, <<Acc/binary, $\\>>, Byte + 2, Line, Column + 2);
take_string(<<C, Rest/binary>>, Acc, Byte, Line, Column) when C < 128 ->
    take_string(Rest, <<Acc/binary, C>>, Byte + 1, Line, Column + 1);
take_string(<<_C, _/binary>>, _Acc, Byte, Line, Column) ->
    {error, diagnostic(non_ascii_source, Byte, Line, Column, <<"Phase 2 source profile is ASCII">>)}.

skip_comment(<<>>, Byte, Line, Column) ->
    {<<>>, Byte, Line, Column};
skip_comment(<<$\n, Rest/binary>>, Byte, Line, _Column) ->
    {Rest, Byte + 1, Line + 1, 1};
skip_comment(<<_, Rest/binary>>, Byte, Line, Column) ->
    skip_comment(Rest, Byte + 1, Line, Column + 1).

keyword(<<"module">>) -> module_kw;
keyword(<<"version">>) -> version_kw;
keyword(<<"task">>) -> task_kw;
keyword(<<"effect">>) -> effect_kw;
keyword(<<"requires">>) -> requires_kw;
keyword(<<"ensures">>) -> ensures_kw;
keyword(<<"true">>) -> true_kw;
keyword(<<"false">>) -> false_kw;
keyword(_) -> identifier.

punctuation(${) -> lbrace;
punctuation($}) -> rbrace;
punctuation($() -> lparen;
punctuation($)) -> rparen;
punctuation($[) -> lbracket;
punctuation($]) -> rbracket;
punctuation($:) -> colon;
punctuation($;) -> semicolon;
punctuation($,) -> comma;
punctuation($+) -> plus;
punctuation($=) -> equal;
punctuation(_) -> unknown.

origin(Byte, Line, Column) ->
    #{byte => Byte, line => Line, column => Column}.

diagnostic(Code, Byte, Line, Column, Message) ->
    #{
        code => Code,
        severity => error,
        origin => origin(Byte, Line, Column),
        message => Message
    }.
