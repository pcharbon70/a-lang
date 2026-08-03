-module(alang_phase3_forms).

-export([validate/1]).

-define(GENERATED_MODULE, alang_phase3_program_v1).
-define(MAX_FORMS, 40).
-define(MAX_DEPTH, 64).
-define(MAX_LIST, 256).
-define(MAX_TUPLE, 20).

-spec validate(list()) -> ok | {error, term()}.
validate(Forms) when is_list(Forms), length(Forms) =< ?MAX_FORMS ->
    case Forms of
        [
            {attribute, _, module, ?GENERATED_MODULE},
            {attribute, _, export, [{execute, 3}]},
            {attribute, _, alang_backend, Metadata},
            {function, _, execute, 3, _}
            | _
        ] ->
            case validate_metadata(Metadata) of
                ok -> validate_forms(Forms, 0);
                {error, _} = Error -> Error
            end;
        _ -> {error, unsupported_module_shape}
    end;
validate(Forms) when is_list(Forms) ->
    {error, {too_many_abstract_forms, length(Forms)}};
validate(_) ->
    {error, invalid_abstract_forms}.

validate_metadata(#{
    format := alang_backend_metadata_v1,
    abi := alang_runtime_v1,
    ir_format := alang_typed_task_ir_v1,
    source_sha256 := SourceDigest,
    ir_sha256 := IrDigest,
    capability_manifest := #{effects := Effects, requirements := Requirements},
    source_map := SourceMap
}) when
    is_binary(SourceDigest),
    byte_size(SourceDigest) =< 64,
    is_binary(IrDigest),
    byte_size(IrDigest) =< 64,
    is_list(Effects),
    length(Effects) =< 32,
    is_list(Requirements),
    length(Requirements) =< 32,
    is_list(SourceMap),
    length(SourceMap) =< ?MAX_LIST
->
    ok;
validate_metadata(_) ->
    {error, invalid_backend_metadata}.

validate_forms([], _Depth) -> ok;
validate_forms([Form | Rest], Depth) ->
    case validate_form(Form, Depth + 1) of
        ok -> validate_forms(Rest, Depth);
        {error, _} = Error -> Error
    end.

validate_form({attribute, Line, module, ?GENERATED_MODULE}, _Depth) -> valid_line(Line);
validate_form({attribute, Line, export, [{execute, 3}]}, _Depth) -> valid_line(Line);
validate_form({attribute, Line, alang_backend, _Metadata}, _Depth) -> valid_line(Line);
validate_form({function, Line, Name, Arity, Clauses}, Depth) when
    is_atom(Name), is_integer(Arity), Arity >= 0, Arity =< 17, is_list(Clauses), Clauses =/= []
->
    case valid_line(Line) of
        ok ->
            case allowed_function(Name) of
                true -> validate_list(fun validate_clause/2, Clauses, Depth + 1);
                false -> {error, {unsupported_generated_function, Name}}
            end;
        {error, _} = Error -> Error
    end;
validate_form(Form, _Depth) -> {error, {unsupported_abstract_form, summarize(Form)}}.

validate_clause({clause, Line, Patterns, Guards, Body}, Depth) when
    is_list(Patterns), length(Patterns) =< 17, Guards =:= [], is_list(Body), Body =/= []
->
    with_depth(Depth, fun() ->
        with_ok(valid_line(Line), fun() ->
            with_ok(validate_list(fun validate_pattern/2, Patterns, Depth + 1), fun() ->
                validate_list(fun validate_expression/2, Body, Depth + 1)
            end)
        end)
    end);
validate_clause(Clause, _Depth) -> {error, {unsupported_clause, summarize(Clause)}}.

validate_pattern({var, Line, Name}, _Depth) ->
    with_ok(valid_line(Line), fun() -> validate_variable(Name) end);
validate_pattern({atom, Line, Atom}, _Depth) ->
    with_ok(valid_line(Line), fun() -> validate_literal_atom(Atom) end);
validate_pattern({integer, Line, Value}, _Depth) when is_integer(Value) -> valid_line(Line);
validate_pattern({string, Line, Value}, _Depth) when is_list(Value), length(Value) =< 65536 -> valid_line(Line);
validate_pattern({nil, Line}, _Depth) -> valid_line(Line);
validate_pattern({cons, Line, Head, Tail}, Depth) ->
    with_ok(valid_line(Line), fun() ->
        with_ok(validate_pattern(Head, Depth + 1), fun() -> validate_pattern(Tail, Depth + 1) end)
    end);
validate_pattern({tuple, Line, Elements}, Depth) when is_list(Elements), length(Elements) =< ?MAX_TUPLE ->
    with_ok(valid_line(Line), fun() -> validate_list(fun validate_pattern/2, Elements, Depth + 1) end);
