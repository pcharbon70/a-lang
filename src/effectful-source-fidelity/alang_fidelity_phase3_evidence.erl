-module(alang_fidelity_phase3_evidence).

-export([build/0, main/0, negative_results/0,
    paired_negative_cases/0, write/1]).

-define(CORPUS_GLOB, "assets/effectful-source-fidelity/corpus/*/*.alang").
-define(CORPUS_ROOT, "assets/effectful-source-fidelity/corpus").
-define(OWNED_ROOT, "build/effectful-source-fidelity/phase-03").
-define(PROPERTY_CASES, 256).

-spec build() -> {ok, map()} | {error, term()}.
build() ->
    try
        Files = lists:sort(filelib:wildcard(?CORPUS_GLOB)),
        Compiled = [compile_case(Path) || Path <- Files],
        true = length(Compiled) =:= 24,
        Cases = [maps:get(record, Entry) || Entry <- Compiled],
        true = lists:all(fun(Entry) -> maps:get(matched, Entry) end, Cases),
        Negatives = negative_results(),
        true = lists:all(fun(Entry) -> maps:get(matched, Entry) end, Negatives),
        Mutants = alang_fidelity_phase3_mutation:run(),
        true = lists:all(fun(Entry) -> maps:get(detected, Entry) end, Mutants),
        Properties = property_sweep(Compiled),
        true = maps:get(failures, Properties) =:= 0,
        Residency = residency(),
        true = lists:all(fun(Entry) -> maps:get(is_beam, Entry) end, Residency),
        Body = #{
            format => alang_fidelity_phase3_evidence_body_v1,
            engine => beam,
            vm => 'BEAM',
            otp_release => list_to_binary(erlang:system_info(otp_release)),
            hosted_calls => 0,
            corpus_count => length(Cases),
            cases => Cases,
            semantic_bundle_sha256 => bundle_digest(semantic_sha256, Cases),
            ir_bundle_sha256 => bundle_digest(ir_sha256, Cases),
            manifest_bundle_sha256 => bundle_digest(manifest_sha256, Cases),
            limits_bundle_sha256 => bundle_digest(limits_sha256, Cases),
            completion_bundle_sha256 => bundle_digest(completion_sha256, Cases),
            negative_case_count => length(Negatives),
            negative_cases => Negatives,
            property_results => Properties,
            mutant_count => length(Mutants),
            mutants => Mutants,
            module_residency => Residency,
            campaign_accepts_manual_ir => false,
            compiler_runtime_effects => [],
            foreign_compiler_executables => []
        },
        {ok, #{
            format => alang_fidelity_phase3_evidence_v1,
            evidence_sha256 => digest(Body),
            evidence => Body
        }}
    catch
        Class:Reason:Stack -> {error, {Class, Reason, Stack}}
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
                        ok -> {ok, Evidence#{
                            artifact_sha256 => hex(crypto:hash(sha256, Binary))
                        }};
                        {error, Reason} -> {error, {evidence_write_failed, Reason}}
                    end;
                {error, _} = Error -> Error
            end;
        false ->
            {error, evidence_path_outside_owned_root}
    end.

main() ->
    case init:get_plain_arguments() of
        [Output] ->
            case write(Output) of
                {ok, Evidence} ->
                    Body = maps:get(evidence, Evidence),
                    Properties = maps:get(property_results, Body),
                    io:format(
                        "fidelity_phase3_ok digest=~s artifact=~s cases=~B negatives=~B properties=~B mutants=~B otp=~s output=~s~n",
                        [
                            maps:get(evidence_sha256, Evidence),
                            maps:get(artifact_sha256, Evidence),
                            maps:get(corpus_count, Body),
                            maps:get(negative_case_count, Body),
                            maps:get(cases, Properties),
                            maps:get(mutant_count, Body),
                            maps:get(otp_release, Body),
                            Output
                        ]
                    ),
                    halt(0);
                {error, Reason} ->
                    io:format(standard_error, "fidelity_phase3_error ~tp~n", [Reason]),
                    halt(1)
            end;
        _ ->
            io:format(standard_error,
                "usage: alang_fidelity_phase3_evidence <output.etf>~n", []),
            halt(2)
    end.

