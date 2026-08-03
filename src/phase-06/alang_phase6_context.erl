-module(alang_phase6_context).

-export([contains_prohibited/1, slice/2]).

-define(MAX_CANDIDATES, 128).
-define(MAX_FRAGMENT_BYTES, 32768).
-define(MAX_DEPTH, 24).

-spec slice(map(), map()) -> {ok, map()} | {error, atom()}.
slice(#{
    goal := Goal,
    inputs := Inputs,
    actions := Actions,
    evidence := Evidence,
    diagnostics := Diagnostics
} = Spec, #{max_context_bytes := MaxBytes, max_fragments := MaxFragments}) when
    map_size(Spec) =:= 5,
    is_list(Inputs),
    is_list(Actions),
    is_list(Evidence),
    is_list(Diagnostics),
    is_integer(MaxBytes), MaxBytes > 0, MaxBytes =< 65536,
    is_integer(MaxFragments), MaxFragments > 0, MaxFragments =< 32
->
    Candidates = [Goal | Inputs ++ Evidence ++ Diagnostics],
    case length(Candidates) =< ?MAX_CANDIDATES andalso length(Actions) =< 32 of
        true -> select(Candidates, Actions, MaxBytes, MaxFragments);
        false -> {error, context_candidate_limit}
    end;
slice(_Spec, _Limits) -> {error, invalid_context_specification}.

-spec contains_prohibited(term()) -> boolean().
contains_prohibited(Value) -> contains_prohibited(Value, 0).

select(Candidates, Actions, MaxBytes, MaxFragments) ->
    case select_candidates(Candidates, [], [], []) of
        {ok, Selected0, Excluded, SeenIds} ->
            case action_fragments(Actions, SeenIds) of
                {ok, ActionFragments} ->
                    Selected = Selected0 ++ ActionFragments,
                    finish_slice(Selected, Excluded, MaxBytes, MaxFragments);
                {error, _} = Error -> Error
            end;
        {error, _} = Error -> Error
    end.

select_candidates([], Selected, Excluded, SeenIds) ->
    {ok, lists:reverse(Selected), lists:reverse(Excluded), SeenIds};
select_candidates([Candidate | Rest], Selected, Excluded, SeenIds) ->
    case classify_candidate(Candidate, SeenIds) of
        {include, Fragment, Id} ->
            select_candidates(Rest, [Fragment | Selected], Excluded, [Id | SeenIds]);
        {exclude, Id, Reason} ->
            select_candidates(Rest, Selected, [#{id => Id, reason => Reason} | Excluded], SeenIds);
        {error, _} = Error -> Error
    end.

classify_candidate(#{
    id := Id,
    kind := Kind,
    visibility := Visibility,
    provenance := Provenance,
    trust := Trust,
    content := Content
} = Candidate, SeenIds) when map_size(Candidate) =:= 6 ->
    case {
        valid_id(Id),
        lists:member(Id, SeenIds),
        lists:member(Kind, [goal, input, evidence, diagnostic, retrieved]),
        lists:member(Visibility, [public, task_local, private]),
        valid_digest(Provenance),
        lists:member(Trust, [instruction, data_only]),
        is_binary(Content) andalso byte_size(Content) =< ?MAX_FRAGMENT_BYTES,
        contains_prohibited(Content),
        Kind =:= retrieved andalso Trust =:= instruction
    } of
        {false, _, _, _, _, _, _, _, _} -> {error, invalid_context_candidate};
        {_, true, _, _, _, _, _, _, _} -> {error, duplicate_context_id};
        {_, _, false, _, _, _, _, _, _} -> {error, invalid_context_candidate};
        {_, _, _, false, _, _, _, _, _} -> {error, invalid_context_candidate};
        {_, _, _, _, false, _, _, _, _} -> {error, invalid_context_candidate};
        {_, _, _, _, _, false, _, _, _} -> {error, invalid_context_candidate};
        {_, _, _, _, _, _, false, _, _} -> {error, invalid_context_candidate};
        {_, _, _, _, _, _, _, true, _} -> {error, prohibited_context_material};
        {_, _, _, _, _, _, _, _, true} -> {exclude, Id, retrieved_instruction_forbidden};
        {true, false, true, true, true, true, true, false, false} ->
            case Visibility of
                private -> {exclude, Id, private_visibility};
                _ -> {include, fragment(Id, Visibility, Provenance, Trust, Content), Id}
            end
    end;
classify_candidate(_Candidate, _SeenIds) -> {error, invalid_context_candidate}.

action_fragments(Actions, SeenIds) -> action_fragments(Actions, SeenIds, []).

action_fragments([], _SeenIds, Acc) -> {ok, lists:reverse(Acc)};
action_fragments([#{
    operation := Operation,
    requirement := Requirement,
    constraints := Constraints
} = Action | Rest], SeenIds, Acc) when map_size(Action) =:= 3, is_list(Constraints) ->
    Id = <<"action:", Operation/binary>>,
    case valid_id(Operation) andalso valid_id(Id) andalso valid_id(Requirement) andalso
        length(Constraints) =< 16 andalso
        lists:all(fun valid_constraint/1, Constraints) andalso
        not lists:member(Id, SeenIds) andalso not contains_prohibited(Action)
    of
        true ->
            Content = iolist_to_binary([
                <<"operation=">>, Operation,
                <<"; requirement=">>, Requirement,
                <<"; constraints=">>, join(Constraints)
            ]),
            Provenance = digest({allowed_action, Operation, Requirement, Constraints}),
            Fragment = fragment(Id, task_local, Provenance, data_only, Content),
            action_fragments(Rest, [Id | SeenIds], [Fragment | Acc]);
        false -> {error, invalid_action_summary}
    end;
