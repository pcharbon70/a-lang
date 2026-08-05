-module(alang_fidelity_semantics).

-export([check/1, check_control/1, check_source/1, digest/1, meaning/1]).

-spec check_source(binary()) -> {ok, map()} | {error, [map()]}.
check_source(Binary) ->
    check_decoded(alang_fidelity_source:decode(Binary)).

-spec check_control(binary()) -> {ok, map()} | {error, [map()]}.
check_control(Binary) ->
    check_decoded(alang_fidelity_control:decode(Binary)).

-spec check(map()) -> {ok, map()} | {error, [map()]}.
check(Input) when is_map(Input) ->
    try
        validate_input_envelope(Input),
        Semantic = maps:get(semantic, Input),
        validate_contract(Semantic, Input),
        CaseId = maps:get(case_id, Input),
        Normalized = normalize_semantic(CaseId, Semantic),
        Inputs = checked_inputs(CaseId, maps:get(<<"inputs">>, Normalized)),
        {TaskId, Actions, ActionMap} = check_actions(CaseId, Inputs,
            maps:get(<<"actions">>, Normalized), Input),
        Child = check_child(maps:get(<<"child_attenuation">>, Semantic),
            Actions, Input),
        Completion = check_completion(Semantic, ActionMap, Input),
        check_terminal(Semantic, Actions, Input),
        SemanticDigest = alang_fidelity_json:digest(Normalized),
        ensure(
            SemanticDigest =:= maps:get(semantic_digest, Input),
            control_boundary,
            semantic_digest_mismatch,
            [],
            Input,
            <<"frontend semantic digest does not match the checked meaning">>
        ),
        Checked = #{
            format => alang_checked_semantics_v2,
            case_id => CaseId,
            task_id => TaskId,
            inputs => Inputs,
            actions => Actions,
            child => Child,
            completion => Completion,
            terminal_class => maps:get(<<"terminal_class">>, Semantic),
            error_branches => maps:get(<<"error_branches">>, Normalized),
            semantic => Normalized,
            semantic_digest => SemanticDigest,
            call_graph => #{TaskId => []},
            frontend => maps:get(frontend, Input),
            source_digest => maps:get(source_digest, Input),
            source_map => maps:get(origins, Input)
        },
        {ok, Checked}
    catch
        throw:{semantic_error, Diagnostic} -> {error, [Diagnostic]};
        _Class:_Reason ->
            {error, [diagnostic(
                control_boundary,
                invalid_semantic_input,
                default_origin(Input),
                <<"invalid representation-neutral semantic input">>
            )]}
    end;
check(_) ->
    {error, [diagnostic(
        control_boundary,
        invalid_semantic_input,
        default_origin(#{}),
        <<"semantic input must be a map">>
    )]}.

-spec meaning(map()) -> map().
meaning(#{format := alang_checked_semantics_v2} = Checked) ->
    maps:with([
        format,
        case_id,
        task_id,
        inputs,
        actions,
        child,
        completion,
        terminal_class,
        error_branches,
        semantic,
        semantic_digest,
        call_graph
    ], Checked).

-spec digest(map()) -> binary().
digest(Checked) ->
    alang_fidelity_json:digest(meaning(Checked)).

check_decoded({ok, Input}) -> check(Input);
check_decoded({error, _} = Error) -> Error.

validate_input_envelope(Input) ->
    Keys = [format, frontend, case_id, semantic, semantic_digest,
        source_digest, origins],
    ensure(
        lists:sort(maps:keys(Input)) =:= lists:sort(Keys),
        control_boundary,
        invalid_semantic_input_shape,
        [],
        Input,
        <<"semantic input envelope has unknown or missing fields">>
    ),
    ensure(
        maps:get(format, Input) =:= alang_semantic_input_v2,
        control_boundary,
        invalid_semantic_input_version,
        [],
        Input,
        <<"expected alang_semantic_input_v2">>
    ),
    ensure(
        lists:member(maps:get(frontend, Input), [alang_source, typed_json]),
        control_boundary,
        unknown_frontend,
        [],
        Input,
        <<"frontend is outside the closed representation set">>
    ),
    ensure(is_binary(maps:get(case_id, Input)), name, invalid_task_name,
        [<<"@case-id">>], Input, <<"task identity must be binary">>),
    ensure(is_map(maps:get(semantic, Input)), control_boundary,
        invalid_semantic_task, [], Input, <<"semantic task must be a map">>),
    ensure(is_map(maps:get(origins, Input)), control_boundary,
        invalid_source_map, [], Input, <<"source map must be a map">>),
    ensure(valid_digest(maps:get(semantic_digest, Input)), control_boundary,
        invalid_semantic_digest, [], Input, <<"semantic digest must be lowercase SHA-256">>),
    ensure(valid_digest(maps:get(source_digest, Input)), control_boundary,
        invalid_source_digest, [], Input, <<"source digest must be lowercase SHA-256">>).

validate_contract(Semantic, Input) ->
    Comprehension = Semantic#{
        <<"format">> => <<"alang_task_comprehension_v1">>,
        <<"case_id">> => maps:get(case_id, Input)
    },
    case alang_fidelity_contract:validate_comprehension(Comprehension) of
        {ok, _} -> ok;
        {error, {contract_error, Path, Reason}} ->
            {Class, Code} = classify_contract(Path, Reason),
            fail(Class, Code, Path, Input, reason_message(Reason))
    end.

checked_inputs(CaseId, Inputs) ->
    [#{
        id => <<"binding:", CaseId/binary, ":input:", (maps:get(<<"name">>, Input))/binary>>,
        name => maps:get(<<"name">>, Input),
        type => checked_type(maps:get(<<"type">>, Input)),
        required => maps:get(<<"required">>, Input)
    } || Input <- Inputs].

