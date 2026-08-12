-module(alang_compact_source_map).

-export([build/2, diagnostic/4, load_contract/1, validate/3, validate_contract/1]).

-define(SECURITY_ROOTS, [<<"effects">>, <<"requirements">>, <<"scopes">>,
    <<"budgets">>, <<"error_branches">>, <<"child_attenuation">>,
    <<"completion_predicates">>, <<"terminal_class">>]).

-spec load_contract(file:filename()) -> {ok, map()} | {error, term()}.
load_contract(Path) ->
    case alang_fidelity_json:decode_file(Path) of
        {ok, Value} -> validate_contract(Value);
        {error, Reason} -> {error, {source_map_contract_read_failed, Reason}}
    end.

-spec validate_contract(term()) -> {ok, map()} | {error, term()}.
validate_contract(Value) when is_map(Value) ->
    Expected = expected_contract(),
    case Value =:= Expected of
        true -> {ok, Value};
        false -> {error, {source_map_contract_mismatch,
            alang_fidelity_json:digest(Expected), alang_fidelity_json:digest(Value)}}
    end;
validate_contract(Value) -> {error, {invalid_source_map_contract, Value}}.

-spec build(map(), map()) -> {ok, map()} | {error, term()}.
build(Surface, Oracle) ->
    try
        Bytes = maps:get(bytes, Surface),
        SurfaceId = maps:get(surface_id, Surface),
        SemanticLeaves = flatten(Oracle, <<>>),
        ValueIndex = value_index(SemanticLeaves),
        ReadableIndex = readable_index(Oracle, ValueIndex),
        OpaqueReverse = maps:get(opaque_reverse_map, maps:get(provenance, Surface), #{}),
        LocalAliases = local_aliases(Bytes),
        Tokens0 = lex(Bytes),
        Tokens1 = case lists:member(SurfaceId, [<<"R3">>, <<"R4">>, <<"R5">>]) of
            true -> mark_schema_keys(Tokens0);
            false -> Tokens0
        end,
        Tokens = [origin_token(Token, ValueIndex, LocalAliases, OpaqueReverse, ReadableIndex) || Token <- Tokens1],
        DeclaredDerivations = declared_derivations(Bytes),
        Fields = security_fields(Oracle, Tokens, ReadableIndex, DeclaredDerivations),
        AliasEntries = alias_entries(Tokens, LocalAliases, OpaqueReverse),
        Map = #{
            <<"format">> => <<"alang-compact-source-map-v1">>,
            <<"surface_id">> => SurfaceId,
            <<"version">> => maps:get(version, Surface),
            <<"byte_count">> => byte_size(Bytes),
            <<"tokens">> => Tokens,
            <<"fields">> => Fields,
            <<"aliases">> => AliasEntries,
            <<"coverage">> => <<"contiguous-every-byte-exactly-once">>
        },
        validate(Map, Surface, Oracle)
    catch
        error:Reason -> {error, {source_map_error, [], {invalid_surface, Reason}}};
        throw:{source_map_error, Path, Reason} -> {error, {source_map_error, Path, Reason}}
    end.

