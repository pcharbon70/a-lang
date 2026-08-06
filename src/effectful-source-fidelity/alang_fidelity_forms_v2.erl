-module(alang_fidelity_forms_v2).

-export([
    decode_metadata/1,
    encode_metadata/1,
    generated_module/0,
    runtime_calls/1,
    validate/1,
    validate_metadata/1
]).

-define(GENERATED_MODULE, alang_fidelity_program_v2).
-define(MAX_FORMS, 8).
-define(MAX_METADATA_BYTES, 524288).
-define(MAX_DEPTH, 96).

-spec generated_module() -> atom().
generated_module() -> ?GENERATED_MODULE.

-spec encode_metadata(map()) -> binary().
encode_metadata(Metadata) ->
    term_to_binary({alang_backend_metadata_v2, Metadata}, [deterministic]).

-spec decode_metadata(binary()) -> {ok, map()} | {error, atom()}.
decode_metadata(<<131, 80, _/binary>>) ->
    {error, compressed_backend_metadata};
decode_metadata(Binary) when is_binary(Binary), byte_size(Binary) =< ?MAX_METADATA_BYTES ->
    try binary_to_term(Binary, [safe, used]) of
        {{alang_backend_metadata_v2, Metadata}, Used} when Used =:= byte_size(Binary) ->
            case encode_metadata(Metadata) of
                Binary ->
                    case validate_metadata(Metadata) of
                        ok -> {ok, Metadata};
                        {error, _} -> {error, invalid_backend_metadata}
                    end;
                _ -> {error, noncanonical_backend_metadata}
            end;
        {_Term, Used} when Used =/= byte_size(Binary) ->
            {error, trailing_backend_metadata};
        _ -> {error, invalid_backend_metadata_envelope}
    catch
        error:badarg -> {error, invalid_backend_metadata_etf}
    end;
decode_metadata(Binary) when is_binary(Binary) ->
    {error, backend_metadata_too_large};
decode_metadata(_) ->
    {error, invalid_backend_metadata_etf}.

-spec validate_metadata(term()) -> ok | {error, atom()}.
validate_metadata(Metadata) when is_map(Metadata) ->
    Keys = [
        format, module, abi, ir_format, frontend, source_sha256,
        semantic_sha256, ir_sha256, manifest, task_id, parameters,
        task_limits, static_bounds, child, completion, error_branches,
        terminal_class, source_map, line_map, compiler, toolchain,
        reproducibility
    ],
    case lists:sort(maps:keys(Metadata)) =:= lists:sort(Keys) of
        false -> {error, invalid_backend_metadata_shape};
        true -> validate_metadata_values(Metadata)
    end;
validate_metadata(_) ->
    {error, invalid_backend_metadata_shape}.

validate_metadata_values(Metadata) ->
    Checks = [
        maps:get(format, Metadata) =:= alang_backend_metadata_v2,
        maps:get(module, Metadata) =:= ?GENERATED_MODULE,
        maps:get(abi, Metadata) =:= alang_fidelity_runtime_abi_v1,
        maps:get(ir_format, Metadata) =:= alang_typed_task_ir_v2,
        lists:member(maps:get(frontend, Metadata), [alang_source, typed_json]),
        valid_digest(maps:get(source_sha256, Metadata)),
        valid_digest(maps:get(semantic_sha256, Metadata)),
        valid_digest(maps:get(ir_sha256, Metadata)),
        is_map(maps:get(manifest, Metadata)),
        is_binary(maps:get(task_id, Metadata)),
        is_list(maps:get(parameters, Metadata)),
        valid_limits(maps:get(task_limits, Metadata)),
        valid_limits(maps:get(static_bounds, Metadata)),
        valid_child(maps:get(child, Metadata)),
        valid_completion(maps:get(completion, Metadata)),
        is_list(maps:get(error_branches, Metadata)),
        lists:member(maps:get(terminal_class, Metadata),
            [<<"complete">>, <<"failed">>, <<"needs-clarification">>]),
        valid_source_map(maps:get(source_map, Metadata)),
        valid_line_map(maps:get(line_map, Metadata)),
        maps:get(compiler, Metadata) =:= #{
            format => alang_fidelity_compiler_v2,
            module => alang_fidelity_backend_v2,
            engine => beam
        },
        is_map(maps:get(toolchain, Metadata)),
        maps:get(reproducibility, Metadata) =:= #{
            forms_encoding => deterministic_etf,
            compiler_profile => alang_fidelity_otp29_v1
        }
    ],
    case lists:all(fun(Value) -> Value =:= true end, Checks) of
        true -> validate_metadata_relationships(Metadata);
        false -> {error, invalid_backend_metadata_value}
    end.

validate_metadata_relationships(Metadata) ->
    Limits = maps:get(task_limits, Metadata),
    Bounds = maps:get(static_bounds, Metadata),
    Keys = limit_keys(),
    case lists:all(fun(Key) -> maps:get(Key, Limits) >= maps:get(Key, Bounds) end, Keys) of
        true -> ok;
        false -> {error, backend_limit_below_static_bound}
    end.

