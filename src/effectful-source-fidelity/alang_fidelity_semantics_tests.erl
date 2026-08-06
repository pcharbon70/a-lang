-module(alang_fidelity_semantics_tests).

-include_lib("eunit/include/eunit.hrl").

all_frozen_pairs_share_one_checked_meaning_test() ->
    Files = source_files(),
    ?assertEqual(24, length(Files)),
    lists:foreach(fun(SourcePath) ->
        JsonPath = filename:rootname(SourcePath, ".alang") ++ ".json",
        {ok, Source} = file:read_file(SourcePath),
        {ok, Control} = file:read_file(JsonPath),
        {ok, SourceChecked} = alang_fidelity_semantics:check_source(Source),
        {ok, ControlChecked} = alang_fidelity_semantics:check_control(Control),
        ?assertEqual(
            alang_fidelity_semantics:meaning(SourceChecked),
            alang_fidelity_semantics:meaning(ControlChecked)
        ),
        ?assertEqual(
            alang_fidelity_semantics:digest(SourceChecked),
            alang_fidelity_semantics:digest(ControlChecked)
        ),
        ?assertNotEqual(maps:get(source_map, SourceChecked),
            maps:get(source_map, ControlChecked))
    end, Files).

stable_task_binding_and_type_identities_test() ->
    {ok, Checked} = alang_fidelity_semantics:check_source(
        read_source("single-model-artifact/sma-simple.alang")),
    ?assertEqual(<<"task:sma-simple/1">>, maps:get(task_id, Checked)),
    [Input] = maps:get(inputs, Checked),
    ?assertEqual(<<"binding:sma-simple:input:change-summary">>, maps:get(id, Input)),
    ?assertEqual(binary, maps:get(type, Input)),
    [Draft, Publish, Finish] = maps:get(actions, Checked),
    ?assertEqual(<<"binding:task:sma-simple/1:draft">>, maps:get(binding_id, Draft)),
    ?assertEqual({result, binary, effect_error}, maps:get(result_type, Draft)),
    ?assertEqual({result, unit, effect_error}, maps:get(result_type, Publish)),
    ?assertEqual(terminal, maps:get(result_type, Finish)),
    ?assertEqual(#{<<"task:sma-simple/1">> => []}, maps:get(call_graph, Checked)).

both_frontends_reject_unresolved_dependencies_in_the_name_class_test() ->
    Source = read_source("single-model-artifact/sma-simple.alang"),
    SourceMutant = binary:replace(Source,
        <<"step publish: workspace.write depends [draft]">>,
        <<"step publish: workspace.write depends [missing]">>),
    Control = control_value("single-model-artifact/sma-simple.json"),
    Task = maps:get(<<"task">>, Control),
    [Draft, Publish | Rest] = maps:get(<<"actions">>, Task),
    JsonMutant = Control#{<<"task">> => Task#{<<"actions">> =>
        [Draft, Publish#{<<"depends_on">> => [<<"missing">>]} | Rest]}},
    SourceDiagnostic = one_error(alang_fidelity_semantics:check_source(SourceMutant)),
    JsonDiagnostic = one_error(alang_fidelity_semantics:check_control(encode(JsonMutant))),
    ?assertEqual(control, maps:get(class, SourceDiagnostic)),
    ?assertEqual(maps:get(class, SourceDiagnostic), maps:get(class, JsonDiagnostic)),
    ?assertEqual(dependency_not_prior, maps:get(code, SourceDiagnostic)),
    ?assertEqual(maps:get(code, SourceDiagnostic), maps:get(code, JsonDiagnostic)),
    ?assertMatch(#{source := alang_source, line := _}, maps:get(origin, SourceDiagnostic)),
    ?assertMatch(#{source := typed_json, pointer := <<"/task/actions/1/depends_on">>},
        maps:get(origin, JsonDiagnostic)).

actions_that_do_not_reach_completion_are_rejected_test() ->
    Source = read_source("single-model-artifact/sma-simple.alang"),
    SourceMutant = binary:replace(Source,
        <<"step publish: workspace.write depends [draft]">>,
        <<"step publish: workspace.write depends []">>),
    Control = control_value("single-model-artifact/sma-simple.json"),
    Task = maps:get(<<"task">>, Control),
    [Draft, Publish | Rest] = maps:get(<<"actions">>, Task),
    JsonMutant = Control#{<<"task">> => Task#{<<"actions">> =>
        [Draft, Publish#{<<"depends_on">> => []} | Rest]}},
    ?assertEqual({control, unreachable_action}, error_identity(
        alang_fidelity_semantics:check_source(SourceMutant))),
    ?assertEqual({control, unreachable_action}, error_identity(
        alang_fidelity_semantics:check_control(encode(JsonMutant)))).

unsafe_completion_paths_have_equivalent_classes_and_local_origins_test() ->
    Source = read_source("single-model-artifact/sma-simple.alang"),
    SourceMutant = binary:replace(Source,
        <<"complete [artifact-exists \"/workspace/release-note.md\"">>,
        <<"complete [artifact-exists \"/workspace/../secret.md\"">>),
    Control = control_value("single-model-artifact/sma-simple.json"),
    Task = maps:get(<<"task">>, Control),
    [First | Rest] = maps:get(<<"completion_predicates">>, Task),
    JsonMutant = Control#{<<"task">> => Task#{<<"completion_predicates">> =>
        [First#{<<"target">> => <<"/workspace/../secret.md">>} | Rest]}},
    SourceDiagnostic = one_error(alang_fidelity_semantics:check_source(SourceMutant)),
    JsonDiagnostic = one_error(alang_fidelity_semantics:check_control(encode(JsonMutant))),
    ?assertEqual({completion, unsafe_completion_path},
        {maps:get(class, SourceDiagnostic), maps:get(code, SourceDiagnostic)}),
    ?assertEqual({completion, unsafe_completion_path},
        {maps:get(class, JsonDiagnostic), maps:get(code, JsonDiagnostic)}),
    ?assertMatch(#{source := alang_source, byte := _}, maps:get(origin, SourceDiagnostic)),
    ?assertMatch(#{source := typed_json,
        pointer := <<"/task/completion_predicates/0/target">>, byte := _},
        maps:get(origin, JsonDiagnostic)).

sha256_completion_is_typed_equally_in_source_and_json_test() ->
    Digest = binary:copy(<<"a">>, 64),
    Source = read_source("single-model-artifact/sma-simple.alang"),
    SourceMutant = binary:replace(Source,
        <<"artifact-exists \"/workspace/release-note.md\": true,">>,
        <<"artifact-exists \"/workspace/release-note.md\": true, sha256 \"/workspace/release-note.md\": \"",
            Digest/binary, "\",">>),
    Control = control_value("single-model-artifact/sma-simple.json"),
    Task = maps:get(<<"task">>, Control),
    Predicates = maps:get(<<"completion_predicates">>, Task),
    Sha = #{<<"kind">> => <<"sha256">>,
        <<"target">> => <<"/workspace/release-note.md">>, <<"expected">> => Digest},
    JsonMutant = Control#{<<"task">> => Task#{<<"completion_predicates">> =>
        [hd(Predicates), Sha | tl(Predicates)]}},
    {ok, SourceChecked} = alang_fidelity_semantics:check_source(SourceMutant),
    {ok, JsonChecked} = alang_fidelity_semantics:check_control(encode(JsonMutant)),
    ?assertEqual(alang_fidelity_semantics:meaning(SourceChecked),
        alang_fidelity_semantics:meaning(JsonChecked)),
    ?assert(lists:any(fun(#{kind := Kind, expected_type := Type}) ->
        Kind =:= <<"sha256">> andalso Type =:= binary
    end, maps:get(predicates, maps:get(completion, SourceChecked)))).

recursive_child_authority_is_rejected_by_the_shared_core_test() ->
    Source = read_source("attenuated-delegation/ad-simple.alang"),
    SourceMutant = binary:replace(Source,
        <<"child { effects [model.generate]">>,
        <<"child { effects [model.generate, child.run]">>),
    Control = control_value("attenuated-delegation/ad-simple.json"),
    Task = maps:get(<<"task">>, Control),
    Child = maps:get(<<"child_attenuation">>, Task),
    JsonMutant = Control#{<<"task">> => Task#{<<"child_attenuation">> =>
        Child#{<<"effects">> => [<<"model.generate">>, <<"child.run">>]}}},
    ?assertEqual({attenuation, recursive_child_authority}, error_identity(
        alang_fidelity_semantics:check_source(SourceMutant))),
    ?assertEqual({attenuation, recursive_child_authority}, error_identity(
        alang_fidelity_semantics:check_control(encode(JsonMutant)))).

clarification_terminal_cannot_run_effects_first_test() ->
    Source = read_source("single-model-artifact/sma-simple.alang"),
    SourceMutant0 = binary:replace(Source, <<"clarify [];">>,
        <<"clarify [\"Need a source summary\"];">>),
    SourceMutant = binary:replace(SourceMutant0, <<"terminal complete;">>,
        <<"terminal needs-clarification;">>),
    Control = control_value("single-model-artifact/sma-simple.json"),
    Task = maps:get(<<"task">>, Control),
    JsonMutant = Control#{<<"task">> => Task#{
        <<"clarification_needs">> => [<<"Need a source summary">>],
        <<"terminal_class">> => <<"needs-clarification">>
    }},
    ?assertEqual({control, effects_before_clarification}, error_identity(
        alang_fidelity_semantics:check_source(SourceMutant))),
    ?assertEqual({control, effects_before_clarification}, error_identity(
        alang_fidelity_semantics:check_control(encode(JsonMutant)))).

one_error({error, [Diagnostic]}) -> Diagnostic.

error_identity(Result) ->
    Diagnostic = one_error(Result),
    {maps:get(class, Diagnostic), maps:get(code, Diagnostic)}.

source_files() ->
    lists:sort(filelib:wildcard(
        "assets/effectful-source-fidelity/corpus/*/*.alang")).

read_source(Relative) ->
    {ok, Binary} = file:read_file(filename:join(
        "assets/effectful-source-fidelity/corpus", Relative)),
    Binary.

control_value(Relative) ->
    {ok, Value} = alang_fidelity_json:decode(read_source(Relative)),
    Value.

encode(Value) ->
    iolist_to_binary(json:encode(Value)).
