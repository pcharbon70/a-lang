-module(alang_phase6_task).

-export([checkpoint/1, new/2, snapshot/1, transition/3]).

-spec new(map(), integer()) -> {ok, map()} | {error, atom()}.
new(#{
    format := alang_task_spec_v1,
    task_id := TaskId,
    original_goal := OriginalGoal,
    profile_id := ProfileId,
    output_schema_id := OutputSchemaId,
    limits := Limits,
    deadline := Deadline
} = Spec, Now) when map_size(Spec) =:= 7, is_integer(Now) ->
    case valid_id(TaskId) andalso valid_binary(OriginalGoal, 1, 32768) andalso
        valid_id(ProfileId) andalso OutputSchemaId =:= markdown_draft_v1 andalso
        validate_limits(Limits) andalso is_integer(Deadline) andalso Deadline > Now
    of
        true -> {ok, #{
            format => alang_task_state_v1,
            task_id => TaskId,
            original_goal => OriginalGoal,
            current_plan => OriginalGoal,
            profile_id => ProfileId,
            output_schema_id => OutputSchemaId,
            phase => prepare_context,
            counters => #{model_calls => 0, repair_attempts => 0, steps => 0, effects => 0},
            limits => Limits,
            started_at => Now,
            deadline => Deadline,
            context_digest => none,
            pending => none,
            draft => none,
            evidence => [],
            result => none,
            history => []
        }};
        false -> {error, invalid_task_specification}
    end;
new(_Spec, _Now) -> {error, invalid_task_specification}.

-spec checkpoint(map()) -> {ok, map()} | {error, atom()}.
checkpoint(State) ->
    case valid_state(State) of
        true -> {ok, #{
            format => alang_task_checkpoint_v1,
            task_id => maps:get(task_id, State),
            phase => maps:get(phase, State),
            state_digest => state_digest(State),
            steps => maps:get(steps, maps:get(counters, State))
        }};
        false -> {error, invalid_task_state}
    end.

-spec transition(map(), term(), integer()) -> {ok, map()} | {incomplete, atom(), map()} | {error, atom()}.
transition(State, Event, Now) when is_map(State), is_integer(Now) ->
    case valid_state(State) of
        false -> {error, invalid_task_state};
        true -> transition_checked(State, Event, Now)
    end;
transition(_State, _Event, _Now) -> {error, invalid_task_transition}.

-spec snapshot(map()) -> map().
snapshot(State) -> maps:with([
    format, task_id, original_goal, current_plan, phase, counters, context_digest,
    pending, draft, evidence, result, history
], State).

transition_checked(State, cancel, Now) -> terminate(State, cancelled, cancelled, Now);
transition_checked(State, {fail, Reason}, Now) when is_atom(Reason) ->
    terminate(State, failed, Reason, Now);
transition_checked(State, Event, Now) ->
    case stop_reason(State, Now) of
        none -> apply_transition(State, Event, Now);
        Reason -> incomplete(State, Reason, Now)
    end.

apply_transition(#{phase := prepare_context} = State,
    {context_prepared, ContextDigest, ContextBytes}, Now) when
    is_integer(ContextBytes), ContextBytes >= 0
->
    Max = maps:get(max_context_bytes, maps:get(limits, State)),
    case valid_digest(ContextDigest) andalso ContextBytes =< Max of
        true -> advance(State#{context_digest := ContextDigest}, request_model,
            {context_prepared, ContextDigest}, Now);
        false -> incomplete(State, context_bound_exhausted, Now)
    end;
