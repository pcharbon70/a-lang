-module(alang_fidelity_ast).

-export([validate/1]).

-define(MAX_LIST_ITEMS, 64).
-define(MAX_ACTIONS, 16).
-define(MAX_IDENTIFIER_BYTES, 128).
-define(MAX_STRING_BYTES, 4096).

-spec validate(map()) -> {ok, map()} | {error, [map()]}.
validate(Ast) ->
    try
        validate_document(Ast),
        {ok, Ast}
    catch
        throw:{ast_error, Diagnostic} -> {error, [Diagnostic]};
        _Class:_Reason ->
            {error, [diagnostic(invalid_ast_shape, default_origin(), <<"invalid alang_source_ast_v2 shape">>)]}
    end.

validate_document(Ast) ->
    exact_map(Ast, [format, kind, version, task, origin]),
    ensure(maps:get(format, Ast) =:= alang_source_ast_v2, invalid_ast_format, origin_of(Ast), <<"expected alang_source_ast_v2">>),
    ensure(maps:get(kind, Ast) =:= task_document, invalid_ast_kind, origin_of(Ast), <<"expected task_document">>),
    ensure(maps:get(version, Ast) =:= <<"alang-source-v2">>, invalid_ast_version, origin_of(Ast), <<"expected alang-source-v2">>),
    validate_origin(maps:get(origin, Ast)),
    validate_task(maps:get(task, Ast)).

validate_task(Task) ->
    exact_map(Task, [
        kind,
        name,
        name_origin,
        facts,
        inputs,
        effects,
        requirements,
        scopes,
        limits,
        steps,
        on_error,
        child,
        completion,
        clarify,
        terminal,
        origin
    ]),
    ensure(maps:get(kind, Task) =:= task, invalid_ast_kind, origin_of(Task), <<"expected task node">>),
    validate_identifier(maps:get(name, Task), maps:get(name_origin, Task)),
    validate_origin(maps:get(name_origin, Task)),
    validate_origin(maps:get(origin, Task)),
    validate_facts(maps:get(facts, Task)),
    Inputs = maps:get(inputs, Task),
    validate_list(Inputs, 1, 16, fun validate_input/1, origin_of(Task), input_bound_exceeded),
    ensure_unique(Inputs, fun(Node) -> maps:get(name, Node) end, duplicate_input, origin_of(Task)),
    validate_effects(maps:get(effects, Task)),
    validate_requirements(maps:get(requirements, Task)),
    validate_scopes(maps:get(scopes, Task)),
    validate_limits(maps:get(limits, Task)),
    Steps = maps:get(steps, Task),
    validate_list(Steps, 1, ?MAX_ACTIONS, fun validate_step/1, origin_of(Task), action_bound_exceeded),
    ensure_unique(Steps, fun(Node) -> maps:get(name, Node) end, duplicate_step, origin_of(Task)),
    validate_error_branches(maps:get(on_error, Task)),
    validate_child(maps:get(child, Task)),
    validate_completion(maps:get(completion, Task)),
    validate_clarification(maps:get(clarify, Task)),
    validate_terminal(maps:get(terminal, Task)).

validate_facts(Node) ->
    exact_map(Node, [kind, values, origin]),
    ensure(maps:get(kind, Node) =:= facts, invalid_ast_kind, origin_of(Node), <<"expected facts node">>),
    validate_origin(maps:get(origin, Node)),
    validate_list(maps:get(values, Node), 1, 16, fun validate_string_node/1, origin_of(Node), fact_bound_exceeded).

validate_input(Node) ->
    exact_map(Node, [kind, name, name_origin, type, type_origin, required, required_origin, origin]),
    ensure(maps:get(kind, Node) =:= input, invalid_ast_kind, origin_of(Node), <<"expected input node">>),
    validate_identifier(maps:get(name, Node), maps:get(name_origin, Node)),
    Type = maps:get(type, Node),
    ensure(
        lists:member(Type, [<<"bool">>, <<"json">>, <<"model-profile">>, <<"nat">>, <<"path">>, <<"text">>]),
        invalid_input_type,
        maps:get(type_origin, Node),
        <<"input type is outside the frozen set">>
    ),
    ensure(is_boolean(maps:get(required, Node)), invalid_requiredness, maps:get(required_origin, Node), <<"required must be boolean">>),
    validate_origins(Node, [name_origin, type_origin, required_origin, origin]).

