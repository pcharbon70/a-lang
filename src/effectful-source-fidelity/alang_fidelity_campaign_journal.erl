-module(alang_fidelity_campaign_journal).

-export([
    append/4,
    append_file/4,
    load/2,
    new/1,
    validate/2
]).

-define(MAX_RECORDS, 4096).
-define(MAX_RECORD_BYTES, 16384).
-define(ZERO_DIGEST, <<"0000000000000000000000000000000000000000000000000000000000000000">>).

-spec new(binary()) -> {ok, map()} | {error, term()}.
new(CampaignDigest) ->
    case valid_digest(CampaignDigest) of
        true -> {ok, #{
            format => alang_fidelity_campaign_journal_v1,
            campaign_digest => CampaignDigest,
            next_sequence => 0,
            head_digest => ?ZERO_DIGEST,
            records => []
        }};
        false -> {error, invalid_campaign_digest}
    end.

-spec append(map(), atom(), map(), non_neg_integer()) ->
    {ok, map(), map()} | {error, term()}.
append(#{
    format := alang_fidelity_campaign_journal_v1,
    campaign_digest := CampaignDigest,
    next_sequence := Sequence,
    head_digest := Previous,
    records := Records
} = Journal, Kind, Payload, Timestamp) when length(Records) < ?MAX_RECORDS ->
    case valid_payload(Kind, Payload) andalso is_integer(Timestamp) andalso Timestamp >= 0 of
        true ->
            Unsigned = #{
                format => alang_fidelity_campaign_record_v1,
                campaign_digest => CampaignDigest,
                sequence => Sequence,
                kind => Kind,
                timestamp_ms => Timestamp,
                previous_digest => Previous,
                payload => Payload
            },
            Digest = alang_fidelity_json:digest(Unsigned),
            Record = Unsigned#{record_digest => Digest},
            case byte_size(term_to_binary(Record, [deterministic])) =< ?MAX_RECORD_BYTES of
                true -> {ok, Record, Journal#{
                    next_sequence := Sequence + 1,
                    head_digest := Digest,
                    records := Records ++ [Record]
                }};
                false -> {error, campaign_record_too_large}
            end;
        false -> {error, invalid_campaign_record}
    end;
append(#{format := alang_fidelity_campaign_journal_v1}, _Kind, _Payload, _Timestamp) ->
    {error, campaign_record_limit};
append(_Journal, _Kind, _Payload, _Timestamp) -> {error, invalid_campaign_journal}.

-spec append_file(file:filename(), map(), atom(), map()) ->
    {ok, map(), map()} | {error, term()}.
append_file(Root, Journal, Kind, Payload) ->
    Timestamp = erlang:system_time(millisecond),
    case append(Journal, Kind, Payload, Timestamp) of
        {ok, Record, Updated} ->
            case write_record(Root, Record) of
                ok -> {ok, Record, Updated};
                {error, _} = Error -> Error
            end;
        {error, _} = Error -> Error
    end.

-spec load(file:filename(), binary()) -> {ok, map()} | {error, term()}.
load(Root, CampaignDigest) ->
    Directory = records_directory(Root),
    Paths = lists:sort(filelib:wildcard(filename:join(Directory, "*.etf"))),
    case length(Paths) =< ?MAX_RECORDS of
        false -> {error, campaign_record_limit};
        true ->
            case read_records(Paths, []) of
                {ok, Records} -> validate(Records, CampaignDigest);
                {error, _} = Error -> Error
            end
    end.

-spec validate([term()], binary()) -> {ok, map()} | {error, term()}.
validate(Records, CampaignDigest) when is_list(Records) ->
    case new(CampaignDigest) of
        {ok, Journal} -> validate_records(Records, Journal);
        {error, _} = Error -> Error
    end;
validate(_, _) -> {error, invalid_campaign_records}.

validate_records([], Journal) -> {ok, Journal};
validate_records([Record | Rest], Journal) ->
    case validate_record(Record, Journal) of
        ok ->
            validate_records(Rest, Journal#{
                next_sequence := maps:get(next_sequence, Journal) + 1,
                head_digest := maps:get(record_digest, Record),
                records := maps:get(records, Journal) ++ [Record]
            });
        {error, _} = Error -> Error
    end.

validate_record(Record, Journal) when is_map(Record) ->
    Keys = [campaign_digest, format, kind, payload, previous_digest, record_digest, sequence, timestamp_ms],
    Unsigned = maps:remove(record_digest, Record),
    case lists:sort(maps:keys(Record)) =:= Keys
        andalso maps:get(format, Record, invalid) =:= alang_fidelity_campaign_record_v1
        andalso maps:get(campaign_digest, Record, invalid) =:= maps:get(campaign_digest, Journal)
        andalso maps:get(sequence, Record, invalid) =:= maps:get(next_sequence, Journal)
        andalso maps:get(previous_digest, Record, invalid) =:= maps:get(head_digest, Journal)
        andalso maps:get(record_digest, Record, invalid) =:= alang_fidelity_json:digest(Unsigned)
        andalso valid_payload(maps:get(kind, Record, invalid), maps:get(payload, Record, invalid))
        andalso is_integer(maps:get(timestamp_ms, Record, invalid))
        andalso maps:get(timestamp_ms, Record) >= 0 of
        true -> ok;
        false -> {error, {invalid_campaign_record, maps:get(next_sequence, Journal)}}
    end;