apply_transition(#{phase := request_model} = State,
    {model_requested, RequestDigest, Ack}, Now) ->
    Counters = maps:get(counters, State),
    case checkpoint_matches(State, Ack) of
        false -> {error, checkpoint_required};
        true ->
            case maps:get(model_calls, Counters) < maps:get(max_model_calls, maps:get(limits, State)) of
                true ->
                    Updated = State#{
                        counters := Counters#{model_calls := maps:get(model_calls, Counters) + 1},
                        pending := #{kind => model, digest => RequestDigest}
                    },
                    case valid_digest(RequestDigest) of
                        true -> advance(Updated, decode, {model_requested, RequestDigest}, Now);
                        false -> {error, invalid_model_request_identity}
                    end;
                false -> incomplete(State, model_call_bound_exhausted, Now)
            end
    end;
apply_transition(#{phase := decode, pending := #{kind := model, digest := Digest}} = State,
    {model_result, #{format := alang_model_result_v1, status := success,
        request_digest := Digest, output := Output}}, Now) ->
    case valid_binary(Output, 1, maps:get(max_output_bytes, maps:get(limits, State))) of
        true -> advance(State#{pending := none, draft := Output}, verify_draft,
            {model_result, success}, Now);
        false -> incomplete(State, output_bound_exhausted, Now)
    end;
apply_transition(#{phase := decode, pending := #{kind := model, digest := Digest}} = State,
    {model_result, #{format := alang_model_result_v1, status := Status,
        request_digest := Digest} = Result}, Now) when
    Status =:= invalid_syntax; Status =:= schema_failure
-> advance(State#{pending := none, draft := Result}, verify_draft,
    {model_result, Status}, Now);
apply_transition(#{phase := decode, pending := #{kind := model, digest := Digest}} = State,
    {model_result, #{format := alang_model_result_v1, status := Status,
        request_digest := Digest}}, Now) when
    Status =:= content_policy_denial; Status =:= timeout; Status =:= provider_error;
    Status =:= budget_exhausted; Status =:= outcome_unknown
->
    terminate(State#{pending := none}, failed, Status, Now);
apply_transition(#{phase := verify_draft, draft := Draft} = State,
    {draft_verified, DraftDigest}, Now) when is_binary(Draft) ->
    case valid_digest(DraftDigest) of
        true -> advance(State#{evidence := append_evidence(State, DraftDigest)}, request_write,
            {draft_verified, DraftDigest}, Now);
        false -> {error, invalid_draft_evidence}
    end;
apply_transition(#{phase := verify_draft, draft := #{format := alang_model_result_v1,
    status := Status}} = State, {repair_planned, RepairRequestDigest}, Now) when
    Status =:= invalid_syntax; Status =:= schema_failure
->
    Counters = maps:get(counters, State),
    case {valid_digest(RepairRequestDigest),
        maps:get(repair_attempts, Counters) < maps:get(max_repair_attempts, maps:get(limits, State))}
    of
        {true, true} ->
            Updated = State#{
                counters := Counters#{repair_attempts := maps:get(repair_attempts, Counters) + 1},
                pending := none,
                draft := none
            },
            advance(Updated, request_model, {repair_planned, RepairRequestDigest}, Now);
        {false, _} -> {error, invalid_repair_request_identity};
        {_, false} -> incomplete(State, repair_bound_exhausted, Now)
    end;
apply_transition(#{phase := request_write} = State,
    {write_requested, OperationId, Ack}, Now) ->
    Counters = maps:get(counters, State),
    case checkpoint_matches(State, Ack) of
        false -> {error, checkpoint_required};
        true ->
            case maps:get(effects, Counters) < maps:get(max_effects, maps:get(limits, State)) of
                true when is_binary(OperationId), byte_size(OperationId) > 0 ->
                    Updated = State#{
                        counters := Counters#{effects := maps:get(effects, Counters) + 1},
                        pending := #{kind => workspace, operation_id => OperationId}
                    },
                    advance(Updated, verify_artifact, {write_requested, OperationId}, Now);
                true -> {error, invalid_workspace_operation_identity};
                false -> incomplete(State, effect_bound_exhausted, Now)
            end
    end;
