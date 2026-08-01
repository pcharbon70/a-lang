-module(alang_phase2_ir).

-export([apply_transform/2, compose/2, identity/0, lower/1, validate/1]).

-spec lower(map()) -> {ok, map()} | {error, [map()]}.
lower(#{format := alang_checked_program_v1, module := ModuleName, tasks := CheckedTasks}) ->
    case lower_tasks(CheckedTasks, [], []) of
        {ok, Tasks, Nodes} ->
            Ir = #{
                format => alang_typed_task_ir_v1,
                module => ModuleName,
                tasks => Tasks,
                nodes => Nodes
            },
            case validate(Ir) of
                ok -> {ok, Ir};
                {error, _} = Error -> Error
            end;
        {error, _} = Error -> Error
    end;
lower(_) ->
    {error, [diagnostic(invalid_checked_program, <<"invalid checked program">>)]}.

lower_tasks([], TaskAcc, NodeAcc) ->
    {ok, lists:reverse(TaskAcc), lists:append(lists:reverse(NodeAcc))};
lower_tasks([Task | Rest], TaskAcc, NodeAcc) ->
    TaskId = maps:get(id, Task),
    ParameterTypes = maps:from_list([
        {maps:get(name, Parameter), maps:get(type, Parameter)}
        || Parameter <- maps:get(parameters, Task)
    ]),
    ExpressionTypes = ParameterTypes#{<<"result">> => maps:get(result_type, Task)},
    {BodyRoot, BodyNodes, Next} = lower_expression(maps:get(body, Task), TaskId, 0, ExpressionTypes),
    {ConditionRoot, EnsureNodes, VerifyNumber} = lower_expression(
        maps:get(ensures, Task),
        TaskId,
        Next,
        ExpressionTypes
    ),
    VerifyId = node_id(TaskId, VerifyNumber),
    VerifyNode = #{
        id => VerifyId,
        kind => verify,
        type => bool,
        condition => ConditionRoot,
        origin => maps:get(origin, maps:get(ensures, Task))
    },
    IrTask = #{
        id => TaskId,
        name => maps:get(name, Task),
        parameters => maps:get(parameters, Task),
        result_type => maps:get(result_type, Task),
        effects => maps:get(effects, Task),
        requirements => maps:get(requirements, Task),
        body_root => BodyRoot,
        completion_root => VerifyId,
        origin => maps:get(origin, Task)
    },
    lower_tasks(Rest, [IrTask | TaskAcc], [BodyNodes ++ EnsureNodes ++ [VerifyNode] | NodeAcc]).

