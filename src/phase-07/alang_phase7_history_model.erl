-module(alang_phase7_history_model).

-export([invariants/1, new/1, run/2, settle/1, transition/2]).

-spec new(non_neg_integer()) -> map().
new(Budget) when is_integer(Budget), Budget >= 0 -> #{
    format => alang_phase7_history_model_v1,
    phase => ready,
    budget => Budget,
    submissions => 0,
    journal_intent => false,
    authorized => false,
    terminal => false,
    retries => 0,
    steps => 0
}.

-spec run([atom()], non_neg_integer()) -> map().
run(Commands, Budget) -> lists:foldl(fun transition/2, new(Budget), Commands).

-spec transition(atom(), map()) -> map().
transition(_Command, #{terminal := true} = State) -> step(State);
transition(intent, #{phase := ready} = State) ->
    step(State#{phase := intended, journal_intent := true});
transition(authorize, #{phase := intended, budget := Budget} = State) when Budget > 0 ->
    step(State#{phase := authorized, authorized := true});
transition(authorize, #{phase := intended} = State) ->
    step(State#{phase := denied, terminal := true});
transition(submit, #{phase := authorized, submissions := 0} = State) ->
    step(State#{phase := uncertain, submissions := 1});
transition(submit, #{phase := uncertain} = State) ->
    step(State);
transition(result, #{phase := uncertain, budget := Budget} = State) ->
    step(State#{phase := observed, budget := Budget - 1, terminal := true});
transition(crash, #{phase := uncertain} = State) -> step(State);
transition(recover, #{phase := uncertain} = State) ->
    step(State#{phase := explicit_uncertain, terminal := true});
transition(cancel, State) -> step(State#{phase := cancelled, terminal := true});
transition(expire, State) -> step(State#{phase := denied, terminal := true});
transition(restart, #{phase := uncertain} = State) ->
    step(State#{phase := explicit_uncertain, terminal := true, authorized := false});
transition(restart, State) -> step(State#{phase := ready, authorized := false,
    journal_intent := false});
transition(_Command, State) -> step(State).

-spec settle(map()) -> map().
settle(#{terminal := true} = State) -> State;
settle(#{phase := uncertain} = State) ->
    State#{phase := explicit_uncertain, terminal := true, authorized := false,
        steps := maps:get(steps, State) + 1};
settle(State) -> State#{phase := denied, terminal := true, authorized := false,
    steps := maps:get(steps, State) + 1}.

-spec invariants(map()) -> ok | {error, [atom()]}.
invariants(State) ->
    Checks = [
        {budget_underflow, maps:get(budget, State) >= 0},
        {effect_without_intent, maps:get(submissions, State) =:= 0 orelse
            maps:get(journal_intent, State)},
        {effect_without_authorization, maps:get(submissions, State) =:= 0 orelse
            maps:get(authorized, State)},
        {duplicate_submission, maps:get(submissions, State) =< 1},
        {automatic_uncertain_retry, maps:get(retries, State) =:= 0},
        {unbounded_terminal, maps:get(terminal, settle(State))}
    ],
    Failures = [Name || {Name, false} <- Checks],
    case Failures of [] -> ok; _ -> {error, Failures} end.

step(State) -> State#{steps := maps:get(steps, State) + 1}.
