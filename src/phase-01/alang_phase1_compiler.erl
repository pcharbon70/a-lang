-module(alang_phase1_compiler).

-export([
    allowed_beam_imports/0,
    allowed_runtime_calls/0,
    check_toolchain/1,
    check_toolchain_config/1,
    compile_forms/2,
    current_toolchain/0,
    inspect_beam/1,
    load_toolchain_config/1,
    validate_allowed_forms/1
]).

-define(FIXED_MODULE, phase1_counter_v1).
-define(MAX_DEPTH, 64).
-define(MAX_LIST_LENGTH, 256).
-define(MAX_TUPLE_WIDTH, 8).

-type error_reason() :: term().
-type forms() :: [erl_parse:abstract_form()].
-type toolchain_config() :: map().

-spec load_toolchain_config(file:filename()) ->
    {ok, toolchain_config()} | {error, error_reason()}.
load_toolchain_config(Path) ->
    case file:consult(Path) of
        {ok, [Config]} when is_map(Config) ->
            validate_config(Config);
        {ok, Terms} ->
            {error, {invalid_toolchain_config, {expected_one_map, Terms}}};
        {error, Reason} ->
            {error, {toolchain_config_read_failed, Reason}}
    end.

-spec current_toolchain() -> map().
current_toolchain() ->
    OtpRelease = to_binary(erlang:system_info(otp_release)),
    OtpVersionPath = filename:join([
        code:root_dir(),
        "releases",
        binary_to_list(OtpRelease),
        "OTP_VERSION"
    ]),
    OtpVersion =
        case file:read_file(OtpVersionPath) of
            {ok, Value} -> to_binary(string:trim(binary_to_list(Value)));
            {error, Reason} -> {unavailable, Reason}
        end,
    #{
        otp_version => OtpVersion,
        otp_release => OtpRelease,
        erts_version => to_binary(erlang:system_info(version)),
        system_architecture => to_binary(erlang:system_info(system_architecture))
    }.

-spec check_toolchain(file:filename()) -> {ok, map()} | {error, error_reason()}.
check_toolchain(Path) ->
    case load_toolchain_config(Path) of
        {ok, Config} -> check_toolchain_config(Config);
        {error, _} = Error -> Error
    end.

-spec check_toolchain_config(toolchain_config()) ->
    {ok, map()} | {error, error_reason()}.
check_toolchain_config(Config) when is_map(Config) ->
    case validate_config(Config) of
        {ok, ValidConfig} ->
            Actual = current_toolchain(),
            Mismatches = toolchain_mismatches(ValidConfig, Actual),
            case Mismatches of
                [] -> {ok, Actual};
                _ -> {error, {toolchain_mismatch, Mismatches}}
            end;
        {error, _} = Error -> Error
    end;
check_toolchain_config(Other) ->
    {error, {invalid_toolchain_config, {expected_map, Other}}}.

-spec compile_forms(forms(), file:filename()) ->
    {ok, map()} | {error, error_reason()}.
compile_forms(Forms, ConfigPath) ->
    case load_toolchain_config(ConfigPath) of
        {ok, Config} ->
            case check_toolchain_config(Config) of
                {ok, Toolchain} ->
                    compile_checked_forms(Forms, Config, Toolchain);
                {error, _} = Error -> Error
            end;
        {error, _} = Error -> Error
    end.

-spec validate_allowed_forms(forms()) -> ok | {error, error_reason()}.
validate_allowed_forms(Forms) when is_list(Forms), length(Forms) =< 16 ->
    case Forms of
        [
            {attribute, ModuleLine, module, ?FIXED_MODULE},
            {attribute, ExportLine, export, [{start, 1}]},
            {function, FunctionLine, start, 1, Clauses}
        ] ->
            with_valid_lines(
                [ModuleLine, ExportLine, FunctionLine],
                fun() -> validate_clauses(Clauses, 0) end
            );
        _ ->
            {error, {unsupported_module_shape, summarize_forms(Forms)}}
    end;
