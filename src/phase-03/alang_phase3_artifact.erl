-module(alang_phase3_artifact).

-export([inspect/1, load/1, purge/1, run/4]).

-define(GENERATED_MODULE, alang_phase3_program_v1).
-define(MAX_BEAM_BYTES, 1048576).

-spec inspect(binary()) -> {ok, map()} | {error, term()}.
inspect(Beam) when is_binary(Beam), byte_size(Beam) > 0, byte_size(Beam) =< ?MAX_BEAM_BYTES ->
    case beam_lib:all_chunks(Beam) of
        {ok, ?GENERATED_MODULE, Chunks} -> inspect_chunks(Beam, Chunks);
        {ok, Module, _Chunks} -> {error, {unexpected_beam_module, Module}};
        {error, beam_lib, Reason} -> {error, {invalid_beam_container, Reason}}
    end;
inspect(Beam) when is_binary(Beam), byte_size(Beam) > ?MAX_BEAM_BYTES ->
    {error, {beam_size_limit_exceeded, byte_size(Beam)}};
inspect(_) ->
    {error, invalid_beam_binary}.

-spec load(binary()) -> {ok, atom(), map()} | {error, term()}.
load(Beam) ->
    case inspect(Beam) of
        {ok, Inspection} -> load_inspected(Beam, Inspection);
        {error, _} = Error -> Error
    end.

-spec purge(atom()) -> ok | {error, term()}.
purge(?GENERATED_MODULE) ->
    case code:delete(?GENERATED_MODULE) of
        true ->
            case code:soft_purge(?GENERATED_MODULE) of
                true -> ok;
                false -> {error, active_code_references}
            end;
        false ->
            case code:is_loaded(?GENERATED_MODULE) of
                false -> ok;
                _ -> {error, module_delete_failed}
            end
    end;
purge(Module) -> {error, {unexpected_purge_module, Module}}.

-spec run(binary(), binary(), map(), map()) -> {ok, map()} | {error, map() | term()}.
run(Beam, TaskId, Inputs, Options) ->
    case load(Beam) of
        {ok, Module, _Inspection} -> run_loaded(Module, TaskId, Inputs, Options);
        {error, _} = Error -> Error
    end.

inspect_chunks(Beam, Chunks) ->
    ChunkIds = [Id || {Id, _Data} <- Chunks],
    ForbiddenChunks = ChunkIds -- allowed_chunks(),
    MissingChunks = required_chunks() -- ChunkIds,
    case {ForbiddenChunks, MissingChunks} of
        {[], []} -> inspect_decoded_chunks(Beam, lists:sort(ChunkIds));
        {[_ | _], _} -> {error, {forbidden_beam_chunks, ForbiddenChunks}};
        {[], [_ | _]} -> {error, {missing_beam_chunks, MissingChunks}}
    end.

inspect_decoded_chunks(Beam, ChunkIds) ->
    Requested = [attributes, compile_info, imports, exports],
    case beam_lib:chunks(Beam, Requested) of
        {ok, {?GENERATED_MODULE, Decoded}} -> validate_decoded(Beam, ChunkIds, Decoded);
        {error, beam_lib, Reason} -> {error, {beam_inspection_failed, Reason}}
    end.

validate_decoded(Beam, ChunkIds, Decoded) ->
    Attributes = proplists:get_value(attributes, Decoded, []),
    CompileInfo = proplists:get_value(compile_info, Decoded, []),
    Imports = lists:sort(proplists:get_value(imports, Decoded, [])),
    Exports = lists:sort(proplists:get_value(exports, Decoded, [])),
    case {
        extract_metadata(Attributes),
        validate_exports(Exports),
        validate_imports(Imports),
        validate_attributes(Attributes),
        validate_compiler(CompileInfo)
    } of
        {{ok, Metadata}, ok, ok, ok, {ok, CompilerVersion}} ->
            case validate_artifact_metadata(Metadata) of
                ok -> {ok, #{
                    policy => accepted,
                    module => ?GENERATED_MODULE,
                    beam_size => byte_size(Beam),
                    beam_sha256 => sha256(Beam),
                    metadata => Metadata,
                    imports => Imports,
                    exports => Exports,
                    chunks => ChunkIds,
                    compile_info => CompileInfo,
                    compiler_version => CompilerVersion
                }};
                {error, _} = Error -> Error
            end;
        {{error, _} = Error, _, _, _, _} -> Error;
        {_, {error, _} = Error, _, _, _} -> Error;
        {_, _, {error, _} = Error, _, _} -> Error;
        {_, _, _, {error, _} = Error, _} -> Error;
        {_, _, _, _, {error, _} = Error} -> Error
    end.

