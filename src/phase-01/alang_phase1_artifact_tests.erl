-module(alang_phase1_artifact_tests).

-include_lib("eunit/include/eunit.hrl").

-define(CONFIG, "src/phase-01/toolchain.config").
-define(FIXTURE, "src/phase-01/semantic-fixture.config").
-define(ARTIFACT_A, "build/phase-01/test-artifact-a").
-define(ARTIFACT_B, "build/phase-01/test-artifact-b").
-define(ARTIFACT_TAMPERED, "build/phase-01/test-artifact-tampered").

closed_typed_fixture_test() ->
    {ok, Fixture} = alang_phase1_fixture:load(?FIXTURE),
    ?assertEqual(
        {integer_range, 0, 1000000},
        maps:get(input, maps:get(types, Fixture))
    ),
    ?assertEqual(
        {closed_sum, [waiting, completed]},
        maps:get(state, maps:get(types, Fixture))
    ),
    ?assertEqual(
        [initialize, receive_envelope, emit_trace, reply_result, terminate],
        maps:get(runtime_operations, Fixture)
    ).

changed_fixture_is_rejected_test() ->
    {ok, Fixture} = alang_phase1_fixture:load(?FIXTURE),
    Changed = Fixture#{runtime_operations := [initialize, terminate]},
    ?assertMatch(
        {error, {invalid_semantic_fixture, [_ | _]}},
        alang_phase1_fixture:forms(Changed)
    ).

forms_are_deterministic_and_allowed_test() ->
    {ok, Fixture} = alang_phase1_fixture:load(?FIXTURE),
    {ok, First} = alang_phase1_fixture:forms(Fixture),
    {ok, Second} = alang_phase1_fixture:forms(Fixture),
    ?assertEqual(First, Second),
    ?assertEqual(ok, alang_phase1_compiler:validate_allowed_forms(First)),
    ?assertMatch({ok, #{}}, alang_phase1_compiler:compile_forms(First, ?CONFIG)).

package_is_reproducible_test() ->
    {ok, First} = alang_phase1_package:build(?ARTIFACT_A, ?FIXTURE, ?CONFIG),
    {ok, Second} = alang_phase1_package:build(?ARTIFACT_B, ?FIXTURE, ?CONFIG),
    ?assertEqual(maps:get(beam_sha256, First), maps:get(beam_sha256, Second)),
    ?assertEqual(
        maps:get(manifest_sha256, First),
        maps:get(manifest_sha256, Second)
    ),
    {ok, FirstBeam} = file:read_file(maps:get(beam_path, First)),
    {ok, SecondBeam} = file:read_file(maps:get(beam_path, Second)),
    ?assertEqual(FirstBeam, SecondBeam),
    {ok, FirstManifest} = file:read_file(maps:get(manifest_path, First)),
    {ok, SecondManifest} = file:read_file(maps:get(manifest_path, Second)),
    ?assertEqual(FirstManifest, SecondManifest).

manifest_records_and_verifies_boundary_test() ->
    {ok, Built} = alang_phase1_package:build(?ARTIFACT_A, ?FIXTURE, ?CONFIG),
    {ok, Verified} = alang_phase1_package:verify(?ARTIFACT_A, ?FIXTURE, ?CONFIG),
    Manifest = maps:get(manifest, Verified),
    ?assertEqual(alang_beam_artifact_v1, maps:get(artifact_format, Manifest)),
    ?assertEqual(phase1_counter_v1, maps:get(module, Manifest)),
    ?assertEqual(<<"phase1-ir-v1">>, maps:get(semantic_version, Manifest)),
    ?assertEqual(alang_v1, maps:get(runtime_abi, Manifest)),
    ?assertEqual(maps:get(beam_sha256, Built), maps:get(beam_sha256, Manifest)),
    ?assertEqual(
        maps:get(otp_version, alang_phase1_compiler:current_toolchain()),
        maps:get(otp_version, maps:get(otp_target, Manifest))
    ),
    ?assertEqual(
        maps:get(imports, maps:get(inspection, Verified)),
        maps:get(imports, Manifest)
    ).

tampered_artifact_is_rejected_test() ->
    {ok, Built} = alang_phase1_package:build(?ARTIFACT_TAMPERED, ?FIXTURE, ?CONFIG),
    BeamPath = maps:get(beam_path, Built),
    {ok, Beam} = file:read_file(BeamPath),
    ok = file:write_file(BeamPath, <<Beam/binary, 0>>, [binary]),
    ?assertMatch(
        {error, _},
        alang_phase1_package:verify(?ARTIFACT_TAMPERED, ?FIXTURE, ?CONFIG)
    ).