validate_pattern({bin, Line, Elements}, Depth) ->
    with_ok(valid_line(Line), fun() -> validate_bin_elements(Elements, Depth + 1) end);
validate_pattern({match, Line, Left, Right}, Depth) ->
    with_ok(valid_line(Line), fun() ->
        with_ok(validate_pattern(Left, Depth + 1), fun() -> validate_pattern(Right, Depth + 1) end)
    end);
validate_pattern(Pattern, _Depth) -> {error, {unsupported_pattern, summarize(Pattern)}}.

validate_expression({var, Line, Name}, _Depth) ->
    with_ok(valid_line(Line), fun() -> validate_variable(Name) end);
validate_expression({atom, Line, Atom}, _Depth) ->
    with_ok(valid_line(Line), fun() -> validate_literal_atom(Atom) end);
validate_expression({integer, Line, Value}, _Depth) when is_integer(Value) -> valid_line(Line);
validate_expression({string, Line, Value}, _Depth) when is_list(Value), length(Value) =< 65536 -> valid_line(Line);
validate_expression({nil, Line}, _Depth) -> valid_line(Line);
validate_expression({cons, Line, Head, Tail}, Depth) ->
    with_ok(valid_line(Line), fun() ->
        with_ok(validate_expression(Head, Depth + 1), fun() -> validate_expression(Tail, Depth + 1) end)
    end);
validate_expression({tuple, Line, Elements}, Depth) when is_list(Elements), length(Elements) =< ?MAX_TUPLE ->
    with_ok(valid_line(Line), fun() -> validate_list(fun validate_expression/2, Elements, Depth + 1) end);
validate_expression({bin, Line, Elements}, Depth) ->
    with_ok(valid_line(Line), fun() -> validate_bin_elements(Elements, Depth + 1) end);
validate_expression({map, Line, Fields}, Depth) when is_list(Fields), length(Fields) =< 32 ->
    with_ok(valid_line(Line), fun() -> validate_list(fun validate_map_field/2, Fields, Depth + 1) end);
validate_expression({'case', Line, Value, Clauses}, Depth) ->
    with_ok(valid_line(Line), fun() ->
        with_ok(validate_expression(Value, Depth + 1), fun() ->
            validate_list(fun validate_clause/2, Clauses, Depth + 1)
        end)
    end);
validate_expression({'receive', Line, Clauses, Timeout, AfterBody}, Depth) when is_list(AfterBody), AfterBody =/= [] ->
    with_ok(valid_line(Line), fun() ->
        with_ok(validate_list(fun validate_clause/2, Clauses, Depth + 1), fun() ->
            with_ok(validate_expression(Timeout, Depth + 1), fun() ->
                validate_list(fun validate_expression/2, AfterBody, Depth + 1)
            end)
        end)
    end);
validate_expression({match, Line, Pattern, Value}, Depth) ->
    with_ok(valid_line(Line), fun() ->
        with_ok(validate_pattern(Pattern, Depth + 1), fun() -> validate_expression(Value, Depth + 1) end)
    end);
validate_expression({call, Line, {atom, _, Function}, Arguments}, Depth) when is_list(Arguments), length(Arguments) =< 17 ->
    with_ok(valid_line(Line), fun() ->
        case allowed_function(Function) of
            true -> validate_list(fun validate_expression/2, Arguments, Depth + 1);
            false -> {error, {unsupported_local_call, Function, length(Arguments)}}
        end
    end);
validate_expression({call, Line, {remote, _, {atom, _, Module}, {atom, _, Function}}, Arguments}, Depth) when
    is_list(Arguments), length(Arguments) =< 17
->
    with_ok(valid_line(Line), fun() ->
        Call = {Module, Function, length(Arguments)},
        case lists:member(Call, alang_phase3_contract:allowed_runtime_calls()) of
            true -> validate_list(fun validate_expression/2, Arguments, Depth + 1);
            false -> {error, {unsupported_remote_call, Call}}
        end
    end);
validate_expression({op, Line, Operator, Left, Right}, Depth) when Operator =:= '+'; Operator =:= '=:=' ->
    with_ok(valid_line(Line), fun() ->
        with_ok(validate_expression(Left, Depth + 1), fun() -> validate_expression(Right, Depth + 1) end)
    end);
validate_expression(Expression, _Depth) -> {error, {unsupported_expression, summarize(Expression)}}.

validate_map_field({map_field_assoc, Line, Key, Value}, Depth) ->
    with_ok(valid_line(Line), fun() ->
        with_ok(validate_expression(Key, Depth + 1), fun() -> validate_expression(Value, Depth + 1) end)
    end);