extract_metadata(Attributes) ->
    case proplists:get_all_values(alang_backend, Attributes) of
        [[Metadata]] when is_map(Metadata) -> {ok, Metadata};
        Other -> {error, {invalid_backend_metadata_attribute, summarize(Other)}}
    end.

validate_artifact_metadata(Metadata) ->
    case alang_phase3_forms:validate_metadata(Metadata) of
        ok -> validate_artifact_metadata_values(Metadata);
        {error, _} -> {error, incompatible_backend_metadata}
    end.

validate_artifact_metadata_values(#{
    source_sha256 := SourceDigest,
    ir_sha256 := IrDigest,
    toolchain := Toolchain
}) ->
    case {
        valid_digest(SourceDigest),
        valid_digest(IrDigest),
        Toolchain =:= alang_phase1_compiler:current_toolchain()
    } of
        {true, true, true} -> ok;
        {false, _, _} -> {error, invalid_source_digest};
        {_, false, _} -> {error, invalid_ir_digest};
        {_, _, false} -> {error, incompatible_artifact_toolchain}
    end.

validate_exports(Exports) ->
    Expected = lists:sort([{execute, 3}, {module_info, 0}, {module_info, 1}]),
    case Exports =:= Expected of
        true -> ok;
        false -> {error, {unexpected_beam_exports, Exports}}
    end.

validate_imports(Imports) ->
    Forbidden = Imports -- alang_phase3_contract:allowed_beam_imports(),
    case Forbidden of
        [] -> ok;
        _ -> {error, {forbidden_beam_imports, Forbidden}}
    end.

validate_attributes(Attributes) ->
    Names = lists:sort([Name || {Name, _Value} <- Attributes]),
    case Names =:= [alang_backend, vsn] of
        true -> ok;
        false -> {error, {unexpected_beam_attributes, Names}}
    end.

validate_compiler(CompileInfo) ->
    BeamVersion = proplists:get_value(version, CompileInfo),
    _ = application:load(compiler),
    case application:get_key(compiler, vsn) of
        {ok, BeamVersion} -> {ok, list_to_binary(BeamVersion)};
        {ok, CurrentVersion} -> {error, {compiler_version_mismatch, BeamVersion, CurrentVersion}};
        undefined -> {error, compiler_version_unavailable}
    end.

load_inspected(Beam, Inspection) ->
    case code:is_loaded(?GENERATED_MODULE) of
        false ->
            Digest = binary_to_list(maps:get(beam_sha256, Inspection)),
            SourceName = "alang-memory:" ++ Digest,
            case code:load_binary(?GENERATED_MODULE, SourceName, Beam) of
                {module, ?GENERATED_MODULE} -> {ok, ?GENERATED_MODULE, Inspection};
                {error, Reason} -> {error, {beam_load_failed, Reason}}
            end;
        Loaded -> {error, {generated_module_already_loaded, Loaded}}
    end.

run_loaded(Module, TaskId, Inputs, Options) ->
    Outcome = try alang_phase3_launcher:run(Module, TaskId, Inputs, Options) of
        Result -> Result
    catch
        Class:ExecutionReason ->
            {error, #{reason => {loaded_execution_exception, Class, ExecutionReason}, trace => []}}
    end,
    case purge(Module) of
        ok -> Outcome;
        {error, PurgeReason} -> {error, {artifact_purge_failed, PurgeReason, Outcome}}
    end.

allowed_chunks() ->
    ["AtU8", "Code", "StrT", "ImpT", "ExpT", "LitT", "LocT", "Attr", "CInf", "Dbgi", "Line", "Type"].

required_chunks() ->
    ["AtU8", "Code", "StrT", "ImpT", "ExpT", "LocT", "Attr", "CInf", "Dbgi", "Line", "Type"].

valid_digest(Digest) when is_binary(Digest), byte_size(Digest) =:= 64 ->
    lists:all(fun is_hex/1, binary_to_list(Digest));
valid_digest(_) -> false.

is_hex(Character) when Character >= $0, Character =< $9 -> true;
is_hex(Character) when Character >= $a, Character =< $f -> true;
is_hex(_) -> false.

sha256(Binary) ->
    iolist_to_binary([io_lib:format("~2.16.0b", [Byte]) || <<Byte>> <= crypto:hash(sha256, Binary)]).

summarize(Value) when is_list(Value) -> {list, length(Value)};
summarize(Value) when is_map(Value) -> {map, maps:size(Value)};
summarize(Value) -> Value.