checked_type(<<"text">>) -> binary;
checked_type(<<"json">>) -> json;
checked_type(<<"path">>) -> path;
checked_type(<<"model-profile">>) -> model_profile.

check_actions(CaseId, Inputs, SemanticActions, Input) ->
    TaskId = <<"task:", CaseId/binary, "/", (integer_to_binary(length(Inputs)))/binary>>,
    ActionMap = maps:from_list([
        {maps:get(<<"id">>, Action), Action} || Action <- SemanticActions
    ]),
    Complete = [Action || Action <- SemanticActions,
        maps:get(<<"operation">>, Action) =:= <<"complete">>],
    ensure(length(Complete) =:= 1, control, invalid_completion_action_count,
        [<<"actions">>], Input, <<"task must contain exactly one complete action">>),
    [CompleteAction] = Complete,
    ensure(CompleteAction =:= lists:last(SemanticActions), control,
        completion_action_not_last, action_path(SemanticActions, CompleteAction), Input,
        <<"the complete action must be last">>),
    Reachable = ancestors(maps:get(<<"id">>, CompleteAction), ActionMap, #{}),
    ensure(maps:size(Reachable) =:= length(SemanticActions), control,
        unreachable_action, [<<"actions">>], Input,
        <<"every action must reach the final complete action">>),
    Checked = [checked_action(TaskId, Action, Index) ||
        {Action, Index} <- indexed(SemanticActions)],
    {TaskId, Checked, maps:from_list([
        {maps:get(id, Action), Action} || Action <- Checked
    ])}.

checked_action(TaskId, Action, Index) ->
    Id = maps:get(<<"id">>, Action),
    Operation = maps:get(<<"operation">>, Action),
    #{
        id => Id,
        binding_id => <<"binding:", TaskId/binary, ":", Id/binary>>,
        ordinal => Index,
        operation => Operation,
        result_type => operation_type(Operation),
        depends_on => maps:get(<<"depends_on">>, Action)
    }.

operation_type(<<"model.generate">>) -> {result, binary, effect_error};
operation_type(<<"model.repair">>) -> {result, binary, effect_error};
operation_type(<<"workspace.write">>) -> {result, unit, effect_error};
operation_type(<<"child.run">>) -> {result, binary, child_error};
operation_type(<<"complete">>) -> terminal.

ancestors(Id, ActionMap, Seen) ->
    case maps:is_key(Id, Seen) of
        true -> Seen;
        false ->
            Action = maps:get(Id, ActionMap),
            lists:foldl(fun(Dependency, Acc) ->
                ancestors(Dependency, ActionMap, Acc)
            end, Seen#{Id => true}, maps:get(<<"depends_on">>, Action))
    end.

action_path(Actions, Target) ->
    [<<"actions">>, action_index(Actions, Target)].

action_index([Target | _], Target) -> 0;
action_index([_ | Rest], Target) -> 1 + action_index(Rest, Target).

check_child(null, Actions, Input) ->
    ensure(child_action_count(Actions) =:= 0, attenuation,
        missing_child_attenuation, [<<"child_attenuation">>], Input,
        <<"child.run requires one closed attenuation record">>),
    none;
check_child(Child, Actions, Input) ->
    ensure(child_action_count(Actions) =:= 1, attenuation,
        invalid_child_action_count, [<<"actions">>], Input,
        <<"one attenuation record requires exactly one child.run action">>),
    ensure(not lists:member(<<"child.run">>, maps:get(<<"effects">>, Child)),
        attenuation, recursive_child_authority,
        [<<"child_attenuation">>, <<"effects">>], Input,
        <<"child authority cannot include child.run at depth one">>),
    ChildBudgets = maps:get(<<"budgets">>, Child),
    ensure(maps:get(<<"child_calls">>, ChildBudgets) =:= 0,
        attenuation, recursive_child_budget,
        [<<"child_attenuation">>, <<"budgets">>, <<"child_calls">>], Input,
        <<"child call budget must be zero at the frozen depth">>),
    canonical_child(Child).

canonical_child(Child) ->
    Scopes = maps:get(<<"scopes">>, Child),
    Child#{
        <<"effects">> => lists:sort(maps:get(<<"effects">>, Child)),
        <<"requirements">> => sort_maps(maps:get(<<"requirements">>, Child)),
        <<"scopes">> => maps:map(fun(_Key, Values) -> lists:sort(Values) end, Scopes)
    }.

