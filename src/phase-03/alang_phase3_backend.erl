-module(alang_phase3_backend).

-export([compile_forms/2, compile_ir/3]).

-define(GENERATED_MODULE, alang_phase3_program_v1).

-spec compile_ir(map(), map(), file:filename()) -> {ok, map()} | {error, term()}.
compile_ir(Ir, Context, ToolchainPath) ->
    case alang_phase1_compiler:check_toolchain(ToolchainPath) of
        {ok, Toolchain} -> compile_ir_with_toolchain(Ir, Context, Toolchain);
        {error, _} = Error -> Error
    end.

compile_ir_with_toolchain(Ir, Context, Toolchain) ->
    case alang_phase3_lowering:lower(Ir, Context#{toolchain => Toolchain}) of
        {ok, Lowered} ->
            case validate_and_emit(maps:get(forms, Lowered), Toolchain) of
                {ok, Compilation} -> {ok, maps:merge(Lowered, Compilation)};
                {error, _} = Error -> Error
            end;
        {error, _} = Error -> Error
    end.

-spec compile_forms(list(), file:filename()) -> {ok, map()} | {error, term()}.
compile_forms(Forms, ToolchainPath) ->
    case alang_phase3_forms:validate(Forms) of
        ok ->
            case alang_phase1_compiler:check_toolchain(ToolchainPath) of
                {ok, Toolchain} -> validate_and_emit(canonicalize_metadata(Forms), Toolchain);
                {error, _} = Error -> Error
            end;
        {error, Reason} ->
            {error, backend_diagnostic(abstract_format_rejected, Reason, Forms)}
    end.

validate_and_emit(Forms, Toolchain) ->
    ValidationOptions = [
        binary,
        strong_validation,
        return_errors,
        return_warnings
    ],
    case compile:forms(Forms, ValidationOptions) of
        {ok, ?GENERATED_MODULE, []} ->
            emit(Forms, Toolchain, ValidationOptions);
        {ok, ?GENERATED_MODULE, Warnings} ->
            {error, backend_diagnostic(otp_validation_warning, Warnings, Forms)};
        {error, Errors, Warnings} ->
            Detail = #{errors => Errors, warnings => Warnings},
            {error, backend_diagnostic(otp_validation_failed, Detail, Forms)};
        Other ->
            {error, backend_diagnostic(unexpected_otp_validation_result, Other, Forms)}
    end.

emit(Forms, Toolchain, ValidationOptions) ->
    CompilerOptions = [
        binary,
        deterministic,
        no_debug_info,
        no_docs,
        return_errors,
        return_warnings
    ],
    case compile:forms(Forms, CompilerOptions) of
        {ok, ?GENERATED_MODULE, Beam, []} ->
            emit_evidence(Forms, Beam, Toolchain, ValidationOptions, CompilerOptions);
        {ok, ?GENERATED_MODULE, _Beam, Warnings} ->
            {error, backend_diagnostic(otp_emission_warning, Warnings, Forms)};
        {error, Errors, Warnings} ->
            Detail = #{errors => Errors, warnings => Warnings},
            {error, backend_diagnostic(otp_emission_failed, Detail, Forms)};
        Other ->
            {error, backend_diagnostic(unexpected_otp_emission_result, Other, Forms)}
    end.

emit_evidence(Forms, Beam, Toolchain, ValidationOptions, CompilerOptions) ->
    {ok, #{
        beam => Beam,
        beam_sha256 => sha256(Beam),
        forms_sha256 => sha256(term_to_binary(Forms, [deterministic])),
        strong_validation => passed,
        validation_options => ValidationOptions,
        compiler_options => CompilerOptions,
        toolchain => Toolchain,
        compiler_module => ?MODULE,
        compiler_module_path => code:which(?MODULE),
        compiler_engine => beam,
        otp_release => list_to_binary(erlang:system_info(otp_release))
    }}.

backend_diagnostic(Code, Detail, Forms) ->
    {NodeId, Origin} = diagnostic_origin(Detail, Forms),
    #{
        errors => [alang_phase3_contract:compile_error(Code, NodeId, Origin)],
        detail => Detail
    }.

diagnostic_origin(Detail, Forms) ->
    SourceMap = source_map(Forms),
    case diagnostic_line(Detail) of
        undefined -> first_origin(SourceMap);
        Line -> closest_origin(Line, SourceMap)
    end.

source_map([{attribute, _, alang_backend, Encoded} | _]) ->
    case alang_phase3_forms:decode_metadata(Encoded) of
        {ok, #{source_map := SourceMap}} -> SourceMap;
        _ -> []
    end;
source_map([_ | Rest]) -> source_map(Rest);
source_map([]) -> [].

canonicalize_metadata([{attribute, Line, alang_backend, Encoded} | Rest]) ->
    case alang_phase3_forms:decode_metadata(Encoded) of
        {ok, Metadata} -> [{attribute, Line, alang_backend,
            alang_phase3_forms:encode_metadata(Metadata)} | Rest];
        {error, _} -> [{attribute, Line, alang_backend, Encoded} | Rest]
    end;
canonicalize_metadata([Form | Rest]) -> [Form | canonicalize_metadata(Rest)];
canonicalize_metadata([]) -> [].

diagnostic_line(#{errors := Errors}) -> diagnostic_line(Errors);
diagnostic_line([{_File, [{Line, _Module, _Description} | _]} | _]) when is_integer(Line) -> Line;
diagnostic_line([{Line, _Module, _Description} | _]) when is_integer(Line) -> Line;
diagnostic_line([_ | Rest]) -> diagnostic_line(Rest);
diagnostic_line(_) -> undefined.

closest_origin(Line, SourceMap) ->
    case [{abs(SourceLine - Line), Id, Origin} || {Id, {source, _, SourceLine, _} = Origin} <- SourceMap] of
        [] -> first_origin(SourceMap);
        Candidates ->
            {_Distance, Id, Origin} = lists:min(Candidates),
            {Id, origin_map(Origin)}
    end.

first_origin([{Id, Origin} | _]) -> {Id, origin_map(Origin)};
first_origin([]) -> {<<"module">>, #{byte => 0, line => 1, column => 1}}.

origin_map({source, Byte, Line, Column}) -> #{byte => Byte, line => Line, column => Column};
origin_map(_) -> #{byte => 0, line => 1, column => 1}.

sha256(Binary) ->
    iolist_to_binary([io_lib:format("~2.16.0b", [Byte]) || <<Byte>> <= crypto:hash(sha256, Binary)]).
