-module(alang_phase6_child_worker).
-behaviour(gen_server).

-export([assign/5, begin_execution/1, cancel/2, start_link/3]).
-export([handle_call/3, handle_cast/2, handle_info/2, init/1, terminate/2]).

-spec start_link(pid(), map(), function()) -> gen_server:start_ret().
start_link(Parent, Spec, Handler) ->
    gen_server:start_link(?MODULE, {Parent, Spec, Handler}, []).

-spec assign(pid(), binary(), reference(), term(), map()) -> ok | {error, atom()}.
assign(Worker, CorrelationId, ReplyFence, Grant, Context) ->
    gen_server:call(Worker, {assign, CorrelationId, ReplyFence, Grant, Context}, 2000).

-spec begin_execution(pid()) -> ok | {error, atom()}.
begin_execution(Worker) -> gen_server:call(Worker, begin_execution, 2000).

-spec cancel(pid(), binary()) -> ok.
cancel(Worker, CorrelationId) -> gen_server:cast(Worker, {cancel, CorrelationId}).

init({Parent, Spec, Handler}) when is_pid(Parent), is_function(Handler, 3) ->
    case alang_phase6_child:validate_spec(Spec) of
        ok ->
            Remaining = max(1, maps:get(deadline, Spec) - erlang:monotonic_time(millisecond)),
            Timer = erlang:send_after(Remaining, self(), child_deadline),
            {ok, #{parent => Parent, spec => Spec, handler => Handler, phase => waiting,
                correlation_id => none, reply_fence => none, grant => none, context => none,
                executor => none, timer => Timer}};
        {error, Reason} -> {stop, Reason}
    end;
init(_Arguments) -> {stop, invalid_child_worker_arguments}.

handle_call({assign, CorrelationId, ReplyFence, Grant, Context}, _From,
    #{phase := waiting, spec := Spec} = State) ->
    case is_reference(ReplyFence) andalso valid_assignment(CorrelationId, Context, Spec) of
        true -> {reply, ok, State#{phase := assigned, correlation_id := CorrelationId,
            reply_fence := ReplyFence, grant := Grant, context := Context}};
        false -> {reply, {error, invalid_child_assignment}, State}
    end;
handle_call({assign, _CorrelationId, _ReplyFence, _Grant, _Context}, _From, State) ->
    {reply, {error, child_already_assigned}, State};
handle_call(begin_execution, _From, #{phase := assigned, handler := Handler, spec := Spec,
    grant := Grant, context := Context} = State) ->
    Worker = self(),
    {Executor, Monitor} = spawn_monitor(fun() ->
        Result = safe_execute(Handler, Spec, Grant, Context),
        Worker ! {child_execution_result, self(), Result}
    end),
    {reply, ok, State#{phase := running, executor := {Executor, Monitor}}};
handle_call(begin_execution, _From, State) ->
    {reply, {error, child_not_assigned}, State};
handle_call(_Request, _From, State) -> {reply, {error, unsupported_child_call}, State}.

handle_cast({cancel, CorrelationId}, #{correlation_id := CorrelationId} = State) ->
    stop_executor(State),
    reply_and_stop(cancelled, cancelled, State);
handle_cast({cancel, _WrongCorrelation}, State) -> {noreply, State};
handle_cast(_Message, State) -> {noreply, State}.

handle_info({child_execution_result, Executor, Result},
    #{phase := running, executor := {Executor, Monitor}, spec := Spec} = State) ->
    erlang:demonitor(Monitor, [flush]),
    case alang_phase6_child:validate_result(Spec, Result) of
        ok -> reply_and_stop(Result, State);
        {error, _} -> reply_and_stop(failed, invalid_child_result, State)
    end;
handle_info({'DOWN', Monitor, process, Executor, Reason},
    #{phase := running, executor := {Executor, Monitor}} = State) ->
    reply_and_stop(failed, bounded_reason(Reason), State);
handle_info(child_deadline, State) ->
    stop_executor(State),
    reply_and_stop(incomplete, deadline_exhausted, State);
handle_info(_Message, State) -> {noreply, State}.

terminate(_Reason, State) ->
    _ = erlang:cancel_timer(maps:get(timer, State)),
    stop_executor(State),
    ok.

safe_execute(Handler, Spec, Grant, Context) ->
    try Handler(Spec, Grant, Context) of
        Result -> Result
    catch
        _Class:_Reason -> #{format => alang_child_result_v1, status => failed,
            reason => handler_exception}
    end.

reply_and_stop(Result, State) when is_map(Result) ->
    Parent = maps:get(parent, State),
    Spec = maps:get(spec, State),
    Envelope = #{
        format => alang_child_reply_v1,
        parent_task_id => maps:get(parent_task_id, Spec),
        child_task_id => maps:get(child_task_id, Spec),
        session_id => maps:get(session_id, Spec),
        correlation_id => maps:get(correlation_id, State),
        result => Result
    },
    Parent ! {alang_child_reply_v1, self(), maps:get(reply_fence, State), Envelope},
    {stop, normal, State#{phase := terminal, executor := none}}.
reply_and_stop(Status, Reason, State) ->
    reply_and_stop(#{format => alang_child_result_v1, status => Status, reason => Reason}, State).

valid_assignment(CorrelationId, Context, Spec) when is_binary(CorrelationId),
    byte_size(CorrelationId) > 0, byte_size(CorrelationId) =< 128, is_map(Context) ->
    ExpectedKeys = lists:sort([node, runtime_instance, generation, session_id,
        artifact_digest, owner_pid, task_id, presenter_pid, request_deadline,
        cancelled, correlation_id]),
    lists:sort(maps:keys(Context)) =:= ExpectedKeys andalso
        maps:get(session_id, Context) =:= maps:get(session_id, Spec) andalso
        maps:get(artifact_digest, Context) =:= maps:get(artifact_digest, Spec) andalso
        maps:get(owner_pid, Context) =:= self() andalso
        maps:get(task_id, Context) =:= maps:get(child_task_id, Spec) andalso
        maps:get(presenter_pid, Context) =:= self() andalso
        maps:get(request_deadline, Context) =< maps:get(deadline, Spec) andalso
        maps:get(cancelled, Context) =:= false andalso
        maps:get(correlation_id, Context) =:= CorrelationId;
valid_assignment(_CorrelationId, _Context, _Spec) -> false.

stop_executor(#{executor := {Executor, Monitor}}) ->
    erlang:demonitor(Monitor, [flush]),
    exit(Executor, kill),
    ok;
stop_executor(_State) -> ok.

bounded_reason(normal) -> child_terminated;
bounded_reason(killed) -> child_terminated;
bounded_reason(_Reason) -> child_terminated.
