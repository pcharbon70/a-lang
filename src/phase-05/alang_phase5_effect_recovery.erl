-module(alang_phase5_effect_recovery).

-export([reconcile/4]).

-spec reconcile(pid(), pid(), map(), integer()) ->
    {ok, map()} | {paused, map()} | {error, tuple()}.
reconcile(Store, Broker, Recovery, Deadline) when
    is_pid(Store), is_pid(Broker), is_map(Recovery), is_integer(Deadline)
->
    State = maps:get(state, Recovery),
    case maps:get(pending, State) of
        none -> {ok, Recovery#{reconciliation => #{decision => none}}};
        Pending -> reconcile_pending(Store, Broker, Recovery, Pending, Deadline)
    end;
reconcile(_Store, _Broker, _Recovery, _Deadline) ->
    {error, {effect_recovery_failed, invalid_recovery_input}}.

reconcile_pending(Store, Broker, Recovery, Pending, Deadline) ->
    OperationId = maps:get(operation_id, Pending),
    Known = maps:get(known_results, Recovery, #{}),
    case maps:find(OperationId, Known) of
        {ok, Existing} -> known_result(Recovery, Pending, Existing);
        error -> classify_pending(Store, Broker, Recovery, Pending, Deadline)
    end.

known_result(Recovery, Pending, #{payload := Payload, record_digest := RecordDigest}) ->
    ResultDigest = maps:get(result_digest, Payload),
    case alang_phase5_state:result_ack(maps:get(state, Recovery), ResultDigest, RecordDigest) of
        {ok, Ack} -> {ok, Recovery#{reconciliation => #{
            decision => durable_result,
            operation_id => maps:get(operation_id, Pending),
            result_ack => Ack
        }}};
        {error, Reason} -> {error, {effect_recovery_failed, Reason}}
    end;
known_result(_Recovery, _Pending, _Existing) ->
    {error, {effect_recovery_failed, invalid_known_result}}.

classify_pending(_Store, _Broker, Recovery, #{stage := Stage} = Pending, _Deadline) when
    Stage =:= intent; Stage =:= authorized
-> {ok, Recovery#{reconciliation => #{
    decision => retry_allowed,
    reason => definitely_not_submitted,
    operation_id => maps:get(operation_id, Pending)
}}};
classify_pending(Store, Broker, Recovery, Pending, Deadline) ->
    case workspace_query(Pending) of
        {ok, Query} -> query_adapter(Store, Broker, Recovery, Pending, Query, Deadline);
        {error, Reason} -> pause_irreconcilable(Store, Recovery, Pending, Reason, Deadline)
    end.

workspace_query(#{operation := <<"workspace.write">>, recovery := #{
    kind := workspace_write,
    workspace_id := WorkspaceId,
    path_segments := Segments,
    artifact_digest := ArtifactDigest
}, operation_id := OperationId, payload_digest := PayloadDigest}) ->
    {ok, #{
        workspace_id => WorkspaceId,
        path_segments => Segments,
        operation_id => OperationId,
        payload_digest => PayloadDigest,
        artifact_digest => ArtifactDigest
    }};
workspace_query(_Pending) -> {error, missing_workspace_recovery_descriptor}.