validate_effects(Node) ->
    exact_map(Node, [kind, values, origin]),
    ensure(maps:get(kind, Node) =:= effects, invalid_ast_kind, origin_of(Node), <<"expected effects node">>),
    Values = maps:get(values, Node),
    validate_list(Values, 0, 3, fun validate_effect/1, origin_of(Node), effect_bound_exceeded),
    ensure_unique(Values, fun(Item) -> maps:get(name, Item) end, duplicate_effect, origin_of(Node)),
    validate_origin(maps:get(origin, Node)).

validate_effect(Node) ->
    exact_map(Node, [kind, name, origin]),
    ensure(maps:get(kind, Node) =:= effect, invalid_ast_kind, origin_of(Node), <<"expected effect node">>),
    ensure(
        lists:member(maps:get(name, Node), [<<"child.run">>, <<"model.generate">>, <<"workspace.write">>]),
        unknown_effect,
        origin_of(Node),
        <<"effect is outside the frozen set">>
    ),
    validate_origin(maps:get(origin, Node)).

validate_requirements(Node) ->
    exact_map(Node, [kind, values, origin]),
    ensure(maps:get(kind, Node) =:= requirements, invalid_ast_kind, origin_of(Node), <<"expected requirements node">>),
    Values = maps:get(values, Node),
    validate_list(Values, 0, 16, fun validate_requirement/1, origin_of(Node), requirement_bound_exceeded),
    ensure_unique(
        Values,
        fun(Item) -> {maps:get(resource_kind, Item), maps:get(resource, Item)} end,
        duplicate_requirement,
        origin_of(Node)
    ),
    validate_origin(maps:get(origin, Node)).

validate_requirement(Node) ->
    exact_map(Node, [kind, resource_kind, resource, resource_origin, origin]),
    ensure(maps:get(kind, Node) =:= requirement, invalid_ast_kind, origin_of(Node), <<"expected requirement node">>),
    ensure(
        lists:member(maps:get(resource_kind, Node), [<<"model">>, <<"workspace">>]),
        unknown_requirement_kind,
        origin_of(Node),
        <<"requirement kind is outside the frozen set">>
    ),
    validate_identifier(maps:get(resource, Node), maps:get(resource_origin, Node)),
    validate_origins(Node, [resource_origin, origin]).

validate_scopes(Node) ->
    exact_map(Node, [kind, models, workspaces, paths, origin]),
    ensure(maps:get(kind, Node) =:= scopes, invalid_ast_kind, origin_of(Node), <<"expected scopes node">>),
    validate_scope_field(maps:get(models, Node), <<"models">>, identifier),
    validate_scope_field(maps:get(workspaces, Node), <<"workspaces">>, identifier),
    validate_scope_field(maps:get(paths, Node), <<"paths">>, path),
    validate_origin(maps:get(origin, Node)).

validate_scope_field(Node, Name, ValueKind) ->
    exact_map(Node, [kind, name, values, origin]),
    ensure(maps:get(kind, Node) =:= scope_field, invalid_ast_kind, origin_of(Node), <<"expected scope field">>),
    ensure(maps:get(name, Node) =:= Name, invalid_scope_field, origin_of(Node), <<"scope field name does not match its position">>),
    Validator = case ValueKind of
        identifier -> fun validate_identifier_node/1;
        path -> fun validate_path_node/1
    end,
    Values = maps:get(values, Node),
    validate_list(Values, 0, 16, Validator, origin_of(Node), scope_bound_exceeded),
    ensure_unique(Values, fun(Item) -> maps:get(value, Item) end, duplicate_scope_value, origin_of(Node)),
    validate_origin(maps:get(origin, Node)).