validate_map_field({map_field_exact, Line, Key, Value}, Depth) ->
    with_ok(valid_line(Line), fun() ->
        with_ok(validate_expression(Key, Depth + 1), fun() -> validate_expression(Value, Depth + 1) end)
    end);
validate_map_field(Field, _Depth) -> {error, {unsupported_map_field, summarize(Field)}}.

validate_bin_elements(Elements, Depth) when is_list(Elements), length(Elements) =< ?MAX_LIST ->
    validate_list(fun validate_bin_element/2, Elements, Depth);
validate_bin_elements(Elements, _Depth) -> {error, {invalid_binary_elements, summarize(Elements)}}.

validate_bin_element({bin_element, Line, Expression, default, default}, Depth) ->
    with_ok(valid_line(Line), fun() -> validate_expression(Expression, Depth + 1) end);
validate_bin_element(Element, _Depth) -> {error, {unsupported_binary_element, summarize(Element)}}.

validate_variable('_') -> ok;
validate_variable('ALANG_TASK_ID') -> ok;
validate_variable('ALANG_INPUTS') -> ok;
validate_variable('ALANG_CONTEXT') -> ok;
validate_variable('_ALANG_CONTEXT') -> ok;
validate_variable('ALANG_RESULT') -> ok;
validate_variable('ALANG_SEQUENCE_ERROR') -> ok;
validate_variable(Name) ->
    case lists:member(Name, variable_atoms()) of
        true -> ok;
        false -> {error, {unsupported_generated_variable, Name}}
    end.

validate_literal_atom(Atom) ->
    case lists:member(Atom, [
        true,
        false,
        alang_data_v1,
        alang_runtime_v1,
        alang_runtime_error_v1,
        product,
        ok,
        error,
        complete,
        unknown_task,
        verification_failed,
        source
    ]) of
        true -> ok;
        false -> {error, {unsupported_literal_atom, Atom}}
    end.

allowed_function(execute) -> true;
allowed_function(Name) -> lists:member(Name, callable_atoms()).

callable_atoms() ->
    [
        '$alang_callable_0', '$alang_callable_1', '$alang_callable_2', '$alang_callable_3',
        '$alang_callable_4', '$alang_callable_5', '$alang_callable_6', '$alang_callable_7',
        '$alang_callable_8', '$alang_callable_9', '$alang_callable_10', '$alang_callable_11',
        '$alang_callable_12', '$alang_callable_13', '$alang_callable_14', '$alang_callable_15'
    ].

variable_atoms() ->
    [
        'ALANG_V0', 'ALANG_V1', 'ALANG_V2', 'ALANG_V3', 'ALANG_V4', 'ALANG_V5',
        'ALANG_V6', 'ALANG_V7', 'ALANG_V8', 'ALANG_V9', 'ALANG_V10', 'ALANG_V11',
        'ALANG_V12', 'ALANG_V13', 'ALANG_V14', 'ALANG_V15', 'ALANG_V16', 'ALANG_V17',
        'ALANG_V18', 'ALANG_V19', 'ALANG_V20', 'ALANG_V21', 'ALANG_V22', 'ALANG_V23',
        'ALANG_V24', 'ALANG_V25', 'ALANG_V26', 'ALANG_V27', 'ALANG_V28', 'ALANG_V29',
        'ALANG_V30', 'ALANG_V31'
    ].

validate_list(_Validator, [], _Depth) -> ok;
validate_list(Validator, Values, Depth) ->
    validate_list(Validator, Values, Depth, 0).

validate_list(_Validator, [], _Depth, _Count) -> ok;
validate_list(Validator, [Value | Rest], Depth, Count) when Count < ?MAX_LIST ->
    with_ok(Validator(Value, Depth), fun() -> validate_list(Validator, Rest, Depth, Count + 1) end);
validate_list(_Validator, Values, _Depth, _Count) ->
    {error, {invalid_or_oversized_list, summarize(Values)}}.

with_depth(Depth, Function) when Depth =< ?MAX_DEPTH -> Function();
with_depth(_Depth, _Function) -> {error, abstract_format_too_deep}.

with_ok(ok, Function) -> Function();
with_ok({error, _} = Error, _Function) -> Error.

valid_line(Line) when is_integer(Line), Line >= 0 -> ok;
valid_line(Line) -> {error, {invalid_abstract_line, Line}}.

summarize(Value) when is_tuple(Value), tuple_size(Value) > 0 ->
    {tuple, element(1, Value), tuple_size(Value)};
summarize(Value) when is_tuple(Value) -> {tuple, empty, 0};
summarize(Value) when is_list(Value) -> {list, safe_length(Value)};
summarize(Value) when is_map(Value) -> {map, maps:size(Value)};
summarize(Value) -> Value.

safe_length(Value) ->
    try length(Value) of
        Length -> Length
    catch
        error:badarg -> improper
    end.
