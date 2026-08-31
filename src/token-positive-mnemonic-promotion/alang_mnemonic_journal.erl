-module(alang_mnemonic_journal).

-export([append/4, append_file/4, load/2, new/2, validate/3]).

-define(MAX_RECORDS, 8192).
-define(MAX_RECORD_BYTES, 65536).
-define(ZERO, <<"0000000000000000000000000000000000000000000000000000000000000000">>).

-spec new(binary(), binary()) -> {ok, map()} | {error, term()}.
new(QualificationDigest, ScheduleDigest) ->
    case valid_digest(QualificationDigest) andalso valid_digest(ScheduleDigest) of
        true -> {ok, #{format => alang_mnemonic_journal_v1,
            qualification_digest => QualificationDigest,
            schedule_digest => ScheduleDigest, next_sequence => 0,
            head_digest => ?ZERO, records => []}};
        false -> {error, invalid_journal_identity}
    end.

-spec append(map(), atom(), map(), non_neg_integer()) ->
    {ok, map(), map()} | {error, term()}.
append(#{format := alang_mnemonic_journal_v1, records := Records} = Journal,
        Kind, Payload, Timestamp) when length(Records) < ?MAX_RECORDS ->
    try
        ok = validate_payload(Kind, Payload),
        ensure(is_integer(Timestamp) andalso Timestamp >= 0, invalid_timestamp),
        Unsigned = #{format => alang_mnemonic_journal_record_v1,
            qualification_digest => maps:get(qualification_digest, Journal),
            schedule_digest => maps:get(schedule_digest, Journal),
            sequence => maps:get(next_sequence, Journal), kind => Kind,
            timestamp_ms => Timestamp, previous_digest => maps:get(head_digest, Journal),
            payload => Payload},
        Digest = alang_fidelity_json:digest(Unsigned),
        Record = Unsigned#{record_digest => Digest},
        ensure(byte_size(term_to_binary(Record, [deterministic])) =< ?MAX_RECORD_BYTES,
            journal_record_too_large),
        Updated = Journal#{next_sequence := maps:get(next_sequence, Journal) + 1,
            head_digest := Digest, records := Records ++ [Record]},
        {ok, Record, Updated}
    catch throw:{mnemonic_journal_error, Reason} -> {error, Reason} end;
append(#{format := alang_mnemonic_journal_v1}, _, _, _) -> {error, journal_record_limit};
append(_, _, _, _) -> {error, invalid_journal}.

-spec append_file(file:filename(), map(), atom(), map()) ->
    {ok, map(), map()} | {error, term()}.
append_file(Root, Journal, Kind, Payload) ->
    case append(Journal, Kind, Payload, erlang:system_time(millisecond)) of
        {ok, Record, Updated} ->
            Path = record_path(Root, maps:get(sequence, Record)),
            ok = filelib:ensure_dir(Path),
            Bytes = term_to_binary(Record, [deterministic]),
            case file:write_file(Path, Bytes, [raw, binary, exclusive, sync]) of
                ok -> {ok, Record, Updated};
                {error, eexist} -> {error, duplicate_journal_record};
                {error, Reason} -> {error, {journal_write_failed, Reason}}
            end;
        {error, _} = Error -> Error
    end.

-spec load(file:filename(), binary()) -> {ok, map()} | {error, term()}.
load(Root, QualificationDigest) ->
    Paths = lists:sort(filelib:wildcard(filename:join(records_directory(Root), "*.etf"))),
    case read(Paths, []) of
        {ok, []} -> {error, empty_journal};
        {ok, Records} -> validate(Records, QualificationDigest,
            maps:get(schedule_digest, hd(Records)));
        {error, _} = Error -> Error
    end.

-spec validate([map()], binary(), binary()) -> {ok, map()} | {error, term()}.
validate(Records, QualificationDigest, ScheduleDigest) ->
    case new(QualificationDigest, ScheduleDigest) of
        {ok, Journal} -> replay(Records, Journal);
        {error, _} = Error -> Error
    end.

replay([], Journal) -> {ok, Journal};
replay([Record | Rest], Journal) ->
    Unsigned = maps:remove(record_digest, Record),
    ExpectedKeys = [format, kind, payload, previous_digest, qualification_digest,
        record_digest, schedule_digest, sequence, timestamp_ms],
    try
        ensure(lists:sort(maps:keys(Record)) =:= ExpectedKeys, invalid_record_fields),
        ensure(maps:get(format, Record) =:= alang_mnemonic_journal_record_v1,
            invalid_record_format),
        ensure(maps:get(qualification_digest, Record) =:=
            maps:get(qualification_digest, Journal), qualification_drift),
        ensure(maps:get(schedule_digest, Record) =:= maps:get(schedule_digest, Journal),
            schedule_drift),
        ensure(maps:get(sequence, Record) =:= maps:get(next_sequence, Journal), sequence_gap),
        ensure(maps:get(previous_digest, Record) =:= maps:get(head_digest, Journal), chain_break),
        ensure(maps:get(record_digest, Record) =:= alang_fidelity_json:digest(Unsigned),
            record_digest_mismatch),
        ok = validate_payload(maps:get(kind, Record), maps:get(payload, Record)),
        Updated = Journal#{next_sequence := maps:get(next_sequence, Journal) + 1,
            head_digest := maps:get(record_digest, Record),
            records := maps:get(records, Journal) ++ [Record]},
        replay(Rest, Updated)
    catch throw:{mnemonic_journal_error, Reason} -> {error, Reason} end.

