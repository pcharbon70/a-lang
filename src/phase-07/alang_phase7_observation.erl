-module(alang_phase7_observation).

-export([
    equivalent/2,
    manifest_union/2,
    normalize/1,
    reference/1,
    runtime/1,
    trace/1
]).

-spec normalize(term()) -> term().
normalize(Term) ->
    {Normalized, _State} = normalize(Term, #{next => 1, identities => #{}}),
    Normalized.

-spec equivalent(term(), term()) -> boolean().
equivalent(Left, Right) -> normalize(Left) =:= normalize(Right).

-spec manifest_union(map(), map()) -> map().
manifest_union(Left, Right) -> #{
    effects => lists:usort(maps:get(effects, Left, []) ++ maps:get(effects, Right, [])),
    requirements => lists:usort(
        maps:get(requirements, Left, []) ++ maps:get(requirements, Right, []))
}.

-spec reference(map()) -> map().
reference(#{result := Result, completion := Completion, effects := Effects}) -> #{
    result => normalize(Result),
    completion => Completion,
    effects => [maps:get(operation, Effect) || Effect <- Effects]
}.

-spec runtime(map()) -> map().
runtime(#{value := Value, trace := Trace}) -> #{
    result => normalize(Value),
    completion => true,
    effects => [maps:get(detail, Event) || #{kind := effect_intent} = Event <- Trace]
}.

-spec trace([term()]) -> [term()].
trace(Events) when is_list(Events) ->
    normalize([strip_ephemeral(Event) || Event <- Events]).

strip_ephemeral(Event) when is_map(Event) ->
    maps:without([at, timestamp, pid, owner_pid, requester_pid, presenter_pid,
        correlation_id], Event);
strip_ephemeral(Event) -> Event.

normalize(Term, State) when is_pid(Term); is_reference(Term); is_port(Term) ->
    Identities = maps:get(identities, State),
    case maps:find(Term, Identities) of
        {ok, Name} -> {Name, State};
        error ->
            Next = maps:get(next, State),
            Kind = identity_kind(Term),
            Name = {alang_fresh_identity, Kind, Next},
            {Name, State#{next := Next + 1, identities := Identities#{Term => Name}}}
    end;
normalize(Map, State) when is_map(Map) ->
    normalize_map(lists:sort(maps:to_list(Map)), State, []);
normalize(Tuple, State) when is_tuple(Tuple) ->
    {Items, Next} = normalize_list(tuple_to_list(Tuple), State, []),
    {list_to_tuple(Items), Next};
normalize(List, State) when is_list(List) -> normalize_list(List, State, []);
normalize(Term, State) -> {Term, State}.

normalize_map([], State, Acc) -> {maps:from_list(lists:reverse(Acc)), State};
normalize_map([{Key, Value} | Rest], State0, Acc) ->
    {NormalizedKey, State1} = normalize(Key, State0),
    {NormalizedValue, State2} = normalize(Value, State1),
    normalize_map(Rest, State2, [{NormalizedKey, NormalizedValue} | Acc]).

normalize_list([], State, Acc) -> {lists:reverse(Acc), State};
normalize_list([Item | Rest], State0, Acc) ->
    {Normalized, State1} = normalize(Item, State0),
    normalize_list(Rest, State1, [Normalized | Acc]);
normalize_list(Improper, State0, Acc) ->
    {Tail, State1} = normalize(Improper, State0),
    {lists:reverse(Acc, Tail), State1}.

identity_kind(Term) when is_pid(Term) -> pid;
identity_kind(Term) when is_reference(Term) -> reference;
identity_kind(Term) when is_port(Term) -> port.