validate_allowed_forms(Forms) when is_list(Forms) ->
    {error, {too_many_forms, length(Forms)}};
validate_allowed_forms(Other) ->
    {error, {invalid_forms, Other}}.

-spec allowed_runtime_calls() -> [{module(), atom(), arity()}].
allowed_runtime_calls() ->
    [
        {erlang, byte_size, 1},
        {erlang, exit, 1},
        {erlang, external_size, 1},
        {erlang, is_binary, 1},
        {erlang, is_integer, 1},
        {erlang, is_pid, 1},
        {erlang, node, 0},
        {erlang, node, 1},
        {erlang, self, 0}
    ].

-spec allowed_beam_imports() -> [{module(), atom(), arity()}].
allowed_beam_imports() ->
    allowed_runtime_calls() ++
        [
            {erlang, '+', 2},
            {erlang, get_module_info, 1},
            {erlang, get_module_info, 2}
        ].

-spec inspect_beam(binary()) -> {ok, map()} | {error, error_reason()}.
inspect_beam(Beam) when is_binary(Beam) ->
    Requested = [imports, exports, attributes, compile_info],
    case beam_lib:chunks(Beam, Requested) of
        {ok, {?FIXED_MODULE, Chunks}} ->
            Imports = proplists:get_value(imports, Chunks, []),
            Exports = proplists:get_value(exports, Chunks, []),
            ForbiddenImports = Imports -- allowed_beam_imports(),
            ExpectedExports = lists:sort([{module_info, 0}, {module_info, 1}, {start, 1}]),
            case {ForbiddenImports, lists:sort(Exports)} of
                {[], ExpectedExports} ->
                    {ok, #{
                        module => ?FIXED_MODULE,
                        imports => lists:sort(Imports),
                        exports => ExpectedExports,
                        attributes => proplists:get_value(attributes, Chunks, []),
                        compile_info => proplists:get_value(compile_info, Chunks, [])
                    }};
                {[_ | _], _} ->
                    {error, {forbidden_beam_imports, ForbiddenImports}};
                {[], ActualExports} ->
                    {error, {unexpected_beam_exports, ActualExports}}
            end;
        {ok, {Module, _Chunks}} ->
            {error, {unexpected_beam_module, Module}};
        {error, beam_lib, Reason} ->
            {error, {beam_inspection_failed, Reason}}
    end;
inspect_beam(Other) ->
    {error, {invalid_beam_binary, Other}}.

compile_checked_forms(Forms, Config, Toolchain) ->
    case validate_allowed_forms(Forms) of
        ok ->
            ValidationOptions = maps:get(validation_options, Config),
            case compile:forms(Forms, ValidationOptions) of
                {ok, ?FIXED_MODULE, []} ->
                    emit_checked_forms(Forms, Config, Toolchain);
                {ok, ?FIXED_MODULE, Warnings} ->
                    {error, {strong_validation_warnings, Warnings}};
                {error, Errors, Warnings} ->
                    {error, {strong_validation_failed, Errors, Warnings}};
                OtherValidation ->
                    {error, {unexpected_strong_validation_result, OtherValidation}}
            end;
        {error, _} = Error -> Error
    end.

emit_checked_forms(Forms, Config, Toolchain) ->
    CompilerOptions = maps:get(compiler_options, Config),
    case compile:forms(Forms, CompilerOptions) of
        {ok, ?FIXED_MODULE, Beam, []} ->
            case inspect_beam(Beam) of
                {ok, Inspection} ->
                    {ok, #{
                        module => ?FIXED_MODULE,
                        beam => Beam,
                        inspection => Inspection,
                        toolchain => Toolchain,
                        compiler_options => CompilerOptions
                    }};
                {error, _} = Error -> Error
            end;
        {ok, ?FIXED_MODULE, _Beam, Warnings} ->
            {error, {beam_emission_warnings, Warnings}};
        {error, Errors, Warnings} ->
            {error, {beam_emission_failed, Errors, Warnings}};
        OtherEmission ->
            {error, {unexpected_beam_emission_result, OtherEmission}}
    end.

