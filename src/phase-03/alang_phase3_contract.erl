-module(alang_phase3_contract).

-export([
    allowed_abstract_forms/0,
    allowed_node_kinds/0,
    allowed_runtime_calls/0,
    compile_error/3,
    evaluation_order/0,
    runtime_error/2,
    validate_ir/1,
    validate_value/2,
    wrap_value/2
]).

-define(MAX_CALLABLES, 16).
-define(MAX_NODES, 256).
-define(MAX_BINARY_BYTES, 65536).
-define(MAX_PRODUCT_WIDTH, 16).
-define(MIN_INT, -9223372036854775808).
-define(MAX_INT, 9223372036854775807).

-spec allowed_node_kinds() -> [atom()].
allowed_node_kinds() ->
    [
        literal,
        input,
        result,
        add,
        equal,
        product,
        project,
        ok,
        error,
        bind,
        match_result,
        apply,
        sequence,
        effect_request,
        verify
    ].

-spec allowed_abstract_forms() -> [atom()].
allowed_abstract_forms() ->
    [
        attribute,
        function,
        clause,
        var,
        atom,
        integer,
        string,
        nil,
        cons,
        tuple,
        map,
        call,
        local_call,
        'case',
        'receive',
        match,
        op
    ].

-spec allowed_runtime_calls() -> [{module(), atom(), arity()}].
allowed_runtime_calls() ->
    [
        {alang_phase3_abi, request_effect, 5},
        {erlang, '+', 2},
        {erlang, '=:=', 2},
        {erlang, element, 2},
        {erlang, is_boolean, 1},
        {erlang, is_integer, 1},
        {erlang, is_tuple, 1},
        {erlang, map_get, 2},
        {erlang, self, 0}
    ].

-spec evaluation_order() -> [atom()].
evaluation_order() ->
    [
        evaluate_arguments_left_to_right,
        propagate_tagged_error_before_next_step,
        suspend_only_at_effect_request,
        observe_deadline_before_and_after_effect,
        evaluate_verifier_after_result,
        contain_exception_as_runtime_failure
    ].

-spec wrap_value(term(), term()) -> {ok, term()} | {error, term()}.
wrap_value(int, Value) when is_integer(Value), Value >= ?MIN_INT, Value =< ?MAX_INT ->
    {ok, Value};
wrap_value(bool, Value) when is_boolean(Value) ->
    {ok, Value};
wrap_value(binary, Value) when is_binary(Value), byte_size(Value) =< ?MAX_BINARY_BYTES ->
    {ok, Value};
wrap_value({product, Types}, Values) when
    is_list(Types),
    is_list(Values),
    length(Types) =:= length(Values),
    length(Types) =< ?MAX_PRODUCT_WIDTH
->
    case wrap_values(Types, Values, []) of
        {ok, Encoded} -> {ok, {alang_data_v1, product, list_to_tuple(Encoded)}};
        {error, _} = Error -> Error
    end;
wrap_value({result, OkType, _ErrorType}, {ok, Value}) ->
    case wrap_value(OkType, Value) of
        {ok, Encoded} -> {ok, {alang_data_v1, ok, Encoded}};
        {error, _} = Error -> Error
    end;
wrap_value({result, _OkType, ErrorType}, {error, Value}) ->
    case wrap_value(ErrorType, Value) of
        {ok, Encoded} -> {ok, {alang_data_v1, error, Encoded}};
        {error, _} = Error -> Error
    end;
wrap_value({opaque, TypeId}, {opaque, TypeId, Reference}) when
    is_binary(TypeId), byte_size(TypeId) > 0, byte_size(TypeId) =< 128, is_reference(Reference)
->
    {ok, {alang_opaque_v1, TypeId, Reference}};
wrap_value(Type, Value) ->
    {error, {invalid_value_representation, Type, summarize(Value)}}.

-spec validate_value(term(), term()) -> ok | {error, term()}.
validate_value(Type, Encoded) ->
    case unwrap_value(Type, Encoded) of
        {ok, _Value} -> ok;
        {error, _} = Error -> Error
    end.