validate_limits(Node) ->
    exact_map(Node, [kind, values, origin]),
    ensure(maps:get(kind, Node) =:= limits, invalid_ast_kind, origin_of(Node), <<"expected limits node">>),
    Values = maps:get(values, Node),
    validate_list(Values, 7, 7, fun validate_limit/1, origin_of(Node), invalid_limit_count),
    ensure_unique(Values, fun(Item) -> maps:get(name, Item) end, duplicate_limit, origin_of(Node)),
    Names = lists:sort([maps:get(name, Item) || Item <- Values]),
    ensure(Names =:= lists:sort(limit_names()), missing_limit, origin_of(Node), <<"limits must contain the seven frozen fields">>),
    validate_origin(maps:get(origin, Node)).

validate_limit(Node) ->
    exact_map(Node, [kind, name, value, value_origin, origin]),
    ensure(maps:get(kind, Node) =:= limit, invalid_ast_kind, origin_of(Node), <<"expected limit node">>),
    Name = maps:get(name, Node),
    Value = maps:get(value, Node),
    {Minimum, Maximum} = limit_range(Name, origin_of(Node)),
    ensure(is_integer(Value) andalso Value >= Minimum andalso Value =< Maximum, limit_out_of_range, maps:get(value_origin, Node), <<"limit is outside its frozen range">>),
    validate_origins(Node, [value_origin, origin]).

validate_step(Node) ->
    exact_map(Node, [kind, name, name_origin, operation, operation_origin, depends_on, origin]),
    ensure(maps:get(kind, Node) =:= step, invalid_ast_kind, origin_of(Node), <<"expected step node">>),
    validate_identifier(maps:get(name, Node), maps:get(name_origin, Node)),
    ensure(
        lists:member(maps:get(operation, Node), [<<"child.run">>, <<"complete">>, <<"model.generate">>, <<"model.repair">>, <<"workspace.write">>]),
        unknown_operation,
        maps:get(operation_origin, Node),
        <<"step operation is outside the frozen set">>
    ),
    Dependencies = maps:get(depends_on, Node),
    validate_list(Dependencies, 0, ?MAX_ACTIONS, fun validate_identifier_node/1, origin_of(Node), dependency_bound_exceeded),
    ensure_unique(Dependencies, fun(Item) -> maps:get(value, Item) end, duplicate_dependency, origin_of(Node)),
    validate_origins(Node, [name_origin, operation_origin, origin]).

validate_error_branches(Node) ->
    exact_map(Node, [kind, values, origin]),
    ensure(maps:get(kind, Node) =:= error_branches, invalid_ast_kind, origin_of(Node), <<"expected error_branches node">>),
    Values = maps:get(values, Node),
    validate_list(Values, 0, 16, fun validate_error_branch/1, origin_of(Node), error_branch_bound_exceeded),
    ensure_unique(
        Values,
        fun(Item) -> {maps:get(action, Item), maps:get(reason, Item)} end,
        duplicate_error_branch,
        origin_of(Node)
    ),
    validate_origin(maps:get(origin, Node)).

validate_error_branch(Node) ->
    exact_map(Node, [kind, action, reason, terminal_class, reason_origin, terminal_origin, origin]),
    ensure(maps:get(kind, Node) =:= error_branch, invalid_ast_kind, origin_of(Node), <<"expected error branch">>),
    validate_identifier(maps:get(action, Node), origin_of(Node)),
    ensure(
        lists:member(maps:get(reason, Node), [<<"denied">>, <<"invalid-output">>, <<"timeout">>]),
        unknown_error_reason,
        maps:get(reason_origin, Node),
        <<"error reason is outside the frozen set">>
    ),
    ensure(maps:get(terminal_class, Node) =:= <<"failed">>, invalid_error_terminal, maps:get(terminal_origin, Node), <<"error branch must terminate as failed">>),
    validate_origins(Node, [reason_origin, terminal_origin, origin]).

