-module(alang_fidelity_lowering_tests).

-include_lib("eunit/include/eunit.hrl").

all_frozen_pairs_lower_to_identical_v2_ir_test() ->
    Files = source_files(),
    ?assertEqual(24, length(Files)),
    lists:foreach(fun(SourcePath) ->
        {ok, Source} = file:read_file(SourcePath),
        {ok, Control} = file:read_file(
            filename:rootname(SourcePath, ".alang") ++ ".json"),
        {ok, SourceLowered} = alang_fidelity_compiler:compile_source(Source),
        {ok, ControlLowered} = alang_fidelity_compiler:compile_control(Control),
        ?assertEqual(maps:get(ir, SourceLowered), maps:get(ir, ControlLowered)),
        ?assertEqual(maps:get(ir_digest, SourceLowered),
            maps:get(ir_digest, ControlLowered)),
        ?assertEqual(maps:get(semantic_digest, SourceLowered),
            maps:get(semantic_digest, ControlLowered)),
        ?assertEqual(ok, alang_fidelity_ir:validate(maps:get(ir, SourceLowered)))
    end, Files).

declared_effects_must_equal_operation_inference_test() ->
    Source = read("single-model-artifact/sma-simple.alang"),
    SourceMutant = binary:replace(Source,
        <<"effects [model.generate, workspace.write]">>,
        <<"effects [model.generate]">>),
    Control = value("single-model-artifact/sma-simple.json"),
    Task = maps:get(<<"task">>, Control),
    JsonMutant = Control#{<<"task">> => Task#{
        <<"effects">> => [<<"model.generate">>]
    }},
    ?assertEqual({authority, declared_effect_mismatch},
        error_identity(alang_fidelity_compiler:compile_source(SourceMutant))),
    ?assertEqual({authority, declared_effect_mismatch},
        error_identity(alang_fidelity_compiler:compile_control(encode(JsonMutant)))).

unused_or_dynamic_resource_authority_is_rejected_test() ->
    Source = read("single-model-artifact/sma-simple.alang"),
    SourceMutant = binary:replace(Source, <<"models [writer-model]">>,
        <<"models [writer-model, spare-model]">>),
    Control = value("single-model-artifact/sma-simple.json"),
    Task = maps:get(<<"task">>, Control),
    Scopes = maps:get(<<"scopes">>, Task),
    JsonMutant = Control#{<<"task">> => Task#{<<"scopes">> =>
        Scopes#{<<"models">> => [<<"writer-model">>, <<"spare-model">>]}}},
    ?assertEqual({authority, dynamic_resource_selector},
        error_identity(alang_fidelity_compiler:compile_source(SourceMutant))),
    ?assertEqual({authority, dynamic_resource_selector},
        error_identity(alang_fidelity_compiler:compile_control(encode(JsonMutant)))).

limits_cover_direct_and_delegated_static_bounds_test() ->
    Simple = read("single-model-artifact/sma-simple.alang"),
    SimpleLow = binary:replace(Simple, <<"steps 3;">>, <<"steps 2;">>),
    ?assertEqual({limit, limit_below_static_bound},
        error_identity(alang_fidelity_compiler:compile_source(SimpleLow))),
    Delegated = read("attenuated-delegation/ad-simple.alang"),
    DelegatedLow = binary:replace(Delegated, <<"model-calls 2;">>,
        <<"model-calls 1;">>),
    ?assertEqual({limit, limit_below_static_bound},
        error_identity(alang_fidelity_compiler:compile_source(DelegatedLow))),
    {ok, Lowered} = alang_fidelity_compiler:compile_source(Delegated),
    [Task] = maps:get(tasks, maps:get(ir, Lowered)),
    Bounds = maps:get(static_bounds, Task),
    ?assertEqual(2, maps:get(model_calls, Bounds)),
    ?assertEqual(1, maps:get(child_calls, Bounds)),
    ?assertEqual(1, maps:get(workspace_writes, Bounds)).