validate_config(#{
    otp_version := OtpVersion,
    otp_release := OtpRelease,
    erts_version := ErtsVersion,
    system_architectures := Architectures,
    production_boundary := erlang_abstract_format,
    compiler_interface := {compile, forms, 2},
    validation_options := [strong_validation, return_errors, return_warnings],
    compiler_options := [
        binary,
        deterministic,
        no_debug_info,
        no_docs,
        return_errors,
        return_warnings
    ]
} = Config)
    when is_binary(OtpVersion),
         is_binary(OtpRelease),
         is_binary(ErtsVersion),
         is_list(Architectures),
         Architectures =/= [] ->
    case lists:all(fun is_binary/1, Architectures) of
        true -> {ok, Config};
        false -> {error, {invalid_toolchain_config, invalid_architectures}}
    end;
validate_config(Config) ->
    {error, {invalid_toolchain_config, Config}}.

toolchain_mismatches(Config, Actual) ->
    VersionFields = [otp_version, otp_release, erts_version],
    VersionMismatches = [
        {Field, maps:get(Field, Config), maps:get(Field, Actual)}
     || Field <- VersionFields,
        maps:get(Field, Config) =/= maps:get(Field, Actual)
    ],
    ActualArchitecture = maps:get(system_architecture, Actual),
    case lists:member(ActualArchitecture, maps:get(system_architectures, Config)) of
        true -> VersionMismatches;
        false ->
            VersionMismatches ++ [
                {
                    system_architecture,
                    maps:get(system_architectures, Config),
                    ActualArchitecture
                }
            ]
    end.

validate_clauses(Clauses, Depth)
    when is_list(Clauses), length(Clauses) > 0, length(Clauses) =< 32 ->
    validate_list(fun validate_clause/2, Clauses, Depth + 1);
validate_clauses(Clauses, _Depth) ->
    {error, {invalid_clause_count, safe_length(Clauses)}}.

validate_clause({clause, Line, Patterns, Guards, Body}, Depth) ->
    with_depth(Depth, fun() ->
        with_valid_line(Line, fun() ->
            with_ok(validate_list(fun validate_pattern/2, Patterns, Depth + 1), fun() ->
                with_ok(validate_guards(Guards, Depth + 1), fun() ->
                    validate_nonempty_expressions(Body, Depth + 1)
                end)
            end)
        end)
    end);
validate_clause(Other, _Depth) ->
    {error, {unsupported_clause, Other}}.

validate_guards(Guards, Depth) when is_list(Guards), length(Guards) =< 16 ->
    validate_list(
        fun(GuardSequence, InnerDepth) when is_list(GuardSequence) ->
            validate_list(fun validate_expression/2, GuardSequence, InnerDepth + 1);
           (Other, _InnerDepth) ->
            {error, {invalid_guard_sequence, Other}}
        end,
        Guards,
        Depth
    );
validate_guards(Other, _Depth) ->
    {error, {invalid_guards, Other}}.

validate_nonempty_expressions(Expressions, Depth)
    when is_list(Expressions), length(Expressions) > 0 ->
    validate_list(fun validate_expression/2, Expressions, Depth);
validate_nonempty_expressions(Other, _Depth) ->
    {error, {invalid_expression_body, Other}}.

validate_pattern({var, Line, Name}, _Depth) ->
    validate_variable(Line, Name);
validate_pattern({atom, Line, Value}, _Depth) ->
    validate_atom(Line, Value);
validate_pattern({integer, Line, Value}, _Depth) ->
    validate_integer(Line, Value);
validate_pattern({tuple, Line, Elements}, Depth)
    when is_list(Elements), length(Elements) =< ?MAX_TUPLE_WIDTH ->
    with_valid_line(Line, fun() ->
        validate_list(fun validate_pattern/2, Elements, Depth + 1)
    end);
validate_pattern({bin, Line, Elements}, Depth) ->
    with_valid_line(Line, fun() -> validate_bin_elements(Elements, Depth + 1) end);
