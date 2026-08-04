-module(alang_phase8_decision).

-export([decision/0, main/0, validate/1, write/1]).

-define(DEFAULT_OUTPUT, "build/phase-08/decision/architecture-decision.config").

-spec main() -> no_return().
main() ->
    Path = case init:get_plain_arguments() of
        [Output] -> Output;
        [] -> ?DEFAULT_OUTPUT;
        Arguments -> fail_main({invalid_arguments, Arguments})
    end,
    case write(Path) of
        {ok, Record} ->
            io:format("phase8_decision_ok combined=~p next=~p output=~s~n",
                [outcome(combined_architecture, Record),
                    maps:get(id, maps:get(next_decision_boundary, Record)), Path]),
            halt(0);
        {error, Reason} -> fail_main(Reason)
    end.

-spec decision() -> map().
decision() -> #{format => alang_phase8_architecture_decision_v1,
    scope => minimal_beam_native_agent_language_proof_of_concept,
    dispositions => [
        disposition(task_language, narrow,
            [typed_source_and_ir_are_machine_checked,
                effects_authority_and_completion_are_explicit],
            [llm_task_understanding_improvement, effectful_source_language,
                authoring_or_reviewer_advantage],
            ["src/phase-02/phase-02-integration-evidence.md",
                "src/phase-08/controlled-baseline-and-ablation-comparison.md"]),
        disposition(categorical_ir, narrow,
            [declared_laws_are_executable, compiled_and_reference_observations_agree,
                seeded_law_defects_are_detected],
            [advantage_over_conventional_typed_ir, formal_proof,
                human_value_of_categorical_notation],
            ["src/phase-07/typed-generators-and-law-observations.md",
                "src/phase-07/seeded-defect-sensitivity.md",
                "src/phase-08/controlled-baseline-and-ablation-comparison.md"]),
        disposition(beam_compiler_and_runtime, promote,
            [trusted_toolchain_runs_on_erts, generated_programs_are_inspected_beam,
                supervised_faults_are_bounded],
            [multi_otp_compatibility, production_scale, hostile_code_isolation,
                superiority_to_alternative_runtimes],
            ["src/phase-01/beam-execution-evidence.md",
                "src/phase-03/artifact-contract.md",
                "src/phase-07/fault-and-performance-characterization.md",
                "src/phase-08/reproducible-demonstration-package.md"]),
        disposition(local_capability_broker, promote,
            [opaque_local_grants_restrict_scope_and_budget,
                direct_handler_ablation_performs_unauthorized_writes,
                denials_are_structured_and_auditable],
            [portable_delegation, cross_node_authority, malicious_beam_sandboxing],
            ["src/phase-04/phase-04-integration-evidence.md",
                "src/phase-08/controlled-baseline-and-ablation-comparison.md"]),
        disposition(explicit_durability, promote,
            [intent_result_and_checkpoint_order_is_enforced,
                ambiguous_effects_remain_explicitly_uncertain,
                bounded_fault_cases_preserve_single_logical_effect],
            [exactly_once_external_effects, distributed_consensus,
                production_storage_operability],
            ["src/phase-05/phase-05-integration-evidence.md",
                "src/phase-07/fault-and-performance-characterization.md"]),
        disposition(combined_architecture, revise,
            [one_offline_vertical_slice_is_reproducible,
                core_layers_interoperate_on_beam,
                negative_and_tamper_cases_fail_closed],
            [production_readiness, general_agent_language_value,
                live_model_reliability, user_facing_effectful_language],
            ["src/phase-08/reproducible-demonstration-package.md",
                "src/phase-08/controlled-baseline-and-ablation-comparison.md"])
    ],
    accepted_claims => [
        the_pinned_otp29_toolchain_and_generated_programs_execute_on_erts,
        the_frozen_ir_semantics_agree_with_bounded_oracles,
        the_local_broker_materially_enforces_scope_and_budget,
        explicit_durability_preserves_bounded_recovery_classifications,
        completion_is_backed_by_artifact_and_journal_evidence
    ],
    rejected_claims => [
        the_poc_shows_that_llms_understand_tasks_better,
        categorical_ir_outperforms_a_conventional_typed_ir,
        the_current_source_language_expresses_the_effectful_demo,
        beam_processes_are_a_hostile_code_security_boundary,
        single_host_characterization_establishes_production_scale,
        property_tests_constitute_formal_proof
    ],
    next_decision_boundary => #{
        id => effectful_source_task_language_value,
        question => <<"Can user-authored effectful A-Lang source improve task-specification fidelity over a conventional typed notation while compiling through the same BEAM runtime enforcement path?">>,
        required_evidence => [
            no_manually_constructed_ir_in_acceptance_tasks,
            effectful_source_syntax_for_model_workspace_child_and_completion,
            static_manifest_derivation_and_source_local_diagnostics,
            matched_multi_task_comparison_against_conventional_typed_notation,
            llm_fidelity_results_across_at_least_two_declared_model_families,
            human_authoring_and_review_measurement_if_human_advantage_is_claimed,
            unchanged_broker_durability_and_completion_negative_gates
        ],
        frozen_features => [
            general_recursion, polymorphism, parallel_composition, distribution,
            portable_delegation, additional_effect_families, package_management,
            self_hosting, user_visible_categorical_notation
        ],
        decision_rule => promote_only_if_source_fidelity_improves_without_weakening_runtime_gates
    },
    production_status => not_approved,
    continuation_status => one_bounded_prototype_approved}.

