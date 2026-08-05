-module(alang_fidelity_parser).

-export([parse/1, parse_tokens/1]).

-define(MAX_V2_DOCUMENT_BYTES, 8192).
-define(MAX_SIGNED_INTEGER, 9223372036854775807).

-spec parse(binary()) -> {ok, map()} | {error, [map()]}.
parse(<<"#!alang-source-v2", _/binary>> = Source) when byte_size(Source) =< ?MAX_V2_DOCUMENT_BYTES ->
    case alang_fidelity_lexer:scan(Source) of
        {ok, Tokens} -> parse_tokens(Tokens);
        {error, _} = Error -> Error
    end;
parse(<<"#!alang-source-v2", _/binary>>) ->
    {error, [diagnostic(source_document_too_large, default_origin(), <<"alang-source-v2 document exceeds 8192 bytes">>)]};
parse(<<"#!alang-source-", _/binary>>) ->
    {error, [diagnostic(unsupported_source_version, default_origin(), <<"expected #!alang-source-v2">>)]};
parse(Source) ->
    alang_phase2_parser:parse(Source).

-spec parse_tokens(list()) -> {ok, map()} | {error, [map()]}.
parse_tokens(Tokens) when is_list(Tokens) ->
    try
        {Version, VersionOrigin, Tokens1} = expect(source_version, Tokens),
        {_TaskKeyword, TaskOrigin, Tokens2} = expect(task_kw, Tokens1),
        {TaskName, TaskNameOrigin, Tokens3} = expect(identifier, Tokens2),
        {_LBrace, _LBraceOrigin, Tokens4} = expect(lbrace, Tokens3),
        State0 = #{
            facts => undefined,
            inputs => [],
            effects => undefined,
            requirements => undefined,
            scopes => undefined,
            limits => undefined
        },
        {Task, Tokens5} = parse_declarations(Tokens4, State0, TaskName, TaskNameOrigin, TaskOrigin),
        {_Eof, _EofOrigin, []} = expect(eof, Tokens5),
        {ok, #{
            format => alang_source_ast_v2,
            kind => task_document,
            version => Version,
            task => Task,
            origin => VersionOrigin
        }}
    catch
        throw:{parse_error, Diagnostic} -> {error, [Diagnostic]};
        error:{badmatch, _} ->
            {error, [diagnostic(invalid_token_stream, default_origin(), <<"invalid token stream">>)]}
    end;
parse_tokens(_) ->
    {error, [diagnostic(invalid_token_stream, default_origin(), <<"token stream must be a list">>)]}.

parse_declarations([{rbrace, _, EndOrigin} | Rest], State, TaskName, TaskNameOrigin, TaskOrigin) ->
    {finalize_task(State, TaskName, TaskNameOrigin, TaskOrigin, EndOrigin), Rest};