validate_pattern(Other, _Depth) ->
    {error, {unsupported_pattern, Other}}.

validate_expression({var, Line, Name}, _Depth) ->
    validate_variable(Line, Name);
validate_expression({atom, Line, Value}, _Depth) ->
    validate_atom(Line, Value);
validate_expression({integer, Line, Value}, _Depth) ->
    validate_integer(Line, Value);
validate_expression({string, Line, Value}, _Depth)
    when is_list(Value), length(Value) =< 128 ->
    with_valid_line(Line, fun() -> ok end);
validate_expression({nil, Line}, _Depth) ->
    with_valid_line(Line, fun() -> ok end);
validate_expression({cons, Line, Head, Tail}, Depth) ->
    with_valid_line(Line, fun() ->
        with_ok(validate_expression(Head, Depth + 1), fun() ->
            validate_expression(Tail, Depth + 1)
        end)
    end);
validate_expression({tuple, Line, Elements}, Depth)
    when is_list(Elements), length(Elements) =< ?MAX_TUPLE_WIDTH ->
    with_valid_line(Line, fun() ->
        validate_list(fun validate_expression/2, Elements, Depth + 1)
    end);
validate_expression({bin, Line, Elements}, Depth) ->
    with_valid_line(Line, fun() -> validate_bin_elements(Elements, Depth + 1) end);
validate_expression({'case', Line, Value, Clauses}, Depth) ->
    with_valid_line(Line, fun() ->
        with_ok(validate_expression(Value, Depth + 1), fun() ->
            validate_clauses(Clauses, Depth + 1)
        end)
    end);
validate_expression({'receive', Line, Clauses}, Depth) ->
    with_valid_line(Line, fun() -> validate_clauses(Clauses, Depth + 1) end);
validate_expression({'receive', Line, Clauses, Timeout, AfterBody}, Depth) ->
    with_valid_line(Line, fun() ->
        with_ok(validate_clauses(Clauses, Depth + 1), fun() ->
            with_ok(validate_expression(Timeout, Depth + 1), fun() ->
                validate_nonempty_expressions(AfterBody, Depth + 1)
            end)
        end)
    end);
validate_expression({match, Line, Pattern, Value}, Depth) ->
    with_valid_line(Line, fun() ->
        with_ok(validate_pattern(Pattern, Depth + 1), fun() ->
            validate_expression(Value, Depth + 1)
        end)
    end);
validate_expression({op, Line, Operator, Argument}, Depth) ->
    case lists:member(Operator, ['not', '-', '+']) of
        true -> with_valid_line(Line, fun() -> validate_expression(Argument, Depth + 1) end);
        false -> {error, {unsupported_unary_operator, Operator}}
    end;
validate_expression({op, Line, Operator, Left, Right}, Depth) ->
    case lists:member(Operator, ['!', '+', '-', '=:=', '=/=', '<', '=<', '>', '>=', 'andalso', 'orelse']) of
        true ->
            with_valid_line(Line, fun() ->
                with_ok(validate_expression(Left, Depth + 1), fun() ->
                    validate_expression(Right, Depth + 1)
                end)
            end);
        false -> {error, {unsupported_binary_operator, Operator}}
    end;
validate_expression(
    {call, Line, {remote, RemoteLine, {atom, ModuleLine, Module}, {atom, NameLine, Name}}, Args},
    Depth
) when is_list(Args) ->
    Arity = length(Args),
    case lists:member({Module, Name, Arity}, allowed_runtime_calls()) of
        true ->
            with_valid_lines([Line, RemoteLine, ModuleLine, NameLine], fun() ->
                validate_list(fun validate_expression/2, Args, Depth + 1)
            end);
        false -> {error, {forbidden_remote_call, {Module, Name, Arity}}}
    end;
validate_expression(Other, _Depth) ->
    {error, {unsupported_expression, Other}}.

validate_bin_elements(Elements, Depth)
    when is_list(Elements), length(Elements) =< ?MAX_LIST_LENGTH ->
    validate_list(fun validate_bin_element/2, Elements, Depth);