-spec compile_error(atom(), binary(), map()) -> tuple().
compile_error(Code, NodeId, Origin) when is_atom(Code), is_binary(NodeId), is_map(Origin) ->
    {alang_compile_error_v1, Code, NodeId, origin_tuple(Origin)}.

-spec runtime_error(atom(), map()) -> tuple().
runtime_error(Code, Origin) when is_atom(Code), is_map(Origin) ->
    {alang_runtime_error_v1, Code, origin_tuple(Origin)}.

-spec validate_ir(map()) -> ok | {error, [tuple()]}.
validate_ir(#{
    format := alang_typed_task_ir_v1,
    module := ModuleName,
    tasks := Tasks,
    nodes := Nodes
}) when
    is_binary(ModuleName),
    byte_size(ModuleName) > 0,
    byte_size(ModuleName) =< 128,
    is_list(Tasks),
    Tasks =/= [],
    length(Tasks) =< ?MAX_CALLABLES,
    is_list(Nodes),
    Nodes =/= [],
    length(Nodes) =< ?MAX_NODES
->
    validate_graph(Tasks, Nodes);
validate_ir(#{format := Format}) when Format =/= alang_typed_task_ir_v1 ->
    {error, [compile_error(unsupported_ir_version, <<"module">>, default_origin())]};
validate_ir(_) ->
    {error, [compile_error(invalid_ir_shape, <<"module">>, default_origin())]}.

validate_graph(Tasks, Nodes) ->
    NodeIds = [maps:get(id, Node, undefined) || Node <- Nodes],
    NodeMap = maps:from_list([{maps:get(id, Node, undefined), Node} || Node <- Nodes]),
    case length(NodeIds) =:= maps:size(NodeMap) andalso lists:all(fun valid_identity/1, NodeIds) of
        false ->
            {error, [compile_error(invalid_node_identity, <<"module">>, default_origin())]};
        true ->
            Errors = validate_tasks(Tasks, NodeMap) ++ validate_nodes(Nodes, NodeMap),
            case Errors of
                [] -> ok;
                _ -> {error, Errors}
            end
    end.

validate_tasks(Tasks, NodeMap) ->
    lists:append([validate_task(Task, NodeMap) || Task <- Tasks]).

validate_task(#{
    id := TaskId,
    parameters := Parameters,
    result_type := ResultType,
    effects := Effects,
    requirements := Requirements,
    body_root := BodyRoot,
    completion_root := CompletionRoot,
    origin := Origin
}, NodeMap) when
    is_binary(TaskId),
    is_list(Parameters),
    length(Parameters) =< 16,
    is_list(Effects),
    is_list(Requirements),
    is_binary(BodyRoot),
    is_binary(CompletionRoot),
    is_map(Origin)
