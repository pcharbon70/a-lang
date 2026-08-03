-module(alang_phase5_journal).

-export([
    append/5,
    new/1,
    operation_id/3,
    record_digest/1,
    transition_id/2,
    validate/2,
    validate_append/4
]).

-define(FORMAT, alang_journal_v1).
-define(RECORD_FORMAT, alang_journal_record_v1).
-define(MAX_RECORDS, 100000).
-define(MAX_RECORD_BYTES, 65536).
-define(MAX_ID_BYTES, 128).
-define(ZERO_DIGEST, <<"0000000000000000000000000000000000000000000000000000000000000000">>).

-spec new(binary()) -> {ok, map()} | {error, atom()}.
new(SessionId) when is_binary(SessionId), byte_size(SessionId) > 0, byte_size(SessionId) =< ?MAX_ID_BYTES ->
    {ok, #{
        format => ?FORMAT,
        session_id => SessionId,
        next_sequence => 0,
        head_digest => ?ZERO_DIGEST,
        records => []
    }};
new(_SessionId) -> {error, invalid_session_id}.

-spec transition_id(binary(), non_neg_integer()) -> {ok, binary()} | {error, atom()}.
transition_id(SessionId, Sequence) when
    is_binary(SessionId), byte_size(SessionId) > 0, byte_size(SessionId) =< ?MAX_ID_BYTES,
    is_integer(Sequence), Sequence >= 0
->
    {ok, stable_id({alang_transition_v1, SessionId, Sequence})};
transition_id(_SessionId, _Sequence) -> {error, invalid_transition_identity_input}.

-spec operation_id(binary(), binary(), non_neg_integer()) -> {ok, binary()} | {error, atom()}.
operation_id(SessionId, TransitionId, Ordinal) when
    is_binary(SessionId), byte_size(SessionId) > 0, byte_size(SessionId) =< ?MAX_ID_BYTES,
    is_binary(TransitionId), byte_size(TransitionId) =:= 64,
    is_integer(Ordinal), Ordinal >= 0
->
    {ok, stable_id({alang_operation_v1, SessionId, TransitionId, Ordinal})};
operation_id(_SessionId, _TransitionId, _Ordinal) -> {error, invalid_operation_identity_input}.

-spec append(map(), atom(), pos_integer(), map(), integer()) ->
    {ok, map(), map()} | {error, atom()} | {error, tuple()}.
append(
    #{
        format := ?FORMAT,
        session_id := SessionId,
        next_sequence := Sequence,
        head_digest := Previous,
        records := Records
    } = Journal,
    Kind,
    Generation,
    Payload,
    Timestamp
) when length(Records) < ?MAX_RECORDS ->
    case validate_record_input(Kind, Generation, Payload, Timestamp) of
        ok ->
            CorrelationId = correlation_id(SessionId, Kind, Sequence, Payload),
            Unsigned = #{
                format => ?RECORD_FORMAT,
                session_id => SessionId,
                sequence => Sequence,
                generation => Generation,
                kind => Kind,
                correlation_id => CorrelationId,
                timestamp => #{clock => utc_unix_millisecond, value => Timestamp},
                previous_digest => Previous,
                payload => Payload
            },
            Digest = digest_unsigned(Unsigned),
            Record = Unsigned#{record_digest => Digest},
            case encoded_size(Record) =< ?MAX_RECORD_BYTES of
                true ->
                    {ok, Record, Journal#{
                        next_sequence := Sequence + 1,
                        head_digest := Digest,
                        records := Records ++ [Record]
                    }};
                false -> {error, record_too_large}
            end;
        {error, _} = Error -> Error
    end;
