-module(alang_phase3_task_worker).

-behaviour(gen_server).

-export([start_link/1]).
-export([handle_call/3, handle_cast/2, handle_continue/2, handle_info/2, init/1, terminate/2]).

-spec start_link(map()) -> gen_server:start_ret().
start_link(Configuration) ->
    gen_server:start_link(?MODULE, Configuration, []).

init(#{
    module := Module,
    start_envelope := StartEnvelope,
    gateway := Gateway,
    trace := Trace
} = Configuration) when is_atom(Module), is_pid(Gateway), is_pid(Trace) ->
    case alang_phase3_abi:validate_at(StartEnvelope, erlang:monotonic_time(millisecond)) of
        ok when element(2, StartEnvelope) =:= task_start ->
            {ok, Configuration, {continue, execute}};
        {error, Reason} -> {stop, {invalid_task_start, Reason}};
        ok -> {stop, invalid_task_start_kind}
    end;
init(_) ->
    {stop, invalid_task_configuration}.

handle_continue(execute, State) ->
    trace(State, task_start, accepted),
    Result = execute(State),
    deliver(Result, State),
    {stop, normal, State}.

handle_call(_Request, _From, State) ->
    {reply, {error, task_is_not_callable}, State}.

handle_cast(_Message, State) -> {noreply, State}.
handle_info(_Message, State) -> {noreply, State}.
terminate(_Reason, _State) -> ok.

execute(State) ->
    StartEnvelope = maps:get(start_envelope, State),
    Deadline = element(6, StartEnvelope),
    case erlang:monotonic_time(millisecond) >= Deadline of
        true -> {runtime_failure, <<"task-deadline-exceeded">>};
        false -> execute_module(State, Deadline)
    end.

execute_module(State, Deadline) ->
    StartEnvelope = maps:get(start_envelope, State),
    Module = maps:get(module, State),
    TaskId = element(4, StartEnvelope),
    {start, Inputs} = element(7, StartEnvelope),
    Context = #{
        session_id => element(3, StartEnvelope),
        task_id => TaskId,
        gateway => maps:get(gateway, State),
        trace => maps:get(trace, State),
        deadline => Deadline
    },
    try Module:execute(TaskId, Inputs, Context) of
        {alang_runtime_v1, complete, Value} ->
            case erlang:monotonic_time(millisecond) =< Deadline of
                true -> {completion, Value};
                false -> {runtime_failure, <<"task-deadline-exceeded">>}
            end;
        {alang_runtime_v1, error, Reason} -> {runtime_failure, bounded_reason(Reason)};
        Other -> {runtime_failure, bounded_reason({invalid_runtime_result, Other})}
    catch
        Class:Reason -> {runtime_failure, bounded_reason({task_exception, Class, Reason})}
    end.

deliver({Kind, Value}, State) ->
    StartEnvelope = maps:get(start_envelope, State),
    EnvelopeKind = case Kind of
        completion -> completion;
        runtime_failure -> runtime_failure
    end,
    Payload = {EnvelopeKind, Value},
    case alang_phase3_abi:new(
        EnvelopeKind,
        element(3, StartEnvelope),
        element(4, StartEnvelope),
        element(5, StartEnvelope),
        max(element(6, StartEnvelope), erlang:monotonic_time(millisecond) + 100),
        Payload,
        self(),
        element(9, StartEnvelope)
    ) of
        {ok, Envelope} ->
            trace(State, EnvelopeKind, Value),
            element(8, StartEnvelope) ! Envelope;
        {error, Reason} ->
            element(8, StartEnvelope) ! {task_delivery_failed, bounded_reason(Reason)}
    end.

trace(State, Kind, Detail) ->
    Event = #{
        kind => Kind,
        detail => bounded_reason(Detail),
        monotonic_time => erlang:monotonic_time(millisecond)
    },
    _ = try alang_phase3_trace:record(maps:get(trace, State), Event)
        catch
            _:_ -> {error, trace_unavailable}
        end,
    ok.

bounded_reason(Reason) when is_binary(Reason), byte_size(Reason) =< 512 -> Reason;
bounded_reason(Reason) ->
    Binary = iolist_to_binary(io_lib:format("~tp", [Reason])),
    case byte_size(Binary) =< 512 of
        true -> Binary;
        false -> binary:part(Binary, 0, 512)
    end.
