-module(alang_phase5_recovery).

-include_lib("kernel/include/file.hrl").

-export([recover/2]).

-define(MAX_ARTIFACT_BYTES, 1048576).

-spec recover(map(), map()) -> {ok, map()} | {error, tuple()}.
recover(Snapshot, Expected) when is_map(Snapshot), is_map(Expected) ->
    case validate_snapshot(Snapshot) of
        {ok, Records, Pointer, State} ->
            recover_validated(Snapshot, Records, Pointer, State, Expected);
        {error, _} = Error -> Error
    end;
recover(_Snapshot, _Expected) -> rejected(invalid_recovery_input, #{}).

recover_validated(Snapshot, Records, Pointer, State, Expected) ->
    SessionId = maps:get(session_id, Snapshot),
    case alang_phase5_journal:validate(Records, SessionId) of
        {ok, Journal} ->
            case validate_snapshot_head(Snapshot, Journal) of
                ok -> load_state_and_artifact(Records, Pointer, State, Expected, Journal);
                {error, Reason} -> rejected(Reason, #{})
            end;
        {error, Reason} -> rejected({invalid_journal, Reason}, #{})
    end.

load_state_and_artifact(Records, Pointer, State, Expected, Journal) ->
    case alang_phase5_state:load(State, Expected) of
        {ok, AcceptedState} ->
            case verify_checkpoint_pointer(AcceptedState, Pointer, Records) of
                ok ->
                    case verify_artifact(AcceptedState, Expected) of
                        {ok, Inspection} ->
                            fold_recovery(Records, Pointer, AcceptedState, Journal, Inspection);
                        {error, Reason} -> rejected(Reason, #{})
                    end;
                {error, Reason} -> rejected(Reason, #{})
            end;
        {error, {recovery_rejected, Reason, Evidence}} ->
            rejected(Reason, Evidence)
    end.

validate_snapshot(#{
    format := alang_store_snapshot_v1,
    session_id := SessionId,
    records := Records,
    checkpoint := #{state := State, pointer := Pointer},
    next_sequence := NextSequence,
    head_digest := HeadDigest
}) when is_binary(SessionId), is_list(Records), is_map(State), is_map(Pointer),
    is_integer(NextSequence), NextSequence >= 0, is_binary(HeadDigest)
->
    case maps:get(session_id, State, undefined) =:= SessionId of
        true -> {ok, Records, Pointer, State};
        false -> rejected(checkpoint_session_mismatch, #{})
    end;
validate_snapshot(#{checkpoint := none}) -> rejected(missing_checkpoint, #{});
validate_snapshot(_Snapshot) -> rejected(invalid_store_snapshot, #{}).

validate_snapshot_head(Snapshot, Journal) ->
    case {
        maps:get(next_sequence, Snapshot) =:= maps:get(next_sequence, Journal),
        maps:get(head_digest, Snapshot) =:= maps:get(head_digest, Journal)
    } of
        {true, true} -> ok;
        {false, _} -> {error, snapshot_sequence_conflict};
        {_, false} -> {error, snapshot_head_conflict}
    end.

verify_checkpoint_pointer(State, Pointer, Records) ->
    StateSessionId = maps:get(session_id, State),
    RecordCount = length(Records),
    case alang_phase5_state:checkpoint_digest(State) of
        {ok, Digest} ->
            case Pointer of
                #{
                    format := alang_checkpoint_pointer_v1,
                    session_id := SessionId,
                    sequence := Sequence,
                    state_digest := Digest,
                    filename := Filename
                } when SessionId =:= StateSessionId, is_integer(Sequence),
                    Sequence >= 0, Sequence =< RecordCount, is_binary(Filename)
                -> ok;
                _ -> {error, checkpoint_pointer_mismatch}
            end;
        {error, Reason} -> {error, {invalid_checkpoint, Reason}}
    end.

verify_artifact(State, Expected) ->
    Program = maps:get(program, State),
    ExpectedPath = maps:get(artifact_path, Expected, undefined),
    ExpectedDigest = maps:get(artifact_digest, Program),
    ExpectedModule = maps:get(module_name, Program),
    case is_list(ExpectedPath) andalso filename:pathtype(ExpectedPath) =:= absolute of
        false -> {error, invalid_artifact_path};
        true -> inspect_artifact(ExpectedPath, ExpectedDigest, ExpectedModule)
    end.

inspect_artifact(Path, ExpectedDigest, ExpectedModule) ->
    case file:read_file_info(Path) of
        {ok, #file_info{type = regular, size = Size}} when Size =< ?MAX_ARTIFACT_BYTES ->
            case file:read_file(Path) of
                {ok, Beam} ->
                    case alang_phase3_artifact:inspect(Beam) of
                        {ok, Inspection} ->
                            case {
                                maps:get(beam_sha256, Inspection) =:= ExpectedDigest,
                                atom_to_binary(maps:get(module, Inspection)) =:= ExpectedModule
                            } of
                                {true, true} -> {ok, Inspection};
                                {false, _} -> {error, artifact_digest_mismatch};
                                {_, false} -> {error, artifact_module_mismatch}
                            end;
                        {error, Reason} -> {error, {artifact_rejected, Reason}}
                    end;
                {error, _Reason} -> {error, artifact_unavailable}
            end;
        {ok, #file_info{type = regular}} -> {error, artifact_too_large};
        {ok, _Special} -> {error, artifact_unavailable};
        {error, enoent} -> {error, artifact_missing};
        {error, _Reason} -> {error, artifact_unavailable}
    end.

fold_recovery(Records, Pointer, State, Journal, Inspection) ->
    Sequence = maps:get(sequence, Pointer),
    Suffix = lists:nthtail(Sequence, Records),
    case {validate_record_generations(Records, State), validate_terminal_history(Records, State)} of
        {ok, ok} ->
            Plan0 = #{
                state => State,
                known_results => #{},
                duplicate_decisions => [],
                replayed_records => 0
            },
            case fold_suffix(Suffix, Plan0) of
                {ok, Plan} -> finalize_recovery(Plan, Journal, Inspection);
                {error, Reason} -> rejected(Reason, #{checkpoint_sequence => Sequence})
            end;
        {{error, Reason}, _} -> rejected(Reason, #{});
        {_, {error, Reason}} -> rejected(Reason, #{})
    end.

validate_record_generations(Records, State) ->
    DurableGeneration = maps:get(generation, State),
    case lists:dropwhile(
        fun(Record) -> maps:get(generation, Record) =< DurableGeneration end,
        Records
    ) of
        [] -> ok;
        [Future | _] -> {error, {future_journal_generation,
            maps:get(sequence, Future), maps:get(generation, Future)}}
    end.

validate_terminal_history(Records, State) ->
    TerminalRecords = [Record || Record <- Records,
        lists:member(maps:get(kind, Record), [completion, cancellation])],
    Kinds = lists:usort([maps:get(kind, Record) || Record <- TerminalRecords]),
    Terminal = maps:get(terminal, State),
    case Kinds of
        [] -> ok;
        [completion] when Terminal =:= completed -> terminal_digests_match(TerminalRecords, State);
        [cancellation] when Terminal =:= cancelled -> ok;
        [_One] -> {error, terminal_state_mismatch};
        _ -> {error, conflicting_terminal_states}
    end.

terminal_digests_match(Records, State) ->
    {ok, StateDigest} = alang_phase5_state:checkpoint_digest(State),
    case lists:all(
        fun(Record) -> maps:get(state_digest, maps:get(payload, Record)) =:= StateDigest end,
        Records
    ) of
        true -> ok;
        false -> {error, terminal_digest_mismatch}
    end.

fold_suffix([], Plan) -> {ok, Plan};
fold_suffix([Record | Rest], Plan) ->
    case fold_record(Record, Plan) of
        {ok, Updated} -> fold_suffix(Rest, Updated#{
            replayed_records := maps:get(replayed_records, Updated) + 1
        });
        {duplicate, Updated} -> fold_suffix(Rest, Updated#{
            duplicate_decisions := [maps:get(correlation_id, Record) |
                maps:get(duplicate_decisions, Updated)],
            replayed_records := maps:get(replayed_records, Updated) + 1
        });
        {error, _} = Error -> Error
    end.

fold_record(#{kind := observation, payload := Payload}, Plan) ->
    State = maps:get(state, Plan),
    Observations = maps:get(observations, State),
    Digest = maps:get(observation_digest, Payload),
    {ok, Plan#{state := State#{observations := Observations ++ [#{<<"digest">> => Digest}]}}};
fold_record(#{kind := effect_intent, payload := Payload}, Plan) ->
    State = maps:get(state, Plan),
    Intent = maps:with([operation_id, transition_id, operation, payload_digest], Payload),
    case maps:get(pending, State) of
        none -> map_state_result(alang_phase5_state:begin_effect(State, Intent), Plan);
        Existing when is_map(Existing) ->
            case same_intent(Existing, Intent) of
                true -> {duplicate, Plan};
                false -> {error, conflicting_effect_intent}
            end
    end;
fold_record(#{kind := authorization, payload := Payload}, Plan) ->
    case maps:get(decision, Payload) of
        allowed ->
            case apply_authorization_budget(Payload, Plan) of
                {ok, Budgeted} ->
                    advance_stage(Budgeted, maps:get(operation_id, Payload), authorized, undefined);
                {error, _} = Error -> Error
            end;
        denied -> {ok, Plan}
    end;
fold_record(#{kind := submission, payload := Payload}, Plan) ->
    advance_stage(Plan, maps:get(operation_id, Payload), submitted,
        maps:get(adapter_identity, Payload));
fold_record(#{kind := effect_result} = Record, Plan) ->
    remember_result(Record, Plan);
fold_record(#{kind := completion}, Plan) ->
    case maps:get(terminal, maps:get(state, Plan)) of
        completed -> {ok, Plan};
        _ -> {error, terminal_state_mismatch}
    end;
fold_record(#{kind := cancellation}, Plan) ->
    case maps:get(terminal, maps:get(state, Plan)) of
        cancelled -> {ok, Plan};
        _ -> {error, terminal_state_mismatch}
    end;
fold_record(#{kind := transition}, _Plan) -> {error, unpublished_transition};
fold_record(#{kind := checkpoint}, _Plan) -> {error, unpublished_checkpoint_record};
fold_record(#{kind := session_created}, _Plan) -> {error, duplicate_session_creation};
fold_record(#{kind := failure}, Plan) -> {ok, Plan};
fold_record(_Record, Plan) -> {ok, Plan}.

advance_stage(Plan, OperationId, Stage, AdapterIdentity) ->
    State = maps:get(state, Plan),
    Pending = maps:get(pending, State),
    case Pending of
        #{operation_id := OperationId, stage := Stage} -> {duplicate, Plan};
        _ -> map_state_result(
            alang_phase5_state:mark_effect(State, OperationId, Stage, AdapterIdentity),
            Plan
        )
    end.

remember_result(#{payload := Payload, record_digest := RecordDigest}, Plan) ->
    OperationId = maps:get(operation_id, Payload),
    Known = maps:get(known_results, Plan),
    case maps:find(OperationId, Known) of
        error ->
            State = maps:get(state, Plan),
            case maps:get(pending, State) of
                #{operation_id := OperationId, stage := Stage} when Stage =:= submitted; Stage =:= outcome_unknown ->
                    {ok, Plan#{known_results := Known#{OperationId => #{
                        payload => Payload,
                        record_digest => RecordDigest
                    }}}};
                _ -> {error, result_without_submission}
            end;
        {ok, #{payload := Payload}} -> {duplicate, Plan};
        {ok, _Conflict} -> {error, conflicting_effect_result}
    end.

apply_authorization_budget(Payload, Plan) ->
    State = maps:get(state, Plan),
    Pending = maps:get(pending, State),
    OperationId = maps:get(operation_id, Payload),
    case Pending of
        #{operation_id := OperationId, operation := Operation} ->
            GrantId = maps:get(grant_id, Payload),
            Remaining = maps:get(remaining_budget, Payload),
            case reduce_authority(maps:get(authority, State), GrantId, Operation, Remaining, []) of
                {ok, Authority} -> {ok, Plan#{state := State#{authority := Authority}}};
                {error, _} = Error -> Error
            end;
        _ -> {error, authorization_without_intent}
    end.

reduce_authority([], _GrantId, _Operation, _Remaining, _Acc) ->
    {error, authorization_unknown_grant};
reduce_authority([#{grant_id := GrantId, budgets := Budgets} = Grant | Rest], GrantId,
    Operation, Remaining, Acc) ->
    case maps:find(Operation, Budgets) of
        {ok, Current} when Remaining =< Current ->
            {ok, lists:reverse(Acc) ++ [Grant#{budgets := Budgets#{Operation := Remaining}} | Rest]};
        {ok, _Current} -> {error, authorization_budget_widening};
        error -> {error, authorization_scope_mismatch}
    end;
reduce_authority([Grant | Rest], GrantId, Operation, Remaining, Acc) ->
    reduce_authority(Rest, GrantId, Operation, Remaining, [Grant | Acc]).

map_state_result({ok, State}, Plan) -> {ok, Plan#{state := State}};
map_state_result({error, Reason}, _Plan) -> {error, {invalid_semantic_transition, Reason}}.

same_intent(Existing, Intent) ->
    maps:with([operation_id, transition_id, operation, payload_digest], Existing) =:= Intent.

finalize_recovery(Plan, Journal, Inspection) ->
    State = maps:get(state, Plan),
    Generation = maps:get(generation, State) + 1,
    FreshState = State#{generation := Generation},
    case alang_phase5_state:validate(FreshState) of
        ok -> {ok, #{
            format => alang_recovery_plan_v1,
            state => FreshState,
            generation => Generation,
            known_results => maps:get(known_results, Plan),
            duplicate_decisions => lists:reverse(maps:get(duplicate_decisions, Plan)),
            replayed_records => maps:get(replayed_records, Plan),
            journal_next_sequence => maps:get(next_sequence, Journal),
            journal_head_digest => maps:get(head_digest, Journal),
            artifact => maps:with([module, beam_sha256, imports, exports], Inspection)
        }};
        {error, Reason} -> rejected({invalid_recovered_state, Reason}, #{})
    end.

rejected(Reason, Evidence) ->
    {error, {recovery_rejected, Reason, bounded_evidence(Evidence)}}.

bounded_evidence(Evidence) when is_map(Evidence) ->
    maps:with([checkpoint_sequence, actual, expected], Evidence);
bounded_evidence(_Evidence) -> #{}.
