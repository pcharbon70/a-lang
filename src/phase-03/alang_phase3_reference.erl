-module(alang_phase3_reference).

-export([evaluate/4, reference_only/0]).

-spec reference_only() -> true.
reference_only() -> true.

-spec evaluate(map(), binary(), map(), fun((binary(), term()) -> term())) ->
    {ok, map()} | {error, term()}.
evaluate(Ir, TaskId, Inputs, EffectHandler) when
    is_binary(TaskId), is_map(Inputs), is_function(EffectHandler, 2)
->
    case alang_phase3_contract:validate_ir(Ir) of
        ok -> evaluate_valid(Ir, TaskId, Inputs, EffectHandler);
        {error, _} = Error -> Error
    end;
evaluate(_Ir, _TaskId, _Inputs, _EffectHandler) ->
    {error, invalid_reference_request}.

evaluate_valid(#{tasks := Tasks, nodes := Nodes}, TaskId, Inputs, EffectHandler) ->
    TaskMap = maps:from_list([{maps:get(id, Task), Task} || Task <- Tasks]),
    NodeMap = maps:from_list([{maps:get(id, Node), Node} || Node <- Nodes]),
    case maps:find(TaskId, TaskMap) of
        {ok, Task} ->
            case parameter_environment(maps:get(parameters, Task), Inputs, #{}) of
                {ok, Environment} ->
                    State = #{effects => [], handler => EffectHandler, tasks => TaskMap},
                    evaluate_task(Task, NodeMap, Environment, State);
                {error, _} = Error -> Error
            end;
        error -> {error, unknown_reference_task}
    end.

evaluate_task(Task, NodeMap, Environment, State) ->
    case evaluate_node(maps:get(body_root, Task), NodeMap, Environment, State) of
        {ok, Result, BodyState} ->
            #{condition := Condition} = maps:get(maps:get(completion_root, Task), NodeMap),
            case evaluate_node(Condition, NodeMap, Environment#{<<"result">> => Result}, BodyState) of
                {ok, Completion, FinalState} when is_boolean(Completion) ->
                    {ok, #{
                        result => Result,
                        completion => Completion,
                        effects => lists:reverse(maps:get(effects, FinalState))
                    }};
                {ok, _Other, _FinalState} -> {error, non_boolean_reference_verifier};
                {error, _Reason, _FinalState} = Error -> strip_state(Error)
            end;
        {error, _Reason, _BodyState} = Error -> strip_state(Error)
    end.

evaluate_node(NodeId, NodeMap, Environment, State) ->
    evaluate_node_value(maps:get(NodeId, NodeMap), NodeMap, Environment, State).

evaluate_node_value(#{kind := literal, value := Value}, _NodeMap, _Environment, State) ->
    {ok, Value, State};
evaluate_node_value(#{kind := input, name := Name}, _NodeMap, Environment, State) ->
    lookup(Name, Environment, State);
evaluate_node_value(#{kind := result}, _NodeMap, Environment, State) ->
    lookup(<<"result">>, Environment, State);
evaluate_node_value(#{kind := add, left := Left, right := Right}, NodeMap, Environment, State) ->
    binary_operation(fun(A, B) -> A + B end, Left, Right, NodeMap, Environment, State);
evaluate_node_value(#{kind := equal, left := Left, right := Right}, NodeMap, Environment, State) ->
    binary_operation(fun(A, B) -> A =:= B end, Left, Right, NodeMap, Environment, State);
evaluate_node_value(#{kind := product, elements := Elements}, NodeMap, Environment, State) ->
    case evaluate_nodes(Elements, NodeMap, Environment, State, []) of
        {ok, Values, NextState} -> {ok, {alang_data_v1, product, list_to_tuple(Values)}, NextState};
        {error, _Reason, _NextState} = Error -> Error
    end;
evaluate_node_value(#{kind := project, product := ProductId, index := Index}, NodeMap, Environment, State) ->
    case evaluate_node(ProductId, NodeMap, Environment, State) of
        {ok, {alang_data_v1, product, Values}, NextState} when
            is_tuple(Values), Index =< tuple_size(Values)
        ->
            {ok, element(Index, Values), NextState};
        {ok, _Other, NextState} -> {error, invalid_reference_product, NextState};
        {error, _Reason, _NextState} = Error -> Error
    end;
evaluate_node_value(#{kind := Tag, value := ValueId}, NodeMap, Environment, State) when
    Tag =:= ok; Tag =:= error
->
    case evaluate_node(ValueId, NodeMap, Environment, State) of
        {ok, Value, NextState} -> {ok, {alang_data_v1, Tag, Value}, NextState};
        {error, _Reason, _NextState} = Error -> Error
    end;
evaluate_node_value(#{kind := bind, value := ValueId, body := BodyId, binding := Binding}, NodeMap, Environment, State) ->
    case evaluate_node(ValueId, NodeMap, Environment, State) of
        {ok, Value, NextState} ->
            evaluate_node(BodyId, NodeMap, Environment#{Binding => Value}, NextState);
        {error, _Reason, _NextState} = Error -> Error
    end;
evaluate_node_value(#{
    kind := match_result,
    value := ValueId,
    ok_branch := OkBranch,
    error_branch := ErrorBranch,
    ok_binding := OkBinding,
    error_binding := ErrorBinding
}, NodeMap, Environment, State) ->
    case evaluate_node(ValueId, NodeMap, Environment, State) of
        {ok, {alang_data_v1, ok, Value}, NextState} ->
            evaluate_node(OkBranch, NodeMap, Environment#{OkBinding => Value}, NextState);
        {ok, {alang_data_v1, error, Value}, NextState} ->
            evaluate_node(ErrorBranch, NodeMap, Environment#{ErrorBinding => Value}, NextState);
        {ok, _Other, NextState} -> {error, invalid_reference_result, NextState};
        {error, _Reason, _NextState} = Error -> Error
    end;
evaluate_node_value(#{kind := apply, callable := Callable, arguments := Arguments}, NodeMap, Environment, State) ->
    case evaluate_nodes(Arguments, NodeMap, Environment, State, []) of
        {ok, Values, NextState} -> evaluate_call(Callable, Values, NodeMap, NextState);
        {error, _Reason, _NextState} = Error -> Error
    end;
evaluate_node_value(#{kind := sequence, first := First, then := Then}, NodeMap, Environment, State) ->
    case evaluate_node(First, NodeMap, Environment, State) of
        {ok, {alang_data_v1, error, _Reason} = ErrorValue, NextState} ->
            {ok, ErrorValue, NextState};
        {ok, _Value, NextState} -> evaluate_node(Then, NodeMap, Environment, NextState);
        {error, _Reason, _NextState} = Error -> Error
    end;
evaluate_node_value(#{
    kind := effect_request,
    operation := Operation,
    arguments := Arguments,
    origin := Origin
}, NodeMap, Environment, State) ->
    case evaluate_nodes(Arguments, NodeMap, Environment, State, []) of
        {ok, Values, NextState} -> invoke_effect(Operation, Values, Origin, NextState);
        {error, _Reason, _NextState} = Error -> Error
    end;
evaluate_node_value(#{kind := verify, condition := Condition}, NodeMap, Environment, State) ->
    evaluate_node(Condition, NodeMap, Environment, State);
evaluate_node_value(_Node, _NodeMap, _Environment, State) ->
    {error, unsupported_reference_node, State}.

binary_operation(Function, Left, Right, NodeMap, Environment, State) ->
    case evaluate_node(Left, NodeMap, Environment, State) of
        {ok, LeftValue, LeftState} ->
            case evaluate_node(Right, NodeMap, Environment, LeftState) of
                {ok, RightValue, RightState} ->
                    try Function(LeftValue, RightValue) of
                        Value -> {ok, Value, RightState}
                    catch
                        _:_ -> {error, invalid_reference_operands, RightState}
                    end;
                {error, _Reason, _RightState} = Error -> Error
            end;
        {error, _Reason, _LeftState} = Error -> Error
    end.

evaluate_nodes([], _NodeMap, _Environment, State, Acc) ->
    {ok, lists:reverse(Acc), State};
evaluate_nodes([NodeId | Rest], NodeMap, Environment, State, Acc) ->
    case evaluate_node(NodeId, NodeMap, Environment, State) of
        {ok, Value, NextState} -> evaluate_nodes(Rest, NodeMap, Environment, NextState, [Value | Acc]);
        {error, _Reason, _NextState} = Error -> Error
    end.

evaluate_call(Callable, Values, NodeMap, State) ->
    case maps:find(Callable, maps:get(tasks, State)) of
        {ok, Task} ->
            case bind_values(maps:get(parameters, Task), Values, #{}) of
                {ok, Environment} -> evaluate_node(maps:get(body_root, Task), NodeMap, Environment, State);
                {error, Reason} -> {error, Reason, State}
            end;
        error -> {error, unknown_reference_callable, State}
    end.

invoke_effect(Operation, Values, Origin, State) ->
    Arguments = {alang_data_v1, product, list_to_tuple(Values)},
    Handler = maps:get(handler, State),
    Outcome = try Handler(Operation, Arguments) of
        {ok, HandlerValue} -> {ok, HandlerValue};
        {error, HandlerReason} -> {error, HandlerReason};
        _ -> {error, <<"invalid-handler-result">>}
    catch
        _:_ -> {error, <<"effect-handler-failed">>}
    end,
    Event = #{operation => Operation, arguments => Arguments, outcome => Outcome, origin => Origin},
    NextState = State#{effects := [Event | maps:get(effects, State)]},
    case Outcome of
        {ok, OutcomeValue} -> {ok, {alang_data_v1, ok, OutcomeValue}, NextState};
        {error, OutcomeReason} -> {ok, {alang_data_v1, error, OutcomeReason}, NextState}
    end.

parameter_environment(Parameters, Inputs, Acc) ->
    case [Name || #{name := Name} <- Parameters, not maps:is_key(Name, Inputs)] of
        [] -> {ok, maps:merge(Acc, maps:from_list([
            {maps:get(name, Parameter), maps:get(maps:get(name, Parameter), Inputs)}
         || Parameter <- Parameters
        ]))};
        Missing -> {error, {missing_reference_inputs, Missing}}
    end.

bind_values(Parameters, Values, Acc) when length(Parameters) =:= length(Values) ->
    {ok, maps:merge(Acc, maps:from_list([
        {maps:get(name, Parameter), Value}
     || {Parameter, Value} <- lists:zip(Parameters, Values)
    ]))};
bind_values(_Parameters, _Values, _Acc) -> {error, reference_arity_mismatch}.

lookup(Name, Environment, State) ->
    case maps:find(Name, Environment) of
        {ok, Value} -> {ok, Value, State};
        error -> {error, unresolved_reference_binding, State}
    end.

strip_state({error, Reason, _State}) -> {error, Reason}.