parse_declarations([{facts_kw, _, Origin} | Rest], State, TaskName, TaskNameOrigin, TaskOrigin) ->
    ensure_unset(facts, State, Origin),
    {_LBracket, _LBracketOrigin, Tokens1} = expect(lbracket, Rest),
    {Facts, Tokens2} = parse_string_nodes(Tokens1),
    {_Semicolon, _SemicolonOrigin, Tokens3} = expect(semicolon, Tokens2),
    parse_declarations(Tokens3, State#{facts => #{kind => facts, values => Facts, origin => Origin}}, TaskName, TaskNameOrigin, TaskOrigin);
parse_declarations([{input_kw, _, Origin} | Rest], State, TaskName, TaskNameOrigin, TaskOrigin) ->
    {Input, Tokens1} = parse_input(Rest, Origin),
    Inputs = maps:get(inputs, State),
    ensure_unique_named(Input, Inputs, duplicate_input),
    parse_declarations(Tokens1, State#{inputs => [Input | Inputs]}, TaskName, TaskNameOrigin, TaskOrigin);
parse_declarations([{effects_kw, _, Origin} | Rest], State, TaskName, TaskNameOrigin, TaskOrigin) ->
    ensure_unset(effects, State, Origin),
    {_LBracket, _LBracketOrigin, Tokens1} = expect(lbracket, Rest),
    {Effects, Tokens2} = parse_effect_nodes(Tokens1),
    {_Semicolon, _SemicolonOrigin, Tokens3} = expect(semicolon, Tokens2),
    ensure_unique_values(Effects, duplicate_effect),
    parse_declarations(Tokens3, State#{effects => #{kind => effects, values => Effects, origin => Origin}}, TaskName, TaskNameOrigin, TaskOrigin);
parse_declarations([{requirements_kw, _, Origin} | Rest], State, TaskName, TaskNameOrigin, TaskOrigin) ->
    ensure_unset(requirements, State, Origin),
    {_LBracket, _LBracketOrigin, Tokens1} = expect(lbracket, Rest),
    {Requirements, Tokens2} = parse_requirement_nodes(Tokens1),
    {_Semicolon, _SemicolonOrigin, Tokens3} = expect(semicolon, Tokens2),
    ensure_unique_requirements(Requirements),
    parse_declarations(
        Tokens3,
        State#{requirements => #{kind => requirements, values => Requirements, origin => Origin}},
        TaskName,
        TaskNameOrigin,
        TaskOrigin
    );
parse_declarations([{scopes_kw, _, Origin} | Rest], State, TaskName, TaskNameOrigin, TaskOrigin) ->
    ensure_unset(scopes, State, Origin),
    {Scopes, Tokens1} = parse_scopes(Rest, Origin),
    parse_declarations(Tokens1, State#{scopes => Scopes}, TaskName, TaskNameOrigin, TaskOrigin);
parse_declarations([{limits_kw, _, Origin} | Rest], State, TaskName, TaskNameOrigin, TaskOrigin) ->
    ensure_unset(limits, State, Origin),
    {Limits, Tokens1} = parse_limits(Rest, Origin),
    parse_declarations(Tokens1, State#{limits => Limits}, TaskName, TaskNameOrigin, TaskOrigin);
parse_declarations([{Kind, _, Origin} | _], _State, _TaskName, _TaskNameOrigin, _TaskOrigin) ->
    fail(unexpected_task_clause, Origin, iolist_to_binary(io_lib:format("unsupported or misplaced task clause: ~p", [Kind])));
parse_declarations([], _State, _TaskName, _TaskNameOrigin, _TaskOrigin) ->
    fail(expected_token, default_origin(), <<"expected rbrace">>).

parse_input(Tokens0, Origin) ->
    {Name, NameOrigin, Tokens1} = expect(identifier, Tokens0),
    {_Colon, _ColonOrigin, Tokens2} = expect(colon, Tokens1),
    {TypeName, TypeOrigin, Tokens3} = expect(identifier, Tokens2),
    Type = checked_type(TypeName, TypeOrigin),
    {Required, RequirementOrigin, Tokens4} = parse_requiredness(Tokens3),
    {_Semicolon, _SemicolonOrigin, Tokens5} = expect(semicolon, Tokens4),
    {#{
        kind => input,
        name => Name,
        name_origin => NameOrigin,
        type => Type,
        type_origin => TypeOrigin,
        required => Required,
        required_origin => RequirementOrigin,
        origin => Origin
    }, Tokens5}.

parse_requiredness([{required_kw, _, Origin} | Rest]) -> {true, Origin, Rest};
parse_requiredness([{optional_kw, _, Origin} | Rest]) -> {false, Origin, Rest};
parse_requiredness(Tokens) -> fail(expected_requiredness, token_origin(Tokens), <<"expected required or optional">>).

parse_string_nodes([{rbracket, _, _} | Rest]) ->
    {[], Rest};
parse_string_nodes(Tokens) ->
    {Value, Origin, Tokens1} = expect(string, Tokens),
    parse_more_string_nodes(Tokens1, [#{kind => string_literal, value => Value, origin => Origin}]).

parse_more_string_nodes([{comma, _, _} | Rest], Acc) ->
    {Value, Origin, Tokens1} = expect(string, Rest),
    parse_more_string_nodes(Tokens1, [#{kind => string_literal, value => Value, origin => Origin} | Acc]);
parse_more_string_nodes([{rbracket, _, _} | Rest], Acc) ->
    {lists:reverse(Acc), Rest};
parse_more_string_nodes(Tokens, _Acc) ->
    fail(expected_list_separator, token_origin(Tokens), <<"expected comma or rbracket">>).

parse_effect_nodes([{rbracket, _, _} | Rest]) ->
    {[], Rest};
parse_effect_nodes(Tokens) ->
    {Effect, Tokens1} = parse_effect(Tokens),
    parse_more_effect_nodes(Tokens1, [Effect]).

parse_more_effect_nodes([{comma, _, _} | Rest], Acc) ->
    {Effect, Tokens1} = parse_effect(Rest),
    parse_more_effect_nodes(Tokens1, [Effect | Acc]);
parse_more_effect_nodes([{rbracket, _, _} | Rest], Acc) ->
    {lists:reverse(Acc), Rest};
parse_more_effect_nodes(Tokens, _Acc) ->
    fail(expected_list_separator, token_origin(Tokens), <<"expected comma or rbracket">>).

parse_effect(Tokens0) ->
    {Namespace, Origin, Tokens1} = expect_word(Tokens0),
    {_Dot, _DotOrigin, Tokens2} = expect(dot, Tokens1),
    {Operation, _OperationOrigin, Tokens3} = expect_word(Tokens2),
    Name = <<Namespace/binary, ".", Operation/binary>>,
    case lists:member(Name, [<<"child.run">>, <<"model.generate">>, <<"workspace.write">>]) of
        true -> {#{kind => effect, name => Name, origin => Origin}, Tokens3};
        false -> fail(unknown_effect, Origin, <<"unknown effect: ", Name/binary>>)
    end.

parse_requirement_nodes([{rbracket, _, _} | Rest]) ->
    {[], Rest};
parse_requirement_nodes(Tokens) ->
    {Requirement, Tokens1} = parse_requirement(Tokens),
    parse_more_requirement_nodes(Tokens1, [Requirement]).

parse_more_requirement_nodes([{comma, _, _} | Rest], Acc) ->
    {Requirement, Tokens1} = parse_requirement(Rest),
    parse_more_requirement_nodes(Tokens1, [Requirement | Acc]);
parse_more_requirement_nodes([{rbracket, _, _} | Rest], Acc) ->
    {lists:reverse(Acc), Rest};
parse_more_requirement_nodes(Tokens, _Acc) ->
    fail(expected_list_separator, token_origin(Tokens), <<"expected comma or rbracket">>).

parse_requirement(Tokens0) ->
    {ResourceKind, Origin, Tokens1} = expect(identifier, Tokens0),
    case lists:member(ResourceKind, [<<"model">>, <<"workspace">>]) of
        true -> ok;
        false -> fail(unknown_requirement_kind, Origin, <<"unknown requirement kind: ", ResourceKind/binary>>)
    end,
    {Resource, ResourceOrigin, Tokens2} = expect(identifier, Tokens1),
    {#{
        kind => requirement,
        resource_kind => ResourceKind,
        resource => Resource,
        resource_origin => ResourceOrigin,
        origin => Origin
    }, Tokens2}.

parse_scopes(Tokens0, Origin) ->
    {_LBrace, _LBraceOrigin, Tokens1} = expect(lbrace, Tokens0),
    State = #{models => undefined, workspaces => undefined, paths => undefined},
    parse_scope_fields(Tokens1, State, Origin).

parse_scope_fields([{rbrace, _, EndOrigin} | Rest], State, Origin) ->
    ensure_fields([models, workspaces, paths], State, missing_scope_field, EndOrigin),
    {#{
        kind => scopes,
        models => maps:get(models, State),
        workspaces => maps:get(workspaces, State),
        paths => maps:get(paths, State),
        origin => Origin
    }, Rest};
parse_scope_fields(Tokens0, State, Origin) ->
    {FieldName, FieldOrigin, Tokens1} = expect(identifier, Tokens0),
    Field = scope_field(FieldName, FieldOrigin),
    ensure_unset(Field, State, FieldOrigin),
    {_LBracket, _LBracketOrigin, Tokens2} = expect(lbracket, Tokens1),
    {Values, Tokens3} = case Field of
        paths -> parse_string_nodes(Tokens2);
        _ -> parse_identifier_nodes(Tokens2)
    end,
    {_Semicolon, _SemicolonOrigin, Tokens4} = expect(semicolon, Tokens3),
    ensure_unique_values(Values, duplicate_scope_value),
    parse_scope_fields(Tokens4, State#{Field => #{kind => scope_field, name => FieldName, values => Values, origin => FieldOrigin}}, Origin).

parse_identifier_nodes([{rbracket, _, _} | Rest]) ->
    {[], Rest};
parse_identifier_nodes(Tokens) ->
    {Value, Origin, Tokens1} = expect(identifier, Tokens),
    parse_more_identifier_nodes(Tokens1, [#{kind => identifier, value => Value, origin => Origin}]).

parse_more_identifier_nodes([{comma, _, _} | Rest], Acc) ->
    {Value, Origin, Tokens1} = expect(identifier, Rest),
    parse_more_identifier_nodes(Tokens1, [#{kind => identifier, value => Value, origin => Origin} | Acc]);
parse_more_identifier_nodes([{rbracket, _, _} | Rest], Acc) ->
    {lists:reverse(Acc), Rest};
parse_more_identifier_nodes(Tokens, _Acc) ->
    fail(expected_list_separator, token_origin(Tokens), <<"expected comma or rbracket">>).

parse_limits(Tokens0, Origin) ->
    {_LBrace, _LBraceOrigin, Tokens1} = expect(lbrace, Tokens0),
    State = maps:from_list([{Name, undefined} || Name <- limit_names()]),
    parse_limit_fields(Tokens1, State, [], Origin).

parse_limit_fields([{rbrace, _, EndOrigin} | Rest], State, Acc, Origin) ->
    ensure_fields(limit_names(), State, missing_limit, EndOrigin),
    {#{kind => limits, values => lists:reverse(Acc), origin => Origin}, Rest};
parse_limit_fields(Tokens0, State, Acc, Origin) ->
    {Name, NameOrigin, Tokens1} = expect(identifier, Tokens0),
    Key = limit_name(Name, NameOrigin),
    ensure_unset(Key, State, NameOrigin),
    {Value, ValueOrigin, Tokens2} = expect(integer, Tokens1),
    case Value =< ?MAX_SIGNED_INTEGER of
        true -> ok;
        false -> fail(limit_value_too_large, ValueOrigin, <<"limit exceeds signed 64-bit range">>)
    end,
    {_Semicolon, _SemicolonOrigin, Tokens3} = expect(semicolon, Tokens2),
    Entry = #{kind => limit, name => Name, value => Value, value_origin => ValueOrigin, origin => NameOrigin},
    parse_limit_fields(Tokens3, State#{Key => Entry}, [Entry | Acc], Origin).

finalize_task(State, TaskName, TaskNameOrigin, TaskOrigin, EndOrigin) ->
    ensure_fields([facts, effects, requirements, scopes, limits], State, missing_task_clause, EndOrigin),
    Facts = maps:get(facts, State),
    case maps:get(values, Facts) of
        [] -> fail(empty_facts, maps:get(origin, Facts), <<"facts must contain at least one string">>);
        _ -> ok
    end,
    Inputs = lists:reverse(maps:get(inputs, State)),
    case Inputs of
        [] -> fail(missing_input, EndOrigin, <<"task must declare at least one input">>);
        _ -> ok
    end,
    #{
        kind => task,
        name => TaskName,
        name_origin => TaskNameOrigin,
        facts => Facts,
        inputs => Inputs,
        effects => maps:get(effects, State),
        requirements => maps:get(requirements, State),
        scopes => maps:get(scopes, State),
        limits => maps:get(limits, State),
        origin => TaskOrigin
    }.

checked_type(Name, _Origin) when
    Name =:= <<"bool">>;
    Name =:= <<"json">>;
    Name =:= <<"model-profile">>;
    Name =:= <<"nat">>;
    Name =:= <<"path">>;
    Name =:= <<"text">>
->
    Name;
checked_type(Name, Origin) ->
    fail(unknown_type, Origin, <<"unknown type: ", Name/binary>>).

scope_field(<<"models">>, _Origin) -> models;
scope_field(<<"workspaces">>, _Origin) -> workspaces;
scope_field(<<"paths">>, _Origin) -> paths;
scope_field(Name, Origin) -> fail(unknown_scope_field, Origin, <<"unknown scope field: ", Name/binary>>).

limit_name(Name, Origin) ->
    case lists:keyfind(Name, 1, limit_name_pairs()) of
        {Name, Key} -> Key;
        false -> fail(unknown_limit, Origin, <<"unknown limit: ", Name/binary>>)
    end.

limit_names() ->
    [steps, model_calls, repair_calls, child_calls, workspace_writes, output_bytes, timeout_ms].

limit_name_pairs() ->
    [
        {<<"steps">>, steps},
        {<<"model-calls">>, model_calls},
        {<<"repair-calls">>, repair_calls},
        {<<"child-calls">>, child_calls},
        {<<"workspace-writes">>, workspace_writes},
        {<<"output-bytes">>, output_bytes},
        {<<"timeout-ms">>, timeout_ms}
    ].

ensure_unset(Key, State, Origin) ->
    case maps:get(Key, State) of
        undefined -> ok;
        _ -> fail(duplicate_field, Origin, iolist_to_binary(io_lib:format("duplicate field: ~p", [Key])))
    end.

ensure_fields([], _State, _Code, _Origin) -> ok;
ensure_fields([Key | Rest], State, Code, Origin) ->
    case maps:get(Key, State) of
        undefined -> fail(Code, Origin, iolist_to_binary(io_lib:format("missing field: ~p", [Key])));
        _ -> ensure_fields(Rest, State, Code, Origin)
    end.

ensure_unique_named(Node, Nodes, Code) ->
    Name = maps:get(name, Node),
    case lists:any(fun(Existing) -> maps:get(name, Existing) =:= Name end, Nodes) of
        true -> fail(Code, maps:get(origin, Node), <<"duplicate name: ", Name/binary>>);
        false -> ok
    end.

ensure_unique_values(Nodes, Code) ->
    ensure_unique_values(Nodes, Code, #{}).

ensure_unique_values([], _Code, _Seen) -> ok;
ensure_unique_values([Node | Rest], Code, Seen) ->
    Value = case maps:find(value, Node) of
        {ok, Scalar} -> Scalar;
        error -> maps:get(name, Node)
    end,
    case maps:is_key(Value, Seen) of
        true -> fail(Code, maps:get(origin, Node), <<"duplicate list value">>);
        false -> ensure_unique_values(Rest, Code, Seen#{Value => true})
    end.

ensure_unique_requirements(Nodes) ->
    ensure_unique_requirements(Nodes, #{}).

ensure_unique_requirements([], _Seen) -> ok;
ensure_unique_requirements([Node | Rest], Seen) ->
    Key = {maps:get(resource_kind, Node), maps:get(resource, Node)},
    case maps:is_key(Key, Seen) of
        true -> fail(duplicate_requirement, maps:get(origin, Node), <<"duplicate requirement">>);
        false -> ensure_unique_requirements(Rest, Seen#{Key => true})
    end.

expect(Kind, [{Kind, Value, Origin} | Rest]) ->
    {Value, Origin, Rest};
expect(Kind, Tokens) ->
    fail(expected_token, token_origin(Tokens), iolist_to_binary(io_lib:format("expected ~p", [Kind]))).

expect_word([{identifier, Value, Origin} | Rest]) -> {Value, Origin, Rest};
expect_word([{child_kw, _, Origin} | Rest]) -> {<<"child">>, Origin, Rest};
expect_word([{complete_kw, _, Origin} | Rest]) -> {<<"complete">>, Origin, Rest};
expect_word(Tokens) -> fail(expected_identifier, token_origin(Tokens), <<"expected identifier">>).

token_origin([{_, _, Origin} | _]) -> Origin;
token_origin([]) -> default_origin().

fail(Code, Origin, Message) ->
    throw({parse_error, diagnostic(Code, Origin, Message)}).

diagnostic(Code, Origin, Message) ->
    #{code => Code, severity => error, origin => Origin, message => Message}.

default_origin() ->
    #{byte => 0, line => 1, column => 1}.
