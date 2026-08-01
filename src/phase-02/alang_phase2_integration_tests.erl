-module(alang_phase2_integration_tests).

-export([main/0]).

-include_lib("eunit/include/eunit.hrl").

-define(GENERATED_FIXTURE, "build/phase-02/frontend/phase1-semantic-fixture.config").
-define(PHASE1_FIXTURE, "src/phase-01/semantic-fixture.config").

main() ->
    case eunit:test(?MODULE, [verbose]) of
        ok -> halt(0);
        error -> halt(1)
    end.

isolated_named_node_test() ->
    ?assertNotEqual(nonode@nohost, node()).

native_frontend_feeds_the_proven_phase1_adapter_test() ->
    {ok, GeneratedFixture} = file:read_file(?GENERATED_FIXTURE),
    {ok, Phase1Fixture} = file:read_file(?PHASE1_FIXTURE),
    ?assertEqual(Phase1Fixture, GeneratedFixture).

compiled_beam_agrees_with_reference_views_test() ->
    {ok, Evidence} = alang_phase2_runtime:run(),
    Agreement = maps:get(phase2_agreement, Evidence),
    ?assertEqual(42, maps:get(reference_result, Agreement)),
    ?assertEqual(true, maps:get(reference_completion, Agreement)),
    ?assertEqual([], maps:get(reference_effects, Agreement)),
    ?assertEqual([], maps:get(manifest_effects, Agreement)),
    ?assertEqual(ok, maps:get(classification, Evidence)),
    ?assertEqual(normal, maps:get(exit_reason, Evidence)),
    ?assertEqual(
        true,
        maps:get(passed, maps:get(no_interpreter_proof, Evidence))
    ),
    ?assertEqual(phase1_counter_v1, maps:get(loaded_module, Evidence)),
    ?assert(lists:member(
        {alang_v1, result, <<"phase-1-success">>, {ok, 42}},
        maps:get(messages, Evidence)
    )).
