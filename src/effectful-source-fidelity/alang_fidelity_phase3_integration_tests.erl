-module(alang_fidelity_phase3_integration_tests).

-include_lib("proper/include/proper.hrl").
-include_lib("eunit/include/eunit.hrl").

-export([prop_ir_bounds_and_attenuation/0,
    prop_pair_lowering_is_deterministic/0]).

-define(CORPUS_GLOB, "assets/effectful-source-fidelity/corpus/*/*.alang").
-define(EVIDENCE_PATH,
    "build/effectful-source-fidelity/phase-03/evidence/lowering-evidence.etf").
-define(EVIDENCE_SHA256,
    <<"1d6f0c2a46a49d104bf7106d190e122aeca1d43fddd05fbb0c961ddbdea4d826">>).
-define(ARTIFACT_SHA256,
    <<"9f0f891c750528c1471a20791886e1a92692449a6b87eb5c16d0501a76a87801">>).
-define(SEMANTIC_BUNDLE_SHA256,
    <<"1e5d7321588c001d5851667a613a461a79b6e0d52a37daff6d24f8229c3a82ba">>).
-define(IR_BUNDLE_SHA256,
    <<"2f84a95398fe71b44e781d82b91a4b9fbf5b8c7efbc661c1a9a9109573de4a89">>).
-define(MANIFEST_BUNDLE_SHA256,
    <<"563c40e22ee58c601b9211a5fe610fa26c85acdecee3268b23abe841fd3f2e00">>).
-define(LIMITS_BUNDLE_SHA256,
    <<"db05e96dabe3b7fc92a20db1fef8a9ad78de11e6957cac2e4047500ee760c248">>).
-define(COMPLETION_BUNDLE_SHA256,
    <<"c1c2457e28c805e02e4a586a779085cb12221eff7a5a1246016e4a55bacdf9a1">>).

all_frozen_pairs_share_checked_meaning_and_v2_ir_test() ->
    Files = source_files(),
    ?assertEqual(24, length(Files)),
    lists:foreach(fun(Path) ->
        {Source, Control} = pair(Path),
        {ok, SourceChecked} = alang_fidelity_semantics:check_source(Source),
        {ok, ControlChecked} = alang_fidelity_semantics:check_control(Control),
        ?assertEqual(alang_fidelity_semantics:meaning(SourceChecked),
            alang_fidelity_semantics:meaning(ControlChecked)),
        ?assertEqual(alang_fidelity_semantics:digest(SourceChecked),
            alang_fidelity_semantics:digest(ControlChecked)),
        {ok, SourceLowered} = alang_fidelity_compiler:compile_source(Source),
        {ok, ControlLowered} = alang_fidelity_compiler:compile_control(Control),
        ?assertEqual(maps:get(ir, SourceLowered), maps:get(ir, ControlLowered)),
        ?assertEqual(maps:get(ir_digest, SourceLowered),
            maps:get(ir_digest, ControlLowered)),
        Ir = maps:get(ir, SourceLowered),
        ?assertEqual(alang_typed_task_ir_v2, maps:get(format, Ir)),
        ?assertEqual(ok, alang_fidelity_ir:validate(Ir)),
        [Task] = maps:get(tasks, Ir),
        ?assertEqual(maps:get(manifest, Ir), maps:get(manifest, Task)),
        ?assertEqual(maps:get(completion, SourceChecked),
            maps:get(completion, Task)),
        ?assertNotEqual(maps:get(source_map, SourceLowered),
            maps:get(source_map, ControlLowered))
    end, Files).

paired_semantic_defects_share_classes_and_local_origins_test() ->
    Results = alang_fidelity_phase3_evidence:negative_results(),
    ?assertEqual(8, length(Results)),
    lists:foreach(fun(Result) ->
        ?assertEqual(maps:get(expected, Result), maps:get(source_actual, Result)),
        ?assertEqual(maps:get(expected, Result), maps:get(control_actual, Result)),
        ?assertEqual(true, maps:get(source_local, Result)),
        ?assertEqual(true, maps:get(control_local, Result)),
        ?assertMatch(#{source := alang_source, byte := _},
            maps:get(source_origin, Result)),
        ?assertMatch(#{source := typed_json, pointer := _, byte := _},
            maps:get(control_origin, Result)),
        ?assertEqual(true, maps:get(matched, Result))
    end, Results).

