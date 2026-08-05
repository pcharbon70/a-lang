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
            limits => undefined,
            steps => [],
            on_error => undefined,
            child => undefined,
            completion => undefined,
            clarify => undefined,
            terminal => undefined
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
parse_declarations([{step_kw, _, Origin} | Rest], State, TaskName, TaskNameOrigin, TaskOrigin) ->
    {Step, Tokens1} = parse_step(Rest, Origin),
    Steps = maps:get(steps, State),
    ensure_unique_named(Step, Steps, duplicate_step),
    parse_declarations(Tokens1, State#{steps => [Step | Steps]}, TaskName, TaskNameOrigin, TaskOrigin);
parse_declarations([{on_error_kw, _, Origin} | Rest], State, TaskName, TaskNameOrigin, TaskOrigin) ->
    ensure_unset(on_error, State, Origin),
    {OnError, Tokens1} = parse_on_error(Rest, Origin),
    parse_declarations(Tokens1, State#{on_error => OnError}, TaskName, TaskNameOrigin, TaskOrigin);
parse_declarations([{child_kw, _, Origin} | Rest], State, TaskName, TaskNameOrigin, TaskOrigin) ->
    ensure_unset(child, State, Origin),
    {Child, Tokens1} = parse_child(Rest, Origin),
    parse_declarations(Tokens1, State#{child => Child}, TaskName, TaskNameOrigin, TaskOrigin);
parse_declarations([{complete_kw, _, Origin} | Rest], State, TaskName, TaskNameOrigin, TaskOrigin) ->
    ensure_unset(completion, State, Origin),
    {Completion, Tokens1} = parse_completion(Rest, Origin),
    parse_declarations(Tokens1, State#{completion => Completion}, TaskName, TaskNameOrigin, TaskOrigin);
parse_declarations([{clarify_kw, _, Origin} | Rest], State, TaskName, TaskNameOrigin, TaskOrigin) ->
    ensure_unset(clarify, State, Origin),
    {_LBracket, _LBracketOrigin, Tokens1} = expect(lbracket, Rest),
    {Needs, Tokens2} = parse_string_nodes(Tokens1),
    {_Semicolon, _SemicolonOrigin, Tokens3} = expect(semicolon, Tokens2),
    parse_declarations(
        Tokens3,
        State#{clarify => #{kind => clarification_needs, values => Needs, origin => Origin}},
        TaskName,
        TaskNameOrigin,
        TaskOrigin
    );
parse_declarations([{terminal_kw, _, Origin} | Rest], State, TaskName, TaskNameOrigin, TaskOrigin) ->
    ensure_unset(terminal, State, Origin),
    {TerminalClass, ClassOrigin, Tokens1} = expect_terminal(Rest),
    {_Semicolon, _SemicolonOrigin, Tokens2} = expect(semicolon, Tokens1),
    Terminal = #{kind => terminal, class => TerminalClass, class_origin => ClassOrigin, origin => Origin},
    parse_declarations(Tokens2, State#{terminal => Terminal}, TaskName, TaskNameOrigin, TaskOrigin);
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

parse_step(Tokens0, Origin) ->
    {Name, NameOrigin, Tokens1} = expect(identifier, Tokens0),
    {_Colon, _ColonOrigin, Tokens2} = expect(colon, Tokens1),
    {Operation, OperationOrigin, Tokens3} = parse_operation(Tokens2),
    {_Depends, _DependsOrigin, Tokens4} = expect(depends_kw, Tokens3),
    {_LBracket, _LBracketOrigin, Tokens5} = expect(lbracket, Tokens4),
    {Dependencies, Tokens6} = parse_identifier_nodes(Tokens5),
    ensure_unique_values(Dependencies, duplicate_dependency),
    {_Semicolon, _SemicolonOrigin, Tokens7} = expect(semicolon, Tokens6),
    {#{
        kind => step,
        name => Name,
        name_origin => NameOrigin,
        operation => Operation,
        operation_origin => OperationOrigin,
        depends_on => Dependencies,
        origin => Origin
    }, Tokens7}.

parse_operation([{complete_kw, _, Origin} | Rest]) ->
    {<<"complete">>, Origin, Rest};
parse_operation(Tokens0) ->
    {Namespace, Origin, Tokens1} = expect_word(Tokens0),
    {_Dot, _DotOrigin, Tokens2} = expect(dot, Tokens1),
    {Operation, _OperationOrigin, Tokens3} = expect_word(Tokens2),
    Name = <<Namespace/binary, ".", Operation/binary>>,
    Allowed = [<<"child.run">>, <<"model.generate">>, <<"model.repair">>, <<"workspace.write">>],
    case lists:member(Name, Allowed) of
        true -> {Name, Origin, Tokens3};
        false -> fail(unknown_operation, Origin, <<"unknown step operation: ", Name/binary>>)
    end.

parse_on_error(Tokens0, Origin) ->
    {_LBracket, _LBracketOrigin, Tokens1} = expect(lbracket, Tokens0),
    {Branches, Tokens2} = parse_error_branches(Tokens1),
    {_Semicolon, _SemicolonOrigin, Tokens3} = expect(semicolon, Tokens2),
    ensure_unique_error_branches(Branches),
    {#{kind => error_branches, values => Branches, origin => Origin}, Tokens3}.

parse_error_branches([{rbracket, _, _} | Rest]) ->
    {[], Rest};
parse_error_branches(Tokens) ->
    {Branch, Tokens1} = parse_error_branch(Tokens),
    parse_more_error_branches(Tokens1, [Branch]).

parse_more_error_branches([{comma, _, _} | Rest], Acc) ->
    {Branch, Tokens1} = parse_error_branch(Rest),
    parse_more_error_branches(Tokens1, [Branch | Acc]);
parse_more_error_branches([{rbracket, _, _} | Rest], Acc) ->
    {lists:reverse(Acc), Rest};
parse_more_error_branches(Tokens, _Acc) ->
    fail(expected_list_separator, token_origin(Tokens), <<"expected comma or rbracket">>).

parse_error_branch(Tokens0) ->
    {Action, Origin, Tokens1} = expect(identifier, Tokens0),
    {Reason, ReasonOrigin, Tokens2} = expect(identifier, Tokens1),
    case lists:member(Reason, [<<"denied">>, <<"invalid-output">>, <<"timeout">>]) of
        true -> ok;
        false -> fail(unknown_error_reason, ReasonOrigin, <<"unknown error reason: ", Reason/binary>>)
    end,
    {_Arrow, _ArrowOrigin, Tokens3} = expect(fat_arrow, Tokens2),
    {TerminalClass, TerminalOrigin, Tokens4} = expect_terminal(Tokens3),
    {#{
        kind => error_branch,
        action => Action,
        reason => Reason,
        terminal_class => TerminalClass,
        reason_origin => ReasonOrigin,
        terminal_origin => TerminalOrigin,
        origin => Origin
    }, Tokens4}.

parse_child([{none_kw, _, ValueOrigin} | Rest], Origin) ->
    {_Semicolon, _SemicolonOrigin, Tokens1} = expect(semicolon, Rest),
    {#{kind => child, value => none, value_origin => ValueOrigin, origin => Origin}, Tokens1};
parse_child(Tokens0, Origin) ->
    {_LBrace, _LBraceOrigin, Tokens1} = expect(lbrace, Tokens0),
    State = #{effects => undefined, requirements => undefined, scopes => undefined, limits => undefined},
    parse_child_fields(Tokens1, State, Origin).

parse_child_fields([{rbrace, _, EndOrigin} | Rest], State, Origin) ->
    ensure_fields([effects, requirements, scopes, limits], State, missing_child_field, EndOrigin),
    {#{
        kind => child,
        value => attenuation,
        effects => maps:get(effects, State),
        requirements => maps:get(requirements, State),
        scopes => maps:get(scopes, State),
        limits => maps:get(limits, State),
        origin => Origin
    }, Rest};
parse_child_fields([{effects_kw, _, FieldOrigin} | Rest], State, Origin) ->
    ensure_unset(effects, State, FieldOrigin),
    {_LBracket, _LBracketOrigin, Tokens1} = expect(lbracket, Rest),
    {Effects, Tokens2} = parse_effect_nodes(Tokens1),
    {_Semicolon, _SemicolonOrigin, Tokens3} = expect(semicolon, Tokens2),
    ensure_unique_values(Effects, duplicate_effect),
    Field = #{kind => effects, values => Effects, origin => FieldOrigin},
    parse_child_fields(Tokens3, State#{effects => Field}, Origin);
parse_child_fields([{requirements_kw, _, FieldOrigin} | Rest], State, Origin) ->
    ensure_unset(requirements, State, FieldOrigin),
    {_LBracket, _LBracketOrigin, Tokens1} = expect(lbracket, Rest),
    {Requirements, Tokens2} = parse_requirement_nodes(Tokens1),
    {_Semicolon, _SemicolonOrigin, Tokens3} = expect(semicolon, Tokens2),
    ensure_unique_requirements(Requirements),
    Field = #{kind => requirements, values => Requirements, origin => FieldOrigin},
    parse_child_fields(Tokens3, State#{requirements => Field}, Origin);
parse_child_fields([{scopes_kw, _, FieldOrigin} | Rest], State, Origin) ->
    ensure_unset(scopes, State, FieldOrigin),
    {Scopes, Tokens1} = parse_scopes(Rest, FieldOrigin),
    parse_child_fields(Tokens1, State#{scopes => Scopes}, Origin);
parse_child_fields([{limits_kw, _, FieldOrigin} | Rest], State, Origin) ->
    ensure_unset(limits, State, FieldOrigin),
    {Limits, Tokens1} = parse_limits(Rest, FieldOrigin),
    parse_child_fields(Tokens1, State#{limits => Limits}, Origin);
parse_child_fields([{_Kind, _, FieldOrigin} | _], _State, _Origin) ->
    fail(unknown_child_field, FieldOrigin, <<"child attenuation contains an unsupported field">>);
parse_child_fields([], _State, _Origin) ->
    fail(expected_token, default_origin(), <<"expected child rbrace">>).

parse_completion(Tokens0, Origin) ->
    {_LBracket, _LBracketOrigin, Tokens1} = expect(lbracket, Tokens0),
    {Predicates, Tokens2} = parse_completion_predicates(Tokens1),
    {_Semicolon, _SemicolonOrigin, Tokens3} = expect(semicolon, Tokens2),
    ensure_unique_predicates(Predicates),
    {#{kind => completion, predicates => Predicates, origin => Origin}, Tokens3}.

parse_completion_predicates([{rbracket, _, _} | Rest]) ->
    {[], Rest};
parse_completion_predicates(Tokens) ->
    {Predicate, Tokens1} = parse_completion_predicate(Tokens),
    parse_more_completion_predicates(Tokens1, [Predicate]).

parse_more_completion_predicates([{comma, _, _} | Rest], Acc) ->
    {Predicate, Tokens1} = parse_completion_predicate(Rest),
    parse_more_completion_predicates(Tokens1, [Predicate | Acc]);
parse_more_completion_predicates([{rbracket, _, _} | Rest], Acc) ->
    {lists:reverse(Acc), Rest};
parse_more_completion_predicates(Tokens, _Acc) ->
    fail(expected_list_separator, token_origin(Tokens), <<"expected comma or rbracket">>).

parse_completion_predicate(Tokens0) ->
    {PredicateKind, Origin, Tokens1} = expect(identifier, Tokens0),
    checked_predicate_kind(PredicateKind, Origin),
    {Target, TargetOrigin, Tokens2} = expect(string, Tokens1),
    {_Colon, _ColonOrigin, Tokens3} = expect(colon, Tokens2),
    {Expected, ExpectedType, ExpectedOrigin, Tokens4} = parse_scalar(Tokens3),
    check_predicate_expected(PredicateKind, ExpectedType, ExpectedOrigin),
    {#{
        kind => completion_predicate,
        predicate => PredicateKind,
        target => Target,
        expected => Expected,
        expected_type => ExpectedType,
        target_origin => TargetOrigin,
        expected_origin => ExpectedOrigin,
        origin => Origin
    }, Tokens4}.

parse_scalar([{true_kw, true, Origin} | Rest]) -> {true, boolean, Origin, Rest};
parse_scalar([{false_kw, false, Origin} | Rest]) -> {false, boolean, Origin, Rest};
parse_scalar([{integer, Value, Origin} | Rest]) -> {Value, integer, Origin, Rest};
parse_scalar([{string, Value, Origin} | Rest]) -> {Value, string, Origin, Rest};
parse_scalar(Tokens) -> fail(expected_scalar, token_origin(Tokens), <<"expected boolean, integer, or string">>).

checked_predicate_kind(Name, _Origin) when
    Name =:= <<"artifact-exists">>;
    Name =:= <<"clarification-recorded">>;
    Name =:= <<"journal-succeeded">>;
    Name =:= <<"markdown-h1">>;
    Name =:= <<"max-bytes">>;
    Name =:= <<"utf8">>
->
    ok;
checked_predicate_kind(Name, Origin) ->
    fail(unknown_completion_predicate, Origin, <<"unknown completion predicate: ", Name/binary>>).

check_predicate_expected(Name, boolean, _Origin) when
    Name =:= <<"artifact-exists">>;
    Name =:= <<"clarification-recorded">>;
    Name =:= <<"journal-succeeded">>;
    Name =:= <<"utf8">>
->
    ok;
check_predicate_expected(<<"markdown-h1">>, string, _Origin) -> ok;
check_predicate_expected(<<"max-bytes">>, integer, _Origin) -> ok;
check_predicate_expected(_Name, _Type, Origin) ->
    fail(invalid_completion_expected_type, Origin, <<"completion predicate has the wrong expected value type">>).

finalize_task(State, TaskName, TaskNameOrigin, TaskOrigin, EndOrigin) ->
    ensure_fields(
        [facts, effects, requirements, scopes, limits, on_error, child, completion, clarify, terminal],
        State,
        missing_task_clause,
        EndOrigin
    ),
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
    Steps = lists:reverse(maps:get(steps, State)),
    case Steps of
        [] -> fail(missing_step, EndOrigin, <<"task must declare at least one step">>);
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
        steps => Steps,
        on_error => maps:get(on_error, State),
        child => maps:get(child, State),
        completion => maps:get(completion, State),
        clarify => maps:get(clarify, State),
        terminal => maps:get(terminal, State),
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

ensure_unique_error_branches(Nodes) ->
    ensure_unique_error_branches(Nodes, #{}).

ensure_unique_error_branches([], _Seen) -> ok;
ensure_unique_error_branches([Node | Rest], Seen) ->
    Key = {maps:get(action, Node), maps:get(reason, Node)},
    case maps:is_key(Key, Seen) of
        true -> fail(duplicate_error_branch, maps:get(origin, Node), <<"duplicate error branch">>);
        false -> ensure_unique_error_branches(Rest, Seen#{Key => true})
    end.

ensure_unique_predicates(Nodes) ->
    ensure_unique_predicates(Nodes, #{}).

ensure_unique_predicates([], _Seen) -> ok;
ensure_unique_predicates([Node | Rest], Seen) ->
    Key = {maps:get(predicate, Node), maps:get(target, Node)},
    case maps:is_key(Key, Seen) of
        true -> fail(duplicate_completion_predicate, maps:get(origin, Node), <<"duplicate completion predicate">>);
        false -> ensure_unique_predicates(Rest, Seen#{Key => true})
    end.

expect(Kind, [{Kind, Value, Origin} | Rest]) ->
    {Value, Origin, Rest};
expect(Kind, Tokens) ->
    fail(expected_token, token_origin(Tokens), iolist_to_binary(io_lib:format("expected ~p", [Kind]))).

expect_word([{identifier, Value, Origin} | Rest]) -> {Value, Origin, Rest};
expect_word([{child_kw, _, Origin} | Rest]) -> {<<"child">>, Origin, Rest};
expect_word([{complete_kw, _, Origin} | Rest]) -> {<<"complete">>, Origin, Rest};
expect_word(Tokens) -> fail(expected_identifier, token_origin(Tokens), <<"expected identifier">>).

expect_terminal([{complete_kw, _, Origin} | Rest]) -> {<<"complete">>, Origin, Rest};
expect_terminal([{identifier, Value, Origin} | Rest]) ->
    case lists:member(Value, [<<"failed">>, <<"needs-clarification">>]) of
        true -> {Value, Origin, Rest};
        false -> fail(unknown_terminal_class, Origin, <<"unknown terminal class: ", Value/binary>>)
    end;
expect_terminal(Tokens) ->
    fail(expected_terminal_class, token_origin(Tokens), <<"expected complete, failed, or needs-clarification">>).

token_origin([{_, _, Origin} | _]) -> Origin;
token_origin([]) -> default_origin().

fail(Code, Origin, Message) ->
    throw({parse_error, diagnostic(Code, Origin, Message)}).

diagnostic(Code, Origin, Message) ->
    #{code => Code, severity => error, origin => Origin, message => Message}.

default_origin() ->
    #{byte => 0, line => 1, column => 1}.