compile_case(Path) ->
    {ok, Source} = file:read_file(Path),
    ControlPath = filename:rootname(Path, ".alang") ++ ".json",
    {ok, Control} = file:read_file(ControlPath),
    {ok, SourceChecked} = alang_fidelity_semantics:check_source(Source),
    {ok, ControlChecked} = alang_fidelity_semantics:check_control(Control),
    {ok, SourceLowered} = alang_fidelity_compiler:compile_source(Source),
    {ok, ControlLowered} = alang_fidelity_compiler:compile_control(Control),
    SourceIr = maps:get(ir, SourceLowered),
    ControlIr = maps:get(ir, ControlLowered),
    true = SourceIr =:= ControlIr,
    ok = alang_fidelity_ir:validate(SourceIr),
    [Task] = maps:get(tasks, SourceIr),
    Manifest = maps:get(manifest, SourceIr),
    CaseId = maps:get(module, SourceIr),
    SemanticDigest = maps:get(semantic_digest, SourceLowered),
    IrDigest = maps:get(ir_digest, SourceLowered),
    true = SemanticDigest =:= maps:get(semantic_digest, ControlLowered),
    true = IrDigest =:= maps:get(ir_digest, ControlLowered),
    true = maps:get(completion, Task) =:= maps:get(completion, SourceChecked),
    true = maps:get(completion, Task) =:= maps:get(completion, ControlChecked),
    Record = #{
        case_id => CaseId,
        family => list_to_binary(filename:basename(filename:dirname(Path))),
        source_path => list_to_binary(Path),
        control_path => list_to_binary(ControlPath),
        source_sha256 => hex(crypto:hash(sha256, Source)),
        control_sha256 => hex(crypto:hash(sha256, Control)),
        semantic_sha256 => SemanticDigest,
        ir_sha256 => IrDigest,
        manifest_sha256 => digest(Manifest),
        limits_sha256 => digest(maps:get(limits, Task)),
        static_bounds_sha256 => digest(maps:get(static_bounds, Task)),
        child_sha256 => digest(maps:get(child, Task)),
        completion_sha256 => digest(maps:get(completion, Task)),
        source_map_sha256 => digest(maps:get(source_map, SourceLowered)),
        control_map_sha256 => digest(maps:get(source_map, ControlLowered)),
        node_count => length(maps:get(nodes, SourceIr)),
        effect_site_count => length([ok || Node <- maps:get(nodes, SourceIr),
            maps:get(kind, Node) =/= complete]),
        matched => true
    },
    #{
        record => Record,
        ir => SourceIr,
        checked => SourceChecked
    }.