lower_expression(#{kind := integer, value := Value, origin := Origin}, TaskId, Number, _Types) ->
    Id = node_id(TaskId, Number),
    {Id, [#{id => Id, kind => literal, type => int, value => Value, origin => Origin}], Number + 1};
lower_expression(#{kind := boolean, value := Value, origin := Origin}, TaskId, Number, _Types) ->
    Id = node_id(TaskId, Number),
    {Id, [#{id => Id, kind => literal, type => bool, value => Value, origin => Origin}], Number + 1};
lower_expression(#{kind := variable, name := <<"result">>, origin := Origin}, TaskId, Number, Types) ->
    Id = node_id(TaskId, Number),
    Type = maps:get(<<"result">>, Types),
    {Id, [#{id => Id, kind => result, type => Type, origin => Origin}], Number + 1};
lower_expression(#{kind := variable, name := Name, origin := Origin}, TaskId, Number, Types) ->
    Id = node_id(TaskId, Number),
    Type = maps:get(Name, Types),
    {Id, [#{id => Id, kind => input, type => Type, name => Name, origin => Origin}], Number + 1};
lower_expression(#{kind := add, left := Left, right := Right, origin := Origin}, TaskId, Number, Types) ->
    Id = node_id(TaskId, Number),
    {LeftId, LeftNodes, Next} = lower_expression(Left, TaskId, Number + 1, Types),
    {RightId, RightNodes, Final} = lower_expression(Right, TaskId, Next, Types),
    Node = #{id => Id, kind => add, type => int, left => LeftId, right => RightId, origin => Origin},
    {Id, [Node | LeftNodes ++ RightNodes], Final};
lower_expression(#{kind := equal, left := Left, right := Right, origin := Origin}, TaskId, Number, Types) ->
    Id = node_id(TaskId, Number),
    {LeftId, LeftNodes, Next} = lower_expression(Left, TaskId, Number + 1, Types),
    {RightId, RightNodes, Final} = lower_expression(Right, TaskId, Next, Types),
    Node = #{id => Id, kind => equal, type => bool, left => LeftId, right => RightId, origin => Origin},
    {Id, [Node | LeftNodes ++ RightNodes], Final}.

-spec validate(map()) -> ok | {error, [map()]}.
validate(#{format := alang_typed_task_ir_v1, tasks := Tasks, nodes := Nodes}) when
    is_list(Tasks), is_list(Nodes)
->
    Ids = [maps:get(id, Node, undefined) || Node <- Nodes],
    NodeMap = maps:from_list([{maps:get(id, Node, undefined), Node} || Node <- Nodes]),
    case length(Ids) =:= maps:size(NodeMap) andalso lists:all(fun valid_node_id/1, Ids) of
        false -> {error, [diagnostic(invalid_node_identity, <<"node identities must be unique binaries">>)]};
        true -> validate_tasks(Tasks, NodeMap)
    end;
validate(_) ->
    {error, [diagnostic(invalid_ir, <<"invalid typed task IR">>)]}.

validate_tasks([], _NodeMap) ->
    ok;
validate_tasks([Task | Rest], NodeMap) ->
    BodyRoot = maps:get(body_root, Task, undefined),
    CompletionRoot = maps:get(completion_root, Task, undefined),
    case {maps:is_key(BodyRoot, NodeMap), maps:find(CompletionRoot, NodeMap)} of
        {true, {ok, #{kind := verify, type := bool, condition := Condition}}} ->
            case maps:is_key(Condition, NodeMap) andalso validate_references(NodeMap) of
                true -> validate_tasks(Rest, NodeMap);
                false -> {error, [diagnostic(dangling_node_reference, <<"IR contains a dangling node reference">>)]}
            end;
        _ ->
            {error, [diagnostic(invalid_task_roots, <<"task roots are absent or ill-typed">>)]}
    end.

validate_references(NodeMap) ->
    maps:fold(
        fun(_Id, #{kind := Kind} = Node, Acc) when Kind =:= add; Kind =:= equal ->
                Acc andalso maps:is_key(maps:get(left, Node), NodeMap) andalso maps:is_key(maps:get(right, Node), NodeMap);
           (_Id, #{kind := verify, condition := Condition}, Acc) ->
                Acc andalso maps:is_key(Condition, NodeMap);
           (_Id, _Node, Acc) ->
                Acc
        end,
        true,
        NodeMap
    ).

valid_node_id(Id) -> is_binary(Id) andalso byte_size(Id) > 0.

node_id(TaskId, Number) ->
    Suffix = iolist_to_binary(io_lib:format("~4..0B", [Number])),
    <<"node:", TaskId/binary, ":", Suffix/binary>>.

%% These tiny morphisms make the law tests executable without making them part
%% of the A-Lang execution path. They run as ordinary BEAM code under EUnit.
-spec identity() -> identity.
identity() -> identity.

-spec compose(term(), term()) -> term().
compose(identity, Right) -> Right;
compose(Left, identity) -> Left;
compose(Left, Right) -> {compose, Left, Right}.

-spec apply_transform(term(), integer()) -> integer().
apply_transform(identity, Value) -> Value;
apply_transform(increment, Value) -> Value + 1;
apply_transform(double, Value) -> Value * 2;
apply_transform(negate, Value) -> -Value;
apply_transform({compose, Left, Right}, Value) ->
    apply_transform(Left, apply_transform(Right, Value)).

diagnostic(Code, Message) ->
    #{code => Code, severity => error, message => Message}.
