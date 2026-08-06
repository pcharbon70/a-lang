-module(alang_fidelity_campaign_runner).

-export([
    advance_without_repair/1,
    intent/2,
    new/1,
    next/1,
    record_result/2,
    replay/2,
    snapshot/1
]).

-define(ALL_CALL_CEILING, 576).
-define(COST_CEILING_MICROUSD, 200000000).

-spec new(map()) -> {ok, map()} | {error, term()}.
new(Schedule) ->
    case alang_fidelity_campaign:validate_schedule(Schedule) of
        {ok, _} -> {ok, #{
            format => alang_fidelity_campaign_runner_v1,
            schedule_digest => maps:get(schedule_digest, Schedule),
            cells => maps:get(cells, Schedule),
            cursor => 0,
            pending => none,
            mode => primary,
            last_result => none,
            calls => 0,
            cost_microusd => 0,
            completed_primary_cells => 0,
            invalid => false,
            histories => #{}
        }};
        {error, _} = Error -> Error
    end.

-spec next(map()) -> {ok, map()} | {done, map()} | {error, term()}.
next(#{pending := Pending}) when Pending =/= none -> {error, intent_already_pending};
next(#{cursor := Cursor, cells := Cells} = State) when Cursor >= length(Cells) -> {done, State};
next(#{cursor := Cursor, cells := Cells, mode := Mode}) ->
    Cell = lists:nth(Cursor + 1, Cells),
    {ok, Cell#{next_attempt_class => Mode}}.

-spec intent(map(), primary | retry | repair | replacement) ->
    {ok, map(), map()} | {error, term()}.
intent(#{pending := none, calls := Calls} = State, AttemptClass) when Calls < ?ALL_CALL_CEILING ->
    case next(State) of
        {ok, Cell} ->
            case legal_attempt(State, AttemptClass) of
                true ->
                    Ordinal = history_count(State, maps:get(trial_id, Cell)),
                    OperationId = alang_fidelity_json:digest({
                        campaign_operation_v1,
                        maps:get(schedule_digest, State),
                        maps:get(trial_id, Cell),
                        AttemptClass,
                        Ordinal
                    }),
                    Intent = #{
                        attempt_class => AttemptClass,
                        operation_id => OperationId,
                        request_digest => maps:get(request_digest, Cell),
                        trial_id => maps:get(trial_id, Cell)
                    },
                    {ok, Intent, State#{pending := Intent, calls := Calls + 1}};
                false -> {error, {illegal_attempt, maps:get(mode, State), AttemptClass}}
            end;
        {done, _} -> {error, campaign_complete};
        {error, _} = Error -> Error
    end;
intent(#{calls := Calls}, _AttemptClass) when Calls >= ?ALL_CALL_CEILING -> {error, call_ceiling_exhausted};
intent(_State, _AttemptClass) -> {error, invalid_runner_state}.

-spec record_result(map(), map()) -> {ok, map()} | {error, term()}.
record_result(#{pending := Pending} = State, Result) when is_map(Pending), is_map(Result) ->
    case result_matches(Pending, Result) of
        false -> {error, result_identity_mismatch};
        true ->
            Cost = maps:get(cost_microusd, Result, invalid),
            Usage = maps:get(usage, Result, #{}),
            case valid_result_accounting(Cost, Usage) of
                false -> {error, invalid_result_accounting};
                true ->
                    Total = maps:get(cost_microusd, State) + Cost,
                    case Total =< ?COST_CEILING_MICROUSD of
                        false -> {error, cost_ceiling_exhausted};
                        true -> apply_result(State#{cost_microusd := Total}, Pending, Result)
                    end
            end
    end;
record_result(#{pending := none}, _Result) -> {error, result_without_intent};
record_result(_, _) -> {error, invalid_runner_state}.

-spec advance_without_repair(map()) -> {ok, map()} | {error, term()}.
advance_without_repair(#{pending := none, mode := repair} = State) -> {ok, advance(State)};
advance_without_repair(_) -> {error, repair_not_pending}.

-spec replay(map(), [map()]) -> {ok, map()} | {error, term()}.
replay(Schedule, Records) ->
    case new(Schedule) of
        {ok, Initial} -> replay_records(Records, Initial);
        {error, _} = Error -> Error
    end.

-spec snapshot(map()) -> map().
snapshot(State) -> maps:without([cells], State).

apply_result(State, Pending, Result) ->
    TrialId = maps:get(trial_id, Pending),
    History0 = maps:get(TrialId, maps:get(histories, State), []),
    Histories = (maps:get(histories, State))#{TrialId => History0 ++ [#{intent => Pending, result => Result}]},
    Updated = State#{pending := none, last_result := Result, histories := Histories},
    Submission = maps:get(submission, Result),
    AttemptClass = maps:get(attempt_class, Pending),
    Status = maps:get(status, Result),
    case {AttemptClass, Submission, repair_eligible(Status)} of
        {repair, _Any, _} -> {ok, advance(Updated)};
        {replacement, definitive, _} -> {ok, advance(Updated)};
        {replacement, _Nondefinitive, _} -> {ok, (advance(Updated))#{invalid := true}};
        {_PrimaryOrRetry, not_submitted, _} -> {ok, Updated#{mode := retry}};
        {_PrimaryOrRetry, uncertain, _} -> {ok, Updated#{mode := replacement}};
        {_PrimaryOrRetry, definitive, true} -> {ok, Updated#{mode := repair}};
        {_PrimaryOrRetry, definitive, false} -> {ok, advance(Updated)}
    end.

advance(State) ->
    State#{
        cursor := maps:get(cursor, State) + 1,
        completed_primary_cells := maps:get(completed_primary_cells, State) + 1,
        pending := none,
        mode := primary,
        last_result := none
    }.

legal_attempt(#{mode := Mode}, AttemptClass) -> Mode =:= AttemptClass.

result_matches(Pending, Result) ->
    maps:get(operation_id, Result, invalid) =:= maps:get(operation_id, Pending)
        andalso maps:get(trial_id, Result, invalid) =:= maps:get(trial_id, Pending)
        andalso lists:member(maps:get(submission, Result, invalid), [definitive, not_submitted, uncertain])
        andalso is_atom(maps:get(status, Result, invalid)).

valid_result_accounting(Cost, Usage) ->
    is_integer(Cost) andalso Cost >= 0 andalso is_map(Usage)
        andalso nonnegative(maps:get(input_tokens, Usage, invalid))
        andalso nonnegative(maps:get(output_tokens, Usage, invalid)).

nonnegative(Value) -> is_integer(Value) andalso Value >= 0.

repair_eligible(malformed_json) -> true;
repair_eligible(schema_invalid) -> true;
repair_eligible(_) -> false.

history_count(State, TrialId) -> length(maps:get(TrialId, maps:get(histories, State), [])).

replay_records([], State) -> {ok, State};
replay_records([#{kind := campaign_started} | Rest], State) -> replay_records(Rest, State);
replay_records([#{kind := trial_intent, payload := Payload} | Rest], State) ->
    AttemptClass = maps:get(attempt_class, Payload),
    case intent(State, AttemptClass) of
        {ok, Expected, Updated} when Expected =:= Payload -> replay_records(Rest, Updated);
        {ok, _Expected, _Updated} -> {error, replay_intent_mismatch};
        {error, _} = Error -> Error
    end;
replay_records([#{kind := trial_result, payload := Payload} | Rest], State) ->
    Result = #{
        trial_id => maps:get(trial_id, Payload),
        operation_id => maps:get(operation_id, Payload),
        status => maps:get(status, Payload),
        submission => maps:get(submission, Payload),
        cost_microusd => maps:get(cost_microusd, Payload),
        usage => #{
            input_tokens => maps:get(input_tokens, Payload),
            output_tokens => maps:get(output_tokens, Payload)
        }
    },
    case record_result(State, Result) of
        {ok, Updated} -> replay_records(Rest, Updated);
        {error, _} = Error -> Error
    end;
replay_records([#{kind := replacement_link} | Rest], State) -> replay_records(Rest, State);
replay_records([#{kind := campaign_closed} | Rest], State) -> replay_records(Rest, State);
replay_records([_ | _], _State) -> {error, unsupported_replay_record}.