apply_transition(#{phase := verify_artifact} = State,
    {artifact_verified, #{status := complete, witness_digest := WitnessDigest} = Witness}, Now) ->
    case alang_phase6_verifier:validate_witness(Witness) of
        ok ->
            Evidence = append_evidence(State, WitnessDigest),
            advance(State#{pending := none, evidence := Evidence,
                result := #{status => complete, witness_digest => WitnessDigest}},
                complete, {artifact_verified, WitnessDigest}, Now);
        {error, _} -> {error, invalid_completion_witness}
    end;
apply_transition(#{phase := verify_artifact}, {artifact_verified, _Witness}, _Now) ->
    {error, invalid_completion_witness};
apply_transition(#{phase := verify_artifact} = State,
    {artifact_incomplete, #{status := incomplete} = Witness}, Now) ->
    case alang_phase6_verifier:validate_witness(Witness) of
        ok -> incomplete(State, completion_predicate_failed, Now);
        {error, _} -> {error, invalid_completion_witness}
    end;
apply_transition(#{phase := Phase}, _Event, _Now) when
    Phase =:= complete; Phase =:= failed; Phase =:= cancelled; Phase =:= incomplete
-> {error, task_terminal};
apply_transition(State, {plan_updated, Plan}, Now) when is_binary(Plan), byte_size(Plan) > 0,
    byte_size(Plan) =< 32768
-> advance(State#{current_plan := Plan}, maps:get(phase, State), plan_updated, Now);
apply_transition(_State, _Event, _Now) -> {error, unexpected_task_event}.

advance(State, NextPhase, HistoryEvent, Now) ->
    case increment_step(State, HistoryEvent, Now) of
        {ok, Updated} -> {ok, Updated#{phase := NextPhase}};
        {incomplete, _, _} = Incomplete -> Incomplete
    end.

terminate(State, Phase, Reason, Now) ->
    case terminal_phase(maps:get(phase, State)) of
        true -> {error, task_terminal};
        false ->
            case increment_step(State, {Phase, Reason}, Now) of
                {ok, Updated} -> {ok, Updated#{phase := Phase,
                    pending := none, result := #{status => Phase, reason => Reason}}};
                {incomplete, _, _} = Incomplete -> Incomplete
            end
    end.

increment_step(State, HistoryEvent, Now) ->
    Counters = maps:get(counters, State),
    Steps = maps:get(steps, Counters),
    case Steps < maps:get(max_steps, maps:get(limits, State)) of
        true -> {ok, State#{
            counters := Counters#{steps := Steps + 1},
            history := bounded_append(maps:get(history, State), #{at => Now, event => HistoryEvent})
        }};
        false -> incomplete(State, step_bound_exhausted, Now)
    end.

incomplete(State, Reason, Now) ->
    Result = #{status => incomplete, reason => Reason},
    Updated = State#{phase := incomplete, pending := none, result := Result,
        history := bounded_append(maps:get(history, State), #{at => Now, event => Result})},
    {incomplete, Reason, Updated}.

stop_reason(State, Now) ->
    Limits = maps:get(limits, State),
    case {
        Now >= maps:get(deadline, State),
        Now - maps:get(started_at, State) >= maps:get(max_elapsed_ms, Limits),
        maps:get(steps, maps:get(counters, State)) >= maps:get(max_steps, Limits)
    } of
        {true, _, _} -> deadline_exhausted;
        {_, true, _} -> elapsed_time_exhausted;
        {_, _, true} -> step_bound_exhausted;
        _ -> none
    end.

checkpoint_matches(State, #{
    format := alang_task_checkpoint_v1,
    task_id := TaskId,
    phase := Phase,
    state_digest := Digest,
    steps := Steps
} = Ack) when map_size(Ack) =:= 5 ->
    TaskId =:= maps:get(task_id, State) andalso Phase =:= maps:get(phase, State) andalso
        Digest =:= state_digest(State) andalso Steps =:= maps:get(steps, maps:get(counters, State));
checkpoint_matches(_State, _Ack) -> false.

state_digest(State) -> hex(crypto:hash(sha256, term_to_binary(State, [deterministic]))).

append_evidence(State, Digest) -> bounded_append(maps:get(evidence, State), Digest).
bounded_append(Items, Item) when length(Items) < 256 -> Items ++ [Item];
bounded_append(Items, _Item) -> Items.

valid_state(#{
    format := alang_task_state_v1,
    task_id := TaskId,
    original_goal := OriginalGoal,
    current_plan := CurrentPlan,
    profile_id := ProfileId,
    output_schema_id := markdown_draft_v1,
    phase := Phase,
    counters := Counters,
    limits := Limits,
    started_at := StartedAt,
    deadline := Deadline,
    context_digest := ContextDigest,
    pending := _Pending,
    draft := _Draft,
    evidence := Evidence,
    result := _Result,
    history := History
} = State) when map_size(State) =:= 17 ->
    valid_id(TaskId) andalso valid_binary(OriginalGoal, 1, 32768) andalso
        valid_binary(CurrentPlan, 1, 32768) andalso valid_id(ProfileId) andalso
        valid_phase(Phase) andalso valid_counters(Counters) andalso validate_limits(Limits) andalso
        is_integer(StartedAt) andalso is_integer(Deadline) andalso
        (ContextDigest =:= none orelse valid_digest(ContextDigest)) andalso
        is_list(Evidence) andalso lists:all(fun valid_digest/1, Evidence) andalso
        is_list(History) andalso length(History) =< 256;
valid_state(_State) -> false.

valid_counters(#{model_calls := Model, repair_attempts := Repair, steps := Steps,
    effects := Effects} = Counters) when map_size(Counters) =:= 4 ->
    lists:all(fun(Value) -> is_integer(Value) andalso Value >= 0 end,
        [Model, Repair, Steps, Effects]);
valid_counters(_Counters) -> false.

validate_limits(#{
    max_model_calls := Model,
    max_repair_attempts := Repair,
    max_steps := Steps,
    max_elapsed_ms := Elapsed,
    max_context_bytes := Context,
    max_output_bytes := Output,
    max_effects := Effects
} = Limits) when map_size(Limits) =:= 7 ->
    valid_limit(Model, 1, 32) andalso valid_limit(Repair, 0, 8) andalso
        valid_limit(Steps, 1, 256) andalso valid_limit(Elapsed, 1, 3600000) andalso
        valid_limit(Context, 1, 65536) andalso valid_limit(Output, 1, 65536) andalso
        valid_limit(Effects, 1, 32);
validate_limits(_Limits) -> false.

valid_phase(Phase) -> lists:member(Phase, [prepare_context, request_model, decode,
    verify_draft, request_write, verify_artifact, complete, failed, cancelled, incomplete]).
terminal_phase(Phase) -> lists:member(Phase, [complete, failed, cancelled, incomplete]).
valid_limit(Value, Minimum, Maximum) -> is_integer(Value) andalso Value >= Minimum andalso Value =< Maximum.
valid_id(Value) -> valid_binary(Value, 1, 128).
valid_binary(Value, Minimum, Maximum) ->
    is_binary(Value) andalso byte_size(Value) >= Minimum andalso byte_size(Value) =< Maximum.
valid_digest(Value) when is_binary(Value), byte_size(Value) =:= 64 ->
    lists:all(fun is_hex/1, binary_to_list(Value));
valid_digest(_Value) -> false.
is_hex(Character) when Character >= $0, Character =< $9 -> true;
is_hex(Character) when Character >= $a, Character =< $f -> true;
is_hex(_Character) -> false.
hex(Binary) -> << <<(hex_digit(Nibble))>> || <<Nibble:4>> <= Binary >>.
hex_digit(Nibble) when Nibble < 10 -> $0 + Nibble;
hex_digit(Nibble) -> $a + Nibble - 10.
