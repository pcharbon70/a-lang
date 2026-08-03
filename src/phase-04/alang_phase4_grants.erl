-module(alang_phase4_grants).

-export([
    allows/2,
    authority_subset/2,
    combine/4,
    consume/3,
    describe/2,
    issue/3,
    new_store/1,
    remaining/3,
    remove_owner/2,
    resolve/4,
    resolve_bound/3,
    restrict/4,
    restrict_for_child/6,
    revoke/2,
    runtime_context/1
]).

-define(GRANT_TYPE, <<"capability:local-grant">>).
-define(MAX_GRANTS, 1024).
-define(MAX_INVOCATIONS, 32).
-define(MAX_BUDGET, 1000000).
-define(MAX_ID_BYTES, 128).

-spec new_store(pos_integer()) -> map().
new_store(Generation) when is_integer(Generation), Generation > 0 ->
    #{
        format => alang_grant_store_v1,
        node => node(),
        runtime_instance => make_ref(),
        generation => Generation,
        grants => #{},
        budget_pools => #{}
    }.

-spec runtime_context(map()) -> map().
runtime_context(Store) ->
    maps:with([node, runtime_instance, generation], Store).

-spec issue(map(), map(), integer()) -> {ok, tuple(), map()} | {error, atom()}.
issue(#{format := alang_grant_store_v1, grants := Grants} = Store, Spec, Now) when
    is_integer(Now),
    map_size(Grants) < ?MAX_GRANTS
->
    case validate_spec(Spec, Now) of
        {ok, Normalized} -> issue_root(Store, Normalized);
        {error, _} = Error -> Error
    end;
issue(#{format := alang_grant_store_v1}, _Spec, _Now) -> {error, grant_limit};
issue(_Store, _Spec, _Now) -> {error, invalid_grant_store}.

-spec restrict(map(), term(), map(), integer()) -> {ok, tuple(), map()} | {error, atom()}.
restrict(Store, Opaque, Restriction, Now) when is_integer(Now) ->
    case lookup_active(Store, Opaque, Now) of
        {ok, #{delegation := restrictable} = Parent} ->
            restrict_parent(Store, Parent, Restriction, Now);
        {ok, _Parent} -> {error, delegation_denied};
        {error, _} = Error -> Error
    end;
restrict(_Store, _Opaque, _Restriction, _Now) -> {error, invalid_clock}.

-spec restrict_for_child(map(), term(), map(), map(), pid(), integer()) ->
    {ok, tuple(), map()} | {error, atom()}.
restrict_for_child(Store, Opaque, Restriction, Binding, Issuer, Now) when
    is_pid(Issuer), is_integer(Now)
->
    case lookup_active(Store, Opaque, Now) of
        {ok, #{delegation := restrictable, owner_pid := Issuer} = Parent} ->
            restrict_child_parent(Store, Parent, Restriction, Binding, Now);
        {ok, #{delegation := deny}} -> {error, delegation_denied};
        {ok, _Parent} -> {error, parent_owner_mismatch};
        {error, _} = Error -> Error
    end;
restrict_for_child(_Store, _Opaque, _Restriction, _Binding, _Issuer, _Now) ->
    {error, invalid_child_restriction}.

-spec combine(map(), term(), term(), integer()) -> {ok, tuple(), map()} | {error, atom()}.
combine(Store, LeftOpaque, RightOpaque, Now) when is_integer(Now) ->
    case {lookup_active(Store, LeftOpaque, Now), lookup_active(Store, RightOpaque, Now)} of
        {{ok, Left}, {ok, Right}} -> combine_active(Store, Left, Right);
        {{error, _} = Error, _} -> Error;
        {_, {error, _} = Error} -> Error
    end;
combine(_Store, _Left, _Right, _Now) -> {error, invalid_clock}.

-spec revoke(map(), term()) -> {ok, non_neg_integer(), map()} | {error, atom()}.
revoke(#{format := alang_grant_store_v1, grants := Grants} = Store, Opaque) ->
    case opaque_reference(Opaque) of
        {ok, Reference} ->
            case maps:is_key(Reference, Grants) of
                true ->
                    {Count, Revoked} = maps:fold(
                        fun(GrantReference, Grant, {AccCount, Acc}) ->
                            case GrantReference =:= Reference orelse
                                lists:member(Reference, maps:get(ancestors, Grant))
                            of
                                true -> {AccCount + 1, Acc#{GrantReference => Grant#{status := revoked}}};
                                false -> {AccCount, Acc#{GrantReference => Grant}}
                            end
                        end,
                        {0, #{}},
                        Grants
                    ),
                    {ok, Count, Store#{grants := Revoked}};
                false -> {error, unknown_grant}
            end;
        error -> {error, unknown_grant}
    end;
revoke(_Store, _Opaque) -> {error, invalid_grant_store}.

-spec remove_owner(map(), pid()) -> {non_neg_integer(), map()}.
remove_owner(#{format := alang_grant_store_v1, grants := Grants} = Store, Owner) when is_pid(Owner) ->
    {Removed, Remaining} = maps:fold(
        fun(Reference, #{owner_pid := GrantOwner} = Grant, {Count, Acc}) ->
            case GrantOwner =:= Owner of
                true -> {Count + 1, Acc};
                false -> {Count, Acc#{Reference => Grant}}
            end
        end,
        {0, #{}},
        Grants
    ),
    {Removed, cleanup_pools(Store#{grants := Remaining})};
remove_owner(Store, _Owner) -> {0, Store}.

-spec resolve(map(), term(), map(), integer()) ->
    {ok, map(), map()} | {error, atom(), map()}.
resolve(#{format := alang_grant_store_v1} = Store, Opaque, Context, Now) when
    is_map(Context),
    is_integer(Now)
->
    case opaque_reference(Opaque) of
        {ok, Reference} -> resolve_reference(Store, Reference, Context, Now);
        error -> {error, unknown_grant, Store}
    end;
resolve(Store, _Opaque, _Context, _Now) -> {error, unknown_grant, Store}.

-spec resolve_bound(map(), term(), map()) ->
    {ok, map(), map()} | {error, atom(), map()}.
resolve_bound(#{format := alang_grant_store_v1, grants := Grants} = Store, Opaque, Context) when
    is_map(Context)
->
    case opaque_reference(Opaque) of
        {ok, Reference} ->
            case maps:find(Reference, Grants) of
                error -> {error, unknown_grant, Store};
                {ok, #{status := revoked}} -> {error, revoked_grant, Store};
                {ok, Grant} -> resolve_binding(Store, Reference, Grant, Context)
            end;
        error -> {error, unknown_grant, Store}
    end;
resolve_bound(Store, _Opaque, _Context) -> {error, unknown_grant, Store}.

-spec allows(map(), map()) -> boolean().
allows(#{invocations := Invocations}, #{operation := Operation, resource := Resource}) ->
    lists:any(fun(Invocation) -> invocation_allows(Invocation, Operation, Resource) end, Invocations);
allows(_Grant, _DecodedRequest) -> false.

-spec consume(map(), term(), binary()) -> {ok, non_neg_integer(), map()} | {error, atom()}.
consume(#{format := alang_grant_store_v1, grants := Grants} = Store, Opaque, Operation) when
    is_binary(Operation)
->
    case opaque_reference(Opaque) of
        {ok, Reference} ->
            case maps:find(Reference, Grants) of
                {ok, #{status := active} = Grant} -> consume_grant(Store, Reference, Grant, Operation);
                {ok, _Grant} -> {error, revoked_grant};
                error -> {error, unknown_grant}
            end;
        error -> {error, unknown_grant}
    end;
consume(_Store, _Opaque, _Operation) -> {error, invalid_grant_store}.

-spec remaining(map(), term(), binary()) -> {ok, non_neg_integer()} | {error, atom()}.
remaining(#{format := alang_grant_store_v1, grants := Grants} = Store, Opaque, Operation) when
    is_binary(Operation)
->
    case opaque_reference(Opaque) of
        {ok, Reference} ->
            case maps:find(Reference, Grants) of
                {ok, #{status := active} = Grant} ->
                    case maps:is_key(Operation, maps:get(budgets, Grant)) of
                        true -> {ok, effective_budget(Store, Grant, Operation)};
                        false -> {error, scope_mismatch}
                    end;
                {ok, _Grant} -> {error, revoked_grant};
                error -> {error, unknown_grant}
            end;
        error -> {error, unknown_grant}
    end;
remaining(_Store, _Opaque, _Operation) -> {error, invalid_grant_store}.

-spec describe(map(), term()) -> {ok, map()} | {error, atom()}.
describe(#{format := alang_grant_store_v1, grants := Grants} = Store, Opaque) ->
    case opaque_reference(Opaque) of
        {ok, Reference} ->
            case maps:find(Reference, Grants) of
                {ok, Grant} -> {ok, public_grant(Store, Grant)};
                error -> {error, unknown_grant}
            end;
        error -> {error, unknown_grant}
    end;
describe(_Store, _Opaque) -> {error, invalid_grant_store}.

-spec authority_subset([map()], [map()]) -> boolean().
authority_subset(Children, Parents) when is_list(Children), is_list(Parents) ->
    lists:all(
        fun(Child) -> lists:any(fun(Parent) -> invocation_subset(Child, Parent) end, Parents) end,
        Children
    );
authority_subset(_Children, _Parents) -> false.

issue_root(Store, Spec) ->
    Operations = operation_set(maps:get(invocations, Spec)),
    {PoolBindings, Pools} = lists:foldl(
        fun(Operation, {Bindings, AccPools}) ->
            Pool = make_ref(),
            Budget = maps:get(Operation, maps:get(budgets, Spec)),
            {Bindings#{Operation => [Pool]}, AccPools#{Pool => Budget}}
        end,
        {#{}, maps:get(budget_pools, Store)},
        Operations
    ),
    insert_grant(Store#{budget_pools := Pools}, Spec#{
        ancestors => [],
        budget_pools => PoolBindings,
        delegation => restrictable,
        presenter_pid => undefined,
        status => active
    }).

restrict_parent(Store, Parent, Restriction, Now) when is_map(Restriction) ->
    case normalize_restriction(Restriction, Parent, Store, Now) of
        {ok, Narrowed} ->
            ParentReference = maps:get(reference, Parent),
            insert_grant(Store, Narrowed#{
                ancestors => lists:usort([ParentReference | maps:get(ancestors, Parent)]),
                budget_pools => maps:with(operation_set(maps:get(invocations, Narrowed)),
                    maps:get(budget_pools, Parent)),
                delegation => restrictable,
                presenter_pid => maps:get(presenter_pid, Parent),
                status => active
            });
        {error, _} = Error -> Error
    end;
restrict_parent(_Store, _Parent, _Restriction, _Now) -> {error, invalid_restriction}.

restrict_child_parent(Store, Parent, Restriction, Binding, Now) when is_map(Binding) ->
    case {normalize_restriction(Restriction, Parent, Store, Now),
        validate_child_binding(Binding, Parent)} of
        {{ok, Narrowed}, ok} ->
            ParentReference = maps:get(reference, Parent),
            Operations = operation_set(maps:get(invocations, Narrowed)),
            insert_grant(Store, Narrowed#{
                owner_pid := maps:get(owner_pid, Binding),
                session_id := maps:get(session_id, Binding),
                artifact_digest := maps:get(artifact_digest, Binding),
                task_id := maps:get(task_id, Binding),
                combination := deny,
                ancestors => lists:usort([ParentReference | maps:get(ancestors, Parent)]),
                budget_pools => maps:with(Operations, maps:get(budget_pools, Parent)),
                delegation => deny,
                presenter_pid => undefined,
                status => active
            });
        {{error, _} = Error, _} -> Error;
        {_, {error, _} = Error} -> Error
    end;
restrict_child_parent(_Store, _Parent, _Restriction, _Binding, _Now) ->
    {error, invalid_child_binding}.

validate_child_binding(Binding, Parent) ->
    Expected = lists:sort([owner_pid, session_id, artifact_digest, task_id]),
    case lists:sort(maps:keys(Binding)) =:= Expected andalso
        is_pid(maps:get(owner_pid, Binding, undefined)) andalso
        erlang:is_process_alive(maps:get(owner_pid, Binding, undefined)) andalso
        valid_id(maps:get(session_id, Binding, invalid)) andalso
        valid_digest(maps:get(artifact_digest, Binding, invalid)) andalso
        valid_id(maps:get(task_id, Binding, invalid))
    of
        false -> {error, invalid_child_binding};
        true ->
            case maps:get(owner_pid, Binding) =/= maps:get(owner_pid, Parent) andalso
                maps:get(session_id, Binding) =/= maps:get(session_id, Parent) andalso
                maps:get(task_id, Binding) =/= maps:get(task_id, Parent)
            of
                true -> ok;
                false -> {error, child_binding_not_fresh}
            end
    end.

normalize_restriction(Restriction, Parent, Store, Now) ->
    ExpectedKeys = lists:sort([invocations, budgets, deadline]),
    case lists:sort(maps:keys(Restriction)) =:= ExpectedKeys of
        false -> {error, invalid_restriction};
        true ->
            Invocations = maps:get(invocations, Restriction),
            Budgets = maps:get(budgets, Restriction),
            Deadline = maps:get(deadline, Restriction),
            case {
                normalize_invocations(Invocations),
                valid_budgets(Budgets, operation_set(Invocations)),
                is_integer(Deadline) andalso Deadline > Now andalso Deadline =< maps:get(deadline, Parent)
            } of
                {{ok, Normalized}, true, true} ->
                    case authority_subset(Normalized, maps:get(invocations, Parent)) andalso
                        budgets_within(Budgets, Parent, Store)
                    of
                        true -> {ok, inherited_spec(Parent, Normalized, Budgets, Deadline)};
                        false -> {error, authority_widening}
                    end;
                {{error, _}, _, _} -> {error, invalid_invocations};
                {_, false, _} -> {error, invalid_budgets};
                {_, _, false} -> {error, invalid_deadline}
            end
    end.

combine_active(Store, Left, Right) ->
    case {
        maps:get(combination, Left),
        maps:get(combination, Right),
        same_binding(Left, Right)
    } of
        {intersect, intersect, true} -> combine_intersection(Store, Left, Right);
        {deny, _, _} -> {error, combination_denied};
        {_, deny, _} -> {error, combination_denied};
        {_, _, false} -> {error, binding_mismatch}
    end.

combine_intersection(Store, Left, Right) ->
    Invocations = invocation_intersection(
        maps:get(invocations, Left),
        maps:get(invocations, Right)
    ),
    case Invocations of
        [] -> {error, no_common_authority};
        _ ->
            Operations = operation_set(Invocations),
            Budgets = maps:from_list([
                {Operation, min(
                    effective_budget(Store, Left, Operation),
                    effective_budget(Store, Right, Operation)
                )}
             || Operation <- Operations
            ]),
            case lists:any(fun(Budget) -> Budget =< 0 end, maps:values(Budgets)) of
                true -> {error, exhausted_budget};
                false ->
                    Pools = maps:from_list([
                        {Operation, lists:usort(
                            maps:get(Operation, maps:get(budget_pools, Left)) ++
                                maps:get(Operation, maps:get(budget_pools, Right))
                        )}
                     || Operation <- Operations
                    ]),
                    Ancestors = lists:usort([
                        maps:get(reference, Left), maps:get(reference, Right)
                        | maps:get(ancestors, Left) ++ maps:get(ancestors, Right)
                    ]),
                    insert_grant(Store, (inherited_spec(
                        Left,
                        Invocations,
                        Budgets,
                        min(maps:get(deadline, Left), maps:get(deadline, Right))
                    ))#{
                        ancestors => Ancestors,
                        budget_pools => Pools,
                        delegation => restrictable,
                        presenter_pid => maps:get(presenter_pid, Left),
                        status => active
                    })
            end
    end.

insert_grant(#{grants := Grants} = Store, Grant0) when map_size(Grants) < ?MAX_GRANTS ->
    Reference = make_ref(),
    RedactedId = redacted_id(maps:get(runtime_instance, Store), Reference),
    Grant = Grant0#{reference => Reference, redacted_id => RedactedId},
    Opaque = {alang_opaque_v1, ?GRANT_TYPE, Reference},
    {ok, Opaque, Store#{grants := Grants#{Reference => Grant}}};
insert_grant(_Store, _Grant) -> {error, grant_limit}.

validate_spec(Spec, Now) when is_map(Spec), map_size(Spec) =:= 8 ->
    case lists:sort(maps:keys(Spec)) =:= lists:sort([
        invocations,
        budgets,
        deadline,
        owner_pid,
        session_id,
        artifact_digest,
        task_id,
        combination
    ]) of
        false -> {error, invalid_grant_spec};
        true -> validate_spec_values(Spec, Now)
    end;
validate_spec(_Spec, _Now) -> {error, invalid_grant_spec}.

validate_spec_values(Spec, Now) ->
    Invocations = maps:get(invocations, Spec),
    Budgets = maps:get(budgets, Spec),
    case {
        normalize_invocations(Invocations),
        valid_budgets(Budgets, operation_set(Invocations)),
        valid_deadline(maps:get(deadline, Spec), Now),
        is_pid(maps:get(owner_pid, Spec)),
        valid_id(maps:get(session_id, Spec)),
        valid_digest(maps:get(artifact_digest, Spec)),
        valid_id(maps:get(task_id, Spec)),
        valid_combination(maps:get(combination, Spec))
    } of
        {{ok, Normalized}, true, true, true, true, true, true, true} ->
            {ok, Spec#{invocations := Normalized}};
        {{error, _}, _, _, _, _, _, _, _} -> {error, invalid_invocations};
        {_, false, _, _, _, _, _, _} -> {error, invalid_budgets};
        {_, _, false, _, _, _, _, _} -> {error, invalid_deadline};
        {_, _, _, false, _, _, _, _} -> {error, invalid_owner};
        {_, _, _, _, false, _, _, _} -> {error, invalid_session};
        {_, _, _, _, _, false, _, _} -> {error, invalid_artifact};
        {_, _, _, _, _, _, false, _} -> {error, invalid_task};
        {_, _, _, _, _, _, _, false} -> {error, invalid_combination_policy}
    end.

normalize_invocations(Invocations) when
    is_list(Invocations),
    Invocations =/= [],
    length(Invocations) =< ?MAX_INVOCATIONS
->
    case lists:all(fun valid_invocation/1, Invocations) of
        true -> {ok, lists:usort(Invocations)};
        false -> {error, invalid_invocation}
    end;
normalize_invocations(_) -> {error, invalid_invocation_set}.

valid_invocation(#{operation := <<"workspace.write">>, workspace_id := WorkspaceId,
    path_prefix := Prefix} = Invocation) ->
    map_size(Invocation) =:= 3 andalso valid_id(WorkspaceId) andalso valid_segments(Prefix);
valid_invocation(#{operation := <<"model.complete">>, model_id := ModelId} = Invocation) ->
    map_size(Invocation) =:= 2 andalso valid_id(ModelId);
valid_invocation(_) -> false.

valid_segments(Segments) when is_list(Segments), length(Segments) =< 32 ->
    lists:all(fun valid_segment/1, Segments);
valid_segments(_) -> false.

valid_segment(Segment) ->
    valid_id(Segment) andalso Segment =/= <<".">> andalso Segment =/= <<"..">> andalso
        binary:match(Segment, <<"/">>) =:= nomatch andalso
        binary:match(Segment, <<"\\">>) =:= nomatch andalso
        binary:match(Segment, <<0>>) =:= nomatch.

operation_set(Invocations) when is_list(Invocations) ->
    lists:usort([
        Operation
     || #{operation := Operation} <- Invocations,
        is_binary(Operation)
    ]);
operation_set(_) -> [].

valid_budgets(Budgets, Operations) when is_map(Budgets) ->
    lists:sort(maps:keys(Budgets)) =:= lists:sort(Operations) andalso
        lists:all(
            fun(Budget) -> is_integer(Budget) andalso Budget > 0 andalso Budget =< ?MAX_BUDGET end,
            maps:values(Budgets)
        );
valid_budgets(_Budgets, _Operations) -> false.

valid_deadline(Deadline, Now) ->
    is_integer(Deadline) andalso Deadline > Now andalso Deadline =< Now + 86400000.

valid_combination(deny) -> true;
valid_combination(intersect) -> true;
valid_combination(_) -> false.

valid_id(Value) ->
    is_binary(Value) andalso byte_size(Value) > 0 andalso byte_size(Value) =< ?MAX_ID_BYTES.

valid_digest(Digest) when is_binary(Digest), byte_size(Digest) =:= 64 ->
    lists:all(fun is_hex/1, binary_to_list(Digest));
valid_digest(_) -> false.

is_hex(Character) when Character >= $0, Character =< $9 -> true;
is_hex(Character) when Character >= $a, Character =< $f -> true;
is_hex(_) -> false.

inherited_spec(Parent, Invocations, Budgets, Deadline) ->
    (maps:with([
        owner_pid,
        session_id,
        artifact_digest,
        task_id,
        combination,
        delegation
    ], Parent))#{
        invocations => Invocations,
        budgets => Budgets,
        deadline => Deadline
    }.

budgets_within(Budgets, Parent, Store) ->
    lists:all(
        fun({Operation, Budget}) -> Budget =< effective_budget(Store, Parent, Operation) end,
        maps:to_list(Budgets)
    ).

lookup_active(#{format := alang_grant_store_v1, grants := Grants}, Opaque, Now) ->
    case opaque_reference(Opaque) of
        {ok, Reference} ->
            case maps:find(Reference, Grants) of
                {ok, #{status := active, deadline := Deadline} = Grant} when Deadline >= Now ->
                    {ok, Grant};
                {ok, #{status := revoked}} -> {error, revoked_grant};
                {ok, _Expired} -> {error, expired_grant};
                error -> {error, unknown_grant}
            end;
        error -> {error, unknown_grant}
    end;
lookup_active(_Store, _Opaque, _Now) -> {error, invalid_grant_store}.

resolve_reference(#{grants := Grants} = Store, Reference, Context, Now) ->
    case maps:find(Reference, Grants) of
        error -> {error, unknown_grant, Store};
        {ok, #{status := revoked}} -> {error, revoked_grant, Store};
        {ok, #{deadline := Deadline}} when Deadline < Now ->
            Removed = Store#{grants := maps:remove(Reference, Grants)},
            {error, expired_grant, cleanup_pools(Removed)};
        {ok, Grant} -> resolve_binding(Store, Reference, Grant, Context)
    end.

resolve_binding(Store, Reference, Grant, Context) ->
    case valid_context(Context) andalso binding_matches(Store, Grant, Context) of
        false -> {error, binding_mismatch, Store};
        true -> bind_presenter(Store, Reference, Grant, maps:get(presenter_pid, Context))
    end.

valid_context(Context) ->
    lists:sort(maps:keys(Context)) =:= lists:sort([
        node,
        runtime_instance,
        generation,
        session_id,
        artifact_digest,
        owner_pid,
        task_id,
        presenter_pid
    ]) andalso is_pid(maps:get(presenter_pid, Context, undefined)).

binding_matches(Store, Grant, Context) ->
    maps:get(node, Context) =:= maps:get(node, Store) andalso
        maps:get(runtime_instance, Context) =:= maps:get(runtime_instance, Store) andalso
        maps:get(generation, Context) =:= maps:get(generation, Store) andalso
        maps:get(session_id, Context) =:= maps:get(session_id, Grant) andalso
        maps:get(artifact_digest, Context) =:= maps:get(artifact_digest, Grant) andalso
        maps:get(owner_pid, Context) =:= maps:get(owner_pid, Grant) andalso
        maps:get(task_id, Context) =:= maps:get(task_id, Grant).

bind_presenter(#{grants := Grants} = Store, Reference, #{presenter_pid := undefined} = Grant, Presenter) ->
    Bound = Grant#{presenter_pid := Presenter},
    {ok, Bound, Store#{grants := Grants#{Reference := Bound}}};
bind_presenter(Store, _Reference, #{presenter_pid := Presenter} = Grant, Presenter) ->
    {ok, Grant, Store};
bind_presenter(Store, _Reference, _Grant, _Presenter) ->
    {error, binding_mismatch, Store}.

invocation_allows(
    #{operation := <<"workspace.write">>, workspace_id := WorkspaceId, path_prefix := Prefix},
    <<"workspace.write">>,
    #{workspace_id := WorkspaceId, path_segments := Segments}
) -> is_prefix(Prefix, Segments);
invocation_allows(
    #{operation := <<"model.complete">>, model_id := ModelId},
    <<"model.complete">>,
    #{model_id := ModelId}
) -> true;
invocation_allows(_Invocation, _Operation, _Resource) -> false.

invocation_subset(
    #{operation := <<"workspace.write">>, workspace_id := WorkspaceId, path_prefix := Child},
    #{operation := <<"workspace.write">>, workspace_id := WorkspaceId, path_prefix := Parent}
) -> is_prefix(Parent, Child);
invocation_subset(
    #{operation := <<"model.complete">>, model_id := ModelId},
    #{operation := <<"model.complete">>, model_id := ModelId}
) -> true;
invocation_subset(_Child, _Parent) -> false.

invocation_intersection(Left, Right) ->
    lists:usort(lists:append([
        case intersect_invocation(LeftInvocation, RightInvocation) of
            none -> [];
            Intersection -> [Intersection]
        end
     || LeftInvocation <- Left,
        RightInvocation <- Right
    ])).

intersect_invocation(
    #{operation := <<"workspace.write">>, workspace_id := WorkspaceId, path_prefix := Left},
    #{operation := <<"workspace.write">>, workspace_id := WorkspaceId, path_prefix := Right}
) ->
    case {is_prefix(Left, Right), is_prefix(Right, Left)} of
        {true, _} -> #{operation => <<"workspace.write">>, workspace_id => WorkspaceId, path_prefix => Right};
        {_, true} -> #{operation => <<"workspace.write">>, workspace_id => WorkspaceId, path_prefix => Left};
        _ -> none
    end;
intersect_invocation(
    #{operation := <<"model.complete">>, model_id := ModelId},
    #{operation := <<"model.complete">>, model_id := ModelId}
) -> #{operation => <<"model.complete">>, model_id => ModelId};
intersect_invocation(_Left, _Right) -> none.

is_prefix([], _Segments) -> true;
is_prefix([Segment | Prefix], [Segment | Segments]) -> is_prefix(Prefix, Segments);
is_prefix(_Prefix, _Segments) -> false.

same_binding(Left, Right) ->
    Keys = [owner_pid, session_id, artifact_digest, task_id, presenter_pid],
    lists:all(fun(Key) -> maps:get(Key, Left) =:= maps:get(Key, Right) end, Keys).

consume_grant(Store, Reference, Grant, Operation) ->
    case maps:find(Operation, maps:get(budgets, Grant)) of
        error -> {error, scope_mismatch};
        {ok, LocalBudget} ->
            PoolReferences = maps:get(Operation, maps:get(budget_pools, Grant)),
            PoolBudgets = [maps:get(Pool, maps:get(budget_pools, Store)) || Pool <- PoolReferences],
            case LocalBudget > 0 andalso lists:all(fun(Budget) -> Budget > 0 end, PoolBudgets) of
                false -> {error, exhausted_budget};
                true -> decrement_budget(Store, Reference, Grant, Operation, PoolReferences)
            end
    end.

decrement_budget(#{grants := Grants, budget_pools := Pools} = Store, Reference, Grant,
    Operation, PoolReferences) ->
    Budgets = maps:get(budgets, Grant),
    UpdatedGrant = Grant#{budgets := Budgets#{Operation := maps:get(Operation, Budgets) - 1}},
    UpdatedPools = lists:foldl(
        fun(Pool, Acc) -> Acc#{Pool := maps:get(Pool, Acc) - 1} end,
        Pools,
        PoolReferences
    ),
    UpdatedStore = Store#{
        grants := Grants#{Reference := UpdatedGrant},
        budget_pools := UpdatedPools
    },
    {ok, effective_budget(UpdatedStore, UpdatedGrant, Operation), UpdatedStore}.

effective_budget(#{budget_pools := Pools}, Grant, Operation) ->
    Local = maps:get(Operation, maps:get(budgets, Grant), 0),
    PoolReferences = maps:get(Operation, maps:get(budget_pools, Grant), []),
    lists:min([Local | [maps:get(Pool, Pools, 0) || Pool <- PoolReferences]]).

cleanup_pools(#{grants := Grants, budget_pools := Pools} = Store) ->
    Used = lists:usort(lists:append([
        lists:append(maps:values(maps:get(budget_pools, Grant)))
     || Grant <- maps:values(Grants)
    ])),
    Store#{budget_pools := maps:with(Used, Pools)}.

public_grant(Store, Grant) ->
    Operations = operation_set(maps:get(invocations, Grant)),
    #{
        format => alang_redacted_grant_v1,
        id => maps:get(redacted_id, Grant),
        invocations => maps:get(invocations, Grant),
        remaining_budgets => maps:from_list([
            {Operation, effective_budget(Store, Grant, Operation)}
         || Operation <- Operations
        ]),
        deadline => maps:get(deadline, Grant),
        session_id => maps:get(session_id, Grant),
        artifact_digest => maps:get(artifact_digest, Grant),
        task_id => maps:get(task_id, Grant),
        status => maps:get(status, Grant),
        combination => maps:get(combination, Grant),
        delegation => maps:get(delegation, Grant)
    }.

opaque_reference({alang_opaque_v1, ?GRANT_TYPE, Reference}) when is_reference(Reference) ->
    {ok, Reference};
opaque_reference(_) -> error.

redacted_id(RuntimeInstance, Reference) ->
    Digest = crypto:hash(sha256, term_to_binary({RuntimeInstance, Reference}, [deterministic])),
    Hex = iolist_to_binary([io_lib:format("~2.16.0b", [Byte]) || <<Byte>> <= Digest]),
    binary:part(Hex, 0, 24).
