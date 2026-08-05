-module(alang_fidelity_frontend_tests).

-include_lib("eunit/include/eunit.hrl").

-define(V1_FIXTURE, "src/phase-02/fixtures/counter.alang").

lexer_recognizes_closed_v2_surface_with_origins_test() ->
    Utf8Text = unicode:characters_to_binary("Résumé"),
    Source = iolist_to_binary(["#!alang-source-v2\n// metadata\ntask sample-task { facts [\"", Utf8Text, "\"]; }"]),
    {ok, Tokens} = alang_fidelity_lexer:scan(Source),
    [{source_version, <<"alang-source-v2">>, HeaderOrigin}, {task_kw, none, TaskOrigin} | _] = Tokens,
    ?assertEqual(#{byte => 0, line => 1, column => 1}, HeaderOrigin),
    ?assertEqual(#{byte => 30, line => 3, column => 1}, TaskOrigin),
    ?assert(lists:any(fun
        ({string, Value, _}) when Value =:= Utf8Text -> true;
        (_) -> false
    end, Tokens)),
    ?assert(lists:all(fun token_value_is_closed/1, Tokens)).

lexer_rejects_unbounded_or_active_literals_test() ->
    {error, [Interpolation]} = alang_fidelity_lexer:scan(<<"\"${value}\"">>),
    ?assertEqual(string_interpolation_forbidden, maps:get(code, Interpolation)),
    {error, [Escape]} = alang_fidelity_lexer:scan(<<"\"\\n\"">>),
    ?assertEqual(invalid_string_escape, maps:get(code, Escape)),
    LongIdentifier = binary:copy(<<"a">>, 129),
    {error, [Identifier]} = alang_fidelity_lexer:scan(LongIdentifier),
    ?assertEqual(identifier_too_long, maps:get(code, Identifier)),
    {error, [Integer]} = alang_fidelity_lexer:scan(<<"12345678901234567890">>),
    ?assertEqual(integer_literal_too_long, maps:get(code, Integer)),
    {error, [Utf8]} = alang_fidelity_lexer:scan(<<16#C3>>),
    ?assertEqual(invalid_utf8, maps:get(code, Utf8)),
    {error, [Size]} = alang_fidelity_lexer:scan(binary:copy(<<" ">>, 1048577)),
    ?assertEqual(source_too_large, maps:get(code, Size)).

parser_accepts_reordered_closed_declarations_test() ->
    {ok, Ast} = alang_fidelity_parser:parse(declaration_source()),
    ?assertEqual(alang_source_ast_v2, maps:get(format, Ast)),
    Task = maps:get(task, Ast),
    ?assertEqual(<<"sample-task">>, maps:get(name, Task)),
    ?assertEqual(2, length(maps:get(inputs, Task))),
    Effects = maps:get(values, maps:get(effects, Task)),
    ?assertEqual([<<"workspace.write">>, <<"model.generate">>], [maps:get(name, Effect) || Effect <- Effects]),
    ScopeModels = maps:get(values, maps:get(models, maps:get(scopes, Task))),
    ?assertEqual([<<"writer-model">>], [maps:get(value, Model) || Model <- ScopeModels]),
    Limits = maps:get(values, maps:get(limits, Task)),
    ?assertEqual(7, length(Limits)),
    ?assert(lists:all(fun has_origin/1, Limits)).

parser_retains_v1_frontend_behavior_test() ->
    {ok, Source} = file:read_file(?V1_FIXTURE),
    ?assertEqual(alang_phase2_parser:parse(Source), alang_fidelity_parser:parse(Source)).

parser_rejects_unknown_and_duplicate_declarations_test() ->
    assert_parse_error(unknown_effect, replace(declaration_source(), <<"model.generate">>, <<"model.invoke">>)),
    assert_parse_error(unknown_type, replace(declaration_source(), <<"text required">>, <<"Widget required">>)),
    assert_parse_error(unknown_limit, replace(declaration_source(), <<"steps 3;">>, <<"tokens 3;">>)),
    assert_parse_error(
        duplicate_field,
        replace(declaration_source(), <<"steps 3;">>, <<"steps 3; steps 4;">>)
    ),
    assert_parse_error(
        duplicate_input,
        replace(
            declaration_source(),
            <<"input brief: text required;">>,
            <<"input brief: text required; input brief: json optional;">>
        )
    ),
    assert_parse_error(
        source_document_too_large,
        <<"#!alang-source-v2\n", (binary:copy(<<" ">>, 8192))/binary>>
    ).

declaration_source() ->
    iolist_to_binary([
        "#!alang-source-v2\n",
        "// corpus-case: sample-task\n",
        "// semantic-sha256: 0000000000000000000000000000000000000000000000000000000000000000\n",
        "// model-visible-begin\n",
        "task sample-task {\n",
        "  scopes { paths [\"/workspace/result.md\"]; workspaces [artifact-workspace]; models [writer-model]; }\n",
        "  requirements [workspace artifact-workspace, model writer-model];\n",
        "  facts [\"Create a bounded result\", \"Do not invent facts\"];\n",
        "  input brief: text required;\n",
        "  input context: json optional;\n",
        "  effects [workspace.write, model.generate];\n",
        "  limits { timeout-ms 30000; output-bytes 2048; workspace-writes 1; child-calls 0; repair-calls 0; model-calls 1; steps 3; }\n",
        "}\n"
    ]).

replace(Source, Pattern, Replacement) ->
    binary:replace(Source, Pattern, Replacement, [global]).

assert_parse_error(Code, Source) ->
    {error, [Diagnostic]} = alang_fidelity_parser:parse(Source),
    ?assertEqual(Code, maps:get(code, Diagnostic)),
    ?assert(maps:is_key(origin, Diagnostic)).

token_value_is_closed({identifier, Value, _}) -> is_binary(Value);
token_value_is_closed({string, Value, _}) -> is_binary(Value);
token_value_is_closed({source_version, Value, _}) -> is_binary(Value);
token_value_is_closed({integer, Value, _}) -> is_integer(Value);
token_value_is_closed({_Kind, none, _}) -> true;
token_value_is_closed({_Kind, Value, _}) -> is_boolean(Value).

has_origin(Node) ->
    case maps:get(origin, Node, undefined) of
        #{byte := Byte, line := Line, column := Column} ->
            is_integer(Byte) andalso is_integer(Line) andalso is_integer(Column);
        _ -> false
    end.
