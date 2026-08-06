-module(alang_fidelity_phase5_mutation).

-export([apply/2, names/0]).

-spec names() -> [atom()].
names() -> [
    repair_as_primary,
    omission_ignored,
    condition_swapped,
    cost_undercounted,
    bootstrap_seed_changed,
    journal_record_deleted
].

-spec apply(atom(), map()) -> map().
apply(repair_as_primary, Result) ->
    Scores = maps:get(scores, Result),
    {Before, [Target | After]} = lists:splitwith(fun(Score) ->
        Repair = maps:get(repair, Score),
        not (maps:get(attempted, Repair) andalso maps:get(exact, Repair))
    end, Scores),
    Mutated = finalize_score(Target#{exact_semantic_fidelity := true}),
    finalize(Result#{scores := Before ++ [Mutated | After]});
apply(omission_ignored, Result) ->
    Scores = maps:get(scores, Result),
    {Before, [Target | After]} = lists:splitwith(fun(Score) ->
        maps:get(omission_count, Score) =:= 0
    end, Scores),
    Mutated = finalize_score(Target#{omission_count := 0}),
    finalize(Result#{scores := Before ++ [Mutated | After]});
apply(condition_swapped, Result) ->
    [Target | Rest] = maps:get(scores, Result),
    Condition = case maps:get(condition, Target) of alang -> json; json -> alang end,
    Mutated = finalize_score(Target#{condition := Condition}),
    finalize(Result#{scores := [Mutated | Rest]});
apply(cost_undercounted, Result) ->
    Accounting = maps:get(accounting, Result),
    Cost = maps:get(cost_microusd, Accounting),
    finalize(Result#{accounting := Accounting#{cost_microusd := Cost - 1}});
apply(bootstrap_seed_changed, Result) ->
    Bootstrap0 = maps:remove(bootstrap_digest, maps:get(bootstrap, Result)),
    Bootstrap1 = Bootstrap0#{seed := maps:get(seed, Bootstrap0) + 1},
    Bootstrap = Bootstrap1#{bootstrap_digest => alang_fidelity_json:digest(Bootstrap1)},
    finalize(Result#{bootstrap := Bootstrap});
apply(journal_record_deleted, Result) ->
    Journal = maps:get(journal, Result),
    [_Start, _Deleted | Records] = maps:get(records, Journal),
    finalize(Result#{journal := Journal#{records := [hd(maps:get(records, Journal)) | Records]}}).

finalize_score(Score0) ->
    Score = maps:remove(score_digest, Score0),
    Score#{score_digest => alang_fidelity_json:digest(Score)}.

finalize(Result0) ->
    Result = maps:remove(offline_digest, Result0),
    Result#{offline_digest => alang_fidelity_json:digest(Result)}.
