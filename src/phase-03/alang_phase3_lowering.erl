-module(alang_phase3_lowering).

-export([lower/2]).

-define(GENERATED_MODULE, alang_phase3_program_v1).

-spec lower(map(), map()) -> {ok, map()} | {error, [tuple()]}.
lower(Ir, Context) when is_map(Context) ->
    case alang_phase3_contract:validate_ir(Ir) of
        ok ->
            try lower_valid_ir(Ir, Context) of
                Lowered -> {ok, Lowered}
            catch
                throw:{lowering_error, Error} -> {error, [Error]}
            end;
        {error, _} = Error -> Error
    end;
lower(_Ir, _Context) ->
    {error, [compile_error(invalid_lowering_context, <<"module">>, default_origin())]}.

lower_valid_ir(#{tasks := Tasks, nodes := Nodes} = Ir, Context) ->
    NodeMap = maps:from_list([{maps:get(id, Node), Node} || Node <- Nodes]),
    CallableMap = callable_map(Tasks, 0, #{}),
    CapabilityManifest = capability_manifest(Tasks, Context),
    SourceMap = [
        {maps:get(id, Node), origin_tuple(maps:get(origin, Node))}
     || Node <- Nodes
    ],
    Metadata = #{
        format => alang_backend_metadata_v1,
        module => ?GENERATED_MODULE,
        abi => alang_runtime_v1,
        ir_format => alang_typed_task_ir_v1,
        compiler => #{
            format => alang_phase3_compiler_v1,
            module => alang_phase3_backend,
            engine => beam
        },
        toolchain => maps:get(toolchain, Context, alang_phase1_compiler:current_toolchain()),
        reproducibility => #{
            forms_encoding => deterministic_etf,
            compiler_profile => alang_phase3_otp29_v1
        },
        source_sha256 => maps:get(source_sha256, Context, <<>>),
        ir_sha256 => maps:get(ir_sha256, Context, hex(crypto:hash(sha256, term_to_binary(Ir, [deterministic])))),
        capability_manifest => CapabilityManifest,
        source_map => SourceMap
    },
    Execute = execute_function(Tasks, Nodes, NodeMap, CallableMap),
    CallableForms = [task_function(Task, Nodes, NodeMap, CallableMap) || Task <- Tasks],
    Forms = [
        {attribute, 1, module, ?GENERATED_MODULE},
        {attribute, 1, export, [{execute, 3}]},
        {attribute, 1, alang_backend, Metadata},
        Execute
        | CallableForms
    ],
    #{
        module => ?GENERATED_MODULE,
        forms => Forms,
        metadata => Metadata,
        source_map => SourceMap,
        callable_map => CallableMap
    }.

capability_manifest(Tasks, Context) ->
    Derived = #{
        effects => lists:usort(lists:append([maps:get(effects, Task) || Task <- Tasks])),
        requirements => lists:usort(lists:append([maps:get(requirements, Task) || Task <- Tasks]))
    },
    case maps:get(capability_manifest, Context, Derived) of
        Derived -> Derived;
        _Other -> fail(capability_manifest_mismatch, <<"module">>, default_origin())
    end.

execute_function(Tasks, Nodes, NodeMap, CallableMap) ->
    TaskIdVariable = {var, 1, 'ALANG_TASK_ID'},
    InputsVariable = {var, 1, '_ALANG_INPUTS'},
    ContextVariable = {var, 1, 'ALANG_CONTEXT'},
    DispatchClauses = [
        dispatch_clause(Task, Nodes, NodeMap, CallableMap, InputsVariable, ContextVariable)
     || Task <- Tasks
    ],
    UnknownClause =
        {clause, 1, [{var, 1, '_'}], [], [
            runtime_tuple(1, error, {atom, 1, unknown_task})
        ]},
    Body = {'case', 1, TaskIdVariable, DispatchClauses ++ [UnknownClause]},
    {function, 1, execute, 3, [
        {clause, 1, [TaskIdVariable, InputsVariable, ContextVariable], [], [Body]}
    ]}.

