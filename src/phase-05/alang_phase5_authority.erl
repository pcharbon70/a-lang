-module(alang_phase5_authority).

-export([restore/5, validate_descriptor/1]).

-spec restore(pid(), map(), pid(), integer(), integer()) -> {ok, map()} | {error, tuple()}.
restore(Broker, State, Owner, NowUtc, NowMonotonic) when
    is_pid(Broker), is_map(State), is_pid(Owner), is_integer(NowUtc), is_integer(NowMonotonic)
->
    Authority = maps:get(authority, State, []),
    Revocations = maps:get(revocations, State, []),
    restore_descriptors(Authority, Revocations, Broker, State, Owner, NowUtc,
        NowMonotonic, #{}, []);
restore(_Broker, _State, _Owner, _NowUtc, _NowMonotonic) ->
    {error, {authority_recovery_failed, invalid_restore_input}}.

-spec validate_descriptor(term()) -> ok | {error, atom()}.
validate_descriptor(Descriptor) when is_map(Descriptor), map_size(Descriptor) =:= 6 ->
    Keys = [grant_id, invocations, budgets, expires_at, task_id, combination],
    case lists:sort(maps:keys(Descriptor)) =:= lists:sort(Keys) andalso
        valid_digest(maps:get(grant_id, Descriptor, undefined)) andalso
        valid_invocations(maps:get(invocations, Descriptor, invalid)) andalso
        valid_budgets(maps:get(budgets, Descriptor, invalid),
            maps:get(invocations, Descriptor, [])) andalso
        is_integer(maps:get(expires_at, Descriptor, invalid)) andalso
        maps:get(expires_at, Descriptor) >= 0 andalso
        valid_id(maps:get(task_id, Descriptor, undefined)) andalso
        lists:member(maps:get(combination, Descriptor, invalid), [deny, intersect])
    of
        true -> ok;
        false -> {error, invalid_authority_descriptor}
    end;
validate_descriptor(_Descriptor) -> {error, invalid_authority_descriptor}.

restore_descriptors([], _Revocations, Broker, _State, _Owner, _NowUtc, _NowMonotonic,
    References, Decisions) ->
    {ok, #{
        format => alang_recovered_authority_v1,
        runtime_context => alang_phase4_broker:runtime_context(Broker),
        references => References,
        decisions => lists:reverse(Decisions)
    }};
