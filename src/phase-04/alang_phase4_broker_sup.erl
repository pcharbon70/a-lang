-module(alang_phase4_broker_sup).

-behaviour(supervisor).

-export([broker/1, start_link/1, stop/1]).
-export([init/1]).

-spec start_link(map()) -> supervisor:startlink_ret().
start_link(Options) -> supervisor:start_link(?MODULE, Options).

-spec broker(pid()) -> {ok, pid()} | {error, broker_unavailable}.
broker(Supervisor) ->
    case [Pid || {broker, Pid, worker, _Modules} <- supervisor:which_children(Supervisor), is_pid(Pid)] of
        [Pid] -> {ok, Pid};
        [] -> {error, broker_unavailable}
    end.

-spec stop(pid()) -> ok.
stop(Supervisor) ->
    unlink(Supervisor),
    exit(Supervisor, shutdown),
    ok.

init(Options) ->
    Broker = #{
        id => broker,
        start => {alang_phase4_broker, start_link, [Options]},
        restart => permanent,
        shutdown => 5000,
        type => worker,
        modules => [alang_phase4_broker]
    },
    {ok, {#{strategy => one_for_one, intensity => 5, period => 10}, [Broker]}}.
