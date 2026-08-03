-module(alang_phase3_artifact_tests).

-include_lib("eunit/include/eunit.hrl").

-define(TOOLCHAIN, "src/phase-01/toolchain.config").
-define(GENERATED_MODULE, alang_phase3_program_v1).

metadata_and_policy_are_inspected_without_execution_test() ->
    Compiled = compiled_counter(),
    {ok, Inspection} = alang_phase3_artifact:inspect(maps:get(beam, Compiled)),
    ?assertEqual(accepted, maps:get(policy, Inspection)),
    ?assertEqual(?GENERATED_MODULE, maps:get(module, Inspection)),
    ?assertEqual(maps:get(beam_sha256, Compiled), maps:get(beam_sha256, Inspection)),
    Metadata = maps:get(metadata, Inspection),
    ?assertEqual(alang_runtime_v1, maps:get(abi, Metadata)),
    ?assertEqual(alang_phase3_backend, maps:get(module, maps:get(compiler, Metadata))),
    ?assertEqual(alang_phase3_otp29_v1,
        maps:get(compiler_profile, maps:get(reproducibility, Metadata))),
    ?assertEqual(alang_phase1_compiler:current_toolchain(), maps:get(toolchain, Metadata)),
    ?assertEqual(false, code:is_loaded(?GENERATED_MODULE)).

inspector_reports_closed_import_export_and_chunk_surfaces_test() ->
    Compiled = compiled_counter(),
    {ok, Inspection} = alang_phase3_artifact:inspect(maps:get(beam, Compiled)),
    ?assertEqual(
        lists:sort([{execute, 3}, {module_info, 0}, {module_info, 1}]),
        maps:get(exports, Inspection)
    ),
    ?assertEqual([], maps:get(imports, Inspection) -- alang_phase3_contract:allowed_beam_imports()),
    ?assert(lists:member("Attr", maps:get(chunks, Inspection))),
    ?assert(lists:member("CInf", maps:get(chunks, Inspection))).

forbidden_import_is_rejected_before_load_test() ->
    Compiled = compiled_counter(),
    Metadata = maps:get(metadata, Compiled),
    Beam = compile_unchecked(external_call_forms(Metadata, os, cmd, [{string, 1, "id"}])),
    ?assertEqual(
        {error, {forbidden_beam_imports, [{os, cmd, 1}]}},
        alang_phase3_artifact:inspect(Beam)
    ),
    ?assertEqual(false, code:is_loaded(?GENERATED_MODULE)).

incompatible_metadata_is_rejected_before_load_test() ->
    Compiled = compiled_counter(),
    Metadata = (maps:get(metadata, Compiled))#{abi := alang_runtime_v2},
    Beam = compile_unchecked(return_forms(Metadata, {atom, 1, ok})),
    ?assertEqual({error, incompatible_backend_metadata}, alang_phase3_artifact:inspect(Beam)),
    ?assertEqual(false, code:is_loaded(?GENERATED_MODULE)).

invalid_digest_and_toolchain_are_rejected_test() ->
    Compiled = compiled_counter(),
    Metadata = maps:get(metadata, Compiled),
    BadDigestBeam = compile_unchecked(return_forms(Metadata#{source_sha256 := <<"short">>}, {atom, 1, ok})),
    ?assertEqual({error, invalid_source_digest}, alang_phase3_artifact:inspect(BadDigestBeam)),
    Toolchain = maps:get(toolchain, Metadata),
    BadToolchain = Toolchain#{otp_release := <<"30">>},
    BadToolchainBeam = compile_unchecked(return_forms(Metadata#{toolchain := BadToolchain}, {atom, 1, ok})),
    ?assertEqual(
        {error, incompatible_artifact_toolchain},
        alang_phase3_artifact:inspect(BadToolchainBeam)
    ).

oversized_and_corrupt_containers_fail_before_beam_parsing_or_load_test() ->
    ?assertMatch(
        {error, {beam_size_limit_exceeded, _}},
        alang_phase3_artifact:inspect(binary:copy(<<0>>, 1048577))
    ),
    ?assertMatch({error, {invalid_beam_container, _}}, alang_phase3_artifact:inspect(<<"not-beam">>)),
    ?assertEqual(false, code:is_loaded(?GENERATED_MODULE)).

approved_artifact_loads_executes_and_purges_test() ->
    Compiled = compiled_counter(),
    Beam = maps:get(beam, Compiled),
    ?assertEqual(false, code:is_loaded(?GENERATED_MODULE)),
    {ok, Result} = alang_phase3_artifact:run(
        Beam,
        <<"task:Counter.successor/1">>,
        #{<<"value">> => 41},
        runtime_options()
    ),
    ?assertEqual(42, maps:get(value, Result)),
    ?assertEqual(false, code:is_loaded(?GENERATED_MODULE)).

already_loaded_generated_module_is_not_replaced_test() ->
    Compiled = compiled_counter(),
    Beam = maps:get(beam, Compiled),
    {ok, ?GENERATED_MODULE, _Inspection} = alang_phase3_artifact:load(Beam),
    try
        ?assertMatch(
            {error, {generated_module_already_loaded, _}},
            alang_phase3_artifact:load(Beam)
        )
    after
        ok = alang_phase3_artifact:purge(?GENERATED_MODULE)
    end,
    ?assertEqual(false, code:is_loaded(?GENERATED_MODULE)).

compiled_counter() ->
    {ok, Source} = file:read_file("src/phase-02/fixtures/counter.alang"),
    {ok, Product} = alang_phase2_compiler:compile_source(Source),
    Context = #{
        source_sha256 => sha256(Source),
        capability_manifest => maps:get(capability_manifest, maps:get(views, Product))
    },
    {ok, Compiled} = alang_phase3_backend:compile_ir(maps:get(ir, Product), Context, ?TOOLCHAIN),
    Compiled.

external_call_forms(Metadata, Module, Function, Arguments) ->
    module_forms(Metadata, {call, 1, {remote, 1, {atom, 1, Module}, {atom, 1, Function}}, Arguments}).

return_forms(Metadata, Expression) -> module_forms(Metadata, Expression).

module_forms(Metadata, Expression) ->
    [
        {attribute, 1, module, ?GENERATED_MODULE},
        {attribute, 1, export, [{execute, 3}]},
        {attribute, 1, alang_backend, Metadata},
        {function, 1, execute, 3, [
            {clause, 1, [{var, 1, '_'}, {var, 1, '_'}, {var, 1, '_'}], [], [Expression]}
        ]}
    ].

compile_unchecked(Forms) ->
    Options = [binary, deterministic, no_debug_info, no_docs, return_errors, return_warnings],
    {ok, ?GENERATED_MODULE, Beam, []} = compile:forms(Forms, Options),
    Beam.

runtime_options() ->
    #{
        handler => fun(_Operation, _Arguments) -> {error, <<"unexpected-effect">>} end,
        timeout => 1000,
        max_in_flight => 1,
        max_mailbox => 16,
        max_trace_events => 32
    }.

sha256(Binary) ->
    iolist_to_binary([io_lib:format("~2.16.0b", [Byte]) || <<Byte>> <= crypto:hash(sha256, Binary)]).