child_action_count(Actions) ->
    length([ok || #{operation := <<"child.run">>} <- Actions]).

check_completion(Semantic, ActionMap, Input) ->
    Predicates = maps:get(<<"completion_predicates">>, Semantic),
    Scopes = maps:get(<<"scopes">>, Semantic),
    Budgets = maps:get(<<"budgets">>, Semantic),
    Checked = [check_predicate(Predicate, Index, Scopes, Budgets,
        ActionMap, Input) || {Predicate, Index} <- indexed(Predicates)],
    #{predicates => sort_maps(Checked),
        terminal_class => maps:get(<<"terminal_class">>, Semantic)}.

check_predicate(Predicate, Index, Scopes, Budgets, ActionMap, Input) ->
    Kind = maps:get(<<"kind">>, Predicate),
    Target = maps:get(<<"target">>, Predicate),
    Base = [<<"completion_predicates">>, Index],
    case artifact_predicate(Kind) of
        true ->
            ensure(safe_workspace_path(Target), completion,
                unsafe_completion_path, Base ++ [<<"target">>], Input,
                <<"completion path must remain below /workspace">>),
            ensure(lists:member(Target, maps:get(<<"paths">>, Scopes)),
                completion, completion_path_outside_scope,
                Base ++ [<<"target">>], Input,
                <<"completion path is not present in the declared path scope">>),
            ensure(has_operation(<<"workspace.write">>, ActionMap), completion,
                completion_without_workspace_write, Base, Input,
                <<"artifact completion requires a workspace.write action">>);
        false -> ok
    end,
    case Kind of
        <<"journal-succeeded">> ->
            ensure(maps:is_key(Target, ActionMap), completion,
                unknown_completion_action, Base ++ [<<"target">>], Input,
                <<"journal completion target does not name an action">>),
            ensure(maps:get(operation, maps:get(Target, ActionMap)) =/= <<"complete">>,
                completion, invalid_completion_action,
                Base ++ [<<"target">>], Input,
                <<"journal completion target must be an effect or delegate action">>);
        <<"clarification-recorded">> ->
            ensure(valid_identifier(Target), completion,
                invalid_clarification_identity, Base ++ [<<"target">>], Input,
                <<"clarification target must be a closed identifier">>);
        <<"max-bytes">> ->
            ensure(maps:get(<<"expected">>, Predicate) =<
                maps:get(<<"output_bytes">>, Budgets), completion,
                completion_exceeds_output_limit, Base ++ [<<"expected">>], Input,
                <<"completion byte bound exceeds the task output limit">>);
        _ -> ok
    end,
    #{
        kind => Kind,
        target => Target,
        expected => maps:get(<<"expected">>, Predicate),
        expected_type => predicate_type(Kind)
    }.

artifact_predicate(Kind) ->
    lists:member(Kind, [<<"artifact-exists">>, <<"sha256">>, <<"max-bytes">>,
        <<"utf8">>, <<"markdown-h1">>]).

predicate_type(<<"sha256">>) -> binary;
predicate_type(<<"markdown-h1">>) -> binary;
predicate_type(<<"max-bytes">>) -> int;
predicate_type(_) -> bool.

has_operation(Operation, ActionMap) ->
    lists:any(fun(Action) -> maps:get(operation, Action) =:= Operation end,
        maps:values(ActionMap)).

