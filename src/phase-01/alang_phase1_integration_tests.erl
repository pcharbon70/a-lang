-module(alang_phase1_integration_tests).

-export([main/0]).

-include_lib("eunit/include/eunit.hrl").

-define(ARTIFACT, "build/phase-01/artifact").
-define(TAMPERED_ARTIFACT, "build/phase-01/integration-tampered-artifact").
-define(CONFIG, "src/phase-01/toolchain.config").
-define(FIXTURE, "src/phase-01/semantic-fixture.config").

main() ->
    case eunit:test(?MODULE, [verbose]) of
        ok -> halt(0);
        error -> halt(1)
    end.

isolated_named_node_test() ->
    ?assertNotEqual(nonode@nohost, node()).

canonical_beam_execution_test() ->
    {ok, Observation} = run(canonical_success),
    ?assertEqual(ok, maps:get(classification, Observation)),
    ?assertEqual(
        [
            {alang_v1, trace, <<"phase-1-success">>, received},
            {
                alang_v1,
                trace,
                <<"phase-1-success">>,
                {transition, waiting, completed}
            },
            {alang_v1, result, <<"phase-1-success">>, {ok, 42}}
        ],
        maps:get(messages, Observation)
    ),
    ?assertEqual(normal, maps:get(exit_reason, Observation)),
    ?assertEqual(true, maps:get(scheduler_visible, Observation)),
    ?assert(
        maps:get(reductions_after, Observation) > maps:get(reductions_before, Observation)
    ),
    ?assertNot(is_process_alive(maps:get(generated_pid, Observation))).

typed_runtime_rejections_test_() ->
    Cases = [
        {unsupported_abi, unsupported_abi},
        {invalid_payload, invalid_payload},
        {oversized_payload, payload_too_large},
        {unavailable_operation, unavailable_operation},
        {invalid_correlation, invalid_correlation},
        {invalid_reply_target, invalid_reply_target},
        {malformed_envelope, malformed_envelope},
        {unexpected_process_exit, unexpected_process_exit}
    ],
    [
        {atom_to_list(CaseName), fun() -> assert_rejection(CaseName, Expected) end}
     || {CaseName, Expected} <- Cases
    ].

manifest_tampering_is_rejected_before_load_test() ->
    {ok, Built} = alang_phase1_package:build(?TAMPERED_ARTIFACT, ?FIXTURE, ?CONFIG),
    ManifestPath = maps:get(manifest_path, Built),
    {ok, ManifestBytes} = file:read_file(ManifestPath),
    ok = file:write_file(ManifestPath, <<ManifestBytes/binary, 0>>, [binary]),
    ?assertMatch(
        {error, {invalid_manifest, _}},
        alang_phase1_package:verify(?TAMPERED_ARTIFACT, ?FIXTURE, ?CONFIG)
    ).

forbidden_beam_import_is_rejected_before_load_test() ->
    {ok, phase1_counter_v1, Beam, []} = compile:forms(
        forbidden_import_forms(),
        [binary, deterministic, no_debug_info, no_docs, return_errors, return_warnings]
    ),
    ?assertMatch(
        {error, {forbidden_beam_imports, [{os, cmd, 1}]}},
        alang_phase1_compiler:inspect_beam(Beam)
    ).

unsupported_abstract_form_is_rejected_before_compile_test() ->
    [Module, Export, Function] = minimal_allowed_forms(),
    Unsupported = {attribute, 2, on_load, {start, 1}},
    ?assertMatch(
        {error, {unsupported_module_shape, _}},
        alang_phase1_compiler:validate_allowed_forms([Module, Export, Unsupported, Function])
    ).

otp_target_drift_is_rejected_before_load_test() ->
    {ok, Config} = alang_phase1_compiler:load_toolchain_config(?CONFIG),
    Wrong = Config#{erts_version := <<"0.0">>},
    ?assertMatch(
        {error, {toolchain_mismatch, [{erts_version, <<"0.0">>, _}]}},
        alang_phase1_compiler:check_toolchain_config(Wrong)
    ).

no_interpreter_gate_test() ->
    {ok, Observation} = run(canonical_success),
    Proof = maps:get(no_interpreter_proof, Observation),
    ?assertEqual(true, maps:get(passed, Proof)),
    ?assertEqual(code_load_binary, maps:get(loader, Proof)),
    ?assertEqual(
        {phase1_counter_v1, start, 1},
        maps:get(current_function, Proof)
    ),
    ?assertEqual([], maps:get(forbidden_imports, Proof)),
    ?assertEqual([], maps:get(forbidden_stack_modules, Proof)),
    ?assertEqual(
        [],
        maps:get(generated_imports, Proof) -- alang_phase1_compiler:allowed_beam_imports()
    ),
    ProcessBefore = maps:get(process_before, Observation),
    ?assertEqual([], proplists:get_value(links, ProcessBefore)),
    ?assert(
        lists:member(proplists:get_value(status, ProcessBefore), [running, waiting])
    ).

assert_rejection(CaseName, Expected) ->
    {ok, Observation} = run(CaseName),
    ?assertEqual(Expected, maps:get(classification, Observation)),
    ?assertNot(is_process_alive(maps:get(generated_pid, Observation))),
    SuccessfulResults = [
        Message
     || {alang_v1, result, _Correlation, {ok, _Value}} = Message <-
            maps:get(messages, Observation)
    ],
    ?assertEqual([], SuccessfulResults).

run(CaseName) ->
    alang_phase1_runtime:run_case(?ARTIFACT, ?FIXTURE, ?CONFIG, CaseName).

forbidden_import_forms() ->
    [
        {attribute, 1, module, phase1_counter_v1},
        {attribute, 1, export, [{start, 1}]},
        {function, 2, start, 1, [
            {clause, 2, [{var, 2, '_Parent'}], [], [
                {call, 3, {remote, 3, {atom, 3, os}, {atom, 3, cmd}}, [
                    {string, 3, "true"}
                ]}
            ]}
        ]}
    ].

minimal_allowed_forms() ->
    [
        {attribute, 1, module, phase1_counter_v1},
        {attribute, 1, export, [{start, 1}]},
        {function, 2, start, 1, [
            {clause, 2, [{var, 2, 'Parent'}], [], [
                {op, 3, '!', {var, 3, 'Parent'}, {atom, 3, normal}}
            ]}
        ]}
    ].