manifest_uses_closed_registry_mappings_without_grants_test() ->
    {ok, Lowered} = alang_fidelity_compiler:compile_source(
        read("repair-and-publish/rap-simple.alang")),
    Manifest = maps:get(manifest, maps:get(ir, Lowered)),
    ?assertEqual(alang_runtime_manifest_v2, maps:get(format, Manifest)),
    ?assertEqual([<<"model.generate">>, <<"workspace.write">>],
        maps:get(effects, Manifest)),
    Operations = maps:get(operations, Manifest),
    ?assertEqual(<<"model.complete">>, runtime_operation(
        <<"model.generate">>, Operations)),
    ?assertEqual(<<"model.complete">>, runtime_operation(
        <<"model.repair">>, Operations)),
    ?assertEqual(<<"workspace.write">>, runtime_operation(
        <<"workspace.write">>, Operations)),
    ?assertEqual(false, contains_key(grant, Manifest)),
    ?assertEqual(false, contains_key(credential, Manifest)),
    ?assertEqual(false, contains_key(capability_handle, Manifest)).

preorder_nodes_dependencies_and_effect_ordinals_are_stable_test() ->
    {ok, Lowered} = alang_fidelity_compiler:compile_source(
        read("single-model-artifact/sma-simple.alang")),
    [Draft, Publish, Finish] = maps:get(nodes, maps:get(ir, Lowered)),
    ?assertEqual(<<"node:task:sma-simple/1:0000">>, maps:get(id, Draft)),
    ?assertEqual(<<"node:task:sma-simple/1:0001">>, maps:get(id, Publish)),
    ?assertEqual(<<"node:task:sma-simple/1:0002">>, maps:get(id, Finish)),
    ?assertEqual(0, maps:get(effect_ordinal, Draft)),
    ?assertEqual(1, maps:get(effect_ordinal, Publish)),
    ?assertEqual([maps:get(id, Draft)], maps:get(dependencies, Publish)),
    ?assertEqual([maps:get(id, Publish)], maps:get(dependencies, Finish)),
    ?assertEqual(false, maps:is_key(effect_ordinal, Finish)).

