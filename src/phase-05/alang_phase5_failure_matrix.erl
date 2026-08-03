-module(alang_phase5_failure_matrix).

-export([invariants/1, minimize/2, stages/0]).

-spec stages() -> [atom()].
stages() -> [
    before_intent,
    after_intent_commit,
    after_authorization,
    after_submission,
    after_mutation,
    after_result_commit,
    after_checkpoint,
    before_terminal,
    after_terminal
].

-spec invariants(map()) -> ok | {error, [atom()]}.
invariants(Evidence) when is_map(Evidence) ->
    Checks = [
        {duplicate_logical_effect, maps:get(operation_count, Evidence, invalid) =:= 1},
        {artifact_digest_mismatch,
            maps:get(actual_artifact_digest, Evidence, invalid) =:=
                maps:get(expected_artifact_digest, Evidence, expected)},
        {invalid_journal_chain, maps:get(journal_valid, Evidence, false)},
        {invalid_checkpoint, maps:get(checkpoint_valid, Evidence, false)},
        {unresolved_intent, maps:get(pending, Evidence, invalid) =:= none},
        {false_completion, maps:get(terminal, Evidence, invalid) =:= completed},
        {authority_widened, maps:get(remaining_budget, Evidence, invalid) =:= 0},
        {stale_message_accepted, maps:get(stale_rejected, Evidence, false)}
    ],
    Failures = [Name || {Name, false} <- Checks],
    case Failures of
        [] -> ok;
        _ -> {error, Failures}
    end;
invariants(_Evidence) -> {error, [invalid_evidence]}.

-spec minimize([term()], fun(([term()]) -> boolean())) -> [term()].
minimize(Events, Violates) when is_list(Events), is_function(Violates, 1) ->
    shrink(Events, Violates, 1);
minimize(Events, _Violates) -> Events.

shrink(Events, _Violates, Index) when Index > length(Events) -> Events;
shrink(Events, Violates, Index) ->
    Candidate = remove_at(Index, Events),
    case Candidate =/= [] andalso Violates(Candidate) of
        true -> shrink(Candidate, Violates, 1);
        false -> shrink(Events, Violates, Index + 1)
    end.

remove_at(Index, Events) ->
    {Before, [_Removed | After]} = lists:split(Index - 1, Events),
    Before ++ After.