validate_record(_, Journal) -> {error, {invalid_campaign_record, maps:get(next_sequence, Journal)}}.

valid_payload(campaign_started, Payload) ->
    exact_payload(Payload, [primary_cells, schedule_digest])
        andalso maps:get(primary_cells, Payload, invalid) =:= 288
        andalso valid_digest(maps:get(schedule_digest, Payload, invalid));
valid_payload(trial_intent, Payload) ->
    exact_payload(Payload, [attempt_class, operation_id, request_digest, trial_id])
        andalso lists:member(maps:get(attempt_class, Payload, invalid), [primary, repair, replacement, retry])
        andalso digests(Payload, [operation_id, request_digest, trial_id]);
valid_payload(trial_result, Payload) ->
    exact_payload(Payload, [cost_microusd, input_tokens, operation_id, output_tokens, result_digest, status, submission, trial_id])
        andalso digests(Payload, [operation_id, result_digest, trial_id])
        andalso lists:member(maps:get(submission, Payload, invalid), [definitive, not_submitted, uncertain])
        andalso is_atom(maps:get(status, Payload, invalid))
        andalso nonnegative(Payload, [cost_microusd, input_tokens, output_tokens]);
valid_payload(replacement_link, Payload) ->
    exact_payload(Payload, [link_class, operation_id, parent_operation_id, trial_id])
        andalso maps:get(link_class, Payload, invalid) =:= no_definitive_response
        andalso digests(Payload, [operation_id, parent_operation_id, trial_id]);
valid_payload(campaign_closed, Payload) ->
    exact_payload(Payload, [call_count, cost_microusd, evidence_digest, valid])
        andalso digests(Payload, [evidence_digest])
        andalso nonnegative(Payload, [call_count, cost_microusd])
        andalso is_boolean(maps:get(valid, Payload, invalid));
valid_payload(_, _) -> false.

write_record(Root, Record) ->
    Directory = records_directory(Root),
    case filelib:ensure_dir(filename:join(Directory, "placeholder")) of
        ok ->
            Name = lists:flatten(io_lib:format("~6..0B.etf", [maps:get(sequence, Record)])),
            Path = filename:join(Directory, Name),
            Bytes = term_to_binary(Record, [deterministic]),
            case file:write_file(Path, Bytes, [raw, binary, exclusive, sync]) of
                ok -> ok;
                {error, eexist} -> {error, duplicate_campaign_record};
                {error, Reason} -> {error, {campaign_journal_write_failed, Reason}}
            end;
        {error, Reason} -> {error, {campaign_journal_directory_failed, Reason}}
    end.

read_records([], Acc) -> {ok, lists:reverse(Acc)};
read_records([Path | Rest], Acc) ->
    case file:read_file(Path) of
        {ok, Bytes} when byte_size(Bytes) =< ?MAX_RECORD_BYTES ->
            try binary_to_term(Bytes, [safe]) of
                Record ->
                    case term_to_binary(Record, [deterministic]) =:= Bytes of
                        true -> read_records(Rest, [Record | Acc]);
                        false -> {error, noncanonical_campaign_record}
                    end
            catch
                _:_ -> {error, invalid_campaign_record_etf}
            end;
        {ok, _} -> {error, campaign_record_too_large};
        {error, Reason} -> {error, {campaign_journal_read_failed, Reason}}
    end.

records_directory(Root0) ->
    Root = filename:absname(Root0),
    Owned = filename:absname("build/effectful-source-fidelity/phase-05"),
    true = lists:prefix(Owned ++ "/", Root),
    filename:join(Root, "records").

exact_payload(Payload, Keys) when is_map(Payload) -> lists:sort(maps:keys(Payload)) =:= Keys;
exact_payload(_, _) -> false.

digests(Payload, Keys) -> lists:all(fun(Key) -> valid_digest(maps:get(Key, Payload, invalid)) end, Keys).
nonnegative(Payload, Keys) -> lists:all(fun(Key) ->
    Value = maps:get(Key, Payload, invalid),
    is_integer(Value) andalso Value >= 0
end, Keys).

valid_digest(Value) when is_binary(Value), byte_size(Value) =:= 64 ->
    re:run(Value, <<"^[0-9a-f]{64}$">>, [{capture, none}]) =:= match;
valid_digest(_) -> false.
