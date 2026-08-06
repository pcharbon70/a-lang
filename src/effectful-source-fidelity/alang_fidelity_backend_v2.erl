-module(alang_fidelity_backend_v2).

-export([compile/2, compile_forms/2, lower_forms/2]).

-define(GENERATED_MODULE, alang_fidelity_program_v2).

-spec compile(map(), file:filename()) -> {ok, map()} | {error, map() | term()}.
compile(#{format := alang_lowered_program_v2} = Lowered, ToolchainPath) ->
    case alang_phase1_compiler:check_toolchain(ToolchainPath) of
        {ok, Toolchain} ->
            case lower_forms(Lowered, Toolchain) of
                {ok, Product} ->
                    case compile_forms(maps:get(forms, Product), ToolchainPath) of
                        {ok, Emitted} ->
                            Compilation = maps:merge(Product, Emitted),
                            case alang_fidelity_artifact_v2:inspect(
                                maps:get(beam, Compilation), maps:get(metadata, Compilation))
                            of
                                {ok, Inspection} -> {ok, Compilation#{inspection => Inspection}};
                                {error, _} = Error -> Error
                            end;
                        {error, _} = Error -> Error
                    end;
                {error, _} = Error -> Error
            end;
        {error, _} = Error -> Error
    end;
compile(_Lowered, _ToolchainPath) ->
    {error, public_diagnostic(invalid_lowered_program, undefined, #{})}.

-spec lower_forms(map(), map()) -> {ok, map()} | {error, map()}.
lower_forms(Lowered, Toolchain) ->
    try lower_validated(Lowered, Toolchain) of
        Product -> {ok, Product}
    catch
        throw:{backend_error, Code, Pointer} ->
            {error, public_diagnostic(Code, Pointer, metadata_from_lowered(Lowered))};
        _Class:_Reason ->
            {error, public_diagnostic(invalid_lowered_program, undefined,
                metadata_from_lowered(Lowered))}
    end.

lower_validated(Lowered, Toolchain) ->
    Ir = maps:get(ir, Lowered),
    case alang_fidelity_ir:validate(Ir) of
        ok -> ok;
        {error, _} -> fail(invalid_ir_v2, <<>>)
    end,
    require(maps:get(ir_digest, Lowered) =:= digest_ir(Ir),
        ir_digest_mismatch, <<>>),
    require(maps:get(semantic_digest, Lowered) =:= maps:get(semantic_digest, Ir),
        semantic_digest_mismatch, <<>>),
    require(maps:get(frontend, Lowered) =:= maps:get(frontend,
        maps:get(provenance, Lowered)), provenance_mismatch, <<>>),
    [Task] = maps:get(tasks, Ir),
    Nodes = maps:get(nodes, Ir),
    LineMap = line_map(Nodes),
    Metadata = metadata(Lowered, Ir, Task, LineMap, Toolchain),
    Forms = [
        {attribute, 1, module, ?GENERATED_MODULE},
        {attribute, 1, export, [{execute, 3}]},
        {attribute, 1, alang_backend,
            alang_fidelity_forms_v2:encode_metadata(Metadata)},
        execute_function(Task, Nodes)
    ],
    case alang_fidelity_forms_v2:validate(Forms) of
        ok -> #{module => ?GENERATED_MODULE, forms => Forms, metadata => Metadata};
        {error, {_Reason, Line}} -> fail(generated_forms_rejected, pointer_for_line(Line, LineMap))
    end.

metadata(Lowered, Ir, Task, LineMap, Toolchain) ->
    #{
        format => alang_backend_metadata_v2,
        module => ?GENERATED_MODULE,
        abi => alang_fidelity_runtime_abi_v1,
        ir_format => alang_typed_task_ir_v2,
        frontend => maps:get(frontend, Lowered),
        source_sha256 => maps:get(source_digest, Lowered),
        semantic_sha256 => maps:get(semantic_digest, Lowered),
        ir_sha256 => maps:get(ir_digest, Lowered),
        manifest => maps:get(manifest, Ir),
        task_id => maps:get(id, Task),
        parameters => maps:get(parameters, Task),
        task_limits => maps:get(limits, Task),
        static_bounds => maps:get(static_bounds, Task),
        child => maps:get(child, Task),
        completion => maps:get(completion, Task),
        error_branches => maps:get(error_branches, Task),
        terminal_class => maps:get(terminal_class, Task),
        source_map => maps:get(source_map, Lowered),
        line_map => LineMap,
        compiler => #{
            format => alang_fidelity_compiler_v2,
            module => ?MODULE,
            engine => beam
        },
        toolchain => Toolchain,
        reproducibility => #{
            forms_encoding => deterministic_etf,
            compiler_profile => alang_fidelity_otp29_v1
        }
    }.

metadata_from_lowered(Lowered) when is_map(Lowered) ->
    #{
        frontend => maps:get(frontend, Lowered, undefined),
        source_map => maps:get(source_map, Lowered, #{})
    };
metadata_from_lowered(_) -> #{}.

execute_function(Task, Nodes) ->
    TaskId = maps:get(id, Task),
    Inputs = {var, 1, 'ALANG_INPUTS'},
    Context = {var, 1, 'ALANG_CONTEXT'},
    Token = {var, 1, 'ALANG_TOKEN'},
    BeginError = {var, 1, 'ALANG_BEGIN_ERROR'},
    Begin = remote_call(1, begin_task, [Context, literal(TaskId), Inputs]),
    Body = {'case', 1, Begin, [
        {clause, 1, [ok_pattern(1, Token)], [], [lower_nodes(Nodes, Context, Token, Task)]},
        {clause, 1, [error_pattern(1, BeginError)], [], [error_tuple(1, BeginError)]}
    ]},
    {function, 1, execute, 3, [
        {clause, 1, [literal(TaskId), Inputs, Context], [], [Body]},
        {clause, 1, [{var, 1, '_'}, {var, 1, '_ALANG_INPUTS_UNKNOWN'},
            {var, 1, '_ALANG_CONTEXT_UNKNOWN'}], [], [
            {tuple, 1, [{atom, 1, error}, {atom, 1, unknown_task}]}
        ]}
    ]}.

lower_nodes([#{kind := complete} = Node], Context, Token, Task) ->
    Line = node_line(Node),
    remote_call(Line, complete, [
        Context,
        Token,
        literal(maps:get(action_id, Node)),
        literal(maps:get(completion, Task)),
        literal(maps:get(terminal_class, Task))
    ]);
lower_nodes([Node | Rest], Context, Token, Task) ->
    Line = node_line(Node),
    Ordinal = maps:get(effect_ordinal, Node),
    Value = {var, Line, value_variable(Ordinal)},
    Error = {var, Line, error_variable(Ordinal)},
    Function = case maps:get(kind, Node) of
        effect_request -> effect;
        delegate -> delegate
    end,
    Call = remote_call(Line, Function, [
        Context,
        Token,
        {integer, Line, Ordinal},
        literal(maps:get(action_id, Node)),
        literal(maps:get(operation, Node)),
        literal(maps:get(dependencies, Node))
    ]),
    {'case', Line, Call, [
        {clause, Line, [ok_pattern(Line, Value)], [], [
            lower_nodes(Rest, Context, Token, Task)
        ]},
        {clause, Line, [error_pattern(Line, Error)], [], [error_tuple(Line, Error)]}
    ]}.

remote_call(Line, Function, Arguments) ->
    {call, Line, {remote, Line,
        {atom, Line, alang_fidelity_runtime_abi}, {atom, Line, Function}}, Arguments}.

ok_pattern(Line, Value) -> {tuple, Line, [{atom, Line, ok}, Value]}.
error_pattern(Line, Value) -> {tuple, Line, [{atom, Line, error}, Value]}.
error_tuple(Line, Value) -> {tuple, Line, [{atom, Line, error}, Value]}.

literal(Value) -> erl_parse:abstract(Value).

value_variable(Ordinal) ->
    list_to_atom("_ALANG_VALUE_" ++ integer_to_list(Ordinal)).

error_variable(Ordinal) ->
    list_to_atom("ALANG_ERROR_" ++ integer_to_list(Ordinal)).

node_line(Node) -> maps:get(effect_ordinal, Node, length(maps:get(dependencies, Node))) + 2.

line_map(Nodes) ->
    [#{
        line => node_line(Node),
        node_id => maps:get(id, Node),
        pointer => action_pointer(Index)
    } || {Node, Index} <- lists:zip(Nodes, lists:seq(0, length(Nodes) - 1))].

action_pointer(Index) ->
    iolist_to_binary(io_lib:format("/actions/~B", [Index])).

pointer_for_line(Line, LineMap) ->
    case [Entry || Entry <- LineMap, maps:get(line, Entry) =:= Line] of
        [#{pointer := Pointer} | _] -> Pointer;
        [] -> <<>>
    end.

digest_ir(Ir) ->
    case alang_fidelity_ir:digest(Ir) of
        {ok, Digest} -> Digest;
        {error, _} -> fail(invalid_ir_v2, <<>>)
    end.

-spec compile_forms(list(), file:filename()) -> {ok, map()} | {error, map() | term()}.
compile_forms(Forms, ToolchainPath) ->
    Metadata = forms_metadata(Forms),
    case alang_fidelity_forms_v2:validate(Forms) of
        ok ->
            case alang_phase1_compiler:check_toolchain(ToolchainPath) of
                {ok, Toolchain} -> validate_and_emit(Forms, Toolchain, Metadata);
                {error, _} = Error -> Error
            end;
        {error, {Reason, Line}} ->
            {error, public_diagnostic(Reason, pointer_from_metadata(Line, Metadata), Metadata)}
    end.

validate_and_emit(Forms, Toolchain, Metadata) ->
    Validation = [binary, strong_validation, return_errors, return_warnings],
    case compile:forms(Forms, Validation) of
        {ok, ?GENERATED_MODULE, []} -> emit(Forms, Toolchain, Metadata, Validation);
        {ok, ?GENERATED_MODULE, _Warnings} ->
            {error, compile_diagnostic(otp_validation_warning, Metadata)};
        {error, Errors, _Warnings} ->
            {error, compile_diagnostic(otp_validation_failed,
                Metadata, compiler_line(Errors))};
        _ -> {error, compile_diagnostic(unexpected_otp_validation_result, Metadata)}
    end.

emit(Forms, Toolchain, Metadata, Validation) ->
    Options = [binary, deterministic, no_debug_info, no_docs,
        return_errors, return_warnings],
    case compile:forms(Forms, Options) of
        {ok, ?GENERATED_MODULE, Beam, []} ->
            {ok, #{
                beam => Beam,
                beam_sha256 => sha256(Beam),
                forms_sha256 => sha256(term_to_binary(Forms, [deterministic])),
                metadata_sha256 => sha256(alang_fidelity_forms_v2:encode_metadata(Metadata)),
                strong_validation => passed,
                validation_options => Validation,
                compiler_options => Options,
                toolchain => Toolchain,
                compiler_module => ?MODULE,
                compiler_module_path => code:which(?MODULE),
                compiler_engine => beam,
                otp_release => list_to_binary(erlang:system_info(otp_release))
            }};
        {ok, ?GENERATED_MODULE, _Beam, _Warnings} ->
            {error, compile_diagnostic(otp_emission_warning, Metadata)};
        {error, Errors, _Warnings} ->
            {error, compile_diagnostic(otp_emission_failed,
                Metadata, compiler_line(Errors))};
        _ -> {error, compile_diagnostic(unexpected_otp_emission_result, Metadata)}
    end.

forms_metadata(Forms) ->
    case [Encoded || {attribute, _, alang_backend, Encoded} <- Forms] of
        [Encoded] ->
            case alang_fidelity_forms_v2:decode_metadata(Encoded) of
                {ok, Metadata} -> Metadata;
                {error, _} -> #{}
            end;
        _ -> #{}
    end.

compile_diagnostic(Code, Metadata) -> public_diagnostic(Code, <<>>, Metadata).
compile_diagnostic(Code, Metadata, Line) ->
    public_diagnostic(Code, pointer_from_metadata(Line, Metadata), Metadata).

pointer_from_metadata(Line, Metadata) ->
    pointer_for_line(Line, maps:get(line_map, Metadata, [])).

compiler_line([{_File, [{Line, _Module, _Description} | _]} | _]) -> Line;
compiler_line([{Line, _Module, _Description} | _]) -> Line;
compiler_line([_ | Rest]) -> compiler_line(Rest);
compiler_line(_) -> 1.

public_diagnostic(Code, Pointer, Metadata) ->
    Location = public_location(Pointer, Metadata),
    #{
        class => backend,
        code => Code,
        severity => error,
        message => <<"generated BEAM backend rejected the checked program">>,
        location => Location
    }.

public_location(Pointer, Metadata) ->
    SourceMap = maps:get(source_map, Metadata, #{}),
    Origin = maps:get(Pointer, SourceMap, maps:get(<<>>, SourceMap, #{})),
    case maps:get(frontend, Metadata, undefined) of
        alang_source -> #{
            frontend => alang_source,
            byte => maps:get(byte, Origin, 0),
            line => maps:get(line, Origin, 1),
            column => maps:get(column, Origin, 1)
        };
        typed_json -> #{
            frontend => typed_json,
            pointer => maps:get(pointer, Origin, Pointer),
            offset => maps:get(byte, Origin, 0)
        };
        _ -> #{frontend => unknown, byte => 0}
    end.

require(true, _Code, _Pointer) -> ok;
require(false, Code, Pointer) -> fail(Code, Pointer).

fail(Code, Pointer) -> throw({backend_error, Code, Pointer}).

sha256(Binary) ->
    iolist_to_binary([io_lib:format("~2.16.0b", [Byte]) ||
        <<Byte>> <= crypto:hash(sha256, Binary)]).
