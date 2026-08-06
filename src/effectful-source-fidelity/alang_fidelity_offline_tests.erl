-module(alang_fidelity_offline_tests).

-include_lib("eunit/include/eunit.hrl").

all_24_pairs_execute_with_equal_normalized_observations_test_() ->
    {timeout, 180, fun() ->
        Base = unique_base("matrix"),
        try
            {ok, Evidence} = alang_fidelity_offline:run_matrix(Base),
            ?assertEqual(24, maps:get(case_count, Evidence)),
            ?assertEqual(48, maps:get(representation_count, Evidence)),
            ?assertEqual(#{
                <<"attenuated-delegation">> => 8,
                <<"repair-and-publish">> => 8,
                <<"single-model-artifact">> => 8
            }, maps:get(family_counts, Evidence)),
            ?assert(lists:all(fun(Pair) ->
                maps:get(outcome_class, Pair) =:= complete orelse
                    maps:get(outcome_class, Pair) =:= incomplete
            end, maps:get(pairs, Evidence))),
            ?assert(lists:all(fun(Pair) ->
                maps:get(raw_artifacts_distinct, Pair) andalso
                    maps:get(accounting_valid, Pair)
            end, maps:get(pairs, Evidence))),
            ?assertMatch(<<_:64/binary>>, maps:get(evidence_digest, Evidence))
        after cleanup(Base) end
    end}.