validate_payload(trial_intent, P) ->
    closed(P, [attempt, cell, request, request_digest]),
    ensure(lists:member(maps:get(attempt, P), [primary, replacement]), invalid_attempt),
    ensure(is_map(maps:get(cell, P)) andalso is_map(maps:get(request, P)),
        invalid_intent_maps),
    digests(P, [request_digest]),
    ensure(alang_fidelity_json:digest(maps:get(request, P)) =:=
        maps:get(request_digest, P), request_digest_mismatch);
validate_payload(trial_result, P) ->
    closed(P, [result, result_digest]),
    Result = maps:get(result, P), ensure(is_map(Result), invalid_result),
    ensure(lists:member(maps:get(<<"provider_state">>, Result),
        [<<"definitive">>, <<"not_submitted">>, <<"uncertain">>]),
        invalid_provider_state),
    digests(P, [result_digest]),
    ensure(alang_fidelity_json:digest(Result) =:= maps:get(result_digest, P),
        result_digest_mismatch);
validate_payload(replacement_link, P) ->
    closed(P, [operation_id, parent_operation_id, reason, trial_id]),
    ensure(lists:member(maps:get(reason, P), [transport_failure_before_response,
        timeout_before_response_metadata]), invalid_replacement_reason),
    digests(P, [operation_id, parent_operation_id]), ok;
validate_payload(invalid_campaign, P) ->
    closed(P, [reason]), ensure(is_binary(maps:get(reason, P)), invalid_reason);
validate_payload(campaign_closed, P) ->
    closed(P, [calls, evidence_digest, valid]),
    ensure(is_integer(maps:get(calls, P)) andalso maps:get(calls, P) >= 0, invalid_calls),
    ensure(is_boolean(maps:get(valid, P)), invalid_validity),
    digests(P, [evidence_digest]);
validate_payload(_, _) -> fail(invalid_record_kind).

closed(P, Keys) ->
    ensure(is_map(P) andalso lists:sort(maps:keys(P)) =:= lists:sort(Keys),
        invalid_payload_fields).
digests(P, Keys) ->
    ensure(lists:all(fun(K) -> valid_digest(maps:get(K, P)) end, Keys), invalid_digest), ok.

read([], Acc) -> {ok, lists:reverse(Acc)};
read([Path | Rest], Acc) ->
    case file:read_file(Path) of
        {ok, Bytes} when byte_size(Bytes) =< ?MAX_RECORD_BYTES ->
            try binary_to_term(Bytes, [safe]) of
                Record ->
                    case term_to_binary(Record, [deterministic]) =:= Bytes of
                        true -> read(Rest, [Record | Acc]);
                        false -> {error, noncanonical_journal_record}
                    end
            catch _:_ -> {error, invalid_journal_record} end;
        {ok, _} -> {error, journal_record_too_large};
        {error, Reason} -> {error, {journal_read_failed, Reason}}
    end.

record_path(Root, Sequence) ->
    filename:join(records_directory(Root),
        lists:flatten(io_lib:format("~6..0B.etf", [Sequence]))).
records_directory(Root0) ->
    Root = filename:absname(Root0),
    Owned = filename:absname("build/token-positive-mnemonic-promotion/phase-03"),
    true = Root =:= Owned orelse lists:prefix(Owned ++ "/", Root),
    filename:join(Root, "records").
valid_digest(Value) when is_binary(Value), byte_size(Value) =:= 64 ->
    re:run(Value, <<"^[0-9a-f]{64}$">>, [{capture, none}]) =:= match;
valid_digest(_) -> false.
ensure(true, _Reason) -> ok;
ensure(false, Reason) -> fail(Reason).
fail(Reason) -> throw({mnemonic_journal_error, Reason}).
