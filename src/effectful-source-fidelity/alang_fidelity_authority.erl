-module(alang_fidelity_authority).

-export([derive/1]).

-spec derive(map()) -> {ok, map()} | {error, [map()]}.
derive(#{format := alang_checked_semantics_v2} = Checked) ->
    try
        Semantic = maps:get(semantic, Checked),
        Actions = maps:get(actions, Checked),
        Child = maps:get(child, Checked),
        InferredEffects = infer_effects(Actions),
        DeclaredEffects = maps:get(<<"effects">>, Semantic),
        ensure(InferredEffects =:= DeclaredEffects, authority,
            declared_effect_mismatch, [<<"effects">>], Checked,
            <<"declared effects must equal the operations inferred from the action graph">>),
        Scopes = maps:get(<<"scopes">>, Semantic),
        Requirements = infer_requirements(InferredEffects, Scopes, Child, Checked),
        DeclaredRequirements = trusted_requirements(
            maps:get(<<"requirements">>, Semantic)),
        ensure(Requirements =:= DeclaredRequirements, authority,
            declared_requirement_mismatch, [<<"requirements">>], Checked,
            <<"declared requirements must equal the least inferred resource authority">>),
        ChildDescriptor = derive_child(Child, Checked),
        TaskLimits = trusted_limits(maps:get(<<"budgets">>, Semantic)),
        StaticBounds = infer_bounds(Actions, ChildDescriptor,
            maps:get(completion, Checked)),
        check_bounds(TaskLimits, StaticBounds, Checked),
        Manifest = #{
            format => alang_runtime_manifest_v2,
            effects => InferredEffects,
            requirements => Requirements,
            resources => trusted_scopes(Scopes),
            operations => operation_requirements(Actions, Requirements,
                ChildDescriptor)
        },
        {ok, #{
            format => alang_derived_semantics_v2,
            checked => Checked,
            manifest => Manifest,
            task_limits => TaskLimits,
            static_bounds => StaticBounds,
            child => ChildDescriptor
        }}
    catch
        throw:{authority_error, Diagnostic} -> {error, [Diagnostic]};
        _Class:_Reason ->
            {error, [diagnostic(authority, invalid_authority_input,
                default_origin(Checked), <<"invalid checked semantic input">>)]}
    end;
