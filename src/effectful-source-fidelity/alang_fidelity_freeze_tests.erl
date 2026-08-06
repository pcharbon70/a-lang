-module(alang_fidelity_freeze_tests).

-include_lib("eunit/include/eunit.hrl").

-define(BASE, "assets/effectful-source-fidelity").
-define(CLOSURE,
    "assets/effectful-source-fidelity/evidence/hosted-campaign-closure-v1.json").
-define(OUTPUT,
    "build/effectful-source-fidelity/phase-06/evidence/section-6-1-freeze.json").

no_run_closure_accounts_for_every_registered_cell_test_() ->
    {timeout, 60, fun() ->
        {ok, Freeze} = alang_fidelity_freeze:build(?BASE, ?CLOSURE),
        ?assertEqual(false, maps:get(<<"campaign_valid">>, Freeze)),
        Accounting = maps:get(<<"accounting">>, Freeze),
        ?assertEqual(288, maps:get(<<"scheduled_primary_cells">>, Accounting)),
        ?assertEqual(288, maps:get(<<"missing_primary_cells">>, Accounting)),
        ?assertEqual(0, maps:get(<<"hosted_calls">>, Accounting)),
        Missing = maps:get(<<"missing_cells">>, Freeze),
        ?assertEqual(lists:seq(0, 287), [maps:get(<<"index">>, Cell) || Cell <- Missing]),
        ?assertEqual(288, length(lists:usort(
            [maps:get(<<"trial_id">>, Cell) || Cell <- Missing]))),
        ?assert(lists:all(fun(Cell) ->
            maps:get(<<"failure_cause">>, Cell) =:=
                <<"live-authorization-not-granted">>
        end, Missing))
    end}.

invalid_campaign_suppresses_efficacy_analysis_test() ->
    {ok, Freeze} = alang_fidelity_freeze:build(?BASE, ?CLOSURE),
    ?assertEqual(
        [<<"live_authorization">>, <<"reproducible_scores">>,
            <<"three_scorable_primary_observations_per_cell">>],
        maps:get(<<"failing_predicates">>, Freeze)),
    Analysis = maps:get(<<"analysis">>, Freeze),
    ?assertEqual(null, maps:get(<<"primary_table">>, Analysis)),
    ?assertEqual(null, maps:get(<<"secondary_table">>, Analysis)),
    ?assertEqual(null, maps:get(<<"bootstrap_intervals">>, Analysis)),
    ?assertEqual(<<"forbidden">>, maps:get(<<"efficacy_conclusion">>, Analysis)).

closure_accounting_and_contract_mutants_fail_closed_test() ->
    {ok, Closure} = alang_fidelity_json:decode_file(?CLOSURE),
    Mutants = [
        Closure#{<<"schedule_digest">> => <<"changed">>},
        Closure#{<<"hosted_call_count">> => 1},
        Closure#{<<"missing_primary_cells">> => 287},
        Closure#{<<"observations">> => [#{<<"unexpected">> => true}]},
        Closure#{<<"extra">> => <<"post-hoc">>}
    ],
    lists:foreach(fun(Mutant) ->
        ?assertMatch({error, _}, alang_fidelity_freeze:build_from(?BASE, Mutant))
    end, Mutants).

canonical_freeze_round_trips_and_detects_tampering_test() ->
    {ok, Freeze} = alang_fidelity_freeze:write(?BASE, ?CLOSURE, ?OUTPUT),
    ?assertMatch({ok, Freeze}, alang_fidelity_freeze:read(?OUTPUT)),
    Mutant = Freeze#{<<"campaign_valid">> => true},
    ?assertMatch({error, _}, alang_fidelity_freeze:validate(Mutant)),
    ?assertEqual(ok, file:delete(?OUTPUT)).

freeze_implementation_is_beam_resident_test() ->
    Path = code:which(alang_fidelity_freeze),
    ?assert(is_list(Path)),
    ?assertEqual(".beam", filename:extension(Path)),
    {ok, {alang_fidelity_freeze, [{imports, Imports}]}} =
        beam_lib:chunks(Path, [imports]),
    ?assertEqual(false, lists:member({erlang, open_port, 2}, Imports)),
    ?assertEqual(false, lists:member({os, cmd, 1}, Imports)).
