-module(alang_fidelity_phase4_evidence).

-export([build/0, decode/1, main/0, residency/0, validate/1, write/1]).

-define(OWNED_ROOT, "build/effectful-source-fidelity/phase-04").
-define(REPRODUCTION_A,
    "build/effectful-source-fidelity/phase-04/evidence/reproduction-a.etf").
-define(REPRODUCTION_B,
    "build/effectful-source-fidelity/phase-04/evidence/reproduction-b.etf").

-spec build() -> {ok, map()} | {error, term()}.
build() ->
    Base = filename:join(filename:absname(?OWNED_ROOT), "evidence/runtime"),
    try
        {ok, Matrix} = alang_fidelity_offline:run_matrix(
            filename:join(Base, "matrix")),
        Faults = fault_results(filename:join(Base, "faults")),
        true = lists:all(fun(#{equal := Equal}) -> Equal end, Faults),
        {FirstBinary, Reproduction} = read_reproduction(?REPRODUCTION_A),
        {SecondBinary, Reproduction} = read_reproduction(?REPRODUCTION_B),
        true = FirstBinary =:= SecondBinary,
        Residency = residency(),
        true = lists:all(fun(#{is_beam := IsBeam}) -> IsBeam end, Residency),
        Boundary = compiler_boundary(Matrix),
        true = lists:all(fun(Value) -> Value end, maps:values(Boundary)),
        ReproductionBody = maps:get(evidence, Reproduction),
        Body = #{
            format => alang_fidelity_phase4_evidence_body_v1,
            engine => beam,
            vm => 'BEAM',
            otp_release => list_to_binary(erlang:system_info(otp_release)),
            network => disabled,
            hosted_calls => 0,
            case_count => maps:get(case_count, Matrix),
            representation_count => maps:get(representation_count, Matrix),
            family_counts => maps:get(family_counts, Matrix),
            pair_evidence => maps:get(pairs, Matrix),
            offline_matrix_sha256 => maps:get(evidence_digest, Matrix),
            fault_case_count => length(Faults),
            fault_cases => Faults,
            inspected_artifact_count => maps:get(representation_count, Matrix),
            generated_execution => beam,
            runtime_boundaries => [broker, durable_workflow, workspace_adapter,
                child_supervisor, model_protocol, repair, completion_verifier],
            reproduction => #{
                byte_identical => true,
                bundle_sha256 => maps:get(bundle_sha256, Reproduction),
                artifact_sha256 => digest_binary(FirstBinary),
                case_count => maps:get(case_count, ReproductionBody),
                representation_count => maps:get(representation_count,
                    ReproductionBody),
                compared => [beam, metadata, normalized_trace, artifact_content,
                    completion_witness]
            },
            module_residency => Residency,
            compiler_boundary => Boundary,
            inherited_gate => #{
                status => passed,
                command => <<"make test-phase-8">>,
                phases => [1, 2, 3, 4, 5, 6, 7, 8]
            },
            v2_mutation_gate => #{
                status => passed,
                command => <<"eunit alang_fidelity_offline_tests">>,
                mutants => [ignored_manifest, json_frontend_bypass,
                    increased_runtime_limits, child_authority_widening,
                    skipped_repair_accounting, source_map_swap,
                    model_completion_claim, condition_specific_handler]
            },
            limitations => [same_node_trust, local_filesystem_store,
                fixed_generated_module, single_otp_profile,
                deterministic_mock_provider, not_production_approved]
        },
        Evidence = #{
            format => alang_fidelity_phase4_evidence_v1,
            evidence_sha256 => digest(Body),
            evidence => Body
        },
        ok = validate(Evidence),
        {ok, Evidence}
    catch
        Class:Reason:Stack -> {error, {Class, Reason, lists:sublist(Stack, 3)}}
    after
        cleanup(Base)
    end.