validate_bin_elements(Other, _Depth) ->
    {error, {invalid_binary_elements, Other}}.

validate_bin_element({bin_element, Line, Value, default, default}, Depth) ->
    with_valid_line(Line, fun() -> validate_expression(Value, Depth + 1) end);
validate_bin_element({bin_element, Line, Value, Size, TypeSpecifiers}, Depth)
    when is_list(TypeSpecifiers), length(TypeSpecifiers) =< 8 ->
    with_valid_line(Line, fun() ->
        with_ok(validate_expression(Value, Depth + 1), fun() ->
            case Size of
                default -> ok;
                _ -> validate_expression(Size, Depth + 1)
            end
        end)
    end);
validate_bin_element(Other, _Depth) ->
    {error, {unsupported_binary_element, Other}}.

validate_variable(Line, Name) ->
    Allowed = [
        'Parent',
        'Envelope',
        'Correlation',
        'ReplyTo',
        'Payload',
        'Value',
        'Successor',
        'Other',
        'Abi',
        'Reason'
    ],
    case is_atom(Name) andalso lists:member(Name, Allowed) of
        true -> with_valid_line(Line, fun() -> ok end);
        false -> {error, {unsupported_variable, Name}}
    end.

validate_atom(Line, Value) ->
    Allowed = [
        alang_v1,
        alang_v2,
        run,
        input,
        operation,
        received,
        transition,
        waiting,
        completed,
        result,
        trace,
        ok,
        error,
        malformed_envelope,
        unsupported_abi,
        invalid_correlation,
        invalid_reply_target,
        invalid_payload,
        payload_too_large,
        unavailable_operation,
        unexpected_process_exit,
        normal,
        true,
        false
    ],
    case is_atom(Value) andalso lists:member(Value, Allowed) of
        true -> with_valid_line(Line, fun() -> ok end);
        false -> {error, {unsupported_atom, Value}}
    end.

validate_integer(Line, Value) when is_integer(Value), Value >= -1, Value =< 1000001 ->
    with_valid_line(Line, fun() -> ok end);
validate_integer(_Line, Value) ->
    {error, {unsupported_integer, Value}}.

validate_list(_Validator, [], _Depth) ->
    ok;
validate_list(Validator, List, Depth)
    when is_list(List), length(List) =< ?MAX_LIST_LENGTH ->
    with_depth(Depth, fun() ->
        lists:foldl(
            fun(Item, ok) -> Validator(Item, Depth + 1);
               (_Item, {error, _} = Error) -> Error
            end,
            ok,
            List
        )
    end);
validate_list(_Validator, List, _Depth) ->
    {error, {invalid_or_oversized_list, safe_length(List)}}.

with_valid_lines(Lines, Continuation) ->
    case lists:all(fun valid_line/1, Lines) of
        true -> Continuation();
        false -> {error, {invalid_source_annotations, Lines}}
    end.

with_valid_line(Line, Continuation) ->
    case valid_line(Line) of
        true -> Continuation();
        false -> {error, {invalid_source_annotation, Line}}
    end.

valid_line(Line) -> is_integer(Line) andalso Line >= 1 andalso Line =< 1000000.

with_depth(Depth, Continuation) when Depth =< ?MAX_DEPTH -> Continuation();
with_depth(Depth, _Continuation) -> {error, {form_depth_exceeded, Depth}}.

with_ok(ok, Continuation) -> Continuation();
with_ok({error, _} = Error, _Continuation) -> Error.

safe_length(Value) when is_list(Value) -> length(Value);
safe_length(_Value) -> not_a_list.

summarize_forms(Forms) when is_list(Forms) ->
    [element(1, Form) || Form <- Forms, is_tuple(Form), tuple_size(Form) > 0];
summarize_forms(Other) -> Other.

to_binary(Value) when is_binary(Value) -> Value;
to_binary(Value) when is_list(Value) -> unicode:characters_to_binary(Value);
to_binary(Value) when is_atom(Value) -> atom_to_binary(Value, utf8).
