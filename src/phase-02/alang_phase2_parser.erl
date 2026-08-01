-module(alang_phase2_parser).

-export([parse/1, parse_tokens/1]).

-spec parse(binary()) -> {ok, map()} | {error, [map()]}.
parse(Source) ->
    case alang_phase2_lexer:scan(Source) of
        {ok, Tokens} -> parse_tokens(Tokens);
        {error, _} = Error -> Error
    end.

-spec parse_tokens(list()) -> {ok, map()} | {error, [map()]}.
parse_tokens(Tokens) when is_list(Tokens) ->
    try
        {Module, Rest} = parse_module(Tokens),
        {_Value, _Origin, []} = expect(eof, Rest),
        {ok, Module}
    catch
        throw:{parse_error, Diagnostic} -> {error, [Diagnostic]};
        error:{badmatch, _} -> {error, [diagnostic(invalid_token_stream, #{byte => 0, line => 1, column => 1}, <<"invalid token stream">>)]}
    end.

parse_module(Tokens0) ->
    {_Module, Origin, Tokens1} = expect(module_kw, Tokens0),
    {Name, _NameOrigin, Tokens2} = expect(identifier, Tokens1),
    {_Version, _VersionOrigin, Tokens3} = expect(version_kw, Tokens2),
    {Version, _LiteralOrigin, Tokens4} = expect(string, Tokens3),
    {_LBrace, _LBraceOrigin, Tokens5} = expect(lbrace, Tokens4),
    {Tasks, Tokens6} = parse_tasks(Tokens5, []),
    {_RBrace, _RBraceOrigin, Tokens7} = expect(rbrace, Tokens6),
    {
        #{
            format => alang_source_ast_v1,
            kind => module,
            name => Name,
            version => Version,
            tasks => Tasks,
            origin => Origin
        },
        Tokens7
    }.

parse_tasks([{task_kw, _, _} | _] = Tokens, Acc) ->
    {Task, Rest} = parse_task(Tokens),
    parse_tasks(Rest, [Task | Acc]);
parse_tasks(Tokens, []) ->
    fail(expected_task, Tokens, <<"a module must contain at least one task">>);
parse_tasks(Tokens, Acc) ->
    {lists:reverse(Acc), Tokens}.

parse_task(Tokens0) ->
    {_Task, Origin, Tokens1} = expect(task_kw, Tokens0),
    {Name, _NameOrigin, Tokens2} = expect(identifier, Tokens1),
    {_LParen, _LParenOrigin, Tokens3} = expect(lparen, Tokens2),
    {Parameters, Tokens4} = parse_parameters(Tokens3),
    {_RParen, _RParenOrigin, Tokens5} = expect(rparen, Tokens4),
    {_Arrow, _ArrowOrigin, Tokens6} = expect(arrow, Tokens5),
    {ResultType, Tokens7} = parse_type(Tokens6),
    {_Effect, _EffectOrigin, Tokens8} = expect(effect_kw, Tokens7),
    {Effects, Tokens9} = parse_empty_list(Tokens8, effects_must_be_empty),
    {_Requires, _RequiresOrigin, Tokens10} = expect(requires_kw, Tokens9),
    {Requirements, Tokens11} = parse_empty_list(Tokens10, requirements_must_be_empty),
    {_Equal, _EqualOrigin, Tokens12} = expect(equal, Tokens11),
    {Body, Tokens13} = parse_expression(Tokens12),
    {_Ensures, _EnsuresOrigin, Tokens14} = expect(ensures_kw, Tokens13),
    {Ensures, Tokens15} = parse_expression(Tokens14),
    {_Semicolon, _SemicolonOrigin, Tokens16} = expect(semicolon, Tokens15),
    {
        #{
            kind => task,
            name => Name,
            parameters => Parameters,
            result_type => ResultType,
            effects => Effects,
            requirements => Requirements,
            body => Body,
            ensures => Ensures,
            origin => Origin
        },
        Tokens16
    }.

parse_parameters([{rparen, _, _} | _] = Tokens) ->
    {[], Tokens};
parse_parameters(Tokens) ->
    {First, Rest} = parse_parameter(Tokens),
    parse_more_parameters(Rest, [First]).

parse_more_parameters([{comma, _, _} | Rest], Acc) ->
    {Parameter, Tail} = parse_parameter(Rest),
    parse_more_parameters(Tail, [Parameter | Acc]);
parse_more_parameters(Tokens, Acc) ->
    {lists:reverse(Acc), Tokens}.

parse_parameter(Tokens0) ->
    {Name, Origin, Tokens1} = expect(identifier, Tokens0),
    {_Colon, _ColonOrigin, Tokens2} = expect(colon, Tokens1),
    {Type, Tokens3} = parse_type(Tokens2),
    {#{kind => parameter, name => Name, type => Type, origin => Origin}, Tokens3}.

parse_type(Tokens) ->
    case expect(identifier, Tokens) of
        {<<"Int">>, _Origin, Rest} -> {int, Rest};
        {<<"Bool">>, _Origin, Rest} -> {bool, Rest};
        {Name, Origin, _Rest} ->
            throw({parse_error, diagnostic(unknown_type, Origin, <<"unknown type: ", Name/binary>> )})
    end.

parse_empty_list(Tokens0, ErrorCode) ->
    {_LBracket, _Origin, Tokens1} = expect(lbracket, Tokens0),
    case Tokens1 of
        [{rbracket, _, _} | Rest] -> {[], Rest};
        _ -> fail(ErrorCode, Tokens1, <<"the Phase 2 vertical slice accepts only an empty list">>)
    end.

parse_expression(Tokens) ->
    parse_equality(Tokens).

parse_equality(Tokens0) ->
    {Left, Tokens1} = parse_addition(Tokens0),
    case Tokens1 of
        [{equal_equal, _, Origin} | Rest] ->
            {Right, Tail} = parse_addition(Rest),
            {#{kind => equal, left => Left, right => Right, origin => Origin}, Tail};
        _ ->
            {Left, Tokens1}
    end.

parse_addition(Tokens0) ->
    {First, Tokens1} = parse_primary(Tokens0),
    parse_addition_tail(First, Tokens1).

parse_addition_tail(Left, [{plus, _, Origin} | Rest]) ->
    {Right, Tail} = parse_primary(Rest),
    parse_addition_tail(#{kind => add, left => Left, right => Right, origin => Origin}, Tail);
parse_addition_tail(Left, Tokens) ->
    {Left, Tokens}.

parse_primary([{integer, Value, Origin} | Rest]) ->
    {#{kind => integer, value => Value, origin => Origin}, Rest};
parse_primary([{true_kw, _, Origin} | Rest]) ->
    {#{kind => boolean, value => true, origin => Origin}, Rest};
parse_primary([{false_kw, _, Origin} | Rest]) ->
    {#{kind => boolean, value => false, origin => Origin}, Rest};
parse_primary([{identifier, Name, Origin} | Rest]) ->
    {#{kind => variable, name => Name, origin => Origin}, Rest};
parse_primary([{lparen, _, _Origin} | Rest]) ->
    {Expression, Tail0} = parse_expression(Rest),
    {_RParen, _RParenOrigin, Tail1} = expect(rparen, Tail0),
    {Expression, Tail1};
parse_primary(Tokens) ->
    fail(expected_expression, Tokens, <<"expected an expression">>).

expect(Kind, [{Kind, Value, Origin} | Rest]) ->
    {Value, Origin, Rest};
expect(Kind, Tokens) ->
    fail(expected_token, Tokens, iolist_to_binary(io_lib:format("expected ~p", [Kind]))).

fail(Code, [{Actual, _, Origin} | _], Message) ->
    throw({parse_error, diagnostic(Code, Origin, <<Message/binary, "; found ", (atom_to_binary(Actual))/binary>>)});
fail(Code, [], Message) ->
    throw({parse_error, diagnostic(Code, #{byte => 0, line => 1, column => 1}, Message)}).

diagnostic(Code, Origin, Message) ->
    #{code => Code, severity => error, origin => Origin, message => Message}.