valid_limits(Limits) when is_map(Limits) ->
    Keys = limit_keys(),
    lists:sort(maps:keys(Limits)) =:= lists:sort(Keys) andalso
        lists:all(fun(Key) ->
            Value = maps:get(Key, Limits),
            is_integer(Value) andalso Value >= minimum(Key)
        end, Keys);
valid_limits(_) -> false.

valid_child(none) -> true;
valid_child(Child) when is_map(Child) ->
    maps:get(format, Child, invalid) =:= alang_child_descriptor_v2 andalso
        valid_limits(maps:get(limits, Child, invalid)) andalso
        is_list(maps:get(effects, Child, invalid)) andalso
        is_list(maps:get(requirements, Child, invalid)) andalso
        is_map(maps:get(resources, Child, invalid));
valid_child(_) -> false.

valid_completion(#{predicates := Predicates, terminal_class := Terminal}) ->
    is_list(Predicates) andalso Predicates =/= [] andalso
        lists:member(Terminal, [<<"complete">>, <<"failed">>, <<"needs-clarification">>]);
valid_completion(_) -> false.

valid_source_map(SourceMap) when is_map(SourceMap), map_size(SourceMap) =< 256 ->
    lists:all(fun({Pointer, Origin}) ->
        is_binary(Pointer) andalso is_map(Origin) andalso
            byte_size(term_to_binary(Origin, [deterministic])) =< 4096
    end, maps:to_list(SourceMap));
valid_source_map(_) -> false.

valid_line_map(LineMap) when is_list(LineMap), length(LineMap) =< 16 ->
    lists:all(fun
        (#{line := Line, node_id := NodeId, pointer := Pointer}) ->
            is_integer(Line) andalso Line > 0 andalso
                is_binary(NodeId) andalso is_binary(Pointer);
        (_) -> false
    end, LineMap);
valid_line_map(_) -> false.

limit_keys() -> [steps, model_calls, repair_calls, child_calls,
    workspace_writes, output_bytes, timeout_ms].

minimum(steps) -> 1;
minimum(output_bytes) -> 1;
minimum(timeout_ms) -> 1;
minimum(_) -> 0.

-spec validate(term()) -> ok | {error, term()}.
validate(Forms) when is_list(Forms), length(Forms) =< ?MAX_FORMS ->
    case Forms of
        [
            {attribute, _, module, ?GENERATED_MODULE},
            {attribute, _, export, [{execute, 3}]},
            {attribute, _, alang_backend, Encoded},
            {function, _, execute, 3, Clauses}
        ] ->
            case decode_metadata(Encoded) of
                {ok, _Metadata} -> validate_clauses(Clauses, 0);
                {error, Reason} -> {error, {Reason, 1}}
            end;
        _ -> {error, {invalid_generated_form_envelope, 1}}
    end;
validate(_) ->
    {error, {invalid_or_oversized_generated_forms, 1}}.

-spec runtime_calls(list()) -> [{module(), atom(), arity()}].
runtime_calls(Forms) -> lists:usort(collect_calls(Forms, [])).

collect_calls({call, _Line, {remote, _RemoteLine,
        {atom, _ModuleLine, Module}, {atom, _FunctionLine, Function}}, Arguments}, Acc) ->
    lists:foldl(fun collect_calls/2,
        [{Module, Function, length(Arguments)} | Acc], Arguments);
collect_calls(Tuple, Acc) when is_tuple(Tuple) ->
    lists:foldl(fun collect_calls/2, Acc, tuple_to_list(Tuple));
collect_calls(List, Acc) when is_list(List) ->
    lists:foldl(fun collect_calls/2, Acc, List);
collect_calls(_Value, Acc) -> Acc.

validate_clauses(Clauses, Depth) when is_list(Clauses), length(Clauses) =< 4 ->
    validate_list(fun validate_clause/2, Clauses, Depth + 1);
validate_clauses(_Clauses, _Depth) -> {error, {invalid_execute_clauses, 1}}.

validate_clause({clause, Line, Patterns, Guards, Body}, Depth) ->
    with_depth(Depth, Line, fun() ->
        case Guards of
            [] ->
                with_ok(validate_list(fun validate_pattern/2, Patterns, Depth + 1),
                    fun() -> validate_list(fun validate_expression/2, Body, Depth + 1) end);
            _ -> {error, {generated_guards_forbidden, line(Line)}}
        end
    end);
validate_clause(_Clause, _Depth) -> {error, {invalid_generated_clause, 1}}.

validate_pattern({var, Line, Name}, _Depth) -> validate_variable(Name, Line);
validate_pattern({atom, _Line, _Atom}, _Depth) -> ok;
validate_pattern({integer, _Line, _Integer}, _Depth) -> ok;
validate_pattern({tuple, Line, Elements}, Depth) ->
    with_depth(Depth, Line,
        fun() -> validate_list(fun validate_pattern/2, Elements, Depth + 1) end);
validate_pattern({bin, Line, Elements}, Depth) ->
    with_depth(Depth, Line,
        fun() -> validate_list(fun validate_bin_element/2, Elements, Depth + 1) end);
validate_pattern(Pattern, _Depth) -> {error, {forbidden_generated_pattern, form_line(Pattern)}}.

validate_expression({var, Line, Name}, _Depth) -> validate_variable(Name, Line);
validate_expression({atom, _Line, _Atom}, _Depth) -> ok;
validate_expression({integer, _Line, _Integer}, _Depth) -> ok;
validate_expression({nil, _Line}, _Depth) -> ok;
validate_expression({cons, Line, Head, Tail}, Depth) ->
    with_depth(Depth, Line, fun() ->
        with_ok(validate_expression(Head, Depth + 1),
            fun() -> validate_expression(Tail, Depth + 1) end)
    end);
validate_expression({tuple, Line, Elements}, Depth) ->
    with_depth(Depth, Line,
        fun() -> validate_list(fun validate_expression/2, Elements, Depth + 1) end);
validate_expression({map, Line, Fields}, Depth) ->
    with_depth(Depth, Line,
        fun() -> validate_list(fun validate_map_field/2, Fields, Depth + 1) end);
validate_expression({bin, Line, Elements}, Depth) ->
    with_depth(Depth, Line,
        fun() -> validate_list(fun validate_bin_element/2, Elements, Depth + 1) end);
validate_expression({'case', Line, Value, Clauses}, Depth) ->
    with_depth(Depth, Line, fun() ->
        with_ok(validate_expression(Value, Depth + 1),
            fun() -> validate_clauses(Clauses, Depth + 1) end)
    end);
validate_expression({call, Line, {remote, _RemoteLine,
        {atom, _ModuleLine, Module}, {atom, _FunctionLine, Function}}, Arguments}, Depth) ->
    with_depth(Depth, Line, fun() ->
        Call = {Module, Function, length(Arguments)},
        case lists:member(Call, allowed_runtime_calls()) of
            true -> validate_list(fun validate_expression/2, Arguments, Depth + 1);
            false -> {error, {forbidden_generated_remote_call, line(Line)}}
        end
    end);
validate_expression(Expression, _Depth) ->
    {error, {forbidden_generated_expression, form_line(Expression)}}.

validate_map_field({map_field_assoc, _Line, Key, Value}, Depth) ->
    with_ok(validate_expression(Key, Depth + 1),
        fun() -> validate_expression(Value, Depth + 1) end);
validate_map_field(_Field, _Depth) -> {error, {forbidden_generated_map_field, 1}}.

validate_bin_element({bin_element, _Line, Expression, default, default}, Depth) ->
    validate_expression(Expression, Depth + 1);
validate_bin_element({bin_element, _Line, Expression, Size, Types}, Depth) ->
    with_ok(validate_expression(Expression, Depth + 1), fun() ->
        with_ok(validate_expression(Size, Depth + 1), fun() ->
            case is_list(Types) of
                true -> ok;
                false -> {error, {forbidden_generated_binary_type, 1}}
            end
        end)
    end);
validate_bin_element(_Element, _Depth) -> {error, {forbidden_generated_binary, 1}}.

allowed_runtime_calls() ->
    [
        {alang_fidelity_runtime_abi, begin_task, 3},
        {alang_fidelity_runtime_abi, effect, 6},
        {alang_fidelity_runtime_abi, delegate, 6},
        {alang_fidelity_runtime_abi, complete, 5}
    ].

validate_variable(Name, _Line) when Name =:= '_' -> ok;
validate_variable(Name, Line) when is_atom(Name) ->
    Text = atom_to_list(Name),
    case lists:prefix("ALANG_", Text) orelse lists:prefix("_ALANG_", Text) of
        true -> ok;
        false -> {error, {unsupported_generated_variable, line(Line)}}
    end;
validate_variable(_Name, Line) -> {error, {unsupported_generated_variable, line(Line)}}.

validate_list(_Validator, [], _Depth) -> ok;
validate_list(Validator, [Value | Rest], Depth) ->
    with_ok(Validator(Value, Depth), fun() -> validate_list(Validator, Rest, Depth) end);
validate_list(_Validator, _Improper, _Depth) -> {error, {improper_generated_list, 1}}.

with_depth(Depth, _Line, Function) when Depth =< ?MAX_DEPTH -> Function();
with_depth(_Depth, Line, _Function) -> {error, {generated_forms_too_deep, line(Line)}}.

with_ok(ok, Function) -> Function();
with_ok({error, _} = Error, _Function) -> Error.

form_line(Tuple) when is_tuple(Tuple), tuple_size(Tuple) >= 2 -> line(element(2, Tuple));
form_line(_) -> 1.

line(Anno) when is_integer(Anno), Anno >= 0 -> Anno;
line(Anno) ->
    try erl_anno:line(Anno) of
        undefined -> 1;
        Value -> Value
    catch
        _:_ -> 1
    end.

valid_digest(Digest) when is_binary(Digest), byte_size(Digest) =:= 64 ->
    re:run(Digest, <<"^[0-9a-f]{64}$">>, [{capture, none}]) =:= match;
valid_digest(_) -> false.
