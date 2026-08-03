-module(alang_phase5_session_sup).
-behaviour(supervisor).

-export([start_link/1, stop/1, topology/1]).
-export([init/1]).

-spec start_link(map()) -> supervisor:startlink_ret().
start_link(Options) -> supervisor:start_link(?MODULE, Options).

-spec stop(pid()) -> ok.
stop(Supervisor) ->
    unlink(Supervisor),
    exit(Supervisor, shutdown),
    ok.

-spec topology(pid()) -> {ok, map()} | {error, atom()}.
topology(Supervisor) ->
    Children = supervisor:which_children(Supervisor),
    case child_map(Children) of
        {ok, Map} ->
            BrokerSupervisor = maps:get(broker_supervisor, Map),
            case alang_phase4_broker_sup:broker(BrokerSupervisor) of
                {ok, Broker} ->
                    {ok, Map#{
                        broker => Broker,
                        adapter_status => alang_phase4_broker:adapter_status(Broker)
                    }};
                {error, _} -> {error, broker_unavailable}
            end;
        {error, _} = Error -> Error
    end.

init(#{
    recovery := #{state := State, generation := Generation},
    store_options := StoreOptions,
    broker_options := BrokerOptions
}) ->
    SessionId = maps:get(session_id, State),
    Children = [
        child(durable_store, alang_phase5_store, start_link, [StoreOptions], worker),
        child(broker_supervisor, alang_phase4_broker_sup, start_link, [BrokerOptions], supervisor),
        child(coordinator, alang_phase5_runtime_process, start_link,
            [coordinator, Generation, SessionId, State], worker),
        child(inbox, alang_phase5_runtime_process, start_link,
            [inbox, Generation, SessionId, State], worker),
        child(trace, alang_phase5_runtime_process, start_link,
            [trace, Generation, SessionId, State], worker)
    ],
    {ok, {#{strategy => one_for_all, intensity => 3, period => 10}, Children}};
init(_Options) -> {stop, invalid_session_supervisor_options}.

child(Id, Module, Function, Arguments, Type) -> #{
    id => Id,
    start => {Module, Function, Arguments},
    restart => permanent,
    shutdown => 5000,
    type => Type,
    modules => [Module]
}.

child_map(Children) ->
    Required = [durable_store, broker_supervisor, coordinator, inbox, trace],
    Map = maps:from_list([{Id, Pid} || {Id, Pid, _Type, _Modules} <- Children, is_pid(Pid)]),
    case lists:all(fun(Id) -> maps:is_key(Id, Map) end, Required) of
        true -> {ok, Map};
        false -> {error, incomplete_runtime_topology}
    end.