query_adapter(Store, Broker, Recovery, Pending, Query, Deadline) ->
    ExpectedPayloadDigest = maps:get(payload_digest, Pending),
    ExpectedArtifactDigest = maps:get(artifact_digest, maps:get(recovery, Pending)),
    case alang_phase4_broker:lookup_workspace(Broker, Query, Deadline) of
        {ok, #{status := completed, payload_digest := PayloadDigest,
            artifact_digest := ArtifactDigest}} when
            PayloadDigest =:= ExpectedPayloadDigest,
            ArtifactDigest =:= ExpectedArtifactDigest
        -> record_existing_result(Store, Recovery, Pending, ArtifactDigest, Deadline);
        {ok, #{status := not_submitted}} -> {ok, Recovery#{reconciliation => #{
            decision => retry_allowed,
            reason => adapter_proved_not_submitted,
            operation_id => maps:get(operation_id, Pending)
        }}};
        {ok, #{status := Status}} when Status =:= outcome_unknown; Status =:= conflict ->
            pause_irreconcilable(Store, Recovery, Pending, Status, Deadline);
        {ok, _Invalid} -> pause_irreconcilable(Store, Recovery, Pending,
            adapter_evidence_mismatch, Deadline);
        {error, adapter_unavailable} -> {error, {effect_recovery_deferred, adapter_unavailable}};
        {error, Reason} -> {error, {effect_recovery_deferred, Reason}}
    end.

record_existing_result(Store, Recovery, Pending, ResultDigest, Deadline) ->
    Payload = #{
        operation_id => maps:get(operation_id, Pending),
        outcome => succeeded,
        result_digest => ResultDigest
    },
    case append_record(Store, Recovery, effect_result, Payload, Deadline) of
        {ok, Record, UpdatedRecovery} ->
            RecordDigest = maps:get(record_digest, Record),
            {ok, Ack} = alang_phase5_state:result_ack(
                maps:get(state, Recovery), ResultDigest, RecordDigest),
            Known0 = maps:get(known_results, Recovery, #{}),
            Known = Known0#{maps:get(operation_id, Pending) => #{
                payload => Payload,
                record_digest => RecordDigest
            }},
            {ok, UpdatedRecovery#{known_results := Known, reconciliation => #{
                decision => recovered_result,
                operation_id => maps:get(operation_id, Pending),
                result_ack => Ack
            }}};
        {error, Reason} -> {error, {effect_recovery_failed, Reason}}
    end.

pause_irreconcilable(Store, Recovery, Pending, Reason, Deadline) ->
    EvidenceDigest = stable_digest({irreconcilable_effect, maps:get(operation_id, Pending), Reason}),
    State = maps:get(state, Recovery),
    case alang_phase5_state:pause(State, EvidenceDigest) of
        {ok, PausedState} ->
            FailurePayload = #{class => recovery, evidence_digest => EvidenceDigest},
            case append_record(Store, Recovery, failure, FailurePayload, Deadline) of
                {ok, _Record, UpdatedRecovery} ->
                    Sequence = maps:get(journal_next_sequence, UpdatedRecovery),
                    case alang_phase5_store:checkpoint(Store, PausedState, Sequence, Deadline) of
                        {ok, Ack} -> {paused, UpdatedRecovery#{
                            state := PausedState,
                            resume_checkpoint => Ack,
                            reconciliation => #{
                                decision => paused,
                                operation_id => maps:get(operation_id, Pending),
                                reason => Reason,
                                evidence_digest => EvidenceDigest
                            }
                        }};
                        {error, StoreReason} -> {error, {effect_recovery_failed, StoreReason}}
                    end;
                {error, StoreReason} -> {error, {effect_recovery_failed, StoreReason}}
            end;
        {error, StateReason} -> {error, {effect_recovery_failed, StateReason}}
    end.

append_record(Store, Recovery, Kind, Payload, Deadline) ->
    case alang_phase5_store:read(Store, Deadline) of
        {ok, Snapshot} ->
            case alang_phase5_journal:validate(
                maps:get(records, Snapshot), maps:get(session_id, Snapshot))
            of
                {ok, Journal} ->
                    Generation = maps:get(generation, Recovery),
                    case alang_phase5_journal:append(
                        Journal, Kind, Generation, Payload, erlang:system_time(millisecond))
                    of
                        {ok, Record, UpdatedJournal} ->
                            case alang_phase5_store:append(Store, Record, Deadline) of
                                {ok, _Ack} -> {ok, Record, Recovery#{
                                    journal_next_sequence := maps:get(next_sequence, UpdatedJournal),
                                    journal_head_digest := maps:get(head_digest, UpdatedJournal)
                                }};
                                {error, Reason} -> {error, Reason}
                            end;
                        {error, Reason} -> {error, Reason}
                    end;
                {error, Reason} -> {error, {invalid_journal, Reason}}
            end;
        {error, Reason} -> {error, Reason}
    end.

stable_digest(Term) ->
    Binary = crypto:hash(sha256, term_to_binary(Term, [deterministic])),
    << <<(hex_digit(Nibble))>> || <<Nibble:4>> <= Binary >>.

hex_digit(Nibble) when Nibble < 10 -> $0 + Nibble;
hex_digit(Nibble) -> $a + Nibble - 10.
