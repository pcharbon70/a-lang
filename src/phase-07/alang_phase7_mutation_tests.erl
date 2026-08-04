-module(alang_phase7_mutation_tests).

-include_lib("eunit/include/eunit.hrl").

-export([run/0]).

all_seeded_defects_are_detected_test() ->
    Evidence = alang_phase7_mutation:run(),
    ?assertEqual(17, maps:get(defects, Evidence)),
    ?assertEqual(8, maps:get(semantic_backend, maps:get(categories, Evidence))),
    ?assertEqual(9, maps:get(authorization_recovery, maps:get(categories, Evidence))),
    ?assertEqual(true, maps:get(passed, Evidence)),
    ?assert(lists:all(fun(#{detected := Detected}) -> Detected end,
        maps:get(results, Evidence))).

counterexamples_are_actionable_and_targeted_test() ->
    Results = maps:get(results, alang_phase7_mutation:run()),
    Names = [maps:get(name, Result) || Result <- Results],
    Detectors = [maps:get(intended_test, Result) || Result <- Results],
    ?assertEqual(length(Names), length(lists:usort(Names))),
    ?assert(lists:all(fun is_atom/1, Detectors)),
    ?assert(lists:all(fun(Result) ->
        maps:get(counterexample, Result) =/= undefined andalso
            maps:get(expected, Result) =/= maps:get(mutant, Result)
    end, Results)).

-spec run() -> map().
run() ->
    alang_phase7_mutation:run().