->
    RootErrors =
        missing_reference_errors(TaskId, Origin, [BodyRoot, CompletionRoot], NodeMap),
    TypeErrors =
        case valid_type(ResultType) andalso lists:all(fun valid_parameter/1, Parameters) of
            true -> [];
            false -> [compile_error(invalid_task_signature, TaskId, Origin)]
        end,
    CompletionErrors =
        case maps:find(CompletionRoot, NodeMap) of
            {ok, #{kind := verify, type := bool}} -> [];
            _ -> [compile_error(invalid_completion_root, TaskId, Origin)]
        end,
    RootErrors ++ TypeErrors ++ CompletionErrors;
validate_task(Task, _NodeMap) ->
    [compile_error(invalid_task_shape, maps:get(id, Task, <<"task">>), maps:get(origin, Task, default_origin()))].

validate_nodes(Nodes, NodeMap) ->
    lists:append([validate_node(Node, NodeMap) || Node <- Nodes]).

validate_node(#{id := Id, kind := Kind, type := Type, origin := Origin} = Node, NodeMap) when
    is_binary(Id), is_atom(Kind), is_map(Origin)
->
    case lists:member(Kind, allowed_node_kinds()) of
        false -> [compile_error(unsupported_ir_node, Id, Origin)];
        true ->
            TypeErrors = case valid_type(Type) of
                true -> [];
                false -> [compile_error(invalid_node_type, Id, Origin)]
            end,
            TypeErrors ++ validate_node_fields(Kind, Node, NodeMap)
    end;
validate_node(Node, _NodeMap) ->
    [compile_error(invalid_node_shape, maps:get(id, Node, <<"node">>), maps:get(origin, Node, default_origin()))].

validate_node_fields(literal, #{id := Id, type := Type, value := Value, origin := Origin}, _NodeMap) ->
    case wrap_value(Type, Value) of
        {ok, _} -> [];
        {error, _} -> [compile_error(invalid_literal, Id, Origin)]
    end;
validate_node_fields(input, #{id := Id, name := Name, origin := Origin}, _NodeMap) ->
    require_binary(Name, invalid_input_binding, Id, Origin);
validate_node_fields(result, _Node, _NodeMap) ->
    [];
validate_node_fields(Kind, #{id := Id, left := Left, right := Right, origin := Origin}, NodeMap) when
    Kind =:= add; Kind =:= equal
->
    missing_reference_errors(Id, Origin, [Left, Right], NodeMap);
validate_node_fields(product, #{id := Id, elements := Elements, origin := Origin}, NodeMap) when
    is_list(Elements), length(Elements) =< ?MAX_PRODUCT_WIDTH
->
    missing_reference_errors(Id, Origin, Elements, NodeMap);
validate_node_fields(project, #{id := Id, product := Product, index := Index, origin := Origin}, NodeMap) when
    is_integer(Index), Index >= 1, Index =< ?MAX_PRODUCT_WIDTH
->
    missing_reference_errors(Id, Origin, [Product], NodeMap);
validate_node_fields(Kind, #{id := Id, value := Value, origin := Origin}, NodeMap) when
    Kind =:= ok; Kind =:= error
->
    missing_reference_errors(Id, Origin, [Value], NodeMap);
validate_node_fields(bind, #{
    id := Id,
    value := Value,
    body := Body,
    binding := Binding,
    origin := Origin
}, NodeMap) ->
    require_binary(Binding, invalid_bind_identity, Id, Origin) ++
        missing_reference_errors(Id, Origin, [Value, Body], NodeMap);
validate_node_fields(match_result, #{
    id := Id,
    value := Value,
    ok_branch := OkBranch,
    error_branch := ErrorBranch,
    ok_binding := OkBinding,
    error_binding := ErrorBinding,
    origin := Origin
}, NodeMap) ->
    require_binary(OkBinding, invalid_match_binding, Id, Origin) ++
        require_binary(ErrorBinding, invalid_match_binding, Id, Origin) ++
        missing_reference_errors(Id, Origin, [Value, OkBranch, ErrorBranch], NodeMap);
validate_node_fields(apply, #{id := Id, callable := Callable, arguments := Arguments, origin := Origin}, NodeMap) when
    is_binary(Callable), is_list(Arguments), length(Arguments) =< 16
->
    missing_reference_errors(Id, Origin, Arguments, NodeMap);
validate_node_fields(sequence, #{id := Id, first := First, then := Then, origin := Origin}, NodeMap) ->
    missing_reference_errors(Id, Origin, [First, Then], NodeMap);
validate_node_fields(effect_request, #{
    id := Id,
    operation := Operation,
    arguments := Arguments,
    deadline := Deadline,
    origin := Origin
}, NodeMap) when
    is_binary(Operation),
    byte_size(Operation) > 0,
    byte_size(Operation) =< 128,
    is_list(Arguments),
    length(Arguments) =< 16,
    is_integer(Deadline),
    Deadline > 0
->
    missing_reference_errors(Id, Origin, Arguments, NodeMap);
validate_node_fields(verify, #{id := Id, condition := Condition, type := bool, origin := Origin}, NodeMap) ->
    missing_reference_errors(Id, Origin, [Condition], NodeMap);
validate_node_fields(_Kind, #{id := Id, origin := Origin}, _NodeMap) ->
    [compile_error(invalid_node_fields, Id, Origin)].

missing_reference_errors(OwnerId, Origin, References, NodeMap) ->
    [
        compile_error(dangling_node_reference, OwnerId, Origin)
     || Reference <- References,
        not is_binary(Reference) orelse not maps:is_key(Reference, NodeMap)
    ].

require_binary(Value, _Code, _Id, _Origin) when is_binary(Value), byte_size(Value) > 0, byte_size(Value) =< 128 ->
    [];
require_binary(_Value, Code, Id, Origin) ->
    [compile_error(Code, Id, Origin)].

valid_parameter(#{name := Name, type := Type, origin := Origin}) ->
    is_binary(Name) andalso byte_size(Name) > 0 andalso byte_size(Name) =< 128 andalso
        valid_type(Type) andalso is_map(Origin);
valid_parameter(_) -> false.

valid_type(int) -> true;
valid_type(bool) -> true;
valid_type(binary) -> true;
valid_type({opaque, TypeId}) -> is_binary(TypeId) andalso byte_size(TypeId) > 0 andalso byte_size(TypeId) =< 128;
valid_type({product, Types}) when is_list(Types), length(Types) =< ?MAX_PRODUCT_WIDTH ->
    lists:all(fun valid_type/1, Types);
valid_type({result, OkType, ErrorType}) -> valid_type(OkType) andalso valid_type(ErrorType);
valid_type(_) -> false.

wrap_values([], [], Acc) -> {ok, lists:reverse(Acc)};
wrap_values([Type | Types], [Value | Values], Acc) ->
    case wrap_value(Type, Value) of
        {ok, Encoded} -> wrap_values(Types, Values, [Encoded | Acc]);
        {error, _} = Error -> Error
    end.

unwrap_value(int, Value) when is_integer(Value), Value >= ?MIN_INT, Value =< ?MAX_INT -> {ok, Value};
unwrap_value(bool, Value) when is_boolean(Value) -> {ok, Value};
unwrap_value(binary, Value) when is_binary(Value), byte_size(Value) =< ?MAX_BINARY_BYTES -> {ok, Value};
unwrap_value({product, Types}, {alang_data_v1, product, Tuple}) when
    is_list(Types), is_tuple(Tuple), length(Types) =:= tuple_size(Tuple), tuple_size(Tuple) =< ?MAX_PRODUCT_WIDTH
->
    unwrap_values(Types, tuple_to_list(Tuple), []);
unwrap_value({result, OkType, _ErrorType}, {alang_data_v1, ok, Encoded}) -> unwrap_value(OkType, Encoded);
unwrap_value({result, _OkType, ErrorType}, {alang_data_v1, error, Encoded}) -> unwrap_value(ErrorType, Encoded);
unwrap_value({opaque, TypeId}, {alang_opaque_v1, TypeId, Reference}) when is_reference(Reference) ->
    {ok, {opaque, TypeId, Reference}};
unwrap_value(Type, Encoded) ->
    {error, {invalid_encoded_value, Type, summarize(Encoded)}}.

unwrap_values([], [], Acc) -> {ok, lists:reverse(Acc)};
unwrap_values([Type | Types], [Encoded | EncodedValues], Acc) ->
    case unwrap_value(Type, Encoded) of
        {ok, Value} -> unwrap_values(Types, EncodedValues, [Value | Acc]);
        {error, _} = Error -> Error
    end.

valid_identity(Value) -> is_binary(Value) andalso byte_size(Value) > 0 andalso byte_size(Value) =< 256.

origin_tuple(#{byte := Byte, line := Line, column := Column}) when
    is_integer(Byte), Byte >= 0, is_integer(Line), Line >= 1, is_integer(Column), Column >= 1
->
    {source, Byte, Line, Column};
origin_tuple(_) ->
    {source, 0, 1, 1}.

default_origin() -> #{byte => 0, line => 1, column => 1}.

summarize(Value) when is_binary(Value) -> {binary, byte_size(Value)};
summarize(Value) when is_list(Value) -> {list, safe_length(Value)};
summarize(Value) when is_tuple(Value) -> {tuple, tuple_size(Value)};
summarize(Value) when is_map(Value) -> {map, maps:size(Value)};
summarize(Value) -> Value.

safe_length(Value) ->
    try length(Value) of
        Length -> Length
    catch
        error:badarg -> improper
    end.