paired_failure_incomplete_and_uncertain_classes_match_test_() ->
    {timeout, 120, fun() ->
        Base = unique_base("faults"),
        Scenarios = [
            {denied_scope, source("single-model-artifact/sma-simple")},
            {exhausted_budget, source("single-model-artifact/sma-simple")},
            {malformed_response, source("single-model-artifact/sma-simple")},
            {repair_failure, source("repair-and-publish/rap-simple")},
            {cancellation, source("attenuated-delegation/ad-simple")},
            {uncertain_workspace, source("single-model-artifact/sma-simple")},
            {wrong_digest, source("single-model-artifact/sma-simple")},
            {missing_information,
                source("single-model-artifact/sma-missing-information")}
        ],
        try
            Results = [alang_fidelity_offline:run_fault_pair(Scenario, Path,
                filename:join(Base, atom_to_list(Scenario))) || {Scenario, Path} <- Scenarios],
            ?assert(lists:all(fun(#{equal := Equal}) -> Equal end, Results)),
            Classes = maps:from_list([{maps:get(scenario, Result),
                maps:get(source_class, Result)} || Result <- Results]),
            ?assertEqual(scope_mismatch, maps:get(denied_scope, Classes)),
            ?assertEqual(budget_exhausted, maps:get(exhausted_budget, Classes)),
            ?assertEqual(repair_budget_exhausted, maps:get(malformed_response, Classes)),
            ?assertEqual(repair_failed, maps:get(repair_failure, Classes)),
            ?assertEqual(cancelled, maps:get(cancellation, Classes)),
            ?assertEqual(outcome_unknown, maps:get(uncertain_workspace, Classes)),
            ?assertEqual(incomplete, maps:get(wrong_digest, Classes)),
            ?assertEqual(incomplete, maps:get(missing_information, Classes))
        after cleanup(Base) end
    end}.

v2_specific_mutants_are_detected_test_() ->
    {timeout, 60, fun() ->
        Source = alang_fidelity_offline:compile_path(
            source("attenuated-delegation/ad-simple"), alang_source),
        Json = alang_fidelity_offline:compile_path(
            json("attenuated-delegation/ad-simple"), typed_json),
        SourceMetadata = maps:get(metadata, Source),
        JsonMetadata = maps:get(metadata, Json),
        IgnoredManifest = alang_fidelity_phase4_mutation:seed(
            ignored_manifest, SourceMetadata),
        ?assertMatch({error, {artifact_binding_mismatch, manifest}},
            alang_fidelity_artifact_v2:inspect(maps:get(beam, Source), IgnoredManifest)),
        SwappedMap = alang_fidelity_phase4_mutation:seed(source_map_swap,
            {SourceMetadata, JsonMetadata}),
        ?assertMatch({error, {artifact_binding_mismatch, source_map}},
            alang_fidelity_artifact_v2:inspect(maps:get(beam, Source), SwappedMap)),
        {ok, JsonContent} = file:read_file(
            json("single-model-artifact/sma-simple")),
        JsonBypass = alang_fidelity_phase4_mutation:seed(json_frontend_bypass,
            {JsonContent, maps:get(semantic_sha256, JsonMetadata)}),
        ?assertMatch({error, [_ | _]},
            alang_fidelity_compiler:compile_campaign(JsonBypass)),
        Base = unique_base("mutants"),
        try
            Options = alang_fidelity_offline:runtime_options(Source, Base,
                positive_child_responses(Source), none, true),
            Increased = alang_fidelity_phase4_mutation:seed(
                increased_runtime_limits, Options),
            ?assertEqual({error, invalid_fidelity_runtime_options},
                alang_fidelity_runtime:start(maps:get(beam, Source),
                    SourceMetadata, Increased)),
            Handler = alang_fidelity_phase4_mutation:seed(
                condition_specific_handler, Options),
            ?assertEqual({error, invalid_fidelity_runtime_options},
                alang_fidelity_runtime:start(maps:get(beam, Source),
                    SourceMetadata, Handler))
        after cleanup(Base) end,
        RepairBase = unique_base("repair-mutant"),
        try
            RepairPair = alang_fidelity_offline:run_pair(
                source("repair-and-publish/rap-simple"), RepairBase),
            SkippedRepair = alang_fidelity_phase4_mutation:seed(
                skipped_repair_accounting, maps:get(source, RepairPair)),
            ?assertEqual({error, counter_mismatch},
                alang_fidelity_offline:validate_accounting(SkippedRepair))
        after cleanup(RepairBase) end,
        WidenedIr = alang_fidelity_phase4_mutation:seed(
            child_authority_widening, maps:get(ir,
                compile_lowered(source("attenuated-delegation/ad-simple")))),
        ?assertMatch({error, [#{code := recursive_child_budget}]},
            alang_fidelity_ir:validate(WidenedIr)),
        ?assertMatch({error, [#{code := manual_ir_forbidden}]},
            alang_fidelity_compiler:compile_campaign(#{format => alang_typed_task_ir_v2}))
    end}.

inherited_phase_1_through_8_modules_remain_beam_resident_test() ->
    Modules = [alang_phase3_integration_tests, alang_phase4_integration_tests,
        alang_phase5_integration_tests, alang_phase6_integration_tests,
        alang_phase7_campaign_tests, alang_phase8_release_tests],
    ?assert(lists:all(fun(Module) ->
        Path = code:which(Module),
        is_list(Path) andalso filename:extension(Path) =:= ".beam"
    end, Modules)).

compile_lowered(Path) ->
    {ok, Binary} = file:read_file(Path),
    {ok, Lowered} = alang_fidelity_compiler:compile_source(Binary),
    Lowered.

positive_child_responses(Product) ->
    Metadata = maps:get(metadata, Product),
    Plan = maps:get(execution_plan, Metadata),
    maps:from_list([{maps:get(action_id, Step), #{status => success,
        output => <<"# Fixture\n\n## Findings\n\nBounded.\n">>}} || Step <- Plan,
        lists:member(maps:get(operation, Step, none),
            [<<"model.generate">>, <<"child.run">>])]).

source(Relative) -> filename:join(
    "assets/effectful-source-fidelity/corpus", Relative ++ ".alang").
json(Relative) -> filename:join(
    "assets/effectful-source-fidelity/corpus", Relative ++ ".json").

unique_base(Label) -> filename:join(filename:absname(
    "build/effectful-source-fidelity/phase-04/offline-tests"),
    Label ++ "-" ++ integer_to_list(erlang:unique_integer([monotonic, positive]))).

cleanup(Base) ->
    case filelib:is_dir(Base) of
        true -> file:del_dir_r(Base);
        false -> ok
    end.
