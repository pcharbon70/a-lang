-module(alang_phase4_grants_tests).

-include_lib("eunit/include/eunit.hrl").

restriction_is_monotone_and_shares_parent_budget_test() ->
    Now = 1000,
    Store0 = alang_phase4_grants:new_store(1),
    {ok, Parent, Store1} = alang_phase4_grants:issue(Store0, root_spec(Now, intersect), Now),
    Restriction = #{
        invocations => [workspace_invocation([<<"notes">>])],
        budgets => #{<<"workspace.write">> => 2},
        deadline => Now + 5000
    },
    {ok, Child, Store2} = alang_phase4_grants:restrict(Store1, Parent, Restriction, Now),
    {ok, ParentDescription} = alang_phase4_grants:describe(Store2, Parent),
    {ok, ChildDescription} = alang_phase4_grants:describe(Store2, Child),
    ?assert(alang_phase4_grants:authority_subset(
        maps:get(invocations, ChildDescription),
        maps:get(invocations, ParentDescription)
    )),
    ?assertEqual(
        {error, authority_widening},
        alang_phase4_grants:restrict(Store2, Child, Restriction#{
            invocations := [workspace_invocation([])],
            budgets := #{<<"workspace.write">> => 3}
        }, Now)
    ),
    {ok, 1, Store3} = alang_phase4_grants:consume(Store2, Child, <<"workspace.write">>),
    {ok, 0, Store4} = alang_phase4_grants:consume(Store3, Child, <<"workspace.write">>),
    {ok, 2, Store5} = alang_phase4_grants:consume(Store4, Parent, <<"workspace.write">>),
    {ok, 1, Store6} = alang_phase4_grants:consume(Store5, Parent, <<"workspace.write">>),
    {ok, 0, Store7} = alang_phase4_grants:consume(Store6, Parent, <<"workspace.write">>),
    ?assertEqual(
        {error, exhausted_budget},
        alang_phase4_grants:consume(Store7, Parent, <<"workspace.write">>)
    ).

restriction_law_holds_for_generated_prefixes_test() ->
    Now = 2000,
    lists:foreach(
        fun(Depth) ->
            Store0 = alang_phase4_grants:new_store(Depth + 1),
            {ok, Parent, Store1} = alang_phase4_grants:issue(Store0, root_spec(Now, intersect), Now),
            Prefix = [<<"notes">> | lists:sublist([<<"a">>, <<"b">>, <<"c">>, <<"d">>], Depth)],
            {ok, Child, Store2} = alang_phase4_grants:restrict(Store1, Parent, #{
                invocations => [workspace_invocation(Prefix)],
                budgets => #{<<"workspace.write">> => Depth + 1},
                deadline => Now + 1000 + Depth
            }, Now),
            {ok, ParentDescription} = alang_phase4_grants:describe(Store2, Parent),
            {ok, ChildDescription} = alang_phase4_grants:describe(Store2, Child),
            ?assert(alang_phase4_grants:authority_subset(
                maps:get(invocations, ChildDescription),
                maps:get(invocations, ParentDescription)
            ))
        end,
        lists:seq(0, 4)
    ).

combination_is_policy_gated_intersection_test() ->
    Now = 3000,
    Store0 = alang_phase4_grants:new_store(1),
    {ok, Left, Store1} = alang_phase4_grants:issue(Store0, root_spec(Now, intersect), Now),
    RightSpec = (root_spec(Now, intersect))#{
        invocations := [workspace_invocation([<<"notes">>])],
        budgets := #{<<"workspace.write">> => 3}
    },
    {ok, Right, Store2} = alang_phase4_grants:issue(Store1, RightSpec, Now),
    {ok, Combined, Store3} = alang_phase4_grants:combine(Store2, Left, Right, Now),
    {ok, Description} = alang_phase4_grants:describe(Store3, Combined),
    ?assertEqual([workspace_invocation([<<"notes">>])], maps:get(invocations, Description)),
    ?assertEqual(#{<<"workspace.write">> => 3}, maps:get(remaining_budgets, Description)),
    {ok, Denied, Store4} = alang_phase4_grants:issue(Store3, root_spec(Now, deny), Now),
    ?assertEqual(
        {error, combination_denied},
        alang_phase4_grants:combine(Store4, Left, Denied, Now)
    ).

revocation_invalidates_all_descendants_test() ->
    Now = 4000,
    Store0 = alang_phase4_grants:new_store(1),
    {ok, Parent, Store1} = alang_phase4_grants:issue(Store0, root_spec(Now, intersect), Now),
    Restriction = #{
        invocations => [workspace_invocation([<<"notes">>])],
        budgets => #{<<"workspace.write">> => 2},
        deadline => Now + 1000
    },
    {ok, Child, Store2} = alang_phase4_grants:restrict(Store1, Parent, Restriction, Now),
    {ok, Grandchild, Store3} = alang_phase4_grants:restrict(Store2, Child, Restriction#{
        invocations := [workspace_invocation([<<"notes">>, <<"private">>])],
        budgets := #{<<"workspace.write">> => 1},
        deadline := Now + 500
    }, Now),
    {ok, 3, Store4} = alang_phase4_grants:revoke(Store3, Parent),
    Context = context(Store4, root_spec(Now, intersect), self()),
    ?assertMatch({error, revoked_grant, _}, alang_phase4_grants:resolve(Store4, Child, Context, Now)),
    ?assertMatch({error, revoked_grant, _}, alang_phase4_grants:resolve(Store4, Grandchild, Context, Now)).

