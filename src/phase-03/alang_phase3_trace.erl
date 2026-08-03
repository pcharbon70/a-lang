-module(alang_phase3_trace).

-behaviour(gen_server).

-export([record/2, snapshot/1, start_link/1]).
-export([handle_call/3, handle_cast/2, handle_info/2, init/1, terminate/2]).

-define(MAX_EVENT_BYTES, 4096).

-spec start_link(pos_integer()) -> gen_server:start_ret().
start_link(MaxEvents) ->
    gen_server:start_link(?MODULE, MaxEvents, []).

-spec record(pid(), map()) -> ok | {error, term()}.
record(Pid, Event) when is_pid(Pid), is_map(Event) ->
    gen_server:call(Pid, {record, Event}, 1000);
record(_Pid, _Event) ->
    {error, invalid_trace_event}.

-spec snapshot(pid()) -> {ok, [map()]} | {error, term()}.
snapshot(Pid) when is_pid(Pid) ->
    try gen_server:call(Pid, snapshot, 1000) of
        Events -> {ok, Events}
    catch
        exit:Reason -> {error, {trace_unavailable, Reason}}
    end;
snapshot(_) ->
    {error, invalid_trace_collector}.

init(MaxEvents) when is_integer(MaxEvents), MaxEvents > 0, MaxEvents =< 1024 ->
    {ok, #{max => MaxEvents, count => 0, events => [], dropped => 0}};
init(_) ->
    {stop, invalid_trace_limit}.

handle_call({record, Event}, _From, #{count := Count, max := Max} = State) ->
    case valid_event(Event) of
        false -> {reply, {error, invalid_trace_event}, State};
        true when Count >= Max ->
            {reply, {error, trace_full}, State#{dropped := maps:get(dropped, State) + 1}};
        true ->
            {reply, ok, State#{count := Count + 1, events := [Event | maps:get(events, State)]}}
    end;
handle_call(snapshot, _From, State) ->
    Events = lists:reverse(maps:get(events, State)),
    Summary = #{kind => trace_summary, dropped => maps:get(dropped, State)},
    {reply, Events ++ [Summary], State};
handle_call(_Request, _From, State) ->
    {reply, {error, unsupported_trace_request}, State}.

handle_cast(_Message, State) -> {noreply, State}.
handle_info(_Message, State) -> {noreply, State}.
terminate(_Reason, _State) -> ok.

valid_event(#{kind := Kind, monotonic_time := Time} = Event) when
    is_atom(Kind), is_integer(Time)
->
    lists:member(Kind, [
        task_start,
        effect_intent,
        effect_result,
        effect_denied,
        cancel,
        deadline,
        completion,
        runtime_failure
    ]) andalso bounded(Event);
valid_event(_) -> false.

bounded(Event) ->
    try erlang:external_size(Event) =< ?MAX_EVENT_BYTES
    catch
        error:badarg -> false
    end.