restore_descriptors([Descriptor | Rest], Revocations, Broker, State, Owner, NowUtc,
    NowMonotonic, References, Decisions) ->
    case validate_descriptor(Descriptor) of
        ok ->
            GrantId = maps:get(grant_id, Descriptor),
            case classify_descriptor(Descriptor, Revocations, NowUtc) of
                {skip, Reason} -> restore_descriptors(Rest, Revocations, Broker, State, Owner,
                    NowUtc, NowMonotonic, References,
                    [#{grant_id => GrantId, decision => skipped, reason => Reason} | Decisions]);
                {issue, Invocations, Budgets, RemainingMs} ->
                    Spec = #{
                        invocations => Invocations,
                        budgets => Budgets,
                        deadline => NowMonotonic + erlang:min(RemainingMs, 86400000),
                        owner_pid => Owner,
                        session_id => maps:get(session_id, State),
                        artifact_digest => maps:get(artifact_digest, maps:get(program, State)),
                        task_id => maps:get(task_id, Descriptor),
                        combination => maps:get(combination, Descriptor)
                    },
                    case alang_phase4_broker:issue_grant(Broker, Spec) of
                        {ok, Reference} ->
                            case verify_restored_grant(Broker, Reference, Invocations, Budgets) of
                                ok -> restore_descriptors(Rest, Revocations, Broker, State, Owner,
                                    NowUtc, NowMonotonic, References#{GrantId => Reference},
                                    [#{grant_id => GrantId, decision => issued} | Decisions]);
                                {error, Reason} ->
                                    {error, {authority_recovery_failed, Reason}}
                            end;
                        {error, Reason} -> {error, {authority_recovery_failed, Reason}}
                    end
            end;
        {error, Reason} -> {error, {authority_recovery_failed, Reason}}
    end.

classify_descriptor(Descriptor, Revocations, NowUtc) ->
    GrantId = maps:get(grant_id, Descriptor),
    ExpiresAt = maps:get(expires_at, Descriptor),
    case {lists:member(GrantId, Revocations), ExpiresAt =< NowUtc} of
        {true, _} -> {skip, revoked};
        {_, true} -> {skip, expired};
        {false, false} ->
            Budgets0 = maps:get(budgets, Descriptor),
            PositiveOperations = [Operation || {Operation, Budget} <- maps:to_list(Budgets0),
                Budget > 0],
            Invocations = [Invocation || #{operation := Operation} = Invocation <-
                maps:get(invocations, Descriptor), lists:member(Operation, PositiveOperations)],
            Budgets = maps:with(PositiveOperations, Budgets0),
            case Invocations of
                [] -> {skip, exhausted};
                _ -> {issue, Invocations, Budgets, ExpiresAt - NowUtc}
            end
    end.

verify_restored_grant(Broker, Reference, DurableInvocations, DurableBudgets) ->
    case alang_phase4_broker:describe_grant(Broker, Reference) of
        {ok, Description} ->
            Invocations = maps:get(invocations, Description),
            Budgets = maps:get(remaining_budgets, Description),
            case alang_phase4_grants:authority_subset(Invocations, DurableInvocations) andalso
                budgets_no_greater(Budgets, DurableBudgets)
            of
                true -> ok;
                false -> {error, recovered_authority_widened}
            end;
        {error, Reason} -> {error, Reason}
    end.

budgets_no_greater(Recovered, Durable) ->
    maps:fold(fun(Operation, Budget, Acc) ->
        Acc andalso Budget =< maps:get(Operation, Durable, -1)
    end, true, Recovered).

valid_invocations(Invocations) when is_list(Invocations), Invocations =/= [],
    length(Invocations) =< 32 ->
    lists:all(fun valid_invocation/1, Invocations);
valid_invocations(_) -> false.

valid_invocation(#{operation := <<"workspace.write">>, workspace_id := WorkspaceId,
    path_prefix := Prefix} = Invocation) when map_size(Invocation) =:= 3 ->
    valid_id(WorkspaceId) andalso valid_segments(Prefix);
valid_invocation(#{operation := <<"model.complete">>, model_id := ModelId} = Invocation) when
    map_size(Invocation) =:= 2
-> valid_id(ModelId);
valid_invocation(_Invocation) -> false.

valid_budgets(Budgets, Invocations) when is_map(Budgets) ->
    Operations = lists:usort([maps:get(operation, Invocation) || Invocation <- Invocations]),
    lists:sort(maps:keys(Budgets)) =:= lists:sort(Operations) andalso
        lists:all(fun(Budget) -> is_integer(Budget) andalso Budget >= 0 andalso Budget =< 1000000 end,
            maps:values(Budgets));
valid_budgets(_Budgets, _Invocations) -> false.

valid_segments(Segments) when is_list(Segments), length(Segments) =< 32 ->
    lists:all(fun(Segment) ->
        valid_id(Segment) andalso Segment =/= <<".">> andalso Segment =/= <<"..">> andalso
            Segment =/= <<".alang-operations">> andalso
            binary:match(Segment, <<"/">>) =:= nomatch andalso
            binary:match(Segment, <<"\\">>) =:= nomatch andalso
            binary:match(Segment, <<0>>) =:= nomatch
    end, Segments);
valid_segments(_) -> false.

valid_id(Value) -> is_binary(Value) andalso byte_size(Value) > 0 andalso byte_size(Value) =< 128.

valid_digest(Value) when is_binary(Value), byte_size(Value) =:= 64 ->
    lists:all(fun is_hex/1, binary_to_list(Value));
valid_digest(_) -> false.

is_hex(Character) when Character >= $0, Character =< $9 -> true;
is_hex(Character) when Character >= $a, Character =< $f -> true;
is_hex(_) -> false.