ir_laws_bounds_completion_and_campaign_gate_test() ->
    lists:foreach(fun(Path) ->
        {Source, _Control} = pair(Path),
        {ok, Checked} = alang_fidelity_semantics:check_source(Source),
        {ok, Lowered} = alang_fidelity_compiler:compile_source(Source),
        Ir = maps:get(ir, Lowered),
        [Task] = maps:get(tasks, Ir),
        ?assert(limits_cover(maps:get(limits, Task),
            maps:get(static_bounds, Task))),
        ?assert(child_attenuated(maps:get(child, Task),
            maps:get(limits, Task))),
        ?assertEqual(maps:get(completion, Checked), maps:get(completion, Task)),
        ?assertEqual(ok, alang_fidelity_ir:validate(Ir)),
        {ok, Encoded} = alang_fidelity_ir:encode(Ir),
        ?assertEqual({ok, Ir}, alang_fidelity_ir:decode(Encoded)),
        ?assertEqual({ok, maps:get(ir_digest, Lowered)},
            alang_fidelity_ir:digest(Ir))
    end, source_files()),
    Source = element(1, pair(hd(source_files()))),
    {ok, Lowered} = alang_fidelity_compiler:compile_source(Source),
    Ir = maps:get(ir, Lowered),
    ?assertMatch({error, [#{code := manual_ir_forbidden}]},
        alang_fidelity_compiler:compile_campaign(Ir)),
    ?assertMatch({error, [#{code := non_deployable_fixture_forbidden}]},
        alang_fidelity_compiler:compile_campaign(#{fixture => Ir})),
    ?assertMatch({error, [#{code := non_deployable_fixture_forbidden}]},
        alang_fidelity_compiler:compile_campaign(#{reference_evaluator => Ir})).

seeded_checker_and_lowering_mutants_are_detected_test() ->
    Results = alang_fidelity_phase3_mutation:run(),
    ?assertEqual(6, length(Results)),
    ?assertEqual([
        removed_effect_inference,
        widened_child_limits,
        ignored_completion_fields,
        condition_specific_defaults,
        unstable_node_identities,
        direct_ir_acceptance
    ], [maps:get(name, Result) || Result <- Results]),
    lists:foreach(fun(Result) ->
        ?assertEqual(maps:get(expected, Result), maps:get(actual, Result)),
        ?assertEqual(true, maps:get(detected, Result))
    end, Results).

evidence_is_reproducible_and_freezes_the_complete_gate_test() ->
    {ok, First} = alang_fidelity_phase3_evidence:build(),
    {ok, Second} = alang_fidelity_phase3_evidence:build(),
    ?assertEqual(First, Second),
    ?assertEqual(?EVIDENCE_SHA256, maps:get(evidence_sha256, First)),
    Body = maps:get(evidence, First),
    ?assertEqual(?SEMANTIC_BUNDLE_SHA256,
        maps:get(semantic_bundle_sha256, Body)),
    ?assertEqual(?IR_BUNDLE_SHA256, maps:get(ir_bundle_sha256, Body)),
    ?assertEqual(?MANIFEST_BUNDLE_SHA256,
        maps:get(manifest_bundle_sha256, Body)),
    ?assertEqual(?LIMITS_BUNDLE_SHA256,
        maps:get(limits_bundle_sha256, Body)),
    ?assertEqual(?COMPLETION_BUNDLE_SHA256,
        maps:get(completion_bundle_sha256, Body)),
    ?assertEqual(24, maps:get(corpus_count, Body)),
    ?assertEqual(8, maps:get(negative_case_count, Body)),
    ?assertEqual(6, maps:get(mutant_count, Body)),
    ?assertEqual(0, maps:get(hosted_calls, Body)),
    ?assertEqual(false, maps:get(campaign_accepts_manual_ir, Body)),
    ?assertEqual([], maps:get(compiler_runtime_effects, Body)),
    ?assertEqual([], maps:get(foreign_compiler_executables, Body)),
    Properties = maps:get(property_results, Body),
    ?assertEqual(256, maps:get(cases, Properties)),
    ?assertEqual(0, maps:get(failures, Properties)),
    ?assert(lists:all(fun(Entry) -> maps:get(matched, Entry) end,
        maps:get(cases, Body))),
    ?assert(lists:all(fun(Entry) -> maps:get(matched, Entry) end,
        maps:get(negative_cases, Body))),
    ?assert(lists:all(fun(Entry) -> maps:get(detected, Entry) end,
        maps:get(mutants, Body))),
    ?assert(lists:all(fun(Entry) -> maps:get(is_beam, Entry) end,
        maps:get(module_residency, Body))).

written_evidence_safe_decodes_and_matches_frozen_artifact_test() ->
    {ok, Written} = alang_fidelity_phase3_evidence:write(?EVIDENCE_PATH),
    {ok, Binary} = file:read_file(?EVIDENCE_PATH),
    {Artifact, Used} = binary_to_term(Binary, [safe, used]),
    ?assertEqual(byte_size(Binary), Used),
    ?assertEqual(maps:remove(artifact_sha256, Written), Artifact),
    ?assertEqual(?ARTIFACT_SHA256, maps:get(artifact_sha256, Written)),
    ?assertEqual(?EVIDENCE_SHA256, maps:get(evidence_sha256, Written)),
    ?assertEqual({error, evidence_path_outside_owned_root},
        alang_fidelity_phase3_evidence:write("build/outside-phase3.etf")).

generated_pair_and_ir_laws_test_() ->
    {timeout, 45, fun() ->
        Options = [{numtests, 128}, {max_size, 24}, quiet],
        ?assertEqual(true, proper:quickcheck(
            prop_pair_lowering_is_deterministic(), Options)),
        ?assertEqual(true, proper:quickcheck(
            prop_ir_bounds_and_attenuation(), Options))
    end}.

prop_pair_lowering_is_deterministic() ->
    ?FORALL(Index, proper_types:choose(1, 24), safe_pair_property(Index)).

prop_ir_bounds_and_attenuation() ->
    ?FORALL(Index, proper_types:choose(1, 24), safe_bound_property(Index)).

safe_pair_property(Index) ->
    try
        Path = lists:nth(Index, source_files()),
        {Source, Control} = pair(Path),
        {ok, SourceLowered} = alang_fidelity_compiler:compile_source(Source),
        {ok, ControlLowered} = alang_fidelity_compiler:compile_control(Control),
        Ir = maps:get(ir, SourceLowered),
        {ok, First} = alang_fidelity_ir:encode(Ir),
        {ok, Second} = alang_fidelity_ir:encode(Ir),
        PairEqual = maps:get(ir, SourceLowered) =:= maps:get(ir, ControlLowered),
        PairEqual andalso First =:= Second andalso
            alang_fidelity_ir:decode(First) =:= {ok, Ir}
    catch
        _:_ -> false
    end.

safe_bound_property(Index) ->
    try
        Path = lists:nth(Index, source_files()),
        {Source, _Control} = pair(Path),
        {ok, Lowered} = alang_fidelity_compiler:compile_source(Source),
        Ir = maps:get(ir, Lowered),
        [Task] = maps:get(tasks, Ir),
        alang_fidelity_ir:validate(Ir) =:= ok andalso
            limits_cover(maps:get(limits, Task),
                maps:get(static_bounds, Task)) andalso
            child_attenuated(maps:get(child, Task), maps:get(limits, Task))
    catch
        _:_ -> false
    end.

limits_cover(Limits, Bounds) ->
    lists:all(fun(Key) -> maps:get(Key, Limits) >= maps:get(Key, Bounds) end,
        limit_keys()).

child_attenuated(none, _ParentLimits) -> true;
child_attenuated(Child, ParentLimits) ->
    ChildLimits = maps:get(limits, Child),
    maps:get(child_calls, ChildLimits) =:= 0 andalso
        lists:all(fun(Key) ->
            maps:get(Key, ChildLimits) =< maps:get(Key, ParentLimits)
        end, limit_keys()).

limit_keys() ->
    [steps, model_calls, repair_calls, child_calls, workspace_writes,
        output_bytes, timeout_ms].

source_files() ->
    lists:sort(filelib:wildcard(?CORPUS_GLOB)).

pair(SourcePath) ->
    {ok, Source} = file:read_file(SourcePath),
    {ok, Control} = file:read_file(
        filename:rootname(SourcePath, ".alang") ++ ".json"),
    {Source, Control}.
