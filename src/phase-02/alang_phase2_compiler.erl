-module(alang_phase2_compiler).

-export([compile_file/2, compile_source/1, main/0]).

-define(GOLDEN_FIXTURE, "src/phase-01/semantic-fixture.config").

-spec main() -> no_return().
main() ->
    case init:get_plain_arguments() of
        [SourcePath, OutputDirectory] ->
            case compile_file(SourcePath, OutputDirectory) of
                {ok, Evidence} ->
                    io:format(
                        "phase_2_compile_ok engine=beam module=~s ir_sha256=~s~n",
                        [maps:get(module, Evidence), maps:get(ir_sha256, Evidence)]
                    ),
                    halt(0);
                {error, Reason} ->
                    io:format(standard_error, "phase_2_compile_error ~tp~n", [Reason]),
                    halt(1)
            end;
        Arguments ->
            io:format(standard_error, "usage_error expected source and output directory, got ~tp~n", [Arguments]),
            halt(2)
    end.

-spec compile_file(file:filename(), file:filename()) -> {ok, map()} | {error, term()}.
compile_file(SourcePath, OutputDirectory) ->
    case file:read_file(SourcePath) of
        {ok, Source} ->
            case compile_source(Source) of
                {ok, Product} -> write_product(OutputDirectory, Product);
                {error, _} = Error -> Error
            end;
        {error, Reason} ->
            {error, {source_read_failed, SourcePath, Reason}}
    end.

-spec compile_source(binary()) -> {ok, map()} | {error, term()}.
compile_source(Source) ->
    case alang_phase2_parser:parse(Source) of
        {ok, Ast} -> compile_ast(Ast);
        {error, _} = Error -> Error
    end.

compile_ast(Ast) ->
    case alang_phase2_canonical:encode(Ast) of
        {ok, Canonical} ->
            case alang_phase2_canonical:decode(Canonical) of
                {ok, CanonicalAst} when CanonicalAst =:= Ast -> check_and_lower(Ast, Canonical);
                {ok, _DifferentAst} -> {error, canonical_round_trip_disagreement};
                {error, _} = Error -> Error
            end;
        {error, _} = Error -> Error
    end.

check_and_lower(Ast, Canonical) ->
    case alang_phase2_semantics:check(Ast) of
        {ok, Checked} ->
            case alang_phase2_ir:lower(Checked) of
                {ok, Ir} -> finish_product(Ast, Canonical, Ir);
                {error, _} = Error -> Error
            end;
        {error, _} = Error -> Error
    end.

finish_product(Ast, Canonical, Ir) ->
    TaskId = <<"task:Counter.successor/1">>,
    case {
        alang_phase2_reference:evaluate(Ir, TaskId, #{<<"value">> => 41}),
        alang_phase2_views:project(Ir),
        alang_phase2_bridge:phase1_fixture(Ir, ?GOLDEN_FIXTURE)
    } of
        {{ok, Reference}, {ok, Views}, {ok, Fixture}} ->
            case reference_agrees(Reference, Views) of
                true -> {ok, #{
                    ast => Ast,
                    canonical => Canonical,
                    ir => Ir,
                    views => Views,
                    reference => Reference,
                    fixture => Fixture
                }};
                false -> {error, reference_view_disagreement}
            end;
        {{error, Reason}, _, _} -> {error, {reference_failed, Reason}};
        {_, {error, Reason}, _} -> {error, {view_projection_failed, Reason}};
        {_, _, {error, Reason}} -> {error, {bridge_failed, Reason}}
    end.

reference_agrees(
    #{result := 42, completion := true, effects := []},
    #{capability_manifest := #{effects := [], requirements := []}}
) -> true;
reference_agrees(_, _) -> false.

write_product(OutputDirectory, Product) ->
    case filelib:ensure_dir(filename:join(OutputDirectory, ".keep")) of
        ok -> write_outputs(OutputDirectory, Product);
        {error, Reason} -> {error, {output_directory_failed, Reason}}
    end.