validate_child(#{value := none} = Node) ->
    exact_map(Node, [kind, value, value_origin, origin]),
    ensure(maps:get(kind, Node) =:= child, invalid_ast_kind, origin_of(Node), <<"expected child node">>),
    validate_origins(Node, [value_origin, origin]);
validate_child(#{value := attenuation} = Node) ->
    exact_map(Node, [kind, value, effects, requirements, scopes, limits, origin]),
    ensure(maps:get(kind, Node) =:= child, invalid_ast_kind, origin_of(Node), <<"expected child node">>),
    validate_effects(maps:get(effects, Node)),
    validate_requirements(maps:get(requirements, Node)),
    validate_scopes(maps:get(scopes, Node)),
    validate_limits(maps:get(limits, Node)),
    validate_origin(maps:get(origin, Node));
validate_child(Node) ->
    fail(invalid_child_shape, origin_of(Node), <<"child must be none or one attenuation record">>).

validate_completion(Node) ->
    exact_map(Node, [kind, predicates, origin]),
    ensure(maps:get(kind, Node) =:= completion, invalid_ast_kind, origin_of(Node), <<"expected completion node">>),
    Predicates = maps:get(predicates, Node),
    validate_list(Predicates, 1, 16, fun validate_completion_predicate/1, origin_of(Node), completion_bound_exceeded),
    ensure_unique(
        Predicates,
        fun(Item) -> {maps:get(predicate, Item), maps:get(target, Item)} end,
        duplicate_completion_predicate,
        origin_of(Node)
    ),
    validate_origin(maps:get(origin, Node)).

validate_completion_predicate(Node) ->
    exact_map(Node, [
        kind,
        predicate,
        target,
        expected,
        expected_type,
        target_origin,
        expected_origin,
        origin
    ]),
    ensure(maps:get(kind, Node) =:= completion_predicate, invalid_ast_kind, origin_of(Node), <<"expected completion predicate">>),
    Predicate = maps:get(predicate, Node),
    Target = maps:get(target, Node),
    validate_predicate_target(Predicate, Target, maps:get(target_origin, Node)),
    validate_predicate_expected(Predicate, maps:get(expected, Node), maps:get(expected_type, Node), maps:get(expected_origin, Node)),
    validate_origins(Node, [target_origin, expected_origin, origin]).

validate_predicate_target(Predicate, Target, Origin) when
    Predicate =:= <<"artifact-exists">>;
    Predicate =:= <<"markdown-h1">>;
    Predicate =:= <<"max-bytes">>;
    Predicate =:= <<"utf8">>
->
    ensure(safe_workspace_path(Target), unsafe_completion_path, Origin, <<"completion path must remain below /workspace">>);
validate_predicate_target(<<"journal-succeeded">>, Target, Origin) ->
    validate_identifier(Target, Origin);
validate_predicate_target(<<"clarification-recorded">>, Target, Origin) ->
    validate_identifier(Target, Origin);
validate_predicate_target(_Predicate, _Target, Origin) ->
    fail(unknown_completion_predicate, Origin, <<"completion predicate is outside the frozen set">>).

validate_predicate_expected(Predicate, Value, boolean, Origin) when
    Predicate =:= <<"artifact-exists">>;
    Predicate =:= <<"clarification-recorded">>;
    Predicate =:= <<"journal-succeeded">>;
    Predicate =:= <<"utf8">>
->
    ensure(is_boolean(Value), invalid_completion_expected_type, Origin, <<"completion predicate expects boolean">>);
validate_predicate_expected(<<"markdown-h1">>, Value, string, Origin) ->
    validate_string(Value, Origin, false);
validate_predicate_expected(<<"max-bytes">>, Value, integer, Origin) ->
    ensure(is_integer(Value) andalso Value >= 1 andalso Value =< 8192, invalid_completion_expected, Origin, <<"max-bytes must be within 1..8192">>);
validate_predicate_expected(_Predicate, _Value, _Type, Origin) ->
    fail(invalid_completion_expected_type, Origin, <<"completion predicate expected value does not match its type">>).

validate_clarification(Node) ->
    exact_map(Node, [kind, values, origin]),
    ensure(maps:get(kind, Node) =:= clarification_needs, invalid_ast_kind, origin_of(Node), <<"expected clarification_needs node">>),
    validate_list(maps:get(values, Node), 0, 16, fun validate_string_node/1, origin_of(Node), clarification_bound_exceeded),
    validate_origin(maps:get(origin, Node)).

validate_terminal(Node) ->
    exact_map(Node, [kind, class, class_origin, origin]),
    ensure(maps:get(kind, Node) =:= terminal, invalid_ast_kind, origin_of(Node), <<"expected terminal node">>),
    ensure(
        lists:member(maps:get(class, Node), [<<"complete">>, <<"failed">>, <<"needs-clarification">>]),
        unknown_terminal_class,
        maps:get(class_origin, Node),
        <<"terminal class is outside the frozen set">>
    ),
    validate_origins(Node, [class_origin, origin]).

validate_string_node(Node) ->
    exact_map(Node, [kind, value, origin]),
    ensure(maps:get(kind, Node) =:= string_literal, invalid_ast_kind, origin_of(Node), <<"expected string literal node">>),
    validate_string(maps:get(value, Node), origin_of(Node), false),
    validate_origin(maps:get(origin, Node)).

validate_identifier_node(Node) ->
    exact_map(Node, [kind, value, origin]),
    ensure(maps:get(kind, Node) =:= identifier, invalid_ast_kind, origin_of(Node), <<"expected identifier node">>),
    validate_identifier(maps:get(value, Node), origin_of(Node)),
    validate_origin(maps:get(origin, Node)).

validate_path_node(Node) ->
    exact_map(Node, [kind, value, origin]),
    ensure(maps:get(kind, Node) =:= string_literal, invalid_ast_kind, origin_of(Node), <<"expected path string node">>),
    ensure(safe_workspace_path(maps:get(value, Node)), unsafe_scope_path, origin_of(Node), <<"scope path must remain below /workspace">>),
    validate_origin(maps:get(origin, Node)).

validate_identifier(Value, Origin) ->
    ensure(is_binary(Value), invalid_identifier, Origin, <<"identifier must be binary">>),
    Size = byte_size(Value),
    ensure(Size >= 1 andalso Size =< ?MAX_IDENTIFIER_BYTES, invalid_identifier, Origin, <<"identifier length is out of bounds">>),
    ensure(valid_identifier_bytes(binary_to_list(Value)), invalid_identifier, Origin, <<"identifier contains unsupported bytes">>).

valid_identifier_bytes([First | Rest]) when
    (First >= $a andalso First =< $z) orelse
        (First >= $A andalso First =< $Z) orelse
        First =:= $_
->
    lists:all(fun(C) ->
        (C >= $a andalso C =< $z) orelse
            (C >= $A andalso C =< $Z) orelse
            (C >= $0 andalso C =< $9) orelse
            C =:= $_ orelse
            C =:= $-
    end, Rest);
valid_identifier_bytes(_) -> false.

validate_string(Value, Origin, AllowEmpty) ->
    ensure(is_binary(Value), invalid_string, Origin, <<"string must be binary">>),
    Size = byte_size(Value),
    ensure((AllowEmpty orelse Size > 0) andalso Size =< ?MAX_STRING_BYTES, invalid_string, Origin, <<"string length is out of bounds">>),
    ensure(valid_utf8(Value), invalid_utf8, Origin, <<"string is not valid UTF-8">>).

safe_workspace_path(Value) when is_binary(Value), byte_size(Value) =< ?MAX_STRING_BYTES ->
    case Value of
        <<"/workspace/", Rest/binary>> when byte_size(Rest) > 0 ->
            binary:match(Rest, <<"..">>) =:= nomatch andalso
                binary:match(Rest, <<"//">>) =:= nomatch andalso
                binary:match(Rest, <<"\\">>) =:= nomatch andalso
                binary:match(Rest, <<0>>) =:= nomatch andalso
                valid_utf8(Value);
        _ -> false
    end;
safe_workspace_path(_) -> false.

valid_utf8(Binary) ->
    case unicode:characters_to_binary(Binary, utf8, utf8) of
        Binary -> true;
        _ -> false
    end.

validate_list(List, Minimum, Maximum, Validator, Origin, Code) ->
    ensure(is_list(List), invalid_ast_shape, Origin, <<"AST collection must be a list">>),
    Length = length(List),
    ensure(Length >= Minimum andalso Length =< Maximum andalso Length =< ?MAX_LIST_ITEMS, Code, Origin, <<"AST collection length is out of bounds">>),
    lists:foreach(Validator, List).

ensure_unique(List, KeyFun, Code, Origin) ->
    ensure_unique(List, KeyFun, Code, Origin, #{}).

ensure_unique([], _KeyFun, _Code, _Origin, _Seen) -> ok;
ensure_unique([Item | Rest], KeyFun, Code, Origin, Seen) ->
    Key = KeyFun(Item),
    ensure(not maps:is_key(Key, Seen), Code, origin_of(Item, Origin), <<"AST collection contains a duplicate value">>),
    ensure_unique(Rest, KeyFun, Code, Origin, Seen#{Key => true}).

exact_map(Map, Keys) when is_map(Map) ->
    ensure(lists:sort(maps:keys(Map)) =:= lists:sort(Keys), invalid_ast_shape, origin_of(Map), <<"AST node fields are not exact">>);
exact_map(_Value, _Keys) ->
    fail(invalid_ast_shape, default_origin(), <<"AST node must be a map">>).

validate_origins(_Node, []) -> ok;
validate_origins(Node, [Key | Rest]) ->
    validate_origin(maps:get(Key, Node)),
    validate_origins(Node, Rest).

validate_origin(Origin) when is_map(Origin) ->
    exact_map_origin(Origin),
    Byte = maps:get(byte, Origin),
    Line = maps:get(line, Origin),
    Column = maps:get(column, Origin),
    ensure(
        is_integer(Byte) andalso Byte >= 0 andalso Byte =< 8192 andalso
            is_integer(Line) andalso Line >= 1 andalso
            is_integer(Column) andalso Column >= 1,
        invalid_origin,
        default_origin(),
        <<"origin is outside source bounds">>
    );
validate_origin(_) ->
    fail(invalid_origin, default_origin(), <<"origin must be a byte/line/column map">>).

exact_map_origin(Origin) ->
    ensure(lists:sort(maps:keys(Origin)) =:= [byte, column, line], invalid_origin, default_origin(), <<"origin fields are not exact">>).

limit_names() ->
    [<<"steps">>, <<"model-calls">>, <<"repair-calls">>, <<"child-calls">>, <<"workspace-writes">>, <<"output-bytes">>, <<"timeout-ms">>].

limit_range(<<"steps">>, _Origin) -> {1, 64};
limit_range(<<"model-calls">>, _Origin) -> {0, 8};
limit_range(<<"repair-calls">>, _Origin) -> {0, 4};
limit_range(<<"child-calls">>, _Origin) -> {0, 8};
limit_range(<<"workspace-writes">>, _Origin) -> {0, 8};
limit_range(<<"output-bytes">>, _Origin) -> {1, 8192};
limit_range(<<"timeout-ms">>, _Origin) -> {1, 120000};
limit_range(_Name, Origin) -> fail(unknown_limit, Origin, <<"limit is outside the frozen set">>).

origin_of(Map) -> origin_of(Map, default_origin()).

origin_of(Map, Default) when is_map(Map) -> maps:get(origin, Map, Default);
origin_of(_Value, Default) -> Default.

ensure(true, _Code, _Origin, _Message) -> ok;
ensure(false, Code, Origin, Message) -> fail(Code, Origin, Message).

fail(Code, Origin, Message) ->
    throw({ast_error, diagnostic(Code, Origin, Message)}).

diagnostic(Code, Origin, Message) ->
    #{code => Code, severity => error, origin => Origin, message => Message}.

default_origin() ->
    #{byte => 0, line => 1, column => 1}.
