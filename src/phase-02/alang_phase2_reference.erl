-module(alang_phase2_reference).

-export([evaluate/3]).

-define(MAX_STEPS, 256).

-spec evaluate(map(), binary(), map()) -> {ok, map()} | {error, term()}.
evaluate(#{format := alang_typed_task_ir_v1, tasks := Tasks, nodes := Nodes}, TaskId, Inputs) when
    is_binary(TaskId), is_map(Inputs)
->
    case find_task(TaskId, Tasks) of
        {ok, Task} ->
            NodeMap = maps:from_list([{maps:get(id, Node), Node} || Node <- Nodes]),
            case eval(maps:get(body_root, Task), NodeMap, Inputs, undefined, 0) of
                {ok, Result, Steps1} ->
                    case eval(maps:get(completion_root, Task), NodeMap, Inputs, Result, Steps1) of
                        {ok, Completion, Steps2} when is_boolean(Completion) ->
                            {ok, #{
                                format => alang_reference_observation_v1,
                                task => TaskId,
                                result => Result,
                                completion => Completion,
                                effects => maps:get(effects, Task),
                                steps => Steps2,
                                deployable => false,
                                engine => beam_test_oracle
                            }};
                        {ok, Other, _Steps2} -> {error, {completion_not_boolean, Other}};
                        {error, _} = Error -> Error
                    end;
                {error, _} = Error -> Error
            end;
        error ->
            {error, {unknown_task, TaskId}}
    end;
evaluate(_, _, _) ->
    {error, invalid_reference_input}.

find_task(_TaskId, []) -> error;
find_task(TaskId, [#{id := TaskId} = Task | _]) -> {ok, Task};
find_task(TaskId, [_ | Rest]) -> find_task(TaskId, Rest).

eval(_Id, _Nodes, _Inputs, _Result, Steps) when Steps >= ?MAX_STEPS ->
    {error, reference_step_limit};
eval(Id, Nodes, Inputs, Result, Steps) ->
    case maps:find(Id, Nodes) of
        error -> {error, {missing_node, Id}};
        {ok, #{kind := input, name := Name}} ->
            case maps:find(Name, Inputs) of
                {ok, Value} -> {ok, Value, Steps + 1};
                error -> {error, {missing_input, Name}}
            end;
        {ok, #{kind := result}} when Result =/= undefined ->
            {ok, Result, Steps + 1};
        {ok, #{kind := result}} ->
            {error, result_not_available};
        {ok, #{kind := literal, value := Value}} ->
            {ok, Value, Steps + 1};
        {ok, #{kind := add, left := Left, right := Right}} ->
            eval_binary(add, Left, Right, Nodes, Inputs, Result, Steps + 1);
        {ok, #{kind := equal, left := Left, right := Right}} ->
            eval_binary(equal, Left, Right, Nodes, Inputs, Result, Steps + 1);
        {ok, #{kind := verify, condition := Condition}} ->
            eval(Condition, Nodes, Inputs, Result, Steps + 1);
        {ok, Node} ->
            {error, {unsupported_reference_node, maps:get(kind, Node, undefined)}}
    end.

eval_binary(Operation, Left, Right, Nodes, Inputs, Result, Steps0) ->
    case eval(Left, Nodes, Inputs, Result, Steps0) of
        {ok, LeftValue, Steps1} ->
            case eval(Right, Nodes, Inputs, Result, Steps1) of
                {ok, RightValue, Steps2} -> apply_binary(Operation, LeftValue, RightValue, Steps2);
                {error, _} = Error -> Error
            end;
        {error, _} = Error -> Error
    end.

apply_binary(add, Left, Right, Steps) when is_integer(Left), is_integer(Right) ->
    {ok, Left + Right, Steps};
apply_binary(equal, Left, Right, Steps) ->
    {ok, Left =:= Right, Steps};
apply_binary(Operation, Left, Right, _Steps) ->
    {error, {invalid_reference_operands, Operation, Left, Right}}.