action_fragments(_Actions, _SeenIds, _Acc) -> {error, invalid_action_summary}.

finish_slice(Fragments, Excluded, MaxBytes, MaxFragments) ->
    Bytes = lists:sum([byte_size(maps:get(content, Fragment)) || Fragment <- Fragments]),
    case length(Fragments) =< MaxFragments andalso Bytes =< MaxBytes of
        true ->
            Digests = [digest(Fragment) || Fragment <- Fragments],
            {ok, #{
                format => alang_context_slice_v1,
                fragments => Fragments,
                snapshot => #{
                    format => alang_context_snapshot_v1,
                    selected_ids => [maps:get(id, Fragment) || Fragment <- Fragments],
                    selected_digests => Digests,
                    excluded => Excluded,
                    total_bytes => Bytes,
                    fragment_count => length(Fragments),
                    slice_digest => digest(Digests)
                }
            }};
        false -> {error, context_slice_too_large}
    end.

fragment(Id, Visibility, Provenance, Trust, Content) -> #{
    format => alang_context_fragment_v1,
    id => Id,
    visibility => Visibility,
    provenance => Provenance,
    trust => Trust,
    content => Content
}.

contains_prohibited(_Value, Depth) when Depth > ?MAX_DEPTH -> true;
contains_prohibited(Value, _Depth) when is_pid(Value); is_port(Value); is_reference(Value);
    is_function(Value) -> true;
contains_prohibited(Value, _Depth) when is_binary(Value); is_number(Value); is_atom(Value) -> false;
contains_prohibited([], _Depth) -> false;
contains_prohibited(Value, Depth) when is_list(Value) ->
    lists:any(fun(Item) -> contains_prohibited(Item, Depth + 1) end, Value);
contains_prohibited(Value, Depth) when is_tuple(Value) ->
    contains_prohibited(tuple_to_list(Value), Depth + 1);
contains_prohibited(Value, Depth) when is_map(Value) ->
    ProhibitedKeys = [capability_reference, broker_state, credential, credentials,
        private_state, proof, runtime_address, secret, token],
    lists:any(fun(Key) -> lists:member(Key, ProhibitedKeys) end, maps:keys(Value)) orelse
        maps:fold(fun(Key, Item, Found) -> Found orelse
            contains_prohibited(Key, Depth + 1) orelse contains_prohibited(Item, Depth + 1)
        end, false, Value);
contains_prohibited(_Value, _Depth) -> true.

join([]) -> <<"none">>;
join([First | Rest]) -> lists:foldl(fun(Item, Acc) -> <<Acc/binary, ",", Item/binary>> end,
    First, Rest).

valid_constraint(Value) -> is_binary(Value) andalso byte_size(Value) > 0 andalso byte_size(Value) =< 256.
valid_id(Value) -> is_binary(Value) andalso byte_size(Value) > 0 andalso byte_size(Value) =< 128.
valid_digest(Value) when is_binary(Value), byte_size(Value) =:= 64 ->
    lists:all(fun is_hex/1, binary_to_list(Value));
valid_digest(_Value) -> false.

digest(Term) -> hex(crypto:hash(sha256, term_to_binary(Term, [deterministic]))).
is_hex(Character) when Character >= $0, Character =< $9 -> true;
is_hex(Character) when Character >= $a, Character =< $f -> true;
is_hex(_Character) -> false.
hex(Binary) -> << <<(hex_digit(Nibble))>> || <<Nibble:4>> <= Binary >>.
hex_digit(Nibble) when Nibble < 10 -> $0 + Nibble;
hex_digit(Nibble) -> $a + Nibble - 10.