check_terminal(Semantic, Actions, Input) ->
    Terminal = maps:get(<<"terminal_class">>, Semantic),
    Clarifications = maps:get(<<"clarification_needs">>, Semantic),
    case Terminal of
        <<"needs-clarification">> ->
            ensure(Clarifications =/= [], completion, missing_clarification,
                [<<"clarification_needs">>], Input,
                <<"needs-clarification requires at least one clarification">>),
            ensure(length(Actions) =:= 1 andalso
                maps:get(operation, hd(Actions)) =:= <<"complete">>,
                control, effects_before_clarification,
                [<<"actions">>], Input,
                <<"a clarification-only task cannot execute effects first">>);
        <<"complete">> ->
            ensure(Clarifications =:= [], completion,
                unexpected_clarification, [<<"clarification_needs">>], Input,
                <<"a complete task cannot retain unresolved clarifications">>);
        <<"failed">> -> ok
    end.

normalize_semantic(CaseId, Semantic) ->
    Comprehension = Semantic#{
        <<"format">> => <<"alang_task_comprehension_v1">>,
        <<"case_id">> => CaseId
    },
    alang_fidelity_contract:normalize(Comprehension).

safe_workspace_path(Path) when is_binary(Path), byte_size(Path) =< 4096 ->
    case Path of
        <<"/workspace/", Rest/binary>> when Rest =/= <<>> ->
            binary:match(Path, <<0>>) =:= nomatch andalso
            binary:match(Path, <<"\\">>) =:= nomatch andalso
            lists:all(fun valid_path_segment/1,
                binary:split(Rest, <<"/">>, [global]));
        _ -> false
    end;
safe_workspace_path(_) -> false.

valid_path_segment(Segment) ->
    Segment =/= <<>> andalso Segment =/= <<".">> andalso Segment =/= <<"..">>.

valid_identifier(Value) when is_binary(Value) ->
    re:run(Value, <<"^[a-z][a-z0-9-]{0,63}$">>, [{capture, none}]) =:= match;
valid_identifier(_) -> false.

valid_digest(Value) when is_binary(Value), byte_size(Value) =:= 64 ->
    re:run(Value, <<"^[0-9a-f]{64}$">>, [{capture, none}]) =:= match;
valid_digest(_) -> false.

classify_contract(Path, {not_in_closed_enum, _}) ->
    case Path of
        [] -> {control_boundary, value_outside_closed_set};
        _ -> case lists:last(Path) of
            <<"type">> -> {type, unknown_type};
            <<"operation">> -> {name, unknown_operation};
            _ -> {control_boundary, value_outside_closed_set}
        end
    end;
classify_contract(_Path, {dependency_not_prior, _}) -> {control, dependency_not_prior};
classify_contract(_Path, Reason) when Reason =:= child_effect_widens_authority;
    Reason =:= child_requirement_widens_authority;
    Reason =:= child_scope_widens_authority;
    Reason =:= child_budget_exceeds_parent -> {attenuation, Reason};
classify_contract(_Path, {resource_outside_scope, _, _}) -> {authority, resource_outside_scope};
classify_contract(_Path, duplicate_action_id) -> {name, duplicate_action};
classify_contract(_Path, duplicate_input_name) -> {name, duplicate_input};
classify_contract(_Path, duplicate_error_branch) -> {control, duplicate_error_branch};
classify_contract(_Path, duplicate_completion_predicate) ->
    {completion, duplicate_completion_predicate};
classify_contract(_Path, required_for_terminal_class) -> {completion, missing_clarification};
classify_contract(_Path, Reason) when is_atom(Reason) -> {control_boundary, Reason};
classify_contract(_Path, _Reason) -> {control_boundary, schema_violation}.

ensure(true, _Class, _Code, _Path, _Input, _Message) -> ok;
ensure(false, Class, Code, Path, Input, Message) ->
    fail(Class, Code, Path, Input, Message).

fail(Class, Code, Path, Input, Message) ->
    throw({semantic_error, diagnostic(
        Class, Code, origin_for(Input, pointer(Path)), Message
    )}).

origin_for(Input, Pointer) ->
    Origins = maps:get(origins, Input, #{}),
    nearest_origin(Origins, Pointer, default_origin(Input)).

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

indexed(List) ->
    lists:zip(List, lists:seq(0, length(List) - 1)).

sort_maps(List) ->
    lists:sort(fun(Left, Right) ->
        term_to_binary(Left, [deterministic]) =< term_to_binary(Right, [deterministic])
    end, List).

reason_message(Reason) ->
    iolist_to_binary(io_lib:format("~tp", [Reason])).

diagnostic(Class, Code, Origin, Message) ->
    #{class => Class, code => Code, severity => error, origin => Origin, message => Message}.

default_origin(#{frontend := typed_json}) ->
    #{source => typed_json, pointer => <<>>, byte => 0, kind => document};
default_origin(_) ->
    #{source => alang_source, byte => 0, line => 1, column => 1}.
