-module(alang_phase6_child_sup).
-behaviour(supervisor).

-export([start_child/4, start_link/0, stop/1]).
-export([init/1]).

-spec start_link() -> supervisor:startlink_ret().
start_link() -> supervisor:start_link(?MODULE, []).

-spec start_child(pid(), pid(), map(), function()) -> supervisor:startchild_ret().
start_child(Supervisor, Parent, Spec, Handler) ->
    supervisor:start_child(Supervisor, #{
        id => {alang_phase6_child_worker, make_ref()},
        start => {alang_phase6_child_worker, start_link, [Parent, Spec, Handler]},
        restart => temporary,
        shutdown => 1000,
        type => worker,
        modules => [alang_phase6_child_worker]
    }).

-spec stop(pid()) -> ok.
stop(Supervisor) ->
    unlink(Supervisor),
    exit(Supervisor, shutdown),
    ok.

init([]) ->
    {ok, {#{strategy => one_for_one, intensity => 4, period => 10}, []}}.