disposition(Hypothesis, Outcome, Demonstrated, NotEstablished, Paths) -> #{
    hypothesis => Hypothesis, outcome => Outcome, demonstrated => Demonstrated,
    not_established => NotEstablished,
    evidence_paths => [list_to_binary(Path) || Path <- Paths]}.

-spec validate(term()) -> ok | {error, term()}.
validate(#{format := alang_phase8_architecture_decision_v1,
    dispositions := Dispositions, accepted_claims := Accepted,
    rejected_claims := Rejected, next_decision_boundary := Boundary,
    production_status := not_approved,
    continuation_status := one_bounded_prototype_approved}) when
    is_list(Dispositions), is_list(Accepted), Accepted =/= [],
    is_list(Rejected), Rejected =/= [], is_map(Boundary)
->
    Expected = [task_language, categorical_ir, beam_compiler_and_runtime,
        local_capability_broker, explicit_durability, combined_architecture],
    Names = [maps:get(hypothesis, Entry) || Entry <- Dispositions],
    case lists:sort(Names) =:= lists:sort(Expected) andalso
        length(Names) =:= length(lists:usort(Names)) andalso
        lists:all(fun valid_disposition/1, Dispositions) andalso
        valid_boundary(Boundary) andalso evidence_paths_exist(Dispositions)
    of
        true -> ok;
        false -> {error, invalid_architecture_decision}
    end;
validate(_) -> {error, invalid_architecture_decision}.

valid_disposition(#{outcome := Outcome, demonstrated := Demonstrated,
    not_established := NotEstablished, evidence_paths := Evidence}) ->
    lists:member(Outcome, [promote, revise, narrow, replace, stop]) andalso
        is_list(Demonstrated) andalso Demonstrated =/= [] andalso
        is_list(NotEstablished) andalso NotEstablished =/= [] andalso
        is_list(Evidence) andalso Evidence =/= [];
valid_disposition(_) -> false.

valid_boundary(#{id := effectful_source_task_language_value,
    question := Question, required_evidence := Required, frozen_features := Frozen,
    decision_rule := promote_only_if_source_fidelity_improves_without_weakening_runtime_gates}) ->
    is_binary(Question) andalso byte_size(Question) > 0 andalso
        is_list(Required) andalso Required =/= [] andalso
        is_list(Frozen) andalso Frozen =/= [];
valid_boundary(_) -> false.

evidence_paths_exist(Dispositions) -> lists:all(fun(Path) ->
    filelib:is_regular(binary_to_list(Path))
end, lists:append([maps:get(evidence_paths, Entry) || Entry <- Dispositions])).

outcome(Hypothesis, Record) -> maps:get(outcome, hd([Entry || Entry <-
    maps:get(dispositions, Record), maps:get(hypothesis, Entry) =:= Hypothesis])).

-spec write(file:filename()) -> {ok, map()} | {error, term()}.
write(Path0) ->
    try
        Path = filename:absname(Path0),
        Root = filename:absname("build/phase-08"),
        true = lists:prefix(Root ++ "/", Path),
        Record = decision(),
        ok = validate(Record),
        ok = filelib:ensure_dir(Path),
        ok = file:write_file(Path, io_lib:format("~tp.~n", [Record])),
        {ok, Record}
    catch Class:Reason -> {error, {Class, Reason}} end.

fail_main(Reason) ->
    io:format(standard_error, "phase8_decision_error ~tp~n", [Reason]),
    halt(1).