references_are_opaque_unique_and_only_redacted_state_is_described_test() ->
    Now = 5000,
    Store0 = alang_phase4_grants:new_store(1),
    {References, Store1} = lists:foldl(
        fun(_Index, {Acc, Store}) ->
            {ok, Opaque, Next} = alang_phase4_grants:issue(Store, root_spec(Now, deny), Now),
            {[Opaque | Acc], Next}
        end,
        {[], Store0},
        lists:seq(1, 64)
    ),
    ?assertEqual(64, length(lists:usort(References))),
    [First | _] = References,
    {ok, Description} = alang_phase4_grants:describe(Store1, First),
    ?assertEqual(alang_redacted_grant_v1, maps:get(format, Description)),
    ?assertEqual(24, byte_size(maps:get(id, Description))),
    ?assertNot(contains_reference(Description)),
    ?assertMatch({error, unknown_grant, _},
        alang_phase4_grants:resolve(Store1, make_ref(), #{}, Now)).

runtime_and_process_lifetimes_fail_closed_test() ->
    Now = 6000,
    Store0 = alang_phase4_grants:new_store(7),
    Spec = root_spec(Now, deny),
    {ok, Opaque, Store1} = alang_phase4_grants:issue(Store0, Spec, Now),
    Presenter = spawn(fun wait/0),
    Context = context(Store1, Spec, Presenter),
    {ok, _Grant, Store2} = alang_phase4_grants:resolve(Store1, Opaque, Context, Now),
    WrongContexts = [
        Context#{node := 'other@node'},
        Context#{runtime_instance := make_ref()},
        Context#{generation := 8},
        Context#{session_id := <<"other-session">>},
        Context#{artifact_digest := binary:copy(<<"b">>, 64)},
        Context#{owner_pid := Presenter},
        Context#{task_id := <<"task:Other.effect/0">>},
        Context#{presenter_pid := self()}
    ],
    lists:foreach(
        fun(WrongContext) ->
            ?assertMatch({error, binding_mismatch, _},
                alang_phase4_grants:resolve(Store2, Opaque, WrongContext, Now))
        end,
        WrongContexts
    ),
    ?assertMatch({error, expired_grant, _},
        alang_phase4_grants:resolve(Store2, Opaque, Context, maps:get(deadline, Spec) + 1)),
    {Removed, Store3} = alang_phase4_grants:remove_owner(Store2, self()),
    ?assertEqual(1, Removed),
    ?assertEqual({error, unknown_grant}, alang_phase4_grants:describe(Store3, Opaque)),
    Presenter ! stop.

scope_matching_is_structural_test() ->
    Now = 7000,
    Store0 = alang_phase4_grants:new_store(1),
    {ok, Opaque, Store1} = alang_phase4_grants:issue(Store0, root_spec(Now, deny), Now),
    Context = context(Store1, root_spec(Now, deny), self()),
    {ok, Grant, _Store2} = alang_phase4_grants:resolve(Store1, Opaque, Context, Now),
    ?assert(alang_phase4_grants:allows(Grant, workspace_request([<<"notes">>, <<"result.md">>]))),
    ?assertNot(alang_phase4_grants:allows(Grant, workspace_request([<<"private">>, <<"result.md">>]))),
    ?assertNot(alang_phase4_grants:allows(Grant, model_request())).

root_spec(Now, Combination) ->
    #{
        invocations => [workspace_invocation([<<"notes">>])],
        budgets => #{<<"workspace.write">> => 5},
        deadline => Now + 10000,
        owner_pid => self(),
        session_id => <<"session-a">>,
        artifact_digest => binary:copy(<<"a">>, 64),
        task_id => <<"task:Fixture.effect/0">>,
        combination => Combination
    }.

workspace_invocation(Prefix) -> #{
    operation => <<"workspace.write">>,
    workspace_id => <<"workspace-a">>,
    path_prefix => Prefix
}.

context(Store, Spec, Presenter) ->
    maps:merge(alang_phase4_grants:runtime_context(Store), #{
        session_id => maps:get(session_id, Spec),
        artifact_digest => maps:get(artifact_digest, Spec),
        owner_pid => maps:get(owner_pid, Spec),
        task_id => maps:get(task_id, Spec),
        presenter_pid => Presenter
    }).

workspace_request(Segments) -> #{
    operation => <<"workspace.write">>,
    resource => #{workspace_id => <<"workspace-a">>, path_segments => Segments}
}.

model_request() -> #{
    operation => <<"model.complete">>,
    resource => #{model_id => <<"model-a">>}
}.

contains_reference(Term) when is_reference(Term) -> true;
contains_reference(Term) when is_map(Term) ->
    lists:any(fun contains_reference/1, maps:keys(Term) ++ maps:values(Term));
contains_reference(Term) when is_tuple(Term) -> contains_reference(tuple_to_list(Term));
contains_reference(Term) when is_list(Term) -> lists:any(fun contains_reference/1, Term);
contains_reference(_Term) -> false.

wait() ->
    receive
        stop -> ok
    end.
