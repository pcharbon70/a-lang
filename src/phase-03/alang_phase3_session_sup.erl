-module(alang_phase3_session_sup).

-behaviour(supervisor).

-export([start_link/3, start_task/3, stop/1, topology/1]).
-export([init/1]).

-spec start_link(binary(), fun((binary(), term()) -> term()), map()) -> supervisor:startlink_ret().
start_link(SessionId, Handler, Limits) ->
    supervisor:start_link(?MODULE, {SessionId, Handler, Limits}).

-spec start_task(pid(), atom(), tuple()) -> {ok, pid()} | {error, term()}.
start_task(Supervisor, Module, StartEnvelope) when is_pid(Supervisor), is_atom(Module) ->
    Children = supervisor:which_children(Supervisor),
    case child_pid(task_worker, Children) of
        undefined -> start_task_child(Supervisor, Module, StartEnvelope, Children);
        _Pid -> {error, task_capacity_reached}
    end;
start_task(_, _, _) -> {error, invalid_task_start}.

-spec topology(pid()) -> {ok, map()} | {error, term()}.
topology(Supervisor) when is_pid(Supervisor) ->
    try supervisor:which_children(Supervisor) of
        Children -> {ok, maps:from_list([
            {Id, Pid}
         || {Id, Pid, worker, _Modules} <- Children,
            is_pid(Pid)
        ])}
    catch
        exit:Reason -> {error, {session_unavailable, Reason}}
    end;
topology(_) -> {error, invalid_session_supervisor}.

-spec stop(pid()) -> ok | {error, term()}.
stop(Supervisor) when is_pid(Supervisor) ->
    try gen_server:stop(Supervisor, normal, 1000) of
        ok -> ok
    catch
        exit:Reason -> {error, {session_stop_failed, Reason}}
    end;
stop(_) -> {error, invalid_session_supervisor}.

init({SessionId, Handler, Limits}) ->
    Trace = #{
        id => trace_collector,
        start => {alang_phase3_trace, start_link, [maps:get(max_trace_events, Limits)]},
        restart => permanent,
        shutdown => 1000,
        type => worker,
        modules => [alang_phase3_trace]
    },
    Gateway = #{
        id => effect_gateway,
        start => {alang_phase3_effect_gateway, start_link, [SessionId, Handler, Limits]},
        restart => permanent,
        shutdown => 1000,
        type => worker,
        modules => [alang_phase3_effect_gateway]
    },
    {ok, {{rest_for_one, 1, 5}, [Trace, Gateway]}}.

start_task_child(Supervisor, Module, StartEnvelope, Children) ->
    Gateway = child_pid(effect_gateway, Children),
    Trace = child_pid(trace_collector, Children),
    case is_pid(Gateway) andalso is_pid(Trace) of
        true ->
            Configuration = #{
                module => Module,
                start_envelope => StartEnvelope,
                gateway => Gateway,
                trace => Trace
            },
            Child = #{
                id => task_worker,
                start => {alang_phase3_task_worker, start_link, [Configuration]},
                restart => temporary,
                shutdown => 1000,
                type => worker,
                modules => [alang_phase3_task_worker]
            },
            supervisor:start_child(Supervisor, Child);
        false -> {error, session_components_unavailable}
    end.

child_pid(Id, Children) ->
    case lists:keyfind(Id, 1, Children) of
        {Id, Pid, worker, _Modules} -> Pid;
        false -> undefined
    end.