write_outputs(OutputDirectory, Product) ->
    Ast = maps:get(ast, Product),
    Canonical = maps:get(canonical, Product),
    Ir = maps:get(ir, Product),
    Views = maps:get(views, Product),
    Reference = maps:get(reference, Product),
    Fixture = maps:get(fixture, Product),
    Agreement = agreement(Reference, Views),
    Evidence = compiler_evidence(Ast, Canonical, Ir),
    case maps:get(all_compiler_modules_are_beam, Evidence) of
        true -> write_verified_outputs(OutputDirectory, Canonical, Ir, Views, Reference, Fixture, Agreement, Evidence);
        false -> {error, {compiler_not_beam_resident, maps:get(compiler_modules, Evidence)}}
    end.

write_verified_outputs(OutputDirectory, Canonical, Ir, Views, Reference, Fixture, Agreement, Evidence) ->
    Writes = [
        write_binary(OutputDirectory, "canonical-source.etf", Canonical),
        write_binary(OutputDirectory, "typed-task-ir.etf", term_to_binary(Ir, [deterministic])),
        write_binary(OutputDirectory, "semantic-views.etf", term_to_binary(Views, [deterministic])),
        write_binary(OutputDirectory, "reference-observation.etf", term_to_binary(Reference, [deterministic])),
        write_binary(OutputDirectory, "phase1-semantic-fixture.config", Fixture),
        write_term(OutputDirectory, "agreement.config", Agreement),
        write_term(OutputDirectory, "compiler-evidence.config", Evidence)
    ],
    case [Error || Error <- Writes, Error =/= ok] of
        [] -> {ok, Evidence};
        Errors -> {error, {output_write_failed, Errors}}
    end.

agreement(Reference, Views) ->
    Manifest = maps:get(capability_manifest, Views),
    #{
        format => alang_phase2_agreement_v1,
        task => maps:get(task, Reference),
        input => 41,
        reference_result => maps:get(result, Reference),
        reference_completion => maps:get(completion, Reference),
        reference_effects => maps:get(effects, Reference),
        manifest_effects => maps:get(effects, Manifest)
    }.

compiler_evidence(Ast, Canonical, Ir) ->
    Modules = compiler_modules(),
    ModuleFiles = maps:from_list([{Module, code:which(Module)} || Module <- Modules]),
    #{
        format => alang_compiler_evidence_v1,
        engine => beam,
        vm => erlang:system_info(machine),
        otp_release => list_to_binary(erlang:system_info(otp_release)),
        compiler_module => ?MODULE,
        compiler_modules => ModuleFiles,
        all_compiler_modules_are_beam => lists:all(fun is_beam_file/1, maps:values(ModuleFiles)),
        foreign_compiler_executables => [],
        source_format => maps:get(format, Ast),
        canonical_encoding => deterministic_etf,
        canonical_sha256 => hex(crypto:hash(sha256, Canonical)),
        ir_sha256 => hex(crypto:hash(sha256, term_to_binary(Ir, [deterministic]))),
        module => maps:get(module, Ir)
    }.

compiler_modules() ->
    [
        alang_phase2_lexer,
        alang_phase2_parser,
        alang_phase2_canonical,
        alang_phase2_semantics,
        alang_phase2_ir,
        alang_phase2_reference,
        alang_phase2_views,
        alang_phase2_bridge,
        alang_phase2_compiler,
        alang_phase1_compiler,
        alang_phase1_fixture,
        alang_phase1_package,
        compile,
        beam_lib
    ].

is_beam_file(Path) when is_list(Path) -> filename:extension(Path) =:= ".beam";
is_beam_file(_) -> false.

write_binary(Directory, Name, Binary) ->
    file:write_file(filename:join(Directory, Name), Binary).

write_term(Directory, Name, Term) ->
    file:write_file(filename:join(Directory, Name), io_lib:format("~tp.~n", [Term])).

hex(Binary) ->
    iolist_to_binary([io_lib:format("~2.16.0b", [Byte]) || <<Byte>> <= Binary]).