deterministic_ir_etf_round_trips_safely_test() ->
    {ok, Lowered} = alang_fidelity_compiler:compile_control(
        read("single-model-artifact/sma-simple.json")),
    Ir = maps:get(ir, Lowered),
    {ok, First} = alang_fidelity_ir:encode(Ir),
    {ok, Second} = alang_fidelity_ir:encode(Ir),
    ?assertEqual(First, Second),
    ?assertEqual({ok, Ir}, alang_fidelity_ir:decode(First)),
    {ok, Digest} = alang_fidelity_ir:digest(Ir),
    ?assertEqual(Digest, maps:get(ir_digest, Lowered)),
    ?assertMatch({error, [#{code := compressed_ir_etf}]},
        alang_fidelity_ir:decode(<<131, 80, 0, 0, 0, 0>>)),
    ?assertMatch({error, [#{code := trailing_ir_data}]},
        alang_fidelity_ir:decode(<<First/binary, 0>>)).

ir_validation_detects_manifest_identity_and_child_widening_test() ->
    {ok, SimpleLowered} = alang_fidelity_compiler:compile_source(
        read("single-model-artifact/sma-simple.alang")),
    SimpleIr = maps:get(ir, SimpleLowered),
    SimpleManifest = maps:get(manifest, SimpleIr),
    [SimpleTask] = maps:get(tasks, SimpleIr),
    ReducedManifest = SimpleManifest#{effects => [<<"model.generate">>]},
    ManifestMutant = SimpleIr#{manifest => ReducedManifest,
        tasks => [SimpleTask#{manifest => ReducedManifest}]},
    ?assertEqual(manifest_effect_mismatch,
        ir_error_code(alang_fidelity_ir:validate(ManifestMutant))),
    [First | Rest] = maps:get(nodes, SimpleIr),
    IdentityMutant = SimpleIr#{nodes =>
        [First#{id => <<"node:unstable">>} | Rest]},
    ?assertEqual(unstable_node_identity,
        ir_error_code(alang_fidelity_ir:validate(IdentityMutant))),
    {ok, ChildLowered} = alang_fidelity_compiler:compile_source(
        read("attenuated-delegation/ad-simple.alang")),
    ChildIr = maps:get(ir, ChildLowered),
    [ChildTask] = maps:get(tasks, ChildIr),
    Child = maps:get(child, ChildTask),
    Limits = maps:get(limits, Child),
    ParentLimits = maps:get(limits, ChildTask),
    WideChild = Child#{limits => Limits#{model_calls =>
        maps:get(model_calls, ParentLimits) + 1}},
    WideNodes = [case maps:get(kind, Node) of
        delegate -> Node#{child => WideChild};
        _ -> Node
    end || Node <- maps:get(nodes, ChildIr)],
    WideIr = ChildIr#{tasks => [ChildTask#{child => WideChild}],
        nodes => WideNodes},
    ?assertEqual(child_limit_widens_parent,
        ir_error_code(alang_fidelity_ir:validate(WideIr))).

campaign_gate_requires_original_bytes_and_complete_provenance_test() ->
    Source = read("single-model-artifact/sma-simple.alang"),
    {ok, Checked} = alang_fidelity_semantics:check_source(Source),
    Artifact = campaign_artifact(alang_source, Source,
        maps:get(semantic_digest, Checked)),
    {ok, Lowered} = alang_fidelity_compiler:compile_campaign(Artifact),
    Provenance = maps:get(provenance, Lowered),
    ?assertEqual(alang_source, maps:get(frontend, Provenance)),
    ?assertEqual(maps:get(content_digest, Artifact),
        maps:get(source_digest, Provenance)),
    ?assertEqual(maps:get(semantic_digest, Artifact),
        maps:get(semantic_digest, Provenance)),
    ?assertEqual(maps:get(ir_digest, Lowered), maps:get(ir_digest, Provenance)),
    Ir = maps:get(ir, Lowered),
    ?assertEqual(manual_ir_forbidden,
        error_code(alang_fidelity_compiler:compile_campaign(Ir))),
    ?assertEqual(manual_ir_forbidden,
        error_code(alang_fidelity_compiler:compile_campaign(#{ir => Ir}))),
    ?assertEqual(non_deployable_fixture_forbidden,
        error_code(alang_fidelity_compiler:compile_campaign(#{fixture => Ir}))),
    ?assertEqual(invalid_campaign_input,
        error_code(alang_fidelity_compiler:compile_campaign(
            maps:remove(semantic_digest, Artifact)))),
    ?assertEqual(content_digest_mismatch,
        error_code(alang_fidelity_compiler:compile_campaign(
            Artifact#{content_digest => binary:copy(<<"0">>, 64)}))),
    ?assertEqual(semantic_digest_mismatch,
        error_code(alang_fidelity_compiler:compile_campaign(
            Artifact#{semantic_digest => binary:copy(<<"0">>, 64)}))).

campaign_artifact(Frontend, Content, SemanticDigest) ->
    #{
        format => alang_campaign_input_v1,
        frontend => Frontend,
        content => Content,
        content_digest => alang_fidelity_json:hex(crypto:hash(sha256, Content)),
        semantic_digest => SemanticDigest
    }.

runtime_operation(Semantic, Operations) ->
    [Operation] = [maps:get(runtime_operation, Entry) || Entry <- Operations,
        maps:get(semantic_operation, Entry) =:= Semantic],
    Operation.

contains_key(Key, Map) when is_map(Map) ->
    maps:is_key(Key, Map) orelse lists:any(fun(Value) -> contains_key(Key, Value) end,
        maps:values(Map));
contains_key(Key, List) when is_list(List) ->
    lists:any(fun(Value) -> contains_key(Key, Value) end, List);
contains_key(_Key, _Value) -> false.

error_identity({error, [Diagnostic]}) ->
    {maps:get(class, Diagnostic), maps:get(code, Diagnostic)}.

error_code({error, [Diagnostic]}) -> maps:get(code, Diagnostic).

ir_error_code({error, [Diagnostic]}) -> maps:get(code, Diagnostic).

source_files() ->
    lists:sort(filelib:wildcard(
        "assets/effectful-source-fidelity/corpus/*/*.alang")).

read(Relative) ->
    {ok, Binary} = file:read_file(filename:join(
        "assets/effectful-source-fidelity/corpus", Relative)),
    Binary.

value(Relative) ->
    {ok, Value} = alang_fidelity_json:decode(read(Relative)),
    Value.

encode(Value) ->
    iolist_to_binary(json:encode(Value)).
