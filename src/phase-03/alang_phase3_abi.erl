-module(alang_phase3_abi).

-export([
    kinds/0,
    new/8,
    request_effect/5,
    validate/1,
    validate_at/2
]).

-define(MAX_ID_BYTES, 256).
-define(MAX_PAYLOAD_BYTES, 65536).
-define(MAX_DEADLINE_MS, 60000).
-define(MAX_SKIPPED_MESSAGES, 32).

-type envelope() :: {
    alang_envelope_v1,
    atom(),
    binary(),
    binary(),
    binary(),
    integer(),
    {atom(), term()},
    pid(),
    {source, non_neg_integer(), pos_integer(), pos_integer()}
}.

-spec kinds() -> [atom()].
kinds() ->
    [
        task_start,
        effect_intent,
        effect_result,
        effect_denied,
        cancel,
        deadline,
        trace,
        completion,
        runtime_failure
    ].

-spec new(atom(), binary(), binary(), binary(), integer(), tuple(), pid(), tuple()) ->
    {ok, envelope()} | {error, term()}.
new(Kind, SessionId, TaskId, CorrelationId, Deadline, Payload, ReplyTo, Origin) ->
    Envelope = {
        alang_envelope_v1,
        Kind,
        SessionId,
        TaskId,
        CorrelationId,
        Deadline,
        Payload,
        ReplyTo,
        Origin
    },
    case validate(Envelope) of
        ok -> {ok, Envelope};
        {error, _} = Error -> Error
    end.

-spec validate(term()) -> ok | {error, term()}.
validate(Envelope) ->
    validate_shape(Envelope).

-spec validate_at(term(), integer()) -> ok | {error, term()}.
validate_at(Envelope, Now) when is_integer(Now) ->
    case validate_shape(Envelope) of
        ok ->
            Deadline = element(6, Envelope),
            case Deadline >= Now of
                true -> ok;
                false -> {error, stale_message}
            end;
        {error, _} = Error -> Error
    end;
validate_at(_Envelope, _Now) ->
    {error, invalid_clock}.

-spec request_effect(map(), binary(), term(), tuple(), pos_integer()) -> term().
request_effect(Context, Operation, Arguments, Origin, RelativeDeadline) ->
    case validate_effect_context(Context, Operation, Origin, RelativeDeadline) of
        ok -> issue_effect(Context, Operation, Arguments, Origin, RelativeDeadline);
        {error, Reason} -> tagged_error(reason_binary(Reason))
    end.

validate_shape({
    alang_envelope_v1,
    Kind,
    SessionId,
    TaskId,
    CorrelationId,
    Deadline,
    {PayloadTag, Payload},
    ReplyTo,
    Origin
}) when is_atom(Kind), is_integer(Deadline), is_pid(ReplyTo) ->
    case {
        valid_kind_payload(Kind, PayloadTag),
        valid_id(SessionId),
        valid_id(TaskId),
        valid_id(CorrelationId),
        valid_origin(Origin),
        bounded_term(Payload)
    } of
        {true, true, true, true, true, true} -> ok;
        {false, _, _, _, _, _} -> {error, invalid_kind_or_payload_tag};
        {_, false, _, _, _, _} -> {error, invalid_session_id};
        {_, _, false, _, _, _} -> {error, invalid_task_id};
        {_, _, _, false, _, _} -> {error, invalid_correlation_id};
        {_, _, _, _, false, _} -> {error, invalid_source_origin};
        {_, _, _, _, _, false} -> {error, payload_too_large}
    end;
validate_shape({Version, _, _, _, _, _, _, _, _}) when Version =/= alang_envelope_v1 ->
    {error, unsupported_abi_version};
validate_shape(_) ->
    {error, invalid_envelope_shape}.

valid_kind_payload(task_start, start) -> true;
valid_kind_payload(effect_intent, effect_request) -> true;
valid_kind_payload(effect_result, effect_result) -> true;
valid_kind_payload(effect_denied, denial) -> true;
valid_kind_payload(cancel, cancellation) -> true;
valid_kind_payload(deadline, deadline) -> true;
valid_kind_payload(trace, trace) -> true;
valid_kind_payload(completion, completion) -> true;
valid_kind_payload(runtime_failure, runtime_failure) -> true;
valid_kind_payload(_, _) -> false.

valid_id(Value) ->
    is_binary(Value) andalso byte_size(Value) > 0 andalso byte_size(Value) =< ?MAX_ID_BYTES.

valid_origin({source, Byte, Line, Column}) ->
    is_integer(Byte) andalso Byte >= 0 andalso
        is_integer(Line) andalso Line >= 1 andalso
        is_integer(Column) andalso Column >= 1;
valid_origin(_) -> false.

bounded_term(Term) ->
    try erlang:external_size(Term) =< ?MAX_PAYLOAD_BYTES
    catch
        error:badarg -> false
    end.

validate_effect_context(#{
    session_id := SessionId,
    task_id := TaskId,
    gateway := Gateway,
    trace := Trace,
    deadline := TaskDeadline
}, Operation, Origin, RelativeDeadline) ->
    case {
        valid_id(SessionId),
        valid_id(TaskId),
        is_pid(Gateway),
        is_pid(Trace),
        is_integer(TaskDeadline),
        is_binary(Operation) andalso byte_size(Operation) > 0 andalso byte_size(Operation) =< 128,
        valid_origin(Origin),
        is_integer(RelativeDeadline) andalso RelativeDeadline > 0 andalso
            RelativeDeadline =< ?MAX_DEADLINE_MS
    } of
        {true, true, true, true, true, true, true, true} -> ok;
        _ -> {error, invalid_effect_context}
    end;