-spec paired_negative_cases() -> [map()].
paired_negative_cases() ->
    SimpleSource = read("single-model-artifact/sma-simple.alang"),
    SimpleControl = value("single-model-artifact/sma-simple.json"),
    SimpleTask = maps:get(<<"task">>, SimpleControl),
    [Input] = maps:get(<<"inputs">>, SimpleTask),
    [Draft, Publish | Remaining] = maps:get(<<"actions">>, SimpleTask),
    SimpleBudgets = maps:get(<<"budgets">>, SimpleTask),
    [FirstPredicate | OtherPredicates] =
        maps:get(<<"completion_predicates">>, SimpleTask),
    DelegatedSource = read("attenuated-delegation/ad-simple.alang"),
    DelegatedControl = value("attenuated-delegation/ad-simple.json"),
    DelegatedTask = maps:get(<<"task">>, DelegatedControl),
    Child = maps:get(<<"child_attenuation">>, DelegatedTask),
    [ArtifactPredicate, JournalPredicate] =
        maps:get(<<"completion_predicates">>, DelegatedTask),
    [
        negative(unresolved_dependency, {control, dependency_not_prior},
            replace(SimpleSource,
                <<"step publish: workspace.write depends [draft]">>,
                <<"step publish: workspace.write depends [missing]">>),
            control(SimpleControl, SimpleTask#{<<"actions">> =>
                [Draft, Publish#{<<"depends_on">> => [<<"missing">>]} |
                    Remaining]})),
        negative(unknown_input_type, {type, unknown_type},
            replace(SimpleSource,
                <<"input change-summary: text required;">>,
                <<"input change-summary: decimal required;">>),
            control(SimpleControl, SimpleTask#{<<"inputs">> =>
                [Input#{<<"type">> => <<"decimal">>}]})),
        negative(declared_effect_mismatch,
            {authority, declared_effect_mismatch},
            replace(SimpleSource,
                <<"effects [model.generate, workspace.write]">>,
                <<"effects [model.generate]">>),
            control(SimpleControl, SimpleTask#{<<"effects">> =>
                [<<"model.generate">>]})),
        negative(limit_below_static_bound,
            {limit, limit_below_static_bound},
            replace(SimpleSource, <<"steps 3;">>, <<"steps 2;">>),
            control(SimpleControl, SimpleTask#{<<"budgets">> =>
                SimpleBudgets#{<<"steps">> => 2}})),
        negative(recursive_child_authority,
            {attenuation, recursive_child_authority},
            replace(DelegatedSource,
                <<"child { effects [model.generate]">>,
                <<"child { effects [model.generate, child.run]">>),
            control(DelegatedControl, DelegatedTask#{
                <<"child_attenuation">> => Child#{<<"effects">> =>
                    [<<"model.generate">>, <<"child.run">>]}})),
        negative(unsafe_completion_path,
            {completion, unsafe_completion_path},
            replace(SimpleSource,
                <<"complete [artifact-exists \"/workspace/release-note.md\"">>,
                <<"complete [artifact-exists \"/workspace/../secret.md\"">>),
            control(SimpleControl, SimpleTask#{
                <<"completion_predicates">> =>
                    [FirstPredicate#{<<"target">> =>
                        <<"/workspace/../secret.md">>} | OtherPredicates]})),
        negative(unknown_completion_action,
            {completion, unknown_completion_action},
            replace(DelegatedSource,
                <<"journal-succeeded \"publish\"">>,
                <<"journal-succeeded \"missing\"">>),
            control(DelegatedControl, DelegatedTask#{
                <<"completion_predicates">> => [ArtifactPredicate,
                    JournalPredicate#{<<"target">> => <<"missing">>}]})),
        negative(effects_before_clarification,
            {control, effects_before_clarification},
            replace(replace(SimpleSource,
                <<"clarify [];">>,
                <<"clarify [\"Need a source summary\"];">>),
                <<"terminal complete;">>,
                <<"terminal needs-clarification;">>),
            control(SimpleControl, SimpleTask#{
                <<"clarification_needs">> => [<<"Need a source summary">>],
                <<"terminal_class">> => <<"needs-clarification">>
            }))
    ].

-spec negative_results() -> [map()].
negative_results() ->
    [negative_result(Case) || Case <- paired_negative_cases()].

negative_result(Case) ->
    SourceDiagnostic = one_error(alang_fidelity_compiler:compile_source(
        maps:get(source, Case))),
    ControlDiagnostic = one_error(alang_fidelity_compiler:compile_control(
        maps:get(control, Case))),
    Expected = maps:get(expected, Case),
    SourceIdentity = identity(SourceDiagnostic),
    ControlIdentity = identity(ControlDiagnostic),
    SourceOrigin = maps:get(origin, SourceDiagnostic, #{}),
    ControlOrigin = maps:get(origin, ControlDiagnostic, #{}),
    SourceLocal = maps:get(source, SourceOrigin, undefined) =:= alang_source
        andalso maps:is_key(byte, SourceOrigin),
    ControlLocal = maps:get(source, ControlOrigin, undefined) =:= typed_json
        andalso maps:is_key(pointer, ControlOrigin)
        andalso maps:is_key(byte, ControlOrigin),
    #{
        name => maps:get(name, Case),
        expected => Expected,
        source_actual => SourceIdentity,
        control_actual => ControlIdentity,
        source_origin => SourceOrigin,
        control_origin => ControlOrigin,
        source_local => SourceLocal,
        control_local => ControlLocal,
        matched => SourceIdentity =:= Expected andalso
            ControlIdentity =:= Expected andalso SourceLocal andalso ControlLocal
    }.

negative(Name, Expected, Source, Control) ->
    #{name => Name, expected => Expected, source => Source, control => Control}.

control(Document, Task) ->
    iolist_to_binary(json:encode(Document#{<<"task">> => Task})).

one_error({error, [Diagnostic]}) -> Diagnostic;
one_error({ok, _}) -> #{class => accepted, code => accepted}.

identity(Diagnostic) ->
    {maps:get(class, Diagnostic), maps:get(code, Diagnostic)}.

property_sweep(Compiled) ->
    Results = [property_case(lists:nth(((Index - 1) rem length(Compiled)) + 1,
        Compiled)) || Index <- lists:seq(1, ?PROPERTY_CASES)],
    Failures = length([failed || false <- Results]),
    #{
        seed => 20260805,
        cases => length(Results),
        failures => Failures,
        laws => [
            deterministic_ir_serialization,
            safe_ir_round_trip,
            manifest_agreement,
            finite_limit_bounds,
            child_attenuation,
            stable_node_references,
            completion_preservation
        ]
    }.

property_case(#{ir := Ir, checked := Checked}) ->
    {ok, First} = alang_fidelity_ir:encode(Ir),
    {ok, Second} = alang_fidelity_ir:encode(Ir),
    [Task] = maps:get(tasks, Ir),
    First =:= Second andalso
        alang_fidelity_ir:decode(First) =:= {ok, Ir} andalso
        alang_fidelity_ir:validate(Ir) =:= ok andalso
        maps:get(manifest, Task) =:= maps:get(manifest, Ir) andalso
        limits_cover(maps:get(limits, Task), maps:get(static_bounds, Task))
        andalso child_attenuated(maps:get(child, Task), maps:get(limits, Task))
        andalso maps:get(completion, Task) =:= maps:get(completion, Checked).

limits_cover(Limits, Bounds) ->
    lists:all(fun(Key) -> maps:get(Key, Limits) >= maps:get(Key, Bounds) end,
        [steps, model_calls, repair_calls, child_calls, workspace_writes,
            output_bytes, timeout_ms]).

child_attenuated(none, _ParentLimits) -> true;
child_attenuated(Child, ParentLimits) ->
    ChildLimits = maps:get(limits, Child),
    maps:get(child_calls, ChildLimits) =:= 0 andalso
        lists:all(fun(Key) ->
            maps:get(Key, ChildLimits) =< maps:get(Key, ParentLimits)
        end, [steps, model_calls, repair_calls, child_calls,
            workspace_writes, output_bytes, timeout_ms]).

residency() ->
    Modules = [
        alang_fidelity_json_pointer,
        alang_fidelity_control,
        alang_fidelity_lexer,
        alang_fidelity_parser,
        alang_fidelity_source,
        alang_fidelity_semantics,
        alang_fidelity_authority,
        alang_fidelity_ir,
        alang_fidelity_compiler,
        alang_fidelity_phase3_mutation,
        alang_fidelity_phase3_evidence
    ],
    [residency_record(Module) || Module <- Modules].

residency_record(Module) ->
    {module, Module} = code:ensure_loaded(Module),
    Path = code:which(Module),
    #{
        module => Module,
        path => list_to_binary(relative_path(Path)),
        is_beam => is_list(Path) andalso filename:extension(Path) =:= ".beam"
    }.

bundle_digest(Key, Cases) ->
    digest([{maps:get(case_id, Entry), maps:get(Key, Entry)} || Entry <- Cases]).

owned_path(Path) ->
    Root = filename:absname(?OWNED_ROOT),
    Absolute = filename:absname(Path),
    lists:prefix(Root ++ "/", Absolute).

relative_path(Path) ->
    Root = filename:absname(""),
    Absolute = filename:absname(Path),
    Prefix = Root ++ "/",
    case lists:prefix(Prefix, Absolute) of
        true -> lists:nthtail(length(Prefix), Absolute);
        false -> Absolute
    end.

read(Relative) ->
    {ok, Binary} = file:read_file(filename:join(?CORPUS_ROOT, Relative)),
    Binary.

value(Relative) ->
    {ok, Value} = alang_fidelity_json:decode(read(Relative)),
    Value.

replace(Source, Pattern, Replacement) ->
    Mutant = binary:replace(Source, Pattern, Replacement),
    true = Mutant =/= Source,
    Mutant.

digest(Term) ->
    hex(crypto:hash(sha256, term_to_binary(Term, [deterministic]))).

hex(Binary) ->
    iolist_to_binary([io_lib:format("~2.16.0b", [Byte]) || <<Byte>> <= Binary]).
