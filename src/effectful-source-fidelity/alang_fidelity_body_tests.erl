-module(alang_fidelity_body_tests).

-include_lib("eunit/include/eunit.hrl").

-define(CORPUS, "assets/effectful-source-fidelity/corpus").

ordered_effect_bodies_parse_with_source_origins_test() ->
    Ast = parse_case("single-model-artifact/sma-simple.alang"),
    Task = maps:get(task, Ast),
    Steps = maps:get(steps, Task),
    ?assertEqual([<<"draft">>, <<"publish">>, <<"finish">>], [maps:get(name, Step) || Step <- Steps]),
    ?assertEqual(
        [<<"model.generate">>, <<"workspace.write">>, <<"complete">>],
        [maps:get(operation, Step) || Step <- Steps]
    ),
    [Publish] = [Step || Step <- Steps, maps:get(name, Step) =:= <<"publish">>],
    ?assertEqual([<<"draft">>], [maps:get(value, Dependency) || Dependency <- maps:get(depends_on, Publish)]),
    ?assert(lists:all(fun has_origin/1, Steps)).

repair_and_error_results_remain_explicit_test() ->
    RepairAst = parse_case("repair-and-publish/rap-simple.alang"),
    RepairSteps = maps:get(steps, maps:get(task, RepairAst)),
    ?assert(lists:any(fun(Step) -> maps:get(operation, Step) =:= <<"model.repair">> end, RepairSteps)),
    ErrorAst = parse_case("repair-and-publish/rap-error-branch.alang"),
    ErrorBranches = maps:get(values, maps:get(on_error, maps:get(task, ErrorAst))),
    ?assertEqual(2, length(ErrorBranches)),
    ?assertEqual([<<"invalid-output">>, <<"denied">>], [maps:get(reason, Branch) || Branch <- ErrorBranches]),
    ?assert(lists:all(fun(Branch) -> maps:get(terminal_class, Branch) =:= <<"failed">> end, ErrorBranches)).

attenuated_child_is_a_closed_declaration_test() ->
    Ast = parse_case("attenuated-delegation/ad-semantic-perturbation.alang"),
    Child = maps:get(child, maps:get(task, Ast)),
    ?assertEqual(attenuation, maps:get(value, Child)),
    Effects = maps:get(values, maps:get(effects, Child)),
    ?assertEqual([<<"model.generate">>], [maps:get(name, Effect) || Effect <- Effects]),
    Workspaces = maps:get(values, maps:get(workspaces, maps:get(scopes, Child))),
    ?assertEqual([], Workspaces),
    Limits = maps:get(values, maps:get(limits, Child)),
    ?assertEqual(7, length(Limits)).

completion_clarification_and_terminal_are_structured_test() ->
    CompleteAst = parse_case("single-model-artifact/sma-constraint-heavy.alang"),
    CompleteTask = maps:get(task, CompleteAst),
    Predicates = maps:get(predicates, maps:get(completion, CompleteTask)),
    ?assertEqual(
        [<<"artifact-exists">>, <<"markdown-h1">>, <<"utf8">>, <<"max-bytes">>],
        [maps:get(predicate, Predicate) || Predicate <- Predicates]
    ),
    ?assertEqual(<<"complete">>, maps:get(class, maps:get(terminal, CompleteTask))),
    ClarifyAst = parse_case("single-model-artifact/sma-missing-information.alang"),
    ClarifyTask = maps:get(task, ClarifyAst),
    ?assertEqual(<<"needs-clarification">>, maps:get(class, maps:get(terminal, ClarifyTask))),
    ?assertEqual(1, length(maps:get(values, maps:get(clarify, ClarifyTask)))),
    ?assertEqual(none, maps:get(value, maps:get(child, ClarifyTask))).

body_parser_rejects_dynamic_or_widened_forms_test() ->
    Source = read_case("single-model-artifact/sma-simple.alang"),
    assert_parse_error(unknown_operation, replace(Source, <<"model.generate depends">>, <<"model.invoke depends">>)),
    assert_parse_error(
        duplicate_step,
        replace(
            Source,
            <<"step draft: model.generate depends [];">>,
            <<"step draft: model.generate depends [];\n  step draft: model.generate depends [];">>
        )
    ),
    assert_parse_error(
        invalid_completion_expected_type,
        replace(Source, <<"artifact-exists \"/workspace/release-note.md\": true">>, <<"artifact-exists \"/workspace/release-note.md\": \"yes\"">>)
    ),
    assert_parse_error(
        unknown_completion_predicate,
        replace(Source, <<"artifact-exists">>, <<"model-asserts-complete">>)
    ),
    ChildSource = read_case("attenuated-delegation/ad-simple.alang"),
    assert_parse_error(unknown_child_field, replace(ChildSource, <<"child {">>, <<"child { grants [];">>)),
    assert_parse_error(unknown_terminal_class, replace(Source, <<"terminal complete;">>, <<"terminal maybe;">>)).

parse_case(Relative) ->
    Source = read_case(Relative),
    {ok, Ast} = alang_fidelity_parser:parse(Source),
    Ast.

read_case(Relative) ->
    {ok, Source} = file:read_file(filename:join(?CORPUS, Relative)),
    Source.

replace(Source, Pattern, Replacement) ->
    binary:replace(Source, Pattern, Replacement, [global]).

assert_parse_error(Code, Source) ->
    {error, [Diagnostic]} = alang_fidelity_parser:parse(Source),
    ?assertEqual(Code, maps:get(code, Diagnostic)),
    ?assertMatch(#{byte := _, line := _, column := _}, maps:get(origin, Diagnostic)).

has_origin(Node) ->
    case maps:get(origin, Node, undefined) of
        #{byte := Byte, line := Line, column := Column} ->
            is_integer(Byte) andalso is_integer(Line) andalso is_integer(Column);
        _ -> false
    end.
