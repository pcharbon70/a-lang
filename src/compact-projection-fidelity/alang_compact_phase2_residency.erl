-module(alang_compact_phase2_residency).

-export([audit/1, trusted_modules/0]).

-spec trusted_modules() -> [atom()].
trusted_modules() -> [
    alang_fidelity_json,
    alang_fidelity_contract,
    alang_fidelity_representation,
    alang_fidelity_lexer,
    alang_fidelity_parser,
    alang_fidelity_ast,
    alang_fidelity_source,
    alang_compact_corpus,
    alang_compact_source_normalizer,
    alang_compact_tokenizer,
    alang_compact_token_audit,
    alang_compact_surface,
    alang_compact_model,
    alang_compact_opaque,
    alang_compact_source_map,
    alang_compact_phase2_mutation,
    alang_compact_phase2_worker
].

-spec audit(file:filename()) -> {ok, map()} | {error, term()}.
audit(RepositoryRoot) ->
    try
        Modules = [inspect_module(Module, RepositoryRoot) || Module <- trusted_modules()],
        ForeignInputs = foreign_build_inputs(RepositoryRoot),
        ensure(ForeignInputs =:= [], {foreign_build_inputs, ForeignInputs}),
        {ok, #{
            <<"format">> => <<"alang-compact-phase-2-residency-v1">>,
            <<"runtime">> => <<"ERTS">>,
            <<"artifact_kind">> => <<"beam">>,
            <<"deterministic_compile">> => true,
            <<"trusted_modules">> => Modules,
            <<"trusted_module_count">> => length(Modules),
            <<"foreign_build_inputs">> => [],
            <<"forbidden_runtime_imports">> => [],
            <<"project_loaded_nifs">> => 0,
            <<"ports_or_shell_commands">> => 0,
            <<"provider_sdks">> => 0
        }}
    catch
        throw:{residency_error, Reason} -> {error, {phase2_residency_error, Reason}}
    end.

inspect_module(Module, RepositoryRoot) ->
    case code:ensure_loaded(Module) of
        {module, Module} -> ok;
        Error -> fail({module_not_loadable, Module, Error})
    end,
    BeamPath = code:which(Module),
    ensure(is_list(BeamPath) andalso filename:extension(BeamPath) =:= ".beam",
        {not_loaded_from_beam, Module, BeamPath}),
    Imports = case beam_lib:chunks(BeamPath, [imports]) of
        {ok, {Module, [{imports, Values}]}} -> Values;
        Error2 -> fail({beam_import_read_failed, Module, Error2})
    end,
    Forbidden = [Import || Import <- Imports, forbidden_import(Import)],
    ensure(Forbidden =:= [], {forbidden_runtime_imports, Module, Forbidden}),
    SourcePath = source_path(Module, RepositoryRoot),
    {ok, Source} = file:read_file(SourcePath),
    Patterns = forbidden_source_patterns(),
    Matches = [Pattern || Pattern <- Patterns, binary:match(Source, Pattern) =/= nomatch],
    ensure(Matches =:= [], {forbidden_source_patterns, Module, Matches}),
    {ok, Beam} = file:read_file(BeamPath),
    #{
        <<"module">> => atom_to_binary(Module),
        <<"artifact">> => unicode:characters_to_binary(BeamPath),
        <<"beam_sha256">> => hex(crypto:hash(sha256, Beam)),
        <<"imports_inspected">> => length(Imports),
        <<"source_sha256">> => hex(crypto:hash(sha256, Source))
    }.

source_path(Module, RepositoryRoot) ->
    Filename = atom_to_list(Module) ++ ".erl",
    Base = case lists:prefix("alang_fidelity_", atom_to_list(Module)) of
        true -> filename:join([RepositoryRoot, "src", "effectful-source-fidelity"]);
        false -> filename:join([RepositoryRoot, "src", "compact-projection-fidelity"])
    end,
    Path = filename:join(Base, Filename),
    ensure(filelib:is_regular(Path), {missing_trusted_source, Module, Path}),
    Path.

forbidden_import({erlang, open_port, _}) -> true;
forbidden_import({erlang, load_nif, _}) -> true;
forbidden_import({Module, _Function, _Arity}) ->
    lists:member(Module, [os, erl_eval, epp, compile, httpc, inets]);
forbidden_import(_) -> false.

forbidden_source_patterns() -> [
    <<"open_port">>,
    <<"load_nif">>,
    <<"os:cmd">>,
    <<"erl_eval">>,
    <<"System.cmd">>,
    <<"python -c">>,
    <<"node -e">>
].

foreign_build_inputs(RepositoryRoot) ->
    Directory = filename:join([RepositoryRoot, "src", "compact-projection-fidelity"]),
    Files = filelib:wildcard(filename:join(Directory, "*")),
    Forbidden = [".c", ".cc", ".cpp", ".go", ".rs", ".zig", ".py", ".js", ".sh"],
    lists:sort([unicode:characters_to_binary(Path) || Path <- Files,
        filelib:is_regular(Path), lists:member(filename:extension(Path), Forbidden)]).

ensure(true, _Reason) -> ok;
ensure(false, Reason) -> fail(Reason).
fail(Reason) -> throw({residency_error, Reason}).

hex(Binary) ->
    iolist_to_binary([io_lib:format("~2.16.0b", [Byte]) || <<Byte>> <= Binary]).
