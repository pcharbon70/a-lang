-module(alang_fidelity_artifact_v2).

-export([inspect/1, inspect/2, load/2, purge/0]).

-define(GENERATED_MODULE, alang_fidelity_program_v2).
-define(MAX_BEAM_BYTES, 2097152).

-spec inspect(binary()) -> {ok, map()} | {error, term()}.
inspect(Beam) when is_binary(Beam), byte_size(Beam) > 0,
        byte_size(Beam) =< ?MAX_BEAM_BYTES ->
    case beam_lib:all_chunks(Beam) of
        {ok, ?GENERATED_MODULE, Chunks} -> inspect_chunks(Beam, Chunks);
        {ok, Module, _Chunks} -> {error, {unexpected_beam_module, Module}};
        {error, beam_lib, Reason} -> {error, {invalid_beam_container, Reason}}
    end;
inspect(Beam) when is_binary(Beam), byte_size(Beam) > ?MAX_BEAM_BYTES ->
    {error, {beam_size_limit_exceeded, byte_size(Beam)}};
inspect(_) -> {error, invalid_beam_binary}.

-spec inspect(binary(), map()) -> {ok, map()} | {error, term()}.
inspect(Beam, Expected) ->
    ExpectedMetadata = maps:get(metadata, Expected, Expected),
    case alang_fidelity_forms_v2:validate_metadata(ExpectedMetadata) of
        ok ->
            case inspect(Beam) of
                {ok, #{metadata := ExpectedMetadata} = Inspection} -> {ok, Inspection};
                {ok, #{metadata := Actual}} ->
                    {error, {artifact_binding_mismatch,
                        first_metadata_difference(ExpectedMetadata, Actual)}};
                {error, _} = Error -> Error
            end;
        {error, Reason} -> {error, {invalid_expected_artifact_binding, Reason}}
    end.

-spec load(binary(), map()) -> {ok, atom(), map()} | {error, term()}.
load(Beam, Expected) ->
    case inspect(Beam, Expected) of
        {ok, Inspection} -> load_inspected(Beam, Inspection);
        {error, _} = Error -> Error
    end.

-spec purge() -> ok | {error, term()}.
purge() ->
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
    end.

inspect_chunks(Beam, Chunks) ->
    ChunkIds = [Id || {Id, _} <- Chunks],
    case {ChunkIds -- allowed_chunks(), required_chunks() -- ChunkIds} of
        {[], []} -> inspect_decoded(Beam, Chunks, lists:sort(ChunkIds));
        {Forbidden, _} when Forbidden =/= [] ->
            {error, {forbidden_beam_chunks, Forbidden}};
        {[], Missing} -> {error, {missing_beam_chunks, Missing}}
    end.

inspect_decoded(Beam, RawChunks, ChunkIds) ->
    case beam_lib:chunks(Beam, [attributes, compile_info, imports, exports]) of
        {ok, {?GENERATED_MODULE, Decoded}} ->
            validate_decoded(Beam, RawChunks, ChunkIds, Decoded);
        {error, beam_lib, Reason} -> {error, {beam_inspection_failed, Reason}}
    end.

validate_decoded(Beam, RawChunks, ChunkIds, Decoded) ->
    Attributes = proplists:get_value(attributes, Decoded, []),
    CompileInfo = proplists:get_value(compile_info, Decoded, []),
    Imports = lists:sort(proplists:get_value(imports, Decoded, [])),
    Exports = lists:sort(proplists:get_value(exports, Decoded, [])),
    case extract_metadata(Attributes) of
        {ok, Metadata} ->
            case validate_container(Metadata, Attributes, CompileInfo, Imports, Exports) of
                {ok, CompilerVersion} ->
                    ExecutableDigest = executable_digest(RawChunks, Imports, Exports),
                    {ok, #{
                        policy => accepted,
                        module => ?GENERATED_MODULE,
                        beam_size => byte_size(Beam),
                        beam_sha256 => sha256(Beam),
                        executable_sha256 => ExecutableDigest,
                        semantic_artifact_sha256 => sha256(term_to_binary({
                            maps:get(ir_sha256, Metadata), ExecutableDigest,
                            Imports, Exports
                        }, [deterministic])),
                        metadata => Metadata,
                        metadata_sha256 => sha256(
                            alang_fidelity_forms_v2:encode_metadata(Metadata)),
                        imports => Imports,
                        exports => Exports,
                        chunks => ChunkIds,
                        compiler_version => CompilerVersion
                    }};
                {error, _} = Error -> Error
            end;
        {error, _} = Error -> Error
    end.

extract_metadata(Attributes) ->
    case proplists:get_all_values(alang_backend, Attributes) of
        [[Encoded]] ->
            case alang_fidelity_forms_v2:decode_metadata(Encoded) of
                {ok, Metadata} -> {ok, Metadata};
                {error, Reason} -> {error, {invalid_backend_metadata_attribute, Reason}}
            end;
        Other -> {error, {invalid_backend_metadata_attribute, summarize(Other)}}
    end.

validate_container(Metadata, Attributes, CompileInfo, Imports, Exports) ->
    Checks = [
        validate_metadata(Metadata),
        validate_attributes(Attributes),
        validate_exports(Exports),
        validate_imports(Imports, Metadata),
        validate_compiler(CompileInfo)
    ],
    first_error_or_compiler(Checks).

first_error_or_compiler([ok, ok, ok, ok, {ok, Version}]) -> {ok, Version};
first_error_or_compiler([{error, _} = Error | _]) -> Error;
first_error_or_compiler([_ | Rest]) -> first_error_or_compiler(Rest).

validate_metadata(Metadata) ->
    case alang_fidelity_forms_v2:validate_metadata(Metadata) of
        ok ->
            case maps:get(toolchain, Metadata) =:=
                    alang_phase1_compiler:current_toolchain() of
                true -> ok;
                false -> {error, incompatible_artifact_toolchain}
            end;
        {error, _} -> {error, incompatible_backend_metadata}
    end.

validate_attributes(Attributes) ->
    Names = lists:sort([Name || {Name, _} <- Attributes]),
    case Names =:= [alang_backend, vsn] of
        true -> ok;
        false -> {error, {unexpected_beam_attributes, Names}}
    end.

validate_exports(Exports) ->
    Expected = lists:sort([{execute, 3}, {module_info, 0}, {module_info, 1}]),
    case Exports =:= Expected of
        true -> ok;
        false -> {error, {unexpected_beam_exports, Exports}}
    end.

validate_imports(Imports, Metadata) ->
    Base = [
        {alang_fidelity_runtime_abi, begin_task, 3},
        {alang_fidelity_runtime_abi, complete, 5},
        {erlang, get_module_info, 1},
        {erlang, get_module_info, 2}
    ],
    Operations = maps:get(operations, maps:get(manifest, Metadata)),
    HasDelegate = lists:any(fun(Operation) ->
        maps:get(semantic_operation, Operation) =:= <<"child.run">>
    end, Operations),
    HasEffect = lists:any(fun(Operation) ->
        maps:get(semantic_operation, Operation) =/= <<"child.run">>
    end, Operations),
    Expected = lists:sort(Base ++ optional_import(HasEffect, effect, 6) ++
        optional_import(HasDelegate, delegate, 6)),
    case Imports =:= Expected of
        true -> ok;
        false -> {error, {unexpected_beam_imports, Imports}}
    end.

optional_import(true, Function, Arity) ->
    [{alang_fidelity_runtime_abi, Function, Arity}];
optional_import(false, _Function, _Arity) -> [].

validate_compiler(CompileInfo) ->
    BeamVersion = proplists:get_value(version, CompileInfo),
    _ = application:load(compiler),
    case application:get_key(compiler, vsn) of
        {ok, BeamVersion} -> {ok, list_to_binary(BeamVersion)};
        {ok, CurrentVersion} ->
            {error, {compiler_version_mismatch, BeamVersion, CurrentVersion}};
        undefined -> {error, compiler_version_unavailable}
    end.

executable_digest(Chunks, Imports, Exports) ->
    Selected = [{Id, Data} || {Id, Data} <- Chunks,
        lists:member(Id, ["Code", "StrT", "ImpT", "ExpT", "LitT", "LocT"])],
    sha256(term_to_binary({Selected, Imports, Exports}, [deterministic])).

load_inspected(Beam, Inspection) ->
    case code:is_loaded(?GENERATED_MODULE) of
        false ->
            SourceName = "alang-fidelity-memory:" ++
                binary_to_list(maps:get(beam_sha256, Inspection)),
            case code:load_binary(?GENERATED_MODULE, SourceName, Beam) of
                {module, ?GENERATED_MODULE} -> {ok, ?GENERATED_MODULE, Inspection};
                {error, Reason} -> {error, {beam_load_failed, Reason}}
            end;
        Loaded -> {error, {generated_module_already_loaded, Loaded}}
    end.

first_metadata_difference(Expected, Actual) ->
    Keys = lists:usort(maps:keys(Expected) ++ maps:keys(Actual)),
    case [Key || Key <- Keys,
            maps:get(Key, Expected, '$missing') =/= maps:get(Key, Actual, '$missing')] of
        [Key | _] -> Key;
        [] -> unknown
    end.

allowed_chunks() ->
    ["AtU8", "Code", "StrT", "ImpT", "ExpT", "LitT", "LocT",
        "Attr", "CInf", "Dbgi", "Line", "Type"].

required_chunks() ->
    ["AtU8", "Code", "StrT", "ImpT", "ExpT", "LocT", "Attr",
        "CInf", "Dbgi", "Line", "Type"].

sha256(Binary) ->
    iolist_to_binary([io_lib:format("~2.16.0b", [Byte]) ||
        <<Byte>> <= crypto:hash(sha256, Binary)]).

summarize(Value) when is_list(Value) -> {list, length(Value)};
summarize(Value) when is_map(Value) -> {map, map_size(Value)};
summarize(Value) -> Value.
