-module(alang_phase3_effect_gateway).

-behaviour(gen_server).

-export([start_link/3]).
-export([handle_call/3, handle_cast/2, handle_info/2, init/1, terminate/2]).

-spec start_link(binary(), function(), map()) -> gen_server:start_ret().
start_link(SessionId, Handler, Limits) ->
    gen_server:start_link(?MODULE, {SessionId, Handler, Limits}, []).

init({SessionId, Handler, #{max_in_flight := MaxInFlight, max_mailbox := MaxMailbox}}) when
    is_binary(SessionId),
    (is_function(Handler, 2) orelse is_function(Handler, 3)),
    is_integer(MaxInFlight),
    MaxInFlight > 0,
    MaxInFlight =< 32,
    is_integer(MaxMailbox),
    MaxMailbox > 0,
    MaxMailbox =< 1024
->
    {ok, #{
        session_id => SessionId,
        handler => Handler,
        max_in_flight => MaxInFlight,
        max_mailbox => MaxMailbox,
        in_flight => #{}
    }};
init(_) ->
    {stop, invalid_gateway_configuration}.

handle_call(_Request, _From, State) ->
    {reply, {error, unsupported_gateway_call}, State}.

handle_cast(_Message, State) -> {noreply, State}.

handle_info({alang_envelope_v1, effect_intent, _, _, _, _, _, _, _} = Envelope, State) ->
    {noreply, admit_effect(Envelope, State)};
handle_info({alang_envelope_v1, cancel, _, _, _, _, _, _, _} = Envelope, State) ->
    {noreply, cancel_effects(Envelope, State)};
handle_info({effect_finished, Worker, CorrelationId, Outcome}, State) ->
    {noreply, finish_effect(Worker, CorrelationId, Outcome, State)};
handle_info({'DOWN', Monitor, process, Worker, Reason}, State) ->
    {noreply, effect_down(Monitor, Worker, Reason, State)};
handle_info(_Malformed, State) ->
    {noreply, State}.

terminate(_Reason, #{in_flight := InFlight}) ->
    maps:foreach(
        fun(_Correlation, #{worker := Worker}) -> exit(Worker, shutdown) end,
        InFlight
    ),
    ok.

admit_effect(Envelope, State) ->
    Now = erlang:monotonic_time(millisecond),
    case alang_phase3_abi:validate_at(Envelope, Now) of
        ok -> admit_valid_effect(Envelope, State);
        {error, stale_message} -> deny(Envelope, <<"deadline-exceeded">>), State;
        {error, _} -> State
    end.

admit_valid_effect(Envelope, #{session_id := SessionId} = State) when
    element(3, Envelope) =/= SessionId
->
    State;
admit_valid_effect(Envelope, State) ->
    InFlight = maps:get(in_flight, State),
    QueueLength = message_queue_length(),
    case {
        maps:size(InFlight) < maps:get(max_in_flight, State),
        QueueLength < maps:get(max_mailbox, State)
    } of
        {false, _} -> deny(Envelope, <<"gateway-in-flight-limit">>), State;
        {_, false} -> deny(Envelope, <<"gateway-mailbox-limit">>), State;
        {true, true} -> start_effect(Envelope, State)
    end.

start_effect(
    {alang_envelope_v1, effect_intent, _, _, CorrelationId, _,
        {effect_request, #{operation := Operation, arguments := Arguments}}, _, _} = Envelope,
    State
) when is_binary(Operation) ->
    Parent = self(),
    Handler = maps:get(handler, State),
    HandlerContext = handler_context(Envelope, Parent),
    {Worker, Monitor} = spawn_monitor(fun() ->
        Outcome = invoke_handler(Handler, Operation, Arguments, HandlerContext),
        Parent ! {effect_finished, self(), CorrelationId, Outcome}
    end),
    Entry = #{worker => Worker, monitor => Monitor, envelope => Envelope},
    State#{in_flight := maps:put(CorrelationId, Entry, maps:get(in_flight, State))};
start_effect(Envelope, State) ->
    deny(Envelope, <<"invalid-effect-request">>),
    State.

invoke_handler(Handler, Operation, Arguments, Context) ->
    try call_handler(Handler, Operation, Arguments, Context) of
        {ok, Value} -> {ok, Value};
        {error, Reason} -> {error, bounded_reason(Reason)};
        _ -> {error, <<"invalid-handler-result">>}
    catch
        _Class:_Reason -> {error, <<"effect-handler-failed">>}
    end.

call_handler(Handler, Operation, Arguments, Context) when is_function(Handler, 3) ->
    Handler(Operation, Arguments, Context);
call_handler(Handler, Operation, Arguments, _Context) ->
    Handler(Operation, Arguments).

handler_context(Envelope, Gateway) ->
    #{
        session_id => element(3, Envelope),
        task_id => element(4, Envelope),
        correlation_id => element(5, Envelope),
        deadline => element(6, Envelope),
        requester_pid => element(8, Envelope),
        origin => element(9, Envelope),
        gateway_pid => Gateway
    }.

finish_effect(Worker, CorrelationId, Outcome, State) ->
    InFlight = maps:get(in_flight, State),
    case maps:take(CorrelationId, InFlight) of
        {#{worker := Worker, monitor := Monitor, envelope := Envelope}, Rest} ->
            erlang:demonitor(Monitor, [flush]),
            reply(Envelope, Outcome),
            State#{in_flight := Rest};
        _ -> State
    end.

effect_down(Monitor, Worker, Reason, State) ->
    InFlight = maps:get(in_flight, State),
    case find_by_monitor(Monitor, Worker, maps:to_list(InFlight)) of
        {ok, CorrelationId, #{envelope := Envelope}} ->
            deny(Envelope, bounded_reason({effect_worker_down, Reason})),
            State#{in_flight := maps:remove(CorrelationId, InFlight)};
        error -> State
    end.

cancel_effects(Envelope, #{session_id := SessionId} = State) ->
    Now = erlang:monotonic_time(millisecond),
    case alang_phase3_abi:validate_at(Envelope, Now) of
        ok when element(3, Envelope) =:= SessionId ->
            TaskId = element(4, Envelope),
            InFlight = maps:get(in_flight, State),
            Remaining = maps:fold(
                fun(CorrelationId, Entry, Acc) ->
                    Request = maps:get(envelope, Entry),
                    case element(4, Request) =:= TaskId of
                        true ->
                            exit(maps:get(worker, Entry), shutdown),
                            erlang:demonitor(maps:get(monitor, Entry), [flush]),
                            deny(Request, <<"cancelled">>),
                            Acc;
                        false -> maps:put(CorrelationId, Entry, Acc)
                    end
                end,
                #{},
                InFlight
            ),
            State#{in_flight := Remaining};
        _ -> State
    end.

reply(Envelope, {ok, Value}) -> send_reply(Envelope, effect_result, {effect_result, Value});
reply(Envelope, {error, Reason}) -> deny(Envelope, Reason).

deny(Envelope, Reason) -> send_reply(Envelope, effect_denied, {denial, bounded_reason(Reason)}).

send_reply(Envelope, Kind, Payload) ->
    SessionId = element(3, Envelope),
    TaskId = element(4, Envelope),
    CorrelationId = element(5, Envelope),
    Deadline = element(6, Envelope),
    ReplyTo = element(8, Envelope),
    Origin = element(9, Envelope),
    case alang_phase3_abi:new(
        Kind,
        SessionId,
        TaskId,
        CorrelationId,
        Deadline,
        Payload,
        self(),
        Origin
    ) of
        {ok, Reply} -> ReplyTo ! Reply;
        {error, _} -> ok
    end.

find_by_monitor(_Monitor, _Worker, []) -> error;
find_by_monitor(Monitor, Worker, [{CorrelationId, #{monitor := Monitor, worker := Worker} = Entry} | _]) ->
    {ok, CorrelationId, Entry};
find_by_monitor(Monitor, Worker, [_ | Rest]) -> find_by_monitor(Monitor, Worker, Rest).

bounded_reason(Reason) when is_binary(Reason), byte_size(Reason) =< 256 -> Reason;
bounded_reason(Reason) ->
    Binary = iolist_to_binary(io_lib:format("~tp", [Reason])),
    case byte_size(Binary) =< 256 of
        true -> Binary;
        false -> binary:part(Binary, 0, 256)
    end.

message_queue_length() ->
    case process_info(self(), message_queue_len) of
        {message_queue_len, Length} -> Length;
        undefined -> 0
    end.
