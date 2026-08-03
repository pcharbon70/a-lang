-module(alang_phase2_canonical).

-export([decode/1, encode/1]).

-define(MAX_CANONICAL_BYTES, 1048576).

-spec encode(map()) -> {ok, binary()} | {error, [map()]}.
encode(Ast) ->
    case validate_ast(Ast) of
        {ok, _Checked} -> {ok, term_to_binary(Ast, [deterministic])};
        {error, _} = Error -> Error
    end.

-spec decode(binary()) -> {ok, map()} | {error, [map()]}.
decode(<<131, 80, _/binary>>) ->
    {error, [diagnostic(compressed_canonical_etf, <<"compressed canonical ETF is not accepted">>)]};
decode(Binary) when is_binary(Binary), byte_size(Binary) =< ?MAX_CANONICAL_BYTES ->
    try binary_to_term(Binary, [safe, used]) of
        {Ast, Used} when Used =:= byte_size(Binary), is_map(Ast) ->
            case validate_ast(Ast) of
                {ok, _Checked} -> {ok, Ast};
                {error, _} = Error -> Error
            end;
        {_Ast, _Used} ->
            {error, [diagnostic(trailing_canonical_data, <<"canonical ETF contains trailing bytes">>)]}
    catch
        error:badarg ->
            {error, [diagnostic(invalid_canonical_etf, <<"invalid or unsafe canonical ETF">>)]}
    end;
decode(Binary) when is_binary(Binary) ->
    {error, [diagnostic(canonical_source_too_large, <<"canonical ETF exceeds 1 MiB">>)]};
decode(_) ->
    {error, [diagnostic(invalid_canonical_etf, <<"canonical source must be binary ETF">>)]}.

validate_ast(Ast) ->
    try alang_phase2_semantics:check(Ast) of
        Result -> Result
    catch
        _Class:_Reason ->
            {error, [diagnostic(invalid_canonical_ast, <<"canonical ETF does not contain a valid source AST">>)]}
    end.

diagnostic(Code, Message) ->
    #{code => Code, severity => error, message => Message}.