derive(_) ->
    {error, [diagnostic(authority, invalid_authority_input,
        default_origin(#{}), <<"expected alang_checked_semantics_v2">>)]}.

infer_effects(Actions) ->
    lists:usort([Effect || Action <- Actions,
        Effect <- operation_effect(maps:get(operation, Action))]).

operation_effect(<<"model.generate">>) -> [<<"model.generate">>];
operation_effect(<<"model.repair">>) -> [<<"model.generate">>];
operation_effect(<<"workspace.write">>) -> [<<"workspace.write">>];
operation_effect(<<"child.run">>) -> [<<"child.run">>];
operation_effect(<<"complete">>) -> [].

infer_requirements(Effects, Scopes, Child, Checked) ->
    Models = maps:get(<<"models">>, Scopes),
    Workspaces = maps:get(<<"workspaces">>, Scopes),
    Paths = maps:get(<<"paths">>, Scopes),
    DirectModel = lists:member(<<"model.generate">>, Effects),
    DirectWorkspace = lists:member(<<"workspace.write">>, Effects),
    ChildRequirements = case Child of
        none -> [];
        _ -> trusted_requirements(maps:get(<<"requirements">>, Child))
    end,
    ModelNeeded = DirectModel orelse has_requirement(model, ChildRequirements),
    WorkspaceNeeded = DirectWorkspace orelse
        has_requirement(workspace, ChildRequirements),
    check_resource_selector(model, Models, ModelNeeded, Checked),
    check_resource_selector(workspace, Workspaces, WorkspaceNeeded, Checked),
    ensure(DirectWorkspace orelse Paths =:= [], authority,
        unused_path_authority, [<<"scopes">>, <<"paths">>], Checked,
        <<"path scope is unused without workspace.write">>),
    ensure(not DirectWorkspace orelse Paths =/= [], authority,
        missing_workspace_path, [<<"scopes">>, <<"paths">>], Checked,
        <<"workspace.write requires at least one closed path selector">>),
    Direct =
        case DirectModel of
            true -> [#{kind => model, resource => Resource} || Resource <- Models];
            false -> []
        end ++
        case DirectWorkspace of
            true -> [#{kind => workspace, resource => Resource} ||
                Resource <- Workspaces];
            false -> []
        end,
    sort_maps(lists:usort(Direct ++ ChildRequirements)).

check_resource_selector(_Kind, [], false, _Checked) -> ok;
check_resource_selector(_Kind, [_Resource], true, _Checked) -> ok;
check_resource_selector(Kind, [], true, Checked) ->
    fail(authority, missing_resource_selector,
        [<<"scopes">>, scope_key(Kind)], Checked,
        <<"effect requires one statically selected resource">>);
check_resource_selector(Kind, _Resources, false, Checked) ->
    fail(authority, unused_resource_authority,
        [<<"scopes">>, scope_key(Kind)], Checked,
        <<"resource scope is not used by an operation or child">>);
check_resource_selector(Kind, _Resources, true, Checked) ->
    fail(authority, dynamic_resource_selector,
        [<<"scopes">>, scope_key(Kind)], Checked,
        <<"an operation must resolve to exactly one static resource">>).

scope_key(model) -> <<"models">>;
scope_key(workspace) -> <<"workspaces">>.

has_requirement(Kind, Requirements) ->
    lists:any(fun(Requirement) -> maps:get(kind, Requirement) =:= Kind end,
        Requirements).

derive_child(none, _Checked) -> none;
derive_child(Child, Checked) ->
    Effects = maps:get(<<"effects">>, Child),
    Scopes = maps:get(<<"scopes">>, Child),
    Requirements = trusted_requirements(maps:get(<<"requirements">>, Child)),
    Expected = child_requirements(Effects, Scopes, Checked),
    ensure(Requirements =:= Expected, attenuation,
        child_requirement_mismatch,
        [<<"child_attenuation">>, <<"requirements">>], Checked,
        <<"child requirements must equal its least inferred authority">>),
    Limits = trusted_limits(maps:get(<<"budgets">>, Child)),
    check_child_effect_limits(Effects, Limits, Checked),
    #{
        format => alang_child_descriptor_v2,
        effects => Effects,
        requirements => Requirements,
        resources => trusted_scopes(Scopes),
        limits => Limits
    }.

child_requirements(Effects, Scopes, Checked) ->
    Models = maps:get(<<"models">>, Scopes),
    Workspaces = maps:get(<<"workspaces">>, Scopes),
    Paths = maps:get(<<"paths">>, Scopes),
    HasModel = lists:member(<<"model.generate">>, Effects),
    HasWorkspace = lists:member(<<"workspace.write">>, Effects),
    check_child_selector(model, Models, HasModel, Checked),
    check_child_selector(workspace, Workspaces, HasWorkspace, Checked),
    ensure(HasWorkspace orelse Paths =:= [], attenuation,
        child_unused_path_authority,
        [<<"child_attenuation">>, <<"scopes">>, <<"paths">>], Checked,
        <<"child path scope is unused without workspace.write">>),
    ensure(not HasWorkspace orelse Paths =/= [], attenuation,
        child_missing_workspace_path,
        [<<"child_attenuation">>, <<"scopes">>, <<"paths">>], Checked,
        <<"child workspace.write requires a closed path selector">>),
    sort_maps(
        [#{kind => model, resource => Resource} ||
            HasModel, Resource <- Models] ++
        [#{kind => workspace, resource => Resource} ||
            HasWorkspace, Resource <- Workspaces]
    ).

check_child_selector(_Kind, [], false, _Checked) -> ok;
check_child_selector(_Kind, [_Resource], true, _Checked) -> ok;
check_child_selector(Kind, [], true, Checked) ->
    fail(attenuation, child_missing_resource_selector,
        [<<"child_attenuation">>, <<"scopes">>, scope_key(Kind)], Checked,
        <<"child effect requires one statically selected resource">>);
check_child_selector(Kind, _Resources, false, Checked) ->
    fail(attenuation, child_unused_resource_authority,
        [<<"child_attenuation">>, <<"scopes">>, scope_key(Kind)], Checked,
        <<"child resource scope is unused">>);
check_child_selector(Kind, _Resources, true, Checked) ->
    fail(attenuation, child_dynamic_resource_selector,
        [<<"child_attenuation">>, <<"scopes">>, scope_key(Kind)], Checked,
        <<"child operation must resolve to one static resource">>).

check_child_effect_limits(Effects, Limits, Checked) ->
    ModelMinimum = bool_int(lists:member(<<"model.generate">>, Effects)),
    WorkspaceMinimum = bool_int(lists:member(<<"workspace.write">>, Effects)),
    ensure(maps:get(model_calls, Limits) >= ModelMinimum, limit,
        child_model_limit_too_small,
        [<<"child_attenuation">>, <<"budgets">>, <<"model_calls">>],
        Checked, <<"child model call limit does not cover its effect">>),
    ensure(maps:get(workspace_writes, Limits) >= WorkspaceMinimum, limit,
        child_workspace_limit_too_small,
        [<<"child_attenuation">>, <<"budgets">>, <<"workspace_writes">>],
        Checked, <<"child workspace limit does not cover its effect">>),
    ensure(maps:get(model_calls, Limits) >= maps:get(repair_calls, Limits),
        limit, child_repair_limit_exceeds_model_limit,
        [<<"child_attenuation">>, <<"budgets">>, <<"repair_calls">>],
        Checked, <<"child repair calls must be included in model calls">>),
    ensure(maps:get(steps, Limits) >= length(Effects), limit,
        child_step_limit_too_small,
        [<<"child_attenuation">>, <<"budgets">>, <<"steps">>],
        Checked, <<"child step limit does not cover its closed effects">>).

infer_bounds(Actions, Child, Completion) ->
    DirectModel = count_operations(Actions,
        [<<"model.generate">>, <<"model.repair">>]),
    DirectRepair = count_operations(Actions, [<<"model.repair">>]),
    DirectChild = count_operations(Actions, [<<"child.run">>]),
    DirectWorkspace = count_operations(Actions, [<<"workspace.write">>]),
    ChildLimits = case Child of
        none -> zero_child_limits();
        _ -> maps:get(limits, Child)
    end,
    #{
        steps => length(Actions),
        model_calls => DirectModel + maps:get(model_calls, ChildLimits),
        repair_calls => DirectRepair + maps:get(repair_calls, ChildLimits),
        child_calls => DirectChild,
        workspace_writes => DirectWorkspace + maps:get(workspace_writes, ChildLimits),
        output_bytes => completion_byte_minimum(Completion),
        timeout_ms => 1
    }.

zero_child_limits() ->
    #{model_calls => 0, repair_calls => 0, workspace_writes => 0}.

count_operations(Actions, Operations) ->
    length([ok || Action <- Actions,
        lists:member(maps:get(operation, Action), Operations)]).

completion_byte_minimum(#{predicates := Predicates}) ->
    Values = [Expected || #{kind := <<"max-bytes">>, expected := Expected} <- Predicates],
    case Values of
        [] -> 1;
        _ -> lists:max(Values)
    end.

check_bounds(Limits, Bounds, Checked) ->
    lists:foreach(fun(Key) ->
        ensure(maps:get(Key, Limits) >= maps:get(Key, Bounds), limit,
            limit_below_static_bound, [<<"budgets">>, limit_binary(Key)],
            Checked,
            iolist_to_binary(io_lib:format(
                "~p limit is below the static upper bound", [Key]
            )))
    end, [steps, model_calls, repair_calls, child_calls,
        workspace_writes, output_bytes, timeout_ms]),
    ensure(maps:get(model_calls, Limits) >= maps:get(repair_calls, Limits),
        limit, repair_limit_exceeds_model_limit,
        [<<"budgets">>, <<"repair_calls">>], Checked,
        <<"repair calls must be included in model calls">>).

operation_requirements(Actions, Requirements, Child) ->
    Operations = lists:usort([maps:get(operation, Action) || Action <- Actions,
        maps:get(operation, Action) =/= <<"complete">>]),
    [#{
        semantic_operation => Operation,
        runtime_operation => runtime_operation(Operation),
        requirements => requirements_for_operation(Operation, Requirements, Child)
    } || Operation <- Operations].

runtime_operation(<<"model.generate">>) -> <<"model.complete">>;
runtime_operation(<<"model.repair">>) -> <<"model.complete">>;
runtime_operation(<<"workspace.write">>) -> <<"workspace.write">>;
runtime_operation(<<"child.run">>) -> <<"child.run">>.

requirements_for_operation(Operation, Requirements, _Child) when
    Operation =:= <<"model.generate">>; Operation =:= <<"model.repair">>
->
    [Requirement || #{kind := model} = Requirement <- Requirements];
requirements_for_operation(<<"workspace.write">>, Requirements, _Child) ->
    [Requirement || #{kind := workspace} = Requirement <- Requirements];
requirements_for_operation(<<"child.run">>, _Requirements, Child) ->
    maps:get(requirements, Child).

trusted_requirements(Requirements) ->
    sort_maps([#{
        kind => requirement_kind(maps:get(<<"kind">>, Requirement)),
        resource => maps:get(<<"resource">>, Requirement)
    } || Requirement <- Requirements]).

requirement_kind(<<"model">>) -> model;
requirement_kind(<<"workspace">>) -> workspace.

trusted_scopes(Scopes) ->
    #{
        models => maps:get(<<"models">>, Scopes),
        workspaces => maps:get(<<"workspaces">>, Scopes),
        paths => maps:get(<<"paths">>, Scopes)
    }.

trusted_limits(Limits) ->
    #{
        steps => maps:get(<<"steps">>, Limits),
        model_calls => maps:get(<<"model_calls">>, Limits),
        repair_calls => maps:get(<<"repair_calls">>, Limits),
        child_calls => maps:get(<<"child_calls">>, Limits),
        workspace_writes => maps:get(<<"workspace_writes">>, Limits),
        output_bytes => maps:get(<<"output_bytes">>, Limits),
        timeout_ms => maps:get(<<"timeout_ms">>, Limits)
    }.

limit_binary(steps) -> <<"steps">>;
limit_binary(model_calls) -> <<"model_calls">>;
limit_binary(repair_calls) -> <<"repair_calls">>;
limit_binary(child_calls) -> <<"child_calls">>;
limit_binary(workspace_writes) -> <<"workspace_writes">>;
limit_binary(output_bytes) -> <<"output_bytes">>;
limit_binary(timeout_ms) -> <<"timeout_ms">>.

bool_int(true) -> 1;
bool_int(false) -> 0.

sort_maps(List) ->
    lists:sort(fun(Left, Right) ->
        term_to_binary(Left, [deterministic]) =< term_to_binary(Right, [deterministic])
    end, List).

ensure(true, _Class, _Code, _Path, _Checked, _Message) -> ok;
ensure(false, Class, Code, Path, Checked, Message) ->
    fail(Class, Code, Path, Checked, Message).

fail(Class, Code, Path, Checked, Message) ->
    throw({authority_error, diagnostic(
        Class, Code, origin_for(Checked, pointer(Path)), Message
    )}).

origin_for(Checked, Pointer) ->
    Origins = maps:get(source_map, Checked, #{}),
    nearest_origin(Origins, Pointer, default_origin(Checked)).

nearest_origin(Origins, Pointer, Default) ->
    case maps:find(Pointer, Origins) of
        {ok, Origin} -> Origin;
        error when Pointer =:= <<>> -> Default;
        error -> nearest_origin(Origins, parent_pointer(Pointer), Default)
    end.

parent_pointer(Pointer) ->
    Segments = binary:split(Pointer, <<"/">>, [global]),
    ParentSegments = lists:sublist(Segments, length(Segments) - 1),
    iolist_to_binary(lists:join(<<"/">>, ParentSegments)).

pointer([]) -> <<>>;
pointer(Segments) ->
    iolist_to_binary([[<<"/">>, pointer_segment(Segment)] || Segment <- Segments]).

pointer_segment(Segment) when is_integer(Segment) -> integer_to_binary(Segment);
pointer_segment(Segment) -> Segment.

diagnostic(Class, Code, Origin, Message) ->
    #{class => Class, code => Code, severity => error, origin => Origin, message => Message}.

default_origin(#{frontend := typed_json}) ->
    #{source => typed_json, pointer => <<>>, byte => 0, kind => document};
default_origin(_) ->
    #{source => alang_source, byte => 0, line => 1, column => 1}.