-spec validate(map(), map(), map()) -> {ok, map()} | {error, term()}.
validate(Map, Surface, Oracle) ->
    try
        Required = [<<"format">>, <<"surface_id">>, <<"version">>, <<"byte_count">>,
            <<"tokens">>, <<"fields">>, <<"aliases">>, <<"coverage">>],
        exact_keys(Map, Required, []),
        exact(maps:get(<<"format">>, Map), <<"alang-compact-source-map-v1">>, [<<"format">>]),
        exact(maps:get(<<"surface_id">>, Map), maps:get(surface_id, Surface), [<<"surface_id">>]),
        exact(maps:get(<<"version">>, Map), maps:get(version, Surface), [<<"version">>]),
        Bytes = maps:get(bytes, Surface),
        exact(maps:get(<<"byte_count">>, Map), byte_size(Bytes), [<<"byte_count">>]),
        Tokens = maps:get(<<"tokens">>, Map),
        validate_token_coverage(Tokens, Bytes),
        SemanticPaths = maps:from_list([{Path, true} || {Path, _Value} <- flatten(Oracle, <<>>)]),
        lists:foreach(fun(Token) -> validate_token_origin(Token, SemanticPaths) end, Tokens),
        ExpectedFields = lists:sort([Path || {Path, _} <- security_leaves(Oracle)]),
        Fields = maps:get(<<"fields">>, Map),
        exact(lists:sort([maps:get(<<"path">>, Field) || Field <- Fields]),
            ExpectedFields, [<<"fields">>]),
        lists:foreach(fun(Field) -> validate_field(Field, byte_size(Bytes)) end, Fields),
        exact(maps:get(<<"coverage">>, Map), <<"contiguous-every-byte-exactly-once">>,
            [<<"coverage">>]),
        {ok, Map}
    catch
        throw:{source_map_error, Path, Reason} -> {error, {source_map_error, Path, Reason}};
        error:Reason -> {error, {source_map_error, [], {invalid_map_shape, Reason}}}
    end.

-spec diagnostic(map(), binary(), binary(), binary()) -> map().
diagnostic(SourceMap, SemanticPath, Code, Message) ->
    Fields = maps:get(<<"fields">>, SourceMap),
    case [Field || Field <- Fields, maps:get(<<"path">>, Field) =:= SemanticPath] of
        [Field | _] -> diagnostic_from(Code, SemanticPath, Message,
            maps:get(<<"readable_value">>, Field), maps:get(<<"compact_ranges">>, Field),
            maps:get(<<"readable_spans">>, Field));
        [] ->
            Tokens = maps:get(<<"tokens">>, SourceMap),
            Matches = [Token || Token <- Tokens,
                lists:member(SemanticPath, maps:get(<<"paths">>, maps:get(<<"origin">>, Token), []))],
            Value = case Matches of
                [Token | _] -> maps:get(<<"readable_value">>, maps:get(<<"origin">>, Token), SemanticPath);
                [] -> SemanticPath
            end,
            Ranges = [range(Token) || Token <- Matches],
            ReadableSpans = lists:usort(lists:append([maps:get(<<"readable_spans">>,
                maps:get(<<"origin">>, Token), []) || Token <- Matches])),
            diagnostic_from(Code, SemanticPath, Message, Value, Ranges, ReadableSpans)
    end.

diagnostic_from(Code, Path, Message, Value, Ranges, ReadableSpans) ->
    Rendered = readable_binary(Value),
    #{
        <<"code">> => Code,
        <<"severity">> => <<"error">>,
        <<"semantic_path">> => Path,
        <<"message">> => <<"At ", Path/binary, " (", Rendered/binary, "): ", Message/binary>>,
        <<"readable_source">> => #{<<"value">> => Value,
            <<"edit_target">> => <<"readable-source">>, <<"spans">> => ReadableSpans},
        <<"compact_spans">> => Ranges
    }.

lex(Binary) -> lists:reverse(lex(Binary, 0, [])).
lex(<<>>, _Offset, Acc) -> Acc;
lex(<<Byte, _/binary>> = Binary, Offset, Acc) when
    Byte =:= $\s; Byte =:= $\t; Byte =:= $\n; Byte =:= $\r ->
    {Text, Rest} = take_while(Binary, fun is_whitespace/1, <<>>),
    lex(Rest, Offset + byte_size(Text), [token(Offset, Text, <<"layout">>) | Acc]);