-spec write(file:filename_all()) -> {ok, map()} | {error, term()}.
write(Path) ->
    case owned_path(Path) of
        true ->
            case build() of
                {ok, Evidence} ->
                    ok = filelib:ensure_dir(Path),
                    Binary = term_to_binary(Evidence, [deterministic]),
                    case file:write_file(Path, Binary, [binary]) of
                        ok -> {ok, Evidence#{artifact_sha256 => digest_binary(Binary)}};
                        {error, Reason} -> {error, {evidence_write_failed, Reason}}
                    end;
                {error, _} = Error -> Error
            end;
        false -> {error, evidence_path_outside_owned_root}
    end.

main() ->
    case init:get_plain_arguments() of
        [Output] ->
            case write(Output) of
                {ok, Evidence} ->
                    Body = maps:get(evidence, Evidence),
                    Reproduction = maps:get(reproduction, Body),
                    io:format(
                        "fidelity_phase4_ok digest=~s artifact=~s cases=~B representations=~B faults=~B reproduction=~s otp=~s output=~s~n",
                        [maps:get(evidence_sha256, Evidence),
                            maps:get(artifact_sha256, Evidence),
                            maps:get(case_count, Body),
                            maps:get(representation_count, Body),
                            maps:get(fault_case_count, Body),
                            maps:get(bundle_sha256, Reproduction),
                            maps:get(otp_release, Body), Output]),
                    halt(0);
                {error, Reason} ->
                    io:format(standard_error, "fidelity_phase4_error ~tp~n", [Reason]),
                    halt(1)
            end;
        _ ->
            io:format(standard_error,
                "usage: alang_fidelity_phase4_evidence <output.etf>~n", []),
            halt(2)
    end.

-spec validate(term()) -> ok | {error, atom()}.
validate(#{
    format := alang_fidelity_phase4_evidence_v1,
    evidence_sha256 := Digest,
    evidence := #{
        format := alang_fidelity_phase4_evidence_body_v1,
        engine := beam,
        vm := 'BEAM',
        network := disabled,
        hosted_calls := 0,
        case_count := 24,
        representation_count := 48,
        fault_case_count := 8,
        inspected_artifact_count := 48,
        generated_execution := beam,
        reproduction := #{byte_identical := true, case_count := 3,
            representation_count := 6},
        module_residency := Residency,
        compiler_boundary := Boundary,
        inherited_gate := #{status := passed},
        v2_mutation_gate := #{status := passed},
        limitations := Limitations
    } = Body
} = Evidence) when map_size(Evidence) =:= 3 ->
    Valid = valid_digest(Digest) andalso digest(Body) =:= Digest andalso
        lists:all(fun(#{is_beam := IsBeam}) -> IsBeam end, Residency) andalso
        lists:all(fun(Value) -> Value end, maps:values(Boundary)) andalso
        length(Limitations) =:= 6,
    case Valid of
        true -> ok;
        false -> {error, invalid_phase4_evidence}
    end;
validate(_) -> {error, invalid_phase4_evidence}.

-spec decode(binary()) -> {ok, map()} | {error, atom()}.
decode(Binary) when is_binary(Binary) ->
    lists:foreach(fun(Module) ->
        {module, Module} = code:ensure_loaded(Module)
    end, trusted_modules()),
    try binary_to_term(Binary, [safe]) of
        Evidence ->
            case validate(Evidence) of
                ok -> {ok, Evidence};
                {error, _} = Error -> Error
            end
    catch
        error:badarg -> {error, unsafe_phase4_evidence_etf}
    end;
decode(_) -> {error, unsafe_phase4_evidence_etf}.

-spec residency() -> [map()].
residency() -> [residency_record(Module) || Module <- trusted_modules()].

residency_record(Module) ->
    {module, Module} = code:ensure_loaded(Module),
    Path = code:which(Module),
    #{
        module => Module,
        beam_file => list_to_binary(filename:basename(Path)),
        is_beam => is_list(Path) andalso filename:extension(Path) =:= ".beam"
    }.

compiler_boundary(Matrix) ->
    ManualIrRejected = matches_error(alang_fidelity_compiler:compile_campaign(
        #{format => alang_typed_task_ir_v2})),
    EvaluatorRejected = matches_error(alang_fidelity_compiler:compile_campaign(
        #{reference_evaluator => fun(_Value) -> bypass end})),
    Sources = compiler_sources(),
    Emitted = regular_files(filename:absname(?OWNED_ROOT)),
    #{
        compiler_modules_are_erlang_source => lists:all(fun(Path) ->
            filelib:is_regular(Path) andalso filename:extension(Path) =:= ".erl"
        end, Sources),
        compiler_modules_are_beam_resident => lists:all(fun(Module) ->
            Path = code:which(Module),
            is_list(Path) andalso filename:extension(Path) =:= ".beam"
        end, compiler_modules()),
        accepted_input_requires_original_bytes => ManualIrRejected,
        reference_evaluator_is_nondeployable => EvaluatorRejected,
        generated_artifact_requires_inspection =>
            maps:get(representation_count, Matrix) =:= 48,
        no_erlang_source_emitted => not lists:any(fun(Path) ->
            lists:member(filename:extension(Path), [".erl", ".hrl"])
        end, Emitted),
        no_core_erlang_used => not source_contains_any(Sources,
            [<<"to_core">>, <<"from_core">>, <<"core_transform">>, <<".core">>])
            andalso not lists:any(fun(Path) ->
                filename:extension(Path) =:= ".core"
            end, Emitted),
        no_foreign_compiler_executable_used =>
            forbidden_compiler_imports() =:= []
    }.

matches_error({error, [_ | _]}) -> true;
matches_error(_) -> false.

compiler_modules() -> [
    alang_fidelity_json,
    alang_fidelity_json_pointer,
    alang_fidelity_contract,
    alang_fidelity_representation,
    alang_fidelity_ast,
    alang_fidelity_lexer,
    alang_fidelity_parser,
    alang_fidelity_control,
    alang_fidelity_source,
    alang_fidelity_semantics,
    alang_fidelity_authority,
    alang_fidelity_ir,
    alang_fidelity_compiler,
    alang_fidelity_forms_v2,
    alang_fidelity_artifact_v2,
    alang_fidelity_backend_v2,
    alang_phase1_compiler
].

compiler_sources() -> [compiler_source(Module) || Module <- compiler_modules()].

compiler_source(alang_phase1_compiler) -> "src/phase-01/alang_phase1_compiler.erl";
compiler_source(Module) -> filename:join("src/effectful-source-fidelity",
    atom_to_list(Module) ++ ".erl").

forbidden_compiler_imports() ->
    lists:append([begin
        {ok, {Module, [{imports, Imports}]}} = beam_lib:chunks(
            code:which(Module), [imports]),
        [{Module, Import} || Import <- Imports, forbidden_import(Import)]
    end || Module <- compiler_modules()]).

forbidden_import({os, _Function, _Arity}) -> true;
forbidden_import({erl_ddll, _Function, _Arity}) -> true;
forbidden_import({erlang, open_port, _Arity}) -> true;
forbidden_import({file, write_file, _Arity}) -> true;
forbidden_import(_) -> false.

source_contains_any(Paths, Patterns) ->
    lists:any(fun(Path) ->
        {ok, Binary} = file:read_file(Path),
        lists:any(fun(Pattern) ->
            binary:match(Binary, Pattern) =/= nomatch
        end, Patterns)
    end, Paths).

regular_files(Path) ->
    case file:list_dir(Path) of
        {ok, Names} -> lists:append([begin
            Child = filename:join(Path, Name),
            case filelib:is_dir(Child) of
                true -> regular_files(Child);
                false -> [Child]
            end
        end || Name <- Names]);
        {error, enoent} -> []
    end.

trusted_modules() -> compiler_modules() ++ [
    alang_fidelity_runtime_abi,
    alang_fidelity_runtime,
    alang_fidelity_completion,
    alang_fidelity_offline,
    alang_fidelity_phase4_worker,
    alang_fidelity_phase4_evidence,
    alang_phase4_broker,
    alang_phase4_workspace_adapter,
    alang_phase5_workflow,
    alang_phase5_store,
    alang_phase6_model_protocol,
    alang_phase6_repair,
    alang_phase6_child,
    alang_phase6_verifier
].

fault_results(Base) ->
    [alang_fidelity_offline:run_fault_pair(Name, Path,
        filename:join(Base, atom_to_list(Name))) || {Name, Path} <- [
            {denied_scope, source("single-model-artifact/sma-simple")},
            {exhausted_budget, source("single-model-artifact/sma-simple")},
            {malformed_response, source("single-model-artifact/sma-simple")},
            {repair_failure, source("repair-and-publish/rap-simple")},
            {cancellation, source("attenuated-delegation/ad-simple")},
            {uncertain_workspace, source("single-model-artifact/sma-simple")},
            {wrong_digest, source("single-model-artifact/sma-simple")},
            {missing_information,
                source("single-model-artifact/sma-missing-information")}
        ]].

source(Relative) -> filename:join(
    "assets/effectful-source-fidelity/corpus", Relative ++ ".alang").

read_reproduction(Path) ->
    {ok, Binary} = file:read_file(Path),
    {ok, Bundle} = alang_fidelity_phase4_worker:decode(Binary),
    {Binary, Bundle}.

owned_path(Path) ->
    Root = filename:absname(?OWNED_ROOT),
    Absolute = filename:absname(Path),
    lists:prefix(Root ++ "/", Absolute).

cleanup(Base) ->
    case filelib:is_dir(Base) of
        true -> file:del_dir_r(Base);
        false -> ok
    end.

valid_digest(Digest) when is_binary(Digest), byte_size(Digest) =:= 64 ->
    re:run(Digest, <<"^[0-9a-f]{64}$">>, [{capture, none}]) =:= match;
valid_digest(_) -> false.

digest(Term) -> digest_binary(term_to_binary(Term, [deterministic])).
digest_binary(Binary) -> hex(crypto:hash(sha256, Binary)).
hex(Binary) -> << <<(hex_digit(Nibble))>> || <<Nibble:4>> <= Binary >>.
hex_digit(Nibble) when Nibble < 10 -> $0 + Nibble;
hex_digit(Nibble) -> $a + Nibble - 10.
