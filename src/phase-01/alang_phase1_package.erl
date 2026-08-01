-module(alang_phase1_package).

-export([build/3, sha256/1, verify/3]).

-define(GENERATED_MODULE, phase1_counter_v1).
-define(BEAM_FILE, "phase1_counter_v1.beam").
-define(MANIFEST_FILE, "phase1_counter_v1.manifest.etf").

-type error_reason() :: term().
-type path() :: file:filename().

-spec build(path(), path(), path()) -> {ok, map()} | {error, error_reason()}.
build(OutputDirectory, FixturePath, ToolchainPath) ->
    case fixture_inputs(FixturePath) of
        {ok, Fixture, FixtureBytes, Forms} ->
            case alang_phase1_compiler:compile_forms(Forms, ToolchainPath) of
                {ok, Compilation} ->
                    Manifest = manifest(Fixture, FixtureBytes, Forms, Compilation),
                    write_package(OutputDirectory, Compilation, Manifest);
                {error, _} = Error -> Error
            end;
        {error, _} = Error -> Error
    end.

-spec verify(path(), path(), path()) -> {ok, map()} | {error, error_reason()}.
verify(OutputDirectory, FixturePath, ToolchainPath) ->
    case fixture_inputs(FixturePath) of
        {ok, Fixture, FixtureBytes, Forms} ->
            verify_with_fixture(
                OutputDirectory,
                FixturePath,
                ToolchainPath,
                Fixture,
                FixtureBytes,
                Forms
            );
        {error, _} = Error -> Error
    end.

-spec sha256(binary()) -> binary().
sha256(Binary) when is_binary(Binary) ->
    iolist_to_binary([
        io_lib:format("~2.16.0b", [Byte])
     || <<Byte>> <= crypto:hash(sha256, Binary)
    ]).

fixture_inputs(FixturePath) ->
    case file:read_file(FixturePath) of
        {ok, FixtureBytes} ->
            case alang_phase1_fixture:load(FixturePath) of
                {ok, Fixture} ->
                    case alang_phase1_fixture:forms(Fixture) of
                        {ok, Forms} -> {ok, Fixture, FixtureBytes, Forms};
                        {error, _} = Error -> Error
                    end;
                {error, _} = Error -> Error
            end;
        {error, Reason} ->
            {error, {semantic_fixture_read_failed, Reason}}
    end.

verify_with_fixture(
    OutputDirectory,
    _FixturePath,
    ToolchainPath,
    Fixture,
    FixtureBytes,
    Forms
) ->
    BeamPath = filename:join(OutputDirectory, ?BEAM_FILE),
    ManifestPath = filename:join(OutputDirectory, ?MANIFEST_FILE),
    case read_binary(BeamPath, beam_artifact_read_failed) of
        {ok, Beam} ->
            case read_binary(ManifestPath, manifest_read_failed) of
                {ok, ManifestBytes} ->
                    verify_loaded_package(
                        ToolchainPath,
                        Fixture,
                        FixtureBytes,
                        Forms,
                        BeamPath,
                        Beam,
                        ManifestPath,
                        ManifestBytes
                    );
                {error, _} = Error -> Error
            end;
        {error, _} = Error -> Error
    end.

verify_loaded_package(
    ToolchainPath,
    Fixture,
    FixtureBytes,
    Forms,
    BeamPath,
    Beam,
    ManifestPath,
    ManifestBytes
) ->
    case decode_manifest(ManifestBytes) of
        {ok, ActualManifest} ->
            case verification_context(ToolchainPath, Beam) of
                {ok, Toolchain, Config, Inspection} ->
                    Compilation = #{
                        beam => Beam,
                        compiler_options => maps:get(compiler_options, Config),
                        inspection => Inspection,
                        toolchain => Toolchain
                    },
                    ExpectedManifest = manifest(Fixture, FixtureBytes, Forms, Compilation),
                    case ActualManifest =:= ExpectedManifest of
                        true ->
                            {ok, #{
                                module => ?GENERATED_MODULE,
                                beam_path => BeamPath,
                                manifest_path => ManifestPath,
                                beam => Beam,
                                manifest => ActualManifest,
                                beam_sha256 => sha256(Beam),
                                manifest_sha256 => sha256(ManifestBytes),
                                inspection => Inspection,
                                toolchain => Toolchain
                            }};
                        false ->
                            {error, {manifest_mismatch, ExpectedManifest, ActualManifest}}
                    end;
                {error, _} = Error -> Error
            end;
        {error, _} = Error -> Error
    end.