append(#{format := ?FORMAT}, _Kind, _Generation, _Payload, _Timestamp) ->
    {error, journal_record_limit};
append(_Journal, _Kind, _Generation, _Payload, _Timestamp) -> {error, invalid_journal}.

-spec validate([term()], binary()) -> {ok, map()} | {error, tuple()} | {error, atom()}.
validate(Records, SessionId) when is_list(Records) ->
    case new(SessionId) of
        {ok, Journal} -> validate_records(Records, Journal);
        {error, _} = Error -> Error
    end;
validate(_Records, _SessionId) -> {error, invalid_journal_records}.

-spec validate_append(term(), binary(), non_neg_integer(), binary()) -> ok | {error, tuple()}.
validate_append(Record, SessionId, Sequence, PreviousDigest) ->
    case validate_record(Record, SessionId, Sequence, PreviousDigest) of
        ok -> ok;
        {error, _} = Error -> Error
    end.

-spec record_digest(term()) -> {ok, binary()} | {error, atom()}.
record_digest(#{record_digest := Digest} = Record) ->
    case valid_digest(Digest) andalso maps:get(format, Record, undefined) =:= ?RECORD_FORMAT of
        true -> {ok, Digest};
        false -> {error, invalid_journal_record}
    end;
record_digest(_Record) -> {error, invalid_journal_record}.

validate_records([], Journal) -> {ok, Journal};
validate_records([Record | Rest], Journal) ->
    SessionId = maps:get(session_id, Journal),
    Sequence = maps:get(next_sequence, Journal),
    Previous = maps:get(head_digest, Journal),
    case validate_record(Record, SessionId, Sequence, Previous) of
        ok ->
            Digest = maps:get(record_digest, Record),
            validate_records(Rest, Journal#{
                next_sequence := Sequence + 1,
                head_digest := Digest,
                records := maps:get(records, Journal) ++ [Record]
            });
        {error, _} = Error -> Error
    end.

validate_record(Record, SessionId, Sequence, PreviousDigest) when is_map(Record) ->
    Required = [format, session_id, sequence, generation, kind, correlation_id,
        timestamp, previous_digest, payload, record_digest],
    case exact_keys(Record, Required) of
        false -> {error, {malformed_record, Sequence}};
        true -> validate_record_fields(Record, SessionId, Sequence, PreviousDigest)
    end;
validate_record(_Record, _SessionId, Sequence, _PreviousDigest) ->
    {error, {malformed_record, Sequence}}.

validate_record_fields(Record, SessionId, Sequence, PreviousDigest) ->
    ActualSequence = maps:get(sequence, Record),
    ActualPrevious = maps:get(previous_digest, Record),
    case {
        maps:get(format, Record) =:= ?RECORD_FORMAT,
        maps:get(session_id, Record) =:= SessionId,
        ActualSequence =:= Sequence,
        ActualPrevious =:= PreviousDigest,
        digest_unsigned(maps:remove(record_digest, Record)) =:= maps:get(record_digest, Record),
        validate_record_content(Record)
    } of
        {false, _, _, _, _, _} -> {error, {unknown_record_format, Sequence}};
        {_, false, _, _, _, _} -> {error, {wrong_session, Sequence}};
        {_, _, false, _, _, _} -> {error, {sequence_gap, Sequence, ActualSequence}};
        {_, _, _, false, _, _} -> {error, {previous_digest_mismatch, Sequence}};
        {_, _, _, _, false, _} -> {error, {record_digest_mismatch, Sequence}};
        {_, _, _, _, _, false} -> {error, {malformed_record, Sequence}};
        {true, true, true, true, true, true} -> ok
    end.

validate_record_content(Record) ->
    Kind = maps:get(kind, Record),
    Generation = maps:get(generation, Record),
    Payload = maps:get(payload, Record),
    Timestamp = maps:get(timestamp, Record),
    Correlation = maps:get(correlation_id, Record),
    validate_record_input(
        Kind,
        Generation,
        Payload,
        maps:get(value, Timestamp, invalid)
    ) =:= ok andalso
        exact_keys(Timestamp, [clock, value]) andalso
        maps:get(clock, Timestamp) =:= utc_unix_millisecond andalso
        valid_digest(Correlation) andalso
        correlation_id(
            maps:get(session_id, Record),
            Kind,
            maps:get(sequence, Record),
            Payload
        ) =:= Correlation andalso
        valid_digest(maps:get(previous_digest, Record)) andalso
        valid_digest(maps:get(record_digest, Record)) andalso
        encoded_size(Record) =< ?MAX_RECORD_BYTES.

validate_record_input(Kind, Generation, Payload, Timestamp) ->
    case is_integer(Generation) andalso Generation > 0 andalso
        is_integer(Timestamp) andalso Timestamp >= 0 andalso valid_payload(Kind, Payload)
    of
        true -> ok;
        false -> {error, invalid_journal_record_input}
    end.

valid_payload(session_created, Payload) ->
    payload(Payload, [state_digest, artifact_digest], [state_digest, artifact_digest]);
valid_payload(observation, Payload) -> payload(Payload, [observation_digest], [observation_digest]);
valid_payload(transition, Payload) ->
    payload(Payload, [transition_id, state_digest], [transition_id, state_digest]);
valid_payload(effect_intent, Payload) ->
    payload(Payload, [transition_id, operation_id, operation, payload_digest],
        [transition_id, operation_id, payload_digest]) andalso
        valid_id(maps:get(operation, Payload, undefined));
valid_payload(authorization, Payload) ->
    payload(Payload, [operation_id, grant_id, decision, decision_digest, remaining_budget],
        [operation_id, grant_id, decision_digest]) andalso
        lists:member(maps:get(decision, Payload, invalid), [allowed, denied]) andalso
        is_integer(maps:get(remaining_budget, Payload, invalid)) andalso
        maps:get(remaining_budget, Payload) >= 0 andalso
        maps:get(remaining_budget, Payload) =< 1000000;
valid_payload(submission, Payload) ->
    payload(Payload, [operation_id, adapter_identity, payload_digest], [operation_id, payload_digest]) andalso
        valid_id(maps:get(adapter_identity, Payload, undefined));
valid_payload(effect_result, Payload) ->
    payload(Payload, [operation_id, outcome, result_digest], [operation_id, result_digest]) andalso
        lists:member(maps:get(outcome, Payload, invalid), [succeeded, denied, failed, outcome_unknown]);
valid_payload(checkpoint, Payload) -> payload(Payload, [state_digest], [state_digest]);
valid_payload(cancellation, Payload) -> payload(Payload, [reason_digest], [reason_digest]);
valid_payload(failure, Payload) ->
    payload(Payload, [class, evidence_digest], [evidence_digest]) andalso
        lists:member(maps:get(class, Payload, invalid), [runtime, adapter, storage, recovery, policy]);
valid_payload(completion, Payload) ->
    payload(Payload, [state_digest, evidence_digest], [state_digest, evidence_digest]);
valid_payload(_Kind, _Payload) -> false.

payload(Payload, Keys, DigestKeys) when is_map(Payload) ->
    exact_keys(Payload, Keys) andalso
        lists:all(fun(Key) -> valid_digest(maps:get(Key, Payload, undefined)) end, DigestKeys);
payload(_Payload, _Keys, _DigestKeys) -> false.

correlation_id(_SessionId, Kind, _Sequence, Payload) when
    Kind =:= effect_intent; Kind =:= authorization; Kind =:= submission; Kind =:= effect_result
-> maps:get(operation_id, Payload);
correlation_id(_SessionId, transition, _Sequence, Payload) -> maps:get(transition_id, Payload);
correlation_id(SessionId, Kind, Sequence, Payload) ->
    stable_id({alang_record_correlation_v1, SessionId, Kind, Sequence, Payload}).

digest_unsigned(Unsigned) -> stable_id({alang_journal_digest_v1, Unsigned}).

stable_id(Term) -> hex(crypto:hash(sha256, term_to_binary(Term, [deterministic]))).

encoded_size(Term) -> byte_size(term_to_binary(Term, [deterministic])).

valid_id(Value) -> is_binary(Value) andalso byte_size(Value) > 0 andalso byte_size(Value) =< ?MAX_ID_BYTES.

valid_digest(Value) when is_binary(Value), byte_size(Value) =:= 64 ->
    lists:all(fun is_hex/1, binary_to_list(Value));
valid_digest(_) -> false.

is_hex(Character) when Character >= $0, Character =< $9 -> true;
is_hex(Character) when Character >= $a, Character =< $f -> true;
is_hex(_) -> false.

exact_keys(Map, Keys) -> lists:sort(maps:keys(Map)) =:= lists:sort(Keys).

hex(Binary) -> << <<(hex_digit(Nibble))>> || <<Nibble:4>> <= Binary >>.

hex_digit(Nibble) when Nibble < 10 -> $0 + Nibble;
hex_digit(Nibble) -> $a + Nibble - 10.