dispatch_clause(Task, Nodes, NodeMap, CallableMap, InputsVariable, ContextVariable) ->
    TaskId = maps:get(id, Task),
    Function = maps:get(TaskId, CallableMap),
    Origin = maps:get(origin, Task),
    Line = origin_line(Origin),
    Parameters = maps:get(parameters, Task),
    Environment = environment(Parameters, Nodes),
    ParameterVariables = parameter_variables(Parameters, Environment, undefined, #{}, Line),
    ParameterBindings = [
        {match, Line, Variable,
            remote_call(Line, erlang, map_get, [literal(maps:get(name, Parameter)), InputsVariable])}
     || {Parameter, Variable} <- lists:zip(Parameters, ParameterVariables)
    ],
    ResultVariable = {var, Line, 'ALANG_RESULT'},
    Call = {call, Line, {atom, Line, Function}, ParameterVariables ++ [ContextVariable]},
    #{condition := ConditionId} = maps:get(maps:get(completion_root, Task), NodeMap),
    VerifyExpression = lower_node(
        ConditionId,
        NodeMap,
        Environment#{<<"result">> => 'ALANG_RESULT'},
        CallableMap,
        ContextVariable
    ),
    Verification = {'case', Line, VerifyExpression, [
        {clause, Line, [{atom, Line, true}], [], [runtime_tuple(Line, complete, ResultVariable)]},
        {clause, Line, [{atom, Line, false}], [], [
            runtime_tuple(Line, error, runtime_error_term(Line, verification_failed, Origin))
        ]}
    ]},
    {clause, Line, [literal(TaskId)], [],
        ParameterBindings ++ [{match, Line, ResultVariable, Call}, Verification]}.

task_function(Task, Nodes, NodeMap, CallableMap) ->
    Origin = maps:get(origin, Task),
    Line = origin_line(Origin),
    Parameters = maps:get(parameters, Task),
    Environment = environment(Parameters, Nodes),
    ParameterVariables = parameter_variables(
        Parameters,
        Environment,
        maps:get(body_root, Task),
        NodeMap,
        Line
    ),
    %% The leading underscore keeps pure callables warning-free while the same
    %% fixed variable remains available to effectful and nested calls.
    ContextVariable = {var, Line, '_ALANG_CONTEXT'},
    BodyExpression = lower_node(
        maps:get(body_root, Task),
        NodeMap,
        Environment,
        CallableMap,
        ContextVariable
    ),
    Function = maps:get(maps:get(id, Task), CallableMap),
    {function, Line, Function, length(Parameters) + 1, [
        {clause, Line, ParameterVariables ++ [ContextVariable], [], [BodyExpression]}
    ]}.

lower_node(NodeId, NodeMap, Environment, CallableMap, ContextVariable) ->
    Node = maps:get(NodeId, NodeMap),
    lower_node_value(Node, NodeMap, Environment, CallableMap, ContextVariable).

lower_node_value(#{kind := literal, value := Value}, _NodeMap, _Environment, _CallableMap, _Context) ->
    literal(Value);
lower_node_value(#{kind := input, name := Name, id := Id, origin := Origin}, _NodeMap, Environment, _CallableMap, _Context) ->
    case maps:find(Name, Environment) of
        {ok, Variable} -> {var, origin_line(Origin), Variable};
        error -> fail(unresolved_backend_binding, Id, Origin)
    end;
lower_node_value(#{kind := result, id := Id, origin := Origin}, _NodeMap, Environment, _CallableMap, _Context) ->
    case maps:find(<<"result">>, Environment) of
        {ok, Variable} -> {var, origin_line(Origin), Variable};
        error -> fail(result_outside_verifier, Id, Origin)
    end;
lower_node_value(#{kind := add, left := Left, right := Right, origin := Origin}, NodeMap, Environment, CallableMap, Context) ->
    Line = origin_line(Origin),
    {op, Line, '+',
        lower_node(Left, NodeMap, Environment, CallableMap, Context),
        lower_node(Right, NodeMap, Environment, CallableMap, Context)};
lower_node_value(#{kind := equal, left := Left, right := Right, origin := Origin}, NodeMap, Environment, CallableMap, Context) ->
    Line = origin_line(Origin),
    {op, Line, '=:=',
        lower_node(Left, NodeMap, Environment, CallableMap, Context),
        lower_node(Right, NodeMap, Environment, CallableMap, Context)};
lower_node_value(#{kind := product, elements := Elements, origin := Origin}, NodeMap, Environment, CallableMap, Context) ->
    Line = origin_line(Origin),
    Product = {tuple, Line, [
        lower_node(Element, NodeMap, Environment, CallableMap, Context)
     || Element <- Elements
    ]},
    {tuple, Line, [{atom, Line, alang_data_v1}, {atom, Line, product}, Product]};
lower_node_value(#{kind := project, product := ProductId, index := Index, origin := Origin}, NodeMap, Environment, CallableMap, Context) ->
    Line = origin_line(Origin),
    Product = lower_node(ProductId, NodeMap, Environment, CallableMap, Context),
    Inner = remote_call(Line, erlang, element, [{integer, Line, 3}, Product]),
    remote_call(Line, erlang, element, [{integer, Line, Index}, Inner]);
lower_node_value(#{kind := Kind, value := ValueId, origin := Origin}, NodeMap, Environment, CallableMap, Context) when
    Kind =:= ok; Kind =:= error
->
    Line = origin_line(Origin),
    {tuple, Line, [
        {atom, Line, alang_data_v1},
        {atom, Line, Kind},
        lower_node(ValueId, NodeMap, Environment, CallableMap, Context)
    ]};
lower_node_value(#{kind := bind, value := ValueId, body := BodyId, binding := Binding, id := Id, origin := Origin}, NodeMap, Environment, CallableMap, Context) ->
    Line = origin_line(Origin),
    Variable = case binding_used(Binding, BodyId, NodeMap, []) of
        true -> binding_variable(Binding, Environment, Id, Origin);
        false -> '_'
    end,
    {'case', Line,
        lower_node(ValueId, NodeMap, Environment, CallableMap, Context),
        [{clause, Line, [{var, Line, Variable}], [], [
            lower_node(BodyId, NodeMap, Environment, CallableMap, Context)
        ]}]};
lower_node_value(#{
    kind := match_result,
    value := ValueId,
    ok_branch := OkId,
    error_branch := ErrorId,
    ok_binding := OkBinding,
    error_binding := ErrorBinding,
    id := Id,
    origin := Origin
}, NodeMap, Environment, CallableMap, Context) ->
    Line = origin_line(Origin),
    OkVariable = case binding_used(OkBinding, OkId, NodeMap, []) of
        true -> binding_variable(OkBinding, Environment, Id, Origin);
        false -> '_'
    end,
    ErrorVariable = case binding_used(ErrorBinding, ErrorId, NodeMap, []) of
        true -> binding_variable(ErrorBinding, Environment, Id, Origin);
        false -> '_'
    end,
    {'case', Line,
        lower_node(ValueId, NodeMap, Environment, CallableMap, Context),
        [
            {clause, Line, [tagged_pattern(Line, ok, OkVariable)], [], [
                lower_node(OkId, NodeMap, Environment, CallableMap, Context)
            ]},
            {clause, Line, [tagged_pattern(Line, error, ErrorVariable)], [], [
                lower_node(ErrorId, NodeMap, Environment, CallableMap, Context)
            ]}
        ]};
lower_node_value(#{kind := apply, callable := Callable, arguments := Arguments, id := Id, origin := Origin}, NodeMap, Environment, CallableMap, Context) ->
    Line = origin_line(Origin),
    case maps:find(Callable, CallableMap) of
        {ok, Function} ->
            {call, Line, {atom, Line, Function}, [
                lower_node(Argument, NodeMap, Environment, CallableMap, Context)
             || Argument <- Arguments
            ] ++ [Context]};
        error -> fail(unresolved_backend_callable, Id, Origin)
    end;
lower_node_value(#{kind := sequence, id := Id, first := First, then := Then, origin := Origin}, NodeMap, Environment, CallableMap, Context) ->
    Line = origin_line(Origin),
    ErrorVariable = maps:get({sequence, Id}, Environment),
    {'case', Line,
        lower_node(First, NodeMap, Environment, CallableMap, Context),
        [
            {clause, Line, [tagged_pattern(Line, error, ErrorVariable)], [], [
                {tuple, Line, [
                    {atom, Line, alang_data_v1},
                    {atom, Line, error},
                    {var, Line, ErrorVariable}
                ]}
            ]},
            {clause, Line, [{var, Line, '_'}], [], [
                lower_node(Then, NodeMap, Environment, CallableMap, Context)
            ]}
        ]};
lower_node_value(#{kind := effect_request, operation := Operation, arguments := Arguments, deadline := Deadline, origin := Origin}, NodeMap, Environment, CallableMap, Context) ->
    Line = origin_line(Origin),
    ArgumentTuple = {tuple, Line, [
        lower_node(Argument, NodeMap, Environment, CallableMap, Context)
     || Argument <- Arguments
    ]},
    remote_call(Line, alang_phase3_abi, request_effect, [
        Context,
        literal(Operation),
        {tuple, Line, [{atom, Line, alang_data_v1}, {atom, Line, product}, ArgumentTuple]},
        literal(origin_tuple(Origin)),
        {integer, Line, Deadline}
    ]);
lower_node_value(#{kind := verify, condition := Condition}, NodeMap, Environment, CallableMap, Context) ->
    lower_node(Condition, NodeMap, Environment, CallableMap, Context);
lower_node_value(#{id := Id, origin := Origin}, _NodeMap, _Environment, _CallableMap, _Context) ->
    fail(unsupported_ir_node, Id, Origin).

callable_map([], _Index, Acc) -> Acc;
callable_map([Task | Rest], Index, Acc) ->
    Function = callable_atom(Index),
    callable_map(Rest, Index + 1, Acc#{maps:get(id, Task) => Function}).

assign_variables([], _Index, Acc) -> Acc;
assign_variables([Name | Rest], Index, Acc) when Index < 32 ->
    assign_variables(Rest, Index + 1, Acc#{Name => variable_atom(Index)});
assign_variables([Name | _Rest], _Index, _Acc) ->
    fail(compiler_variable_pool_exhausted, Name, default_origin()).

environment(Parameters, Nodes) ->
    BindingNames = unique_names(
        [maps:get(name, Parameter) || Parameter <- Parameters] ++ collect_bindings(Nodes),
        []
    ),
    BindingEnvironment = assign_variables(BindingNames, 0, #{}),
    assign_sequence_variables(Nodes, 0, BindingEnvironment).

assign_sequence_variables([], _Index, Environment) -> Environment;
assign_sequence_variables([#{kind := sequence, id := Id} | Rest], Index, Environment) when Index < 16 ->
    assign_sequence_variables(Rest, Index + 1, Environment#{{sequence, Id} => sequence_variable_atom(Index)});
assign_sequence_variables([#{kind := sequence, id := Id} | _Rest], _Index, _Environment) ->
    fail(compiler_sequence_pool_exhausted, Id, default_origin());
assign_sequence_variables([_Node | Rest], Index, Environment) ->
    assign_sequence_variables(Rest, Index, Environment).

binding_variable(Binding, Environment, Id, Origin) ->
    case maps:find(Binding, Environment) of
        {ok, Variable} -> Variable;
        error -> fail(unresolved_backend_binding, Id, Origin)
    end.

parameter_variables(Parameters, Environment, undefined, _NodeMap, Line) ->
    [
        {var, Line, maps:get(maps:get(name, Parameter), Environment)}
     || Parameter <- Parameters
    ];
parameter_variables(Parameters, Environment, BodyRoot, NodeMap, Line) ->
    parameter_variables(Parameters, Environment, BodyRoot, NodeMap, Line, 0, []).

parameter_variables([], _Environment, _BodyRoot, _NodeMap, _Line, _Index, Acc) ->
    lists:reverse(Acc);
parameter_variables([Parameter | Rest], Environment, BodyRoot, NodeMap, Line, Index, Acc) ->
    Name = maps:get(name, Parameter),
    Variable = case binding_used(Name, BodyRoot, NodeMap, []) of
        true -> maps:get(Name, Environment);
        false -> unused_variable_atom(Index)
    end,
    parameter_variables(Rest, Environment, BodyRoot, NodeMap, Line, Index + 1, [{var, Line, Variable} | Acc]).

binding_used(Name, NodeId, NodeMap, Seen) ->
    case lists:member(NodeId, Seen) of
        true -> false;
        false ->
            Node = maps:get(NodeId, NodeMap),
            case Node of
                #{kind := input, name := Name} -> true;
                _ -> lists:any(
                    fun(Reference) -> binding_used(Name, Reference, NodeMap, [NodeId | Seen]) end,
                    node_references(Node)
                )
            end
    end.

node_references(#{kind := Kind, left := Left, right := Right}) when Kind =:= add; Kind =:= equal -> [Left, Right];
node_references(#{kind := product, elements := Elements}) -> Elements;
node_references(#{kind := project, product := Product}) -> [Product];
node_references(#{kind := Kind, value := Value}) when Kind =:= ok; Kind =:= error -> [Value];
node_references(#{kind := bind, value := Value, body := Body}) -> [Value, Body];
node_references(#{kind := match_result, value := Value, ok_branch := Ok, error_branch := Error}) ->
    [Value, Ok, Error];
node_references(#{kind := apply, arguments := Arguments}) -> Arguments;
node_references(#{kind := sequence, first := First, then := Then}) -> [First, Then];
node_references(#{kind := effect_request, arguments := Arguments}) -> Arguments;
node_references(#{kind := verify, condition := Condition}) -> [Condition];
node_references(_) -> [].

collect_bindings(Nodes) ->
    lists:append([node_bindings(Node) || Node <- Nodes]).

node_bindings(#{kind := bind, binding := Binding}) -> [Binding];
node_bindings(#{kind := match_result, ok_binding := Ok, error_binding := Error}) -> [Ok, Error];
node_bindings(_) -> [].

unique_names([], Acc) -> lists:reverse(Acc);
unique_names([Name | Rest], Acc) ->
    case lists:member(Name, Acc) of
        true -> unique_names(Rest, Acc);
        false -> unique_names(Rest, [Name | Acc])
    end.

tagged_pattern(Line, Tag, Variable) ->
    {tuple, Line, [{atom, Line, alang_data_v1}, {atom, Line, Tag}, {var, Line, Variable}]}.

runtime_tuple(Line, Tag, Value) ->
    {tuple, Line, [{atom, Line, alang_runtime_v1}, {atom, Line, Tag}, Value]}.

runtime_error_term(Line, Code, Origin) ->
    {tuple, Line, [
        {atom, Line, alang_runtime_error_v1},
        {atom, Line, Code},
        literal(origin_tuple(Origin))
    ]}.

remote_call(Line, Module, Function, Arguments) ->
    {call, Line, {remote, Line, {atom, Line, Module}, {atom, Line, Function}}, Arguments}.

literal(Value) -> erl_parse:abstract(Value).

origin_tuple(#{byte := Byte, line := Line, column := Column}) -> {source, Byte, Line, Column};
origin_tuple(_) -> {source, 0, 1, 1}.

origin_line(#{line := Line}) when is_integer(Line), Line >= 1 -> Line;
origin_line(_) -> 1.

fail(Code, Id, Origin) ->
    throw({lowering_error, compile_error(Code, Id, Origin)}).

compile_error(Code, Id, Origin) -> alang_phase3_contract:compile_error(Code, Id, Origin).

default_origin() -> #{byte => 0, line => 1, column => 1}.

hex(Binary) ->
    iolist_to_binary([io_lib:format("~2.16.0b", [Byte]) || <<Byte>> <= Binary]).

callable_atom(0) -> '$alang_callable_0';
callable_atom(1) -> '$alang_callable_1';
callable_atom(2) -> '$alang_callable_2';
callable_atom(3) -> '$alang_callable_3';
callable_atom(4) -> '$alang_callable_4';
callable_atom(5) -> '$alang_callable_5';
callable_atom(6) -> '$alang_callable_6';
callable_atom(7) -> '$alang_callable_7';
callable_atom(8) -> '$alang_callable_8';
callable_atom(9) -> '$alang_callable_9';
callable_atom(10) -> '$alang_callable_10';
callable_atom(11) -> '$alang_callable_11';
callable_atom(12) -> '$alang_callable_12';
callable_atom(13) -> '$alang_callable_13';
callable_atom(14) -> '$alang_callable_14';
callable_atom(15) -> '$alang_callable_15'.

variable_atom(0) -> 'ALANG_V0';
variable_atom(1) -> 'ALANG_V1';
variable_atom(2) -> 'ALANG_V2';
variable_atom(3) -> 'ALANG_V3';
variable_atom(4) -> 'ALANG_V4';
variable_atom(5) -> 'ALANG_V5';
variable_atom(6) -> 'ALANG_V6';
variable_atom(7) -> 'ALANG_V7';
variable_atom(8) -> 'ALANG_V8';
variable_atom(9) -> 'ALANG_V9';
variable_atom(10) -> 'ALANG_V10';
variable_atom(11) -> 'ALANG_V11';
variable_atom(12) -> 'ALANG_V12';
variable_atom(13) -> 'ALANG_V13';
variable_atom(14) -> 'ALANG_V14';
variable_atom(15) -> 'ALANG_V15';
variable_atom(16) -> 'ALANG_V16';
variable_atom(17) -> 'ALANG_V17';
variable_atom(18) -> 'ALANG_V18';
variable_atom(19) -> 'ALANG_V19';
variable_atom(20) -> 'ALANG_V20';
variable_atom(21) -> 'ALANG_V21';
variable_atom(22) -> 'ALANG_V22';
variable_atom(23) -> 'ALANG_V23';
variable_atom(24) -> 'ALANG_V24';
variable_atom(25) -> 'ALANG_V25';
variable_atom(26) -> 'ALANG_V26';
variable_atom(27) -> 'ALANG_V27';
variable_atom(28) -> 'ALANG_V28';
variable_atom(29) -> 'ALANG_V29';
variable_atom(30) -> 'ALANG_V30';
variable_atom(31) -> 'ALANG_V31'.

sequence_variable_atom(0) -> 'ALANG_SEQUENCE_0';
sequence_variable_atom(1) -> 'ALANG_SEQUENCE_1';
sequence_variable_atom(2) -> 'ALANG_SEQUENCE_2';
sequence_variable_atom(3) -> 'ALANG_SEQUENCE_3';
sequence_variable_atom(4) -> 'ALANG_SEQUENCE_4';
sequence_variable_atom(5) -> 'ALANG_SEQUENCE_5';
sequence_variable_atom(6) -> 'ALANG_SEQUENCE_6';
sequence_variable_atom(7) -> 'ALANG_SEQUENCE_7';
sequence_variable_atom(8) -> 'ALANG_SEQUENCE_8';
sequence_variable_atom(9) -> 'ALANG_SEQUENCE_9';
sequence_variable_atom(10) -> 'ALANG_SEQUENCE_10';
sequence_variable_atom(11) -> 'ALANG_SEQUENCE_11';
sequence_variable_atom(12) -> 'ALANG_SEQUENCE_12';
sequence_variable_atom(13) -> 'ALANG_SEQUENCE_13';
sequence_variable_atom(14) -> 'ALANG_SEQUENCE_14';
sequence_variable_atom(15) -> 'ALANG_SEQUENCE_15'.

unused_variable_atom(0) -> '_ALANG_UNUSED_0';
unused_variable_atom(1) -> '_ALANG_UNUSED_1';
unused_variable_atom(2) -> '_ALANG_UNUSED_2';
unused_variable_atom(3) -> '_ALANG_UNUSED_3';
unused_variable_atom(4) -> '_ALANG_UNUSED_4';
unused_variable_atom(5) -> '_ALANG_UNUSED_5';
unused_variable_atom(6) -> '_ALANG_UNUSED_6';
unused_variable_atom(7) -> '_ALANG_UNUSED_7';
unused_variable_atom(8) -> '_ALANG_UNUSED_8';
unused_variable_atom(9) -> '_ALANG_UNUSED_9';
unused_variable_atom(10) -> '_ALANG_UNUSED_10';
unused_variable_atom(11) -> '_ALANG_UNUSED_11';
unused_variable_atom(12) -> '_ALANG_UNUSED_12';
unused_variable_atom(13) -> '_ALANG_UNUSED_13';
unused_variable_atom(14) -> '_ALANG_UNUSED_14';
unused_variable_atom(15) -> '_ALANG_UNUSED_15'.
