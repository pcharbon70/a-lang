-module(alang_phase3_launcher).

-export([run/4]).

-define(DEFAULT_ORIGIN, {source, 0, 1, 1}).

-spec run(atom(), binary(), map(), map()) -> {ok, map()} | {error, map()}.
run(Module, TaskId, Inputs, Options) when is_atom(Module), is_binary(TaskId), is_map(Inputs), is_map(Options) ->
    case validate_options(Options) of
        {ok, Limits, Handler, Timeout, SessionId} ->
            run_session(Module, TaskId, Inputs, Limits, Handler, Timeout, SessionId);
        {error, Reason} -> {error, #{reason => Reason, trace => []}}
    end;
run(_Module, _TaskId, _Inputs, _Options) ->
    {error, #{reason => invalid_launch_request, trace => []}}.

validate_options(#{
    handler := Handler,
    timeout := Timeout,
    max_in_flight := MaxInFlight,
    max_mailbox := MaxMailbox,
    max_trace_events := MaxTraceEvents
} = Options) when
    (is_function(Handler, 2) orelse is_function(Handler, 3)),
    is_integer(Timeout), Timeout > 0, Timeout =< 60000,
    is_integer(MaxInFlight), MaxInFlight > 0, MaxInFlight =< 32,
    is_integer(MaxMailbox), MaxMailbox > 0, MaxMailbox =< 1024,
    is_integer(MaxTraceEvents), MaxTraceEvents > 0, MaxTraceEvents =< 1024
->
    case requested_session_id(maps:get(session_id, Options, automatic)) of
        {ok, SessionId} -> {ok, #{
            max_in_flight => MaxInFlight,
            max_mailbox => MaxMailbox,
            max_trace_events => MaxTraceEvents
        }, Handler, Timeout, SessionId};
        {error, _} = Error -> Error
    end;
validate_options(_) -> {error, invalid_runtime_limits}.

run_session(Module, TaskId, Inputs, Limits, Handler, Timeout, SessionId) ->
    PreviousTrap = process_flag(trap_exit, true),
    Deadline = erlang:monotonic_time(millisecond) + Timeout,
    try alang_phase3_session_sup:start_link(SessionId, Handler, Limits) of
        {ok, Supervisor} ->
            run_started_session(
                Supervisor,
                Module,
                SessionId,
                TaskId,
                Inputs,
                Deadline,
                PreviousTrap
            );
        {error, Reason} ->
            process_flag(trap_exit, PreviousTrap),
            {error, #{reason => {session_start_failed, Reason}, trace => []}}
    catch
        Class:Reason ->
            process_flag(trap_exit, PreviousTrap),
            {error, #{reason => {launcher_exception, Class, Reason}, trace => []}}
    end.

run_started_session(Supervisor, Module, SessionId, TaskId, Inputs, Deadline, PreviousTrap) ->
    try start_and_wait(Supervisor, Module, SessionId, TaskId, Inputs, Deadline) of
        Result -> Result
    catch
        Class:Reason -> {error, #{reason => {session_exception, Class, Reason}, trace => []}}
    after
        _ = alang_phase3_session_sup:stop(Supervisor),
        flush_exit(Supervisor),
        process_flag(trap_exit, PreviousTrap)
    end.

start_and_wait(Supervisor, Module, SessionId, TaskId, Inputs, Deadline) ->
    {ok, StartEnvelope} = alang_phase3_abi:new(
        task_start,
        SessionId,
        TaskId,
        <<"task">>,
        Deadline,
        {start, Inputs},
        self(),
        ?DEFAULT_ORIGIN
    ),
    case alang_phase3_session_sup:start_task(Supervisor, Module, StartEnvelope) of
        {ok, Worker} ->
            Monitor = erlang:monitor(process, Worker),
            await_task(Supervisor, Worker, Monitor, SessionId, TaskId, Deadline);
        {error, Reason} ->
            finish(Supervisor, {error, {task_start_failed, Reason}})
    end.

await_task(Supervisor, Worker, Monitor, SessionId, TaskId, Deadline) ->
    Timeout = max(0, Deadline - erlang:monotonic_time(millisecond)),
    receive
        {alang_envelope_v1, completion, SessionId, TaskId, <<"task">>, _, {completion, Value}, _, _} = Envelope ->
            case alang_phase3_abi:validate_at(Envelope, erlang:monotonic_time(millisecond)) of
                ok -> erlang:demonitor(Monitor, [flush]), finish(Supervisor, {ok, Value});
                {error, stale_message} -> cancel_and_finish(Supervisor, Worker, SessionId, TaskId, Deadline);
                {error, Reason} -> finish(Supervisor, {error, {invalid_completion, Reason}})
            end;
        {alang_envelope_v1, runtime_failure, SessionId, TaskId, <<"task">>, _,
            {runtime_failure, Reason}, _, _} = Envelope ->
            case alang_phase3_abi:validate(Envelope) of
                ok -> erlang:demonitor(Monitor, [flush]), finish(Supervisor, {error, Reason});
                {error, Invalid} -> finish(Supervisor, {error, {invalid_runtime_failure, Invalid}})
            end;
        {'DOWN', Monitor, process, Worker, Reason} ->
            finish(Supervisor, {error, {task_worker_down, Reason}});
        {'EXIT', Supervisor, Reason} ->
            {error, #{reason => {session_supervisor_down, Reason}, trace => []}}
    after Timeout ->
        erlang:demonitor(Monitor, [flush]),
        cancel_and_finish(Supervisor, Worker, SessionId, TaskId, Deadline)
    end.

cancel_and_finish(Supervisor, Worker, SessionId, TaskId, _ExpiredDeadline) ->
    CancellationDeadline = erlang:monotonic_time(millisecond) + 1000,
    {ok, Cancellation} = alang_phase3_abi:new(
        cancel,
        SessionId,
        TaskId,
        <<"task">>,
        CancellationDeadline,
        {cancellation, <<"launcher-timeout">>},
        self(),
        ?DEFAULT_ORIGIN
    ),
    Worker ! Cancellation,
    case alang_phase3_session_sup:topology(Supervisor) of
        {ok, #{effect_gateway := Gateway}} -> Gateway ! Cancellation;
        _ -> ok
    end,
    finish(Supervisor, {error, <<"task-deadline-exceeded">>}).

finish(Supervisor, Outcome) ->
    Trace = case alang_phase3_session_sup:topology(Supervisor) of
        {ok, #{trace_collector := TraceCollector}} ->
            case alang_phase3_trace:snapshot(TraceCollector) of
                {ok, Events} -> Events;
                {error, _} -> []
            end;
        _ -> []
    end,
    case Outcome of
        {ok, Value} -> {ok, #{value => Value, trace => Trace}};
        {error, Reason} -> {error, #{reason => Reason, trace => Trace}}
    end.

session_id() ->
    Integer = erlang:unique_integer([monotonic, positive]),
    <<"session-", (integer_to_binary(Integer))/binary>>.

requested_session_id(automatic) -> {ok, session_id()};
requested_session_id(SessionId) when
    is_binary(SessionId),
    byte_size(SessionId) > 0,
    byte_size(SessionId) =< 256
-> {ok, SessionId};
requested_session_id(_) -> {error, invalid_session_id}.

flush_exit(Supervisor) ->
    receive
        {'EXIT', Supervisor, _Reason} -> ok
    after 0 -> ok
    end.
