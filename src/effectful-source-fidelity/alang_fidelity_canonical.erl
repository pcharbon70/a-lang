-module(alang_fidelity_canonical).

-export([decode/1, digest/1, encode/1]).

-define(MAX_CANONICAL_BYTES, 1048576).

-spec encode(map()) -> {ok, binary()} | {error, [map()]}.
encode(#{format := alang_source_ast_v2} = Ast) ->
    case alang_fidelity_ast:validate(Ast) of
        {ok, _Checked} ->
            {ok, term_to_binary({alang_source_canonical_v2, Ast}, [deterministic])};
        {error, _} = Error -> Error
    end;
encode(Ast) ->
    alang_phase2_canonical:encode(Ast).

-spec decode(binary()) -> {ok, map()} | {error, [map()]}.
decode(<<131, 80, _/binary>>) ->
    {error, [diagnostic(compressed_canonical_etf, <<"compressed canonical ETF is not accepted">>)]};
decode(Binary) when is_binary(Binary), byte_size(Binary) =< ?MAX_CANONICAL_BYTES ->
    decode_bounded(Binary);
decode(Binary) when is_binary(Binary) ->
    {error, [diagnostic(canonical_source_too_large, <<"canonical ETF exceeds 1 MiB">>)]};
decode(_) ->
    {error, [diagnostic(invalid_canonical_etf, <<"canonical source must be binary ETF">>)]}.

decode_bounded(Binary) ->
    try binary_to_term(Binary, [safe, used]) of
        {{alang_source_canonical_v2, Ast}, Used} when Used =:= byte_size(Binary), is_map(Ast) ->
            validate_canonical_v2(Binary, Ast);
        {{alang_source_canonical_v2, _Ast}, Used} when Used =/= byte_size(Binary) ->
            {error, [diagnostic(trailing_canonical_data, <<"canonical ETF contains trailing bytes">>)]};
        {_Other, Used} when Used =/= byte_size(Binary) ->
            {error, [diagnostic(trailing_canonical_data, <<"canonical ETF contains trailing bytes">>)]};
        {_Other, _Used} ->
            alang_phase2_canonical:decode(Binary)
    catch
        error:badarg ->
            {error, [diagnostic(invalid_canonical_etf, <<"invalid or unsafe canonical ETF">>)]}
    end.

validate_canonical_v2(Binary, Ast) ->
    case alang_fidelity_ast:validate(Ast) of
        {ok, _Checked} ->
            Canonical = term_to_binary({alang_source_canonical_v2, Ast}, [deterministic]),
            case Canonical =:= Binary of
                true -> {ok, Ast};
                false -> {error, [diagnostic(noncanonical_etf, <<"ETF does not use the deterministic v2 encoding">>)]}
            end;
        {error, _} = Error -> Error
    end.

-spec digest(map()) -> {ok, binary()} | {error, [map()]}.
digest(Ast) ->
    case encode(Ast) of
        {ok, Binary} -> {ok, hex(crypto:hash(sha256, Binary))};
        {error, _} = Error -> Error
    end.

hex(Binary) ->
    iolist_to_binary([io_lib:format("~2.16.0b", [Byte]) || <<Byte>> <= Binary]).

diagnostic(Code, Message) ->
    #{code => Code, severity => error, origin => #{byte => 0, line => 1, column => 1}, message => Message}.