verification_context(ToolchainPath, Beam) ->
    case alang_phase1_compiler:load_toolchain_config(ToolchainPath) of
        {ok, Config} ->
            case alang_phase1_compiler:check_toolchain_config(Config) of
                {ok, Toolchain} ->
                    case alang_phase1_compiler:inspect_beam(Beam) of
                        {ok, Inspection} -> {ok, Toolchain, Config, Inspection};
                        {error, _} = Error -> Error
                    end;
                {error, _} = Error -> Error
            end;
        {error, _} = Error -> Error
    end.

manifest(Fixture, FixtureBytes, Forms, Compilation) ->
    Inspection = maps:get(inspection, Compilation),
    #{
        artifact_format => alang_beam_artifact_v1,
        module => ?GENERATED_MODULE,
        semantic_version => maps:get(semantic_version, Fixture),
        runtime_abi => maps:get(runtime_abi, Fixture),
        fixture_sha256 => sha256(FixtureBytes),
        forms_sha256 => sha256(term_to_binary(Forms, [deterministic])),
        otp_target => maps:get(toolchain, Compilation),
        compiler_options => maps:get(compiler_options, Compilation),
        imports => maps:get(imports, Inspection),
        exports => maps:get(exports, Inspection),
        beam_sha256 => sha256(maps:get(beam, Compilation))
    }.

write_package(OutputDirectory, Compilation, Manifest) ->
    Beam = maps:get(beam, Compilation),
    ManifestBytes = term_to_binary(Manifest, [deterministic]),
    BeamPath = filename:join(OutputDirectory, ?BEAM_FILE),
    ManifestPath = filename:join(OutputDirectory, ?MANIFEST_FILE),
    case filelib:ensure_dir(BeamPath) of
        ok ->
            case file:write_file(BeamPath, Beam, [binary]) of
                ok ->
                    case file:write_file(ManifestPath, ManifestBytes, [binary]) of
                        ok ->
                            {ok, #{
                                module => ?GENERATED_MODULE,
                                beam_path => BeamPath,
                                manifest_path => ManifestPath,
                                beam_sha256 => sha256(Beam),
                                manifest_sha256 => sha256(ManifestBytes),
                                manifest => Manifest
                            }};
                        {error, Reason} ->
                            {error, {manifest_write_failed, Reason}}
                    end;
                {error, Reason} ->
                    {error, {beam_artifact_write_failed, Reason}}
            end;
        {error, Reason} ->
            {error, {artifact_directory_create_failed, Reason}}
    end.

read_binary(Path, ErrorTag) ->
    case file:read_file(Path) of
        {ok, Binary} -> {ok, Binary};
        {error, Reason} -> {error, {ErrorTag, Reason}}
    end.

decode_manifest(Binary) ->
    try binary_to_term(Binary, [safe, used]) of
        {Manifest, Used} when is_map(Manifest), Used =:= byte_size(Binary) ->
            {ok, Manifest};
        {Manifest, _Used} when not is_map(Manifest) ->
            {error, {invalid_manifest, expected_map}};
        {_Manifest, Used} ->
            {error, {invalid_manifest, {trailing_bytes, byte_size(Binary) - Used}}}
    catch
        error:Reason -> {error, {invalid_manifest, Reason}}
    end.