lex(<<$", Rest/binary>>, Offset, Acc) ->
    {Text, Tail} = take_quoted(Rest, <<$">>),
    lex(Tail, Offset + byte_size(Text), [token(Offset, Text, <<"string">>) | Acc]);
lex(<<Byte, _/binary>> = Binary, Offset, Acc) when Byte >= $0, Byte =< $9 ->
    {Text, Rest} = take_while(Binary, fun is_digit/1, <<>>),
    lex(Rest, Offset + byte_size(Text), [token(Offset, Text, <<"integer">>) | Acc]);
lex(<<Byte, _/binary>> = Binary, Offset, Acc) when
    (Byte >= $a andalso Byte =< $z) orelse (Byte >= $A andalso Byte =< $Z) orelse
    Byte =:= $_ orelse Byte =:= $@ ->
    {Text, Rest} = take_while(Binary, fun is_word_byte/1, <<>>),
    lex(Rest, Offset + byte_size(Text), [token(Offset, Text, <<"word">>) | Acc]);
lex(<<Byte, Rest/binary>>, Offset, Acc) ->
    lex(Rest, Offset + 1, [token(Offset, <<Byte>>, <<"punctuation">>) | Acc]).

take_while(<<Byte, Rest/binary>>, Predicate, Acc) ->
    case Predicate(Byte) of
        true -> take_while(Rest, Predicate, <<Acc/binary, Byte>>);
        false -> {Acc, <<Byte, Rest/binary>>}
    end;
take_while(<<>>, _Predicate, Acc) -> {Acc, <<>>}.

take_quoted(<<>>, _Acc) -> throw({source_map_error, [], unterminated_string});
take_quoted(<<$\\, Escaped, Rest/binary>>, Acc) ->
    take_quoted(Rest, <<Acc/binary, $\\, Escaped>>);
take_quoted(<<$", Rest/binary>>, Acc) -> {<<Acc/binary, $">>, Rest};
take_quoted(<<Byte, Rest/binary>>, Acc) -> take_quoted(Rest, <<Acc/binary, Byte>>).

token(Offset, Text, Kind) ->
    #{<<"from">> => Offset, <<"to">> => Offset + byte_size(Text),
        <<"text">> => Text, <<"kind">> => Kind, <<"schema_key">> => false}.

mark_schema_keys(Tokens) -> mark_schema_keys(Tokens, []).
mark_schema_keys([], Acc) -> lists:reverse(Acc);
mark_schema_keys([Token | Rest], Acc) ->
    IsKey = maps:get(<<"kind">>, Token) =:= <<"string">> andalso next_is_colon(Rest),
    mark_schema_keys(Rest, [Token#{<<"schema_key">> := IsKey} | Acc]).

next_is_colon([#{<<"kind">> := <<"layout">>} | Rest]) -> next_is_colon(Rest);
next_is_colon([#{<<"text">> := <<":">>} | _]) -> true;
next_is_colon(_) -> false.

origin_token(Token, ValueIndex, LocalAliases, OpaqueReverse, ReadableIndex) ->
    Kind = maps:get(<<"kind">>, Token),
    Generated = Kind =:= <<"layout">> orelse Kind =:= <<"punctuation">> orelse
        maps:get(<<"schema_key">>, Token),
    Value0 = token_value(Token),
    Value = resolve_value(Value0, LocalAliases, OpaqueReverse),
    Paths = maps:get(Value, ValueIndex, []),
    Origin = case Generated orelse Paths =:= [] of
        true -> #{<<"kind">> => <<"generated">>, <<"generator">> => generated_class(Token)};
        false -> #{<<"kind">> => <<"semantic">>, <<"paths">> => Paths,
            <<"readable_value">> => Value,
            <<"readable_spans">> => lists:usort(lists:append(
                [maps:get(Path, ReadableIndex, []) || Path <- Paths]))}
    end,
    (maps:without([<<"schema_key">>], Token))#{<<"origin">> => Origin}.

generated_class(#{<<"schema_key">> := true}) -> <<"schema-key">>;
generated_class(#{<<"kind">> := Kind}) -> Kind.

token_value(#{<<"kind">> := <<"string">>, <<"text">> := Text}) ->
    case alang_fidelity_json:decode(Text) of {ok, Value} -> Value; _ -> Text end;
token_value(#{<<"kind">> := <<"integer">>, <<"text">> := Text}) -> binary_to_integer(Text);
token_value(#{<<"text">> := <<"true">>}) -> true;
token_value(#{<<"text">> := <<"false">>}) -> false;
token_value(#{<<"text">> := <<"null">>}) -> null;
token_value(#{<<"text">> := Text}) -> Text.

resolve_value(Value, Local, Opaque) when is_binary(Value) ->
    Value1 = case Value of
        <<"@", Key/binary>> -> maps:get(Key, Local, Value);
        _ -> Value
    end,
    Value2 = case maps:find(Value1, Opaque) of
        {ok, Entry} -> maps:get(<<"original">>, Entry);
        error -> Value1
    end,
    vocabulary_value(Value2);
resolve_value(Value, _Local, _Opaque) -> Value.

vocabulary_value(<<"gen">>) -> <<"model.generate">>;
vocabulary_value(<<"fix">>) -> <<"model.repair">>;
vocabulary_value(<<"put">>) -> <<"workspace.write">>;
vocabulary_value(<<"sub">>) -> <<"child.run">>;
vocabulary_value(<<"done">>) -> <<"complete">>;
vocabulary_value(<<"exists">>) -> <<"artifact-exists">>;
vocabulary_value(<<"journal">>) -> <<"journal-succeeded">>;
vocabulary_value(<<"maxb">>) -> <<"max-bytes">>;
vocabulary_value(<<"u8">>) -> <<"utf8">>;
vocabulary_value(<<"asked">>) -> <<"clarification-recorded">>;
vocabulary_value(Value) -> Value.

local_aliases(Bytes) ->
    case binary:split(Bytes, <<"\n">>) of
        [_Header, Json] ->
            case alang_fidelity_json:decode(Json) of
                {ok, Value} when is_map(Value) -> maps:get(<<"aliases">>, Value, #{});
                _ -> #{}
            end;
        _ -> #{}
    end.

flatten(Value, Pointer) when is_map(Value) ->
    lists:append([flatten(Child, join(Pointer, escape(Key))) || {Key, Child} <-
        lists:sort(maps:to_list(Value))]);
flatten(Value, Pointer) when is_list(Value), Value =/= [] ->
    lists:append([flatten(Child, join(Pointer, integer_to_binary(Index))) ||
        {Child, Index} <- lists:zip(Value, lists:seq(0, length(Value) - 1))]);
flatten(Value, Pointer) -> [{Pointer, Value}].

security_leaves(Oracle) ->
    lists:append([flatten(maps:get(Key, Oracle), <<"/", Key/binary>>) || Key <- ?SECURITY_ROOTS]).

value_index(Leaves) ->
    lists:foldl(fun({Path, Value}, Acc) ->
        Acc#{Value => lists:usort([Path | maps:get(Value, Acc, [])])}
    end, #{}, Leaves).

readable_index(Oracle, ValueIndex) ->
    {ok, Bytes} = alang_compact_surface:readable_bytes(Oracle),
    Tokens = lex(Bytes),
    Direct = lists:foldl(fun(Token, Acc) ->
        Value = token_value(Token),
        Paths = maps:get(Value, ValueIndex, []),
        Span = readable_span(Token, Bytes),
        lists:foldl(fun(Path, Inner) ->
            Inner#{Path => lists:usort([Span | maps:get(Path, Inner, [])])}
        end, Acc, Paths)
    end, #{}, Tokens),
    lists:foldl(fun({Path, _Value}, Acc) ->
        case maps:is_key(Path, Acc) of
            true -> Acc;
            false -> Acc#{Path => fallback_readable_spans(Path, Tokens, Bytes)}
        end
    end, Direct, security_leaves(Oracle)).

fallback_readable_spans(Path, Tokens, Bytes) ->
    Keyword = readable_keyword(Path),
    Matches = [Token || Token <- Tokens, token_value(Token) =:= Keyword],
    case Matches of
        [] -> [#{<<"from">> => 0, <<"to">> => 1, <<"line">> => 1,
            <<"column">> => 1, <<"semantic_path">> => Path}];
        _ -> [(readable_span(Token, Bytes))#{<<"semantic_path">> => Path} || Token <- Matches]
    end.

readable_keyword(<<"/effects", _/binary>>) -> <<"effects">>;
readable_keyword(<<"/requirements", _/binary>>) -> <<"requirements">>;
readable_keyword(<<"/scopes/models", _/binary>>) -> <<"models">>;
readable_keyword(<<"/scopes/workspaces", _/binary>>) -> <<"workspaces">>;
readable_keyword(<<"/scopes/paths", _/binary>>) -> <<"paths">>;
readable_keyword(<<"/scopes", _/binary>>) -> <<"scopes">>;
readable_keyword(<<"/budgets", _/binary>>) -> <<"limits">>;
readable_keyword(<<"/error_branches", _/binary>>) -> <<"on-error">>;
readable_keyword(<<"/child_attenuation/requirements", _/binary>>) -> <<"requirements">>;
readable_keyword(<<"/child_attenuation/scopes/models", _/binary>>) -> <<"models">>;
readable_keyword(<<"/child_attenuation/scopes/workspaces", _/binary>>) -> <<"workspaces">>;
readable_keyword(<<"/child_attenuation/scopes/paths", _/binary>>) -> <<"paths">>;
readable_keyword(<<"/child_attenuation/budgets", _/binary>>) -> <<"limits">>;
readable_keyword(<<"/child_attenuation/effects", _/binary>>) -> <<"effects">>;
readable_keyword(<<"/child_attenuation", _/binary>>) -> <<"child">>;
readable_keyword(<<"/completion_predicates", _/binary>>) -> <<"complete">>;
readable_keyword(<<"/terminal_class", _/binary>>) -> <<"terminal">>;
readable_keyword(_Path) -> <<"task">>.

readable_span(Token, Bytes) ->
    From = maps:get(<<"from">>, Token),
    {Line, Column} = line_column(Bytes, From),
    #{<<"from">> => From, <<"to">> => maps:get(<<"to">>, Token),
        <<"line">> => Line, <<"column">> => Column}.

line_column(Bytes, Offset) ->
    Prefix = binary:part(Bytes, 0, Offset),
    Codepoints = case unicode:characters_to_list(Prefix) of
        List when is_list(List) -> List;
        _ -> binary_to_list(Prefix)
    end,
    lists:foldl(fun
        ($\n, {Line, _Column}) -> {Line + 1, 1};
        (_Codepoint, {Line, Column}) -> {Line, Column + 1}
    end, {1, 1}, Codepoints).

security_fields(Oracle, Tokens, ReadableIndex, DeclaredDerivations) ->
    [field_entry(Path, Value, Tokens, ReadableIndex, DeclaredDerivations) ||
        {Path, Value} <- security_leaves(Oracle)].

field_entry(Path, Value, Tokens, ReadableIndex, DeclaredDerivations) ->
    Ranges = [range(Token) || Token <- Tokens,
        lists:member(Path, maps:get(<<"paths">>, maps:get(<<"origin">>, Token), []))],
    ReadableSpans = maps:get(Path, ReadableIndex, []),
    case derivation_for(Path, Tokens, DeclaredDerivations) of
        {ok, Rule, WitnessRanges} ->
            field(Path, Value, <<"derived">>, WitnessRanges, ReadableSpans,
                #{<<"rule">> => Rule});
        error ->
            case Ranges of
                [_ | _] -> field(Path, Value, <<"compact">>, Ranges, ReadableSpans, null);
                [] when Value =:= []; Value =:= #{} ->
                    field(Path, Value, <<"versioned-empty-elision">>, [], ReadableSpans,
                        #{<<"rule">> => <<"restore-versioned-empty">>});
                [] -> fail([<<"fields">>, Path], missing_security_field_mapping)
            end
    end.

field(Path, Value, Status, Ranges, ReadableSpans, Witness) ->
    #{<<"path">> => Path, <<"readable_value">> => Value, <<"status">> => Status,
        <<"compact_ranges">> => Ranges, <<"readable_spans">> => ReadableSpans,
        <<"witness">> => Witness}.

derivation_for(Path, Tokens, Declared) ->
    case declared_derivation_name(Path, Declared) of
        none -> error;
        Name ->
            Ranges = [range(Token) || Token <- Tokens, token_value(Token) =:= Name],
            case Ranges of
                [] -> error;
                _ -> {ok, <<"exact-", Name/binary, "-derivation">>, Ranges}
            end
    end.

declared_derivation_name(<<"/effects", _/binary>>, Declared) ->
    declared_name(top_effects, <<"effects">>, Declared);
declared_derivation_name(<<"/requirements", _/binary>>, Declared) ->
    declared_name(top_requirements, <<"requirements">>, Declared);
declared_derivation_name(<<"/child_attenuation/requirements", _/binary>>, Declared) ->
    declared_name(child_requirements, <<"requirements">>, Declared);
declared_derivation_name(_, _Declared) -> none.

declared_name(Key, Name, Declared) ->
    case maps:get(Key, Declared, false) of true -> Name; false -> none end.

declared_derivations(Bytes) ->
    case binary:split(Bytes, <<"\n">>) of
        [_Header, Json] ->
            case alang_fidelity_json:decode(Json) of
                {ok, Value} when is_map(Value) ->
                    Top = maps:get(<<"derived">>, Value, []),
                    Child = maps:get(<<"kid">>, Value, null),
                    ChildDerived = case Child of
                        Map when is_map(Map) -> maps:get(<<"derived">>, Map, []);
                        _ -> []
                    end,
                    #{top_effects => lists:member(<<"effects">>, Top),
                        top_requirements => lists:member(<<"requirements">>, Top),
                        child_requirements => lists:member(<<"requirements">>, ChildDerived)};
                _ -> #{}
            end;
        _ -> #{}
    end.

alias_entries(Tokens, Local, Opaque) ->
    LocalEntries = [#{<<"alias">> => <<"@", Key/binary>>, <<"original">> =>
            resolve_value(Value, #{}, Opaque), <<"kind">> => <<"local-reference">>,
            <<"ranges">> => ranges_for(Tokens, <<"@", Key/binary>>)}
        || {Key, Value} <- lists:sort(maps:to_list(Local))],
    OpaqueEntries = [#{<<"alias">> => Key, <<"original">> => maps:get(<<"original">>, Entry),
            <<"kind">> => maps:get(<<"kind">>, Entry), <<"ranges">> => ranges_for(Tokens, Key)}
        || {Key, Entry} <- lists:sort(maps:to_list(Opaque))],
    LocalEntries ++ OpaqueEntries.

ranges_for(Tokens, Value) -> [range(Token) || Token <- Tokens, token_value(Token) =:= Value].
range(Token) -> #{<<"from">> => maps:get(<<"from">>, Token), <<"to">> => maps:get(<<"to">>, Token)}.

validate_token_coverage(Tokens, Bytes) ->
    {End, Parts} = lists:foldl(fun(Token, {Expected, Acc}) ->
        exact(maps:get(<<"from">>, Token), Expected, [<<"tokens">>]),
        To = maps:get(<<"to">>, Token),
        ensure(To > Expected, [<<"tokens">>], empty_token_range),
        {To, [maps:get(<<"text">>, Token) | Acc]}
    end, {0, []}, Tokens),
    exact(End, byte_size(Bytes), [<<"tokens">>]),
    exact(iolist_to_binary(lists:reverse(Parts)), Bytes, [<<"tokens">>]).

validate_token_origin(Token, SemanticPaths) ->
    Origin = maps:get(<<"origin">>, Token),
    case maps:get(<<"kind">>, Origin) of
        <<"generated">> -> ok;
        <<"semantic">> ->
            Paths = maps:get(<<"paths">>, Origin),
            ensure(Paths =/= [] andalso lists:all(fun(Path) -> maps:is_key(Path, SemanticPaths) end, Paths),
                [<<"tokens">>], unknown_semantic_origin);
        Other -> fail([<<"tokens">>], {unknown_origin_kind, Other})
    end.

validate_field(Field, ByteCount) ->
    Required = [<<"path">>, <<"readable_value">>, <<"status">>, <<"compact_ranges">>,
        <<"readable_spans">>, <<"witness">>],
    exact_keys(Field, Required, [<<"fields">>]),
    Status = maps:get(<<"status">>, Field),
    ensure(lists:member(Status, [<<"compact">>, <<"derived">>, <<"versioned-empty-elision">>]),
        [<<"fields">>], {unknown_field_status, Status}),
    Ranges = maps:get(<<"compact_ranges">>, Field),
    lists:foreach(fun(Range) ->
        From = maps:get(<<"from">>, Range), To = maps:get(<<"to">>, Range),
        ensure(is_integer(From) andalso is_integer(To) andalso From >= 0 andalso To =< ByteCount andalso From < To,
            [<<"fields">>], invalid_compact_range)
    end, Ranges),
    ReadableSpans = maps:get(<<"readable_spans">>, Field),
    ensure(is_list(ReadableSpans) andalso ReadableSpans =/= [], [<<"fields">>], missing_readable_span),
    case Status of
        <<"compact">> -> ensure(Ranges =/= [], [<<"fields">>], missing_compact_range);
        _ -> ensure(maps:get(<<"witness">>, Field) =/= null, [<<"fields">>], missing_witness)
    end.

join(<<>>, Segment) -> <<"/", Segment/binary>>;
join(Pointer, Segment) -> <<Pointer/binary, "/", Segment/binary>>.
escape(Key) -> binary:replace(binary:replace(Key, <<"~">>, <<"~0">>, [global]), <<"/">>, <<"~1">>, [global]).

readable_binary(Value) when is_binary(Value) -> Value;
readable_binary(Value) ->
    case alang_fidelity_json:encode_canonical(Value) of {ok, Binary} -> Binary; _ -> <<"value">> end.

is_whitespace(Byte) -> Byte =:= $\s orelse Byte =:= $\t orelse Byte =:= $\n orelse Byte =:= $\r.
is_digit(Byte) -> Byte >= $0 andalso Byte =< $9.
is_word_byte(Byte) ->
    (Byte >= $a andalso Byte =< $z) orelse (Byte >= $A andalso Byte =< $Z) orelse
    (Byte >= $0 andalso Byte =< $9) orelse lists:member(Byte, "_@./-").

exact_keys(Value, Keys, Path) ->
    ensure(is_map(Value), Path, expected_object),
    exact(lists:sort(maps:keys(Value)), lists:sort(Keys), Path).
exact(Value, Expected, Path) -> ensure(Value =:= Expected, Path, {expected, Expected, Value}).
ensure(true, _Path, _Reason) -> ok;
ensure(false, Path, Reason) -> fail(Path, Reason).
fail(Path, Reason) -> throw({source_map_error, Path, Reason}).

expected_contract() ->
    #{
        <<"format">> => <<"alang-compact-source-map-contract-v1">>,
        <<"map_format">> => <<"alang-compact-source-map-v1">>,
        <<"coverage">> => <<"contiguous-every-byte-exactly-once">>,
        <<"token_origins">> => [<<"generated">>, <<"semantic">>],
        <<"security_field_status">> => [<<"compact">>, <<"derived">>,
            <<"versioned-empty-elision">>],
        <<"diagnostic_edit_target">> => <<"readable-source">>,
        <<"opaque_diagnostics">> => <<"original-identifiers-required">>,
        <<"compact_spans">> => <<"optional-additional-context">>
    }.
