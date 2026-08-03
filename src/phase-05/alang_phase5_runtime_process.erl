-module(alang_phase5_runtime_process).
-behaviour(gen_server).

-export([deliver/2, snapshot/1, start_link/4]).
-export([handle_call/3, handle_cast/2, handle_info/2, init/1, terminate/2]).

-define(MAX_MESSAGES, 128).
-define(MAX_EVENTS, 256).

-spec start_link(atom(), pos_integer(), binary(), map()) -> gen_server:start_ret().
start_link(Role, Generation, SessionId, State) ->
    gen_server:start_link(?MODULE, {Role, Generation, SessionId, State}, []).

-spec deliver(pid(), map()) -> {ok, atom()} | {error, atom()}.
deliver(Process, Envelope) -> gen_server:call(Process, {deliver, Envelope}, 2000).

-spec snapshot(pid()) -> map().
snapshot(Process) -> gen_server:call(Process, snapshot, 2000).

init({Role, Generation, SessionId, SessionState}) ->
    case valid_init(Role, Generation, SessionId, SessionState) of
        true ->
            Timer = erlang:start_timer(60000, self(), deadline_check),
            {ok, #{
                role => Role,
                generation => Generation,
                session_id => SessionId,
                semantic_state_digest => element(2, alang_phase5_state:checkpoint_digest(SessionState)),
                timer => Timer,
                accepted => #{},
                events => []
            }};
        false -> {stop, invalid_runtime_process_state}
    end.

handle_call({deliver, Envelope}, _From, State) ->
    {Reply, Updated} = handle_envelope(Envelope, State),
    {reply, Reply, Updated};
handle_call(snapshot, _From, State) ->
    {reply, #{
        format => alang_runtime_process_snapshot_v1,
        role => maps:get(role, State),
        pid => self(),
        generation => maps:get(generation, State),
        session_id => maps:get(session_id, State),
        semantic_state_digest => maps:get(semantic_state_digest, State),
        timer => maps:get(timer, State),
        accepted_count => map_size(maps:get(accepted, State)),
        events => lists:reverse(maps:get(events, State))
    }, State};
handle_call(_Request, _From, State) -> {reply, {error, unsupported_runtime_call}, State}.

handle_cast(_Message, State) -> {noreply, State}.

handle_info({timeout, Timer, deadline_check}, #{timer := Timer} = State) ->
    Next = erlang:start_timer(60000, self(), deadline_check),
    {noreply, add_event(deadline_check, undefined, State#{timer := Next})};
handle_info(_Message, State) -> {noreply, State}.

terminate(_Reason, State) ->
    _ = erlang:cancel_timer(maps:get(timer, State)),
    ok.

handle_envelope(Envelope, State) when is_map(Envelope) ->
    case decode_envelope(Envelope) of
        {ok, Generation, CorrelationId, PayloadDigest} ->
            Current = maps:get(generation, State),
            case Generation of
                Value when Value < Current ->
                    {{error, stale_generation}, add_event(stale, CorrelationId, State)};
                Value when Value > Current ->
                    {{error, future_generation}, add_event(future, CorrelationId, State)};
                Current -> deduplicate(CorrelationId, PayloadDigest, State)
            end;
        {error, Reason} -> {{error, Reason}, add_event(malformed, undefined, State)}
    end;
handle_envelope(_Envelope, State) -> {{error, invalid_envelope}, add_event(malformed, undefined, State)}.

deduplicate(CorrelationId, PayloadDigest, State) ->
    Accepted = maps:get(accepted, State),
    case maps:find(CorrelationId, Accepted) of
        error when map_size(Accepted) < ?MAX_MESSAGES ->
            {{ok, accepted}, add_event(accepted, CorrelationId,
                State#{accepted := Accepted#{CorrelationId => PayloadDigest}})};
        error -> {{error, inbox_full}, add_event(backpressure, CorrelationId, State)};
        {ok, PayloadDigest} -> {{ok, duplicate}, add_event(duplicate, CorrelationId, State)};
        {ok, _Different} -> {{error, correlation_conflict}, add_event(conflict, CorrelationId, State)}
    end.

decode_envelope(#{
    format := alang_runtime_envelope_v1,
    generation := Generation,
    correlation_id := CorrelationId,
    payload_digest := PayloadDigest,
    payload := Payload
} = Envelope) when map_size(Envelope) =:= 5, is_integer(Generation), Generation > 0 ->
    case valid_digest(CorrelationId) andalso valid_digest(PayloadDigest) andalso
        byte_size(term_to_binary(Payload, [deterministic])) =< 65536
    of
        true -> {ok, Generation, CorrelationId, PayloadDigest};
        false -> {error, invalid_envelope}
    end;
decode_envelope(_Envelope) -> {error, invalid_envelope}.

add_event(Kind, CorrelationId, State) ->
    Event = #{
        kind => Kind,
        correlation_id => CorrelationId,
        generation => maps:get(generation, State)
    },
    Events = maps:get(events, State),
    Updated = case length(Events) < ?MAX_EVENTS of
        true -> [Event | Events];
        false -> Events
    end,
    State#{events := Updated}.

valid_init(Role, Generation, SessionId, SessionState) ->
    lists:member(Role, [coordinator, inbox, trace]) andalso
        is_integer(Generation) andalso Generation > 0 andalso
        is_binary(SessionId) andalso byte_size(SessionId) > 0 andalso
        alang_phase5_state:validate(SessionState) =:= ok.

valid_digest(Value) when is_binary(Value), byte_size(Value) =:= 64 ->
    lists:all(fun is_hex/1, binary_to_list(Value));
valid_digest(_) -> false.

is_hex(Character) when Character >= $0, Character =< $9 -> true;
is_hex(Character) when Character >= $a, Character =< $f -> true;
is_hex(_) -> false.
