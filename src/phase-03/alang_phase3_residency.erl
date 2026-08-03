-module(alang_phase3_residency).

-export([collect/0, verify/0, write/1]).

-spec collect() -> map().
collect() ->
    CompilerModules = compiler_modules(),
    RuntimeModules = runtime_modules(),
    OtpServices = [compile, beam_lib],
    AllModules = CompilerModules ++ RuntimeModules ++ OtpServices,
    _ = [code:ensure_loaded(Module) || Module <- AllModules],
    Paths = maps:from_list([{Module, code:which(Module)} || Module <- AllModules]),
    RepositoryImports = maps:from_list([
        {Module, imports(maps:get(Module, Paths))}
     || Module <- CompilerModules ++ RuntimeModules
    ]),
    ForbiddenImports = maps:map(
        fun(_Module, Imports) -> [Import || Import <- Imports, forbidden_import(Import)] end,
        RepositoryImports
    ),
    #{
        format => alang_phase3_residency_evidence_v1,
        engine => beam,
        vm => list_to_binary(erlang:system_info(machine)),
        otp_release => list_to_binary(erlang:system_info(otp_release)),
        compiler_modules => CompilerModules,
        runtime_modules => RuntimeModules,
        otp_services => OtpServices,
        module_paths => Paths,
        all_modules_are_beam => lists:all(fun is_beam_path/1, maps:values(Paths)),
        repository_imports => RepositoryImports,
        forbidden_foreign_imports => ForbiddenImports,
        no_foreign_imports => lists:all(fun(Values) -> Values =:= [] end, maps:values(ForbiddenImports)),
        production_boundary => erlang_abstract_format,
        compiler_interface => {compile, forms, 2},
        generated_trace => [
            alang_source_bytes,
            phase2_lexer,
            phase2_parser,
            phase2_static_checker,
            typed_task_ir,
            phase3_abstract_format_lowering,
            otp_strong_validation,
            deterministic_beam_binary,
            beam_artifact_inspection,
            code_load_binary,
            supervised_task_worker,
            erts_execution,
            soft_purge
        ],
        erlang_source_emitted => false,
        core_erlang_used => false,
        raw_beam_assembly_used => false,
        foreign_compiler_executables => [],
        test_reference_is_deployable => false
    }.

-spec verify() -> {ok, map()} | {error, map()}.
verify() ->
    Evidence = collect(),
    Required = [
        maps:get(engine, Evidence) =:= beam,
        maps:get(vm, Evidence) =:= <<"BEAM">>,
        maps:get(otp_release, Evidence) =:= <<"29">>,
        maps:get(all_modules_are_beam, Evidence),
        maps:get(no_foreign_imports, Evidence),
        maps:get(production_boundary, Evidence) =:= erlang_abstract_format,
        maps:get(compiler_interface, Evidence) =:= {compile, forms, 2},
        maps:get(erlang_source_emitted, Evidence) =:= false,
        maps:get(core_erlang_used, Evidence) =:= false,
        maps:get(raw_beam_assembly_used, Evidence) =:= false,
        maps:get(foreign_compiler_executables, Evidence) =:= [],
        maps:get(test_reference_is_deployable, Evidence) =:= false
    ],
    case lists:all(fun(Value) -> Value =:= true end, Required) of
        true -> {ok, Evidence};
        false -> {error, Evidence}
    end.

-spec write(file:filename()) -> {ok, map()} | {error, term()}.
write(Path) ->
    case verify() of
        {ok, Evidence} ->
            case filelib:ensure_dir(Path) of
                ok ->
                    case file:write_file(Path, io_lib:format("~tp.~n", [Evidence])) of
                        ok -> {ok, Evidence};
                        {error, Reason} -> {error, {evidence_write_failed, Reason}}
                    end;
                {error, Reason} -> {error, {evidence_directory_failed, Reason}}
            end;
        {error, _} = Error -> Error
    end.

compiler_modules() ->
    [
        alang_phase1_compiler,
        alang_phase2_lexer,
        alang_phase2_parser,
        alang_phase2_semantics,
        alang_phase2_ir,
        alang_phase2_canonical,
        alang_phase2_reference,
        alang_phase2_views,
        alang_phase2_bridge,
        alang_phase2_compiler,
        alang_phase3_contract,
        alang_phase3_lowering,
        alang_phase3_forms,
        alang_phase3_backend
    ].

runtime_modules() ->
    [
        alang_phase3_artifact,
        alang_phase3_abi,
        alang_phase3_trace,
        alang_phase3_effect_gateway,
        alang_phase3_task_worker,
        alang_phase3_session_sup,
        alang_phase3_launcher
    ].

imports(Path) when is_list(Path) ->
    case beam_lib:chunks(Path, [imports]) of
        {ok, {_Module, [{imports, Imports}]}} -> Imports;
        _ -> []
    end;
imports(_) -> [].

forbidden_import({os, cmd, _Arity}) -> true;
forbidden_import({erlang, open_port, _Arity}) -> true;
forbidden_import({erlang, load_nif, _Arity}) -> true;
forbidden_import({erl_ddll, _Function, _Arity}) -> true;
forbidden_import(_) -> false.

is_beam_path(Path) when is_list(Path) -> filename:extension(Path) =:= ".beam";
is_beam_path(_) -> false.