validate_effect_context(_, _, _, _) ->
    {error, invalid_effect_context}.

issue_effect(Context, Operation, Arguments, Origin, RelativeDeadline) ->
    Now = erlang:monotonic_time(millisecond),
    TaskDeadline = maps:get(deadline, Context),
    Deadline = min(TaskDeadline, Now + RelativeDeadline),
    CorrelationId = correlation_id(),
    Payload = {effect_request, #{operation => Operation, arguments => Arguments}},
    case new(
        effect_intent,
        maps:get(session_id, Context),
        maps:get(task_id, Context),
        CorrelationId,
        Deadline,
        Payload,
        self(),
        Origin
    ) of
        {ok, Envelope} ->
            trace(Context, effect_intent, CorrelationId, Operation),
            maps:get(gateway, Context) ! Envelope,
            await_effect(Context, CorrelationId, Deadline, Origin, 0);
        {error, Reason} -> tagged_error(reason_binary(Reason))
    end.

await_effect(Context, CorrelationId, Deadline, Origin, Skipped) when
    Skipped =< ?MAX_SKIPPED_MESSAGES
->
    Now = erlang:monotonic_time(millisecond),
    Timeout = max(0, Deadline - Now),
    receive
        Envelope ->
            case classify_effect_reply(Envelope, Context, CorrelationId) of
                {ok, Value} ->
                    trace(Context, effect_result, CorrelationId, accepted),
                    {alang_data_v1, ok, Value};
                {denied, Reason} ->
                    trace(Context, effect_denied, CorrelationId, Reason),
                    tagged_error(reason_binary(Reason));
                cancelled ->
                    trace(Context, cancel, CorrelationId, accepted),
                    tagged_error(<<"cancelled">>);
                stale ->
                    trace(Context, deadline, CorrelationId, stale_reply),
                    tagged_error(<<"deadline-exceeded">>);
                ignore ->
                    await_effect(Context, CorrelationId, Deadline, Origin, Skipped + 1)
            end
    after Timeout ->
        trace(Context, deadline, CorrelationId, expired),
        tagged_error(<<"deadline-exceeded">>)
    end;
await_effect(Context, CorrelationId, _Deadline, _Origin, _Skipped) ->
    trace(Context, runtime_failure, CorrelationId, mailbox_noise_limit),
    tagged_error(<<"protocol-message-limit">>).

classify_effect_reply(Envelope, Context, CorrelationId) ->
    Now = erlang:monotonic_time(millisecond),
    case validate_at(Envelope, Now) of
        ok -> classify_valid_reply(Envelope, Context, CorrelationId);
        {error, stale_message} ->
            case matching_envelope(Envelope, Context, CorrelationId) of
                true -> stale;
                false -> ignore
            end;
        {error, _} -> ignore
    end.

classify_valid_reply(
    {alang_envelope_v1, effect_result, _, _, CorrelationId, _, {effect_result, Value}, _, _} = Envelope,
    Context,
    CorrelationId
) ->
    case matching_envelope(Envelope, Context, CorrelationId) of
        true -> {ok, Value};
        false -> ignore
    end;
classify_valid_reply(
    {alang_envelope_v1, effect_denied, _, _, CorrelationId, _, {denial, Reason}, _, _} = Envelope,
    Context,
    CorrelationId
) ->
    case matching_envelope(Envelope, Context, CorrelationId) of
        true -> {denied, Reason};
        false -> ignore
    end;
classify_valid_reply(
    {alang_envelope_v1, cancel, _, _, _, _, {cancellation, _Reason}, _, _} = Envelope,
    Context,
    _CorrelationId
) ->
    case matching_task(Envelope, Context) of
        true -> cancelled;
        false -> ignore
    end;
classify_valid_reply(_Envelope, _Context, _CorrelationId) -> ignore.

matching_envelope(Envelope, Context, CorrelationId) ->
    element(3, Envelope) =:= maps:get(session_id, Context) andalso
        element(4, Envelope) =:= maps:get(task_id, Context) andalso
        element(5, Envelope) =:= CorrelationId.

matching_task(Envelope, Context) ->
    element(3, Envelope) =:= maps:get(session_id, Context) andalso
        element(4, Envelope) =:= maps:get(task_id, Context).

trace(Context, Kind, CorrelationId, Detail) ->
    Event = #{
        kind => Kind,
        correlation_id => CorrelationId,
        detail => Detail,
        monotonic_time => erlang:monotonic_time(millisecond)
    },
    _ = try alang_phase3_trace:record(maps:get(trace, Context), Event)
        catch
            _:_ -> {error, trace_unavailable}
        end,
    ok.

tagged_error(Reason) -> {alang_data_v1, error, Reason}.

reason_binary(Reason) when is_binary(Reason), byte_size(Reason) =< 256 -> Reason;
reason_binary(Reason) ->
    Binary = iolist_to_binary(io_lib:format("~tp", [Reason])),
    case byte_size(Binary) =< 256 of
        true -> Binary;
        false -> binary:part(Binary, 0, 256)
    end.

correlation_id() ->
    Integer = erlang:unique_integer([monotonic, positive]),
    <<"effect-", (integer_to_binary(Integer))/binary>>.
