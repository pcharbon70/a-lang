-module(alang_phase7_state_property_tests).

-include_lib("proper/include/proper.hrl").
-include_lib("eunit/include/eunit.hrl").

-export([
    prop_authority_model_agreement/0,
    prop_grant_lifecycle/0,
    prop_history_safety/0,
    prop_journal_histories/0,
    run/0
]).

authority_model_matches_grant_store_test() ->
    ?assertEqual(true, quickcheck(prop_authority_model_agreement(), 120)).

grant_lifecycle_and_budget_model_test() ->
    ?assertEqual(true, quickcheck(prop_grant_lifecycle(), 100)).

effect_history_safety_and_liveness_test() ->
    ?assertEqual(true, quickcheck(prop_history_safety(), 160)).

journal_history_integrity_test() ->
    ?assertEqual(true, quickcheck(prop_journal_histories(), 100)).

-spec run() -> map().
run() ->
    Results = [
        {authority, quickcheck(prop_authority_model_agreement(), 120)},
        {grant_lifecycle, quickcheck(prop_grant_lifecycle(), 100)},
        {history, quickcheck(prop_history_safety(), 160)},
        {journal, quickcheck(prop_journal_histories(), 100)}
    ],
    #{format => alang_phase7_section_result_v1, section => <<"7.2">>, cases => 480,
        results => Results,
        passed => lists:all(fun({_Name, Result}) -> Result =:= true end, Results)}.

prop_authority_model_agreement() ->
    ?FORALL({Depth, ParentBudget, ChildBudget0, IncludeModel},
        {proper_types:integer(0, 3), proper_types:integer(1, 12),
            proper_types:integer(0, 12), proper_types:boolean()},
        authority_model_agreement(Depth, ParentBudget, ChildBudget0, IncludeModel)).

prop_grant_lifecycle() ->
    ?FORALL({Budget, Commands},
        {proper_types:integer(1, 12), proper_types:list(proper_types:elements(
            [resolve, consume, wrong_session, expire, revoke, restart]))},
        grant_lifecycle(Budget, lists:sublist(Commands, 32))).

prop_history_safety() ->
    ?FORALL({Budget, Commands},
        {proper_types:integer(0, 8), proper_types:list(proper_types:elements(
            [intent, authorize, submit, result, crash, recover, cancel, expire, restart]))},
        history_safety(Budget, lists:sublist(Commands, 48))).

prop_journal_histories() ->
    ?FORALL({SessionNumber, Length},
        {proper_types:integer(1, 1000000), proper_types:integer(1, 40)},
        journal_history(SessionNumber, Length)).

authority_model_agreement(Depth, ParentBudget, ChildBudget0, IncludeModel) ->
    Now = 1000,
    ParentInvocations = [workspace_invocation([<<"notes">>]), model_invocation()],
    Parent = spec(ParentInvocations,
        #{<<"workspace.write">> => ParentBudget, <<"model.complete">> => ParentBudget},
        Now + 10000),
    Store0 = alang_phase4_grants:new_store(1),
    {ok, ParentRef, Store1} = alang_phase4_grants:issue(Store0, Parent, Now),
    Suffix = lists:sublist([<<"a">>, <<"b">>, <<"c">>], Depth),
    ChildInvocations0 = [workspace_invocation([<<"notes">> | Suffix])],
    ChildInvocations = case IncludeModel of true -> [model_invocation() | ChildInvocations0]; false -> ChildInvocations0 end,
    ChildBudget = erlang:max(1, erlang:min(ParentBudget, ChildBudget0)),
    ChildBudgets0 = #{<<"workspace.write">> => ChildBudget},
    ChildBudgets = case IncludeModel of true -> ChildBudgets0#{<<"model.complete">> => ChildBudget}; false -> ChildBudgets0 end,
    Restriction = #{invocations => ChildInvocations, budgets => ChildBudgets,
        deadline => Now + 5000},
    {ok, ChildRef, Store2} = alang_phase4_grants:restrict(Store1, ParentRef, Restriction, Now),
    {ok, ParentDescription} = alang_phase4_grants:describe(Store2, ParentRef),
    {ok, ChildDescription} = alang_phase4_grants:describe(Store2, ChildRef),
    ParentSet = alang_phase7_authority_model:observe(ParentDescription),
    RestrictionSet = alang_phase7_authority_model:observe(Restriction),
    ChildSet = alang_phase7_authority_model:observe(ChildDescription),
    Expected = alang_phase7_authority_model:intersection(ParentSet, RestrictionSet),
    GrandRestriction = #{invocations => [workspace_invocation([<<"notes">> | Suffix] ++ [<<"a">>])],
        budgets => #{<<"workspace.write">> => ChildBudget}, deadline => Now + 4000},
    {ok, GrandRef, Store3} = alang_phase4_grants:restrict(Store2, ChildRef, GrandRestriction, Now),
    {ok, GrandDescription} = alang_phase4_grants:describe(Store3, GrandRef),
    GrandSet = alang_phase7_authority_model:observe(GrandDescription),
    ChildSet =:= Expected andalso
        alang_phase7_authority_model:subset(GrandSet, ChildSet) andalso
        alang_phase7_authority_model:subset(ChildSet, ParentSet) andalso
        maps:get(remaining_budgets, ChildDescription) =:= ChildBudgets.

grant_lifecycle(Budget, Commands) ->
    Now = 2000,
    Spec = spec([workspace_invocation([<<"notes">>])],
        #{<<"workspace.write">> => Budget}, Now + 50),
    Store0 = alang_phase4_grants:new_store(1),
    {ok, Ref, Store1} = alang_phase4_grants:issue(Store0, Spec, Now),
    Initial = #{store => Store1, ref => Ref, now => Now, status => active,
        budget => Budget, generation => 1, spec => Spec},
    Final = lists:foldl(fun lifecycle_command/2, Initial, Commands),
    model_matches_store(Final).

lifecycle_command(resolve, State) ->
    assert_resolution(State, context(State));
lifecycle_command(consume, #{status := active, budget := Budget} = State) when Budget > 0 ->
    Resolved = assert_resolution(State, context(State)),
    case maps:get(last_resolution, Resolved) of
        ok ->
            {ok, Remaining, Store} = alang_phase4_grants:consume(maps:get(store, Resolved),
                maps:get(ref, Resolved), <<"workspace.write">>),
            Resolved#{store := Store, budget := Remaining};
        _ -> Resolved
    end;
lifecycle_command(consume, State) -> assert_resolution(State, context(State));
lifecycle_command(wrong_session, State) ->
    Result = alang_phase4_grants:resolve(maps:get(store, State), maps:get(ref, State),
        (context(State))#{session_id := <<"wrong-session">>}, maps:get(now, State)),
    Expected = case maps:get(status, State) of
        active -> binding_mismatch;
        expired -> expired_grant;
        revoked -> revoked_grant;
        missing -> unknown_grant
    end,
    case Result of
        {error, Expected, Store} when Expected =:= expired_grant ->
            State#{store := Store, status := missing};
        {error, Expected, Store} -> State#{store := Store};
        _ -> State#{violation => wrong_session_accepted}
    end;
lifecycle_command(expire, #{status := active} = State) ->
    State#{now := 2100, status := expired};
lifecycle_command(expire, State) -> State#{now := 2100};
lifecycle_command(revoke, #{status := missing} = State) -> State;
lifecycle_command(revoke, State) ->
    case alang_phase4_grants:revoke(maps:get(store, State), maps:get(ref, State)) of
        {ok, _Count, Store} -> State#{store := Store, status := revoked};
        {error, unknown_grant} -> State#{status := missing}
    end;
lifecycle_command(restart, State) ->
    Generation = maps:get(generation, State) + 1,
    State#{store := alang_phase4_grants:new_store(Generation), status := missing,
        generation := Generation};
lifecycle_command(_Command, State) -> State.

assert_resolution(State, Context) ->
    Result = alang_phase4_grants:resolve(maps:get(store, State), maps:get(ref, State),
        Context, maps:get(now, State)),
    Actual = case Result of
        {ok, _Grant, Store} -> {ok, Store};
        {error, ErrorReason, Store} -> {ErrorReason, Store}
    end,
    {ActualReason, Store1} = Actual,
    Expected = expected_resolution(State),
    case ActualReason =:= Expected of
        true when ActualReason =:= expired_grant ->
            State#{store := Store1, status := missing, last_resolution => ActualReason};
        true -> State#{store := Store1, last_resolution => ActualReason};
        false -> State#{store := Store1, last_resolution => ActualReason,
            violation => {resolution_disagreement, Expected, ActualReason}}
    end.

expected_resolution(#{status := active, budget := 0}) -> ok;
expected_resolution(#{status := active}) -> ok;
expected_resolution(#{status := expired}) -> expired_grant;
expected_resolution(#{status := revoked}) -> revoked_grant;
expected_resolution(#{status := missing}) -> unknown_grant.

model_matches_store(State) ->
    case maps:is_key(violation, State) of
        true -> false;
        false ->
            case maps:get(status, State) of
                active -> alang_phase4_grants:remaining(maps:get(store, State),
                    maps:get(ref, State), <<"workspace.write">>) =:= {ok, maps:get(budget, State)};
                revoked -> element(1, alang_phase4_grants:remaining(maps:get(store, State),
                    maps:get(ref, State), <<"workspace.write">>)) =:= error;
                expired -> true;
                missing -> alang_phase4_grants:describe(maps:get(store, State),
                    maps:get(ref, State)) =:= {error, unknown_grant}
            end
    end.

history_safety(Budget, Commands) ->
    States = history_states(Commands, alang_phase7_history_model:new(Budget), []),
    lists:all(fun(State) -> alang_phase7_history_model:invariants(State) =:= ok end, States).

history_states([], State, Acc) -> lists:reverse([State | Acc]);
history_states([Command | Rest], State, Acc) ->
    Next = alang_phase7_history_model:transition(Command, State),
    history_states(Rest, Next, [State | Acc]).

journal_history(SessionNumber, Length) ->
    Session = <<"phase7-session-", (integer_to_binary(SessionNumber))/binary>>,
    {ok, Journal0} = alang_phase5_journal:new(Session),
    {Journal, Records} = lists:foldl(fun(Index, {Current, Acc}) ->
        Payload = #{observation_digest => digest({Session, Index})},
        {ok, Record, Next} = alang_phase5_journal:append(Current, observation, 1,
            Payload, 1000 + Index),
        {Next, Acc ++ [Record]}
    end, {Journal0, []}, lists:seq(1, Length)),
    Valid = alang_phase5_journal:validate(Records, Session),
    [First | Rest] = Records,
    Tampered = First#{record_digest := digest(tampered)},
    TamperedResult = alang_phase5_journal:validate([Tampered | Rest], Session),
    case Valid of
        {ok, Validated} -> maps:get(head_digest, Validated) =:= maps:get(head_digest, Journal)
            andalso element(1, TamperedResult) =:= error;
        _ -> false
    end.

spec(Invocations, Budgets, Deadline) -> #{invocations => Invocations, budgets => Budgets,
    deadline => Deadline, owner_pid => self(), session_id => <<"phase7-session">>,
    artifact_digest => binary:copy(<<"a">>, 64), task_id => <<"task:Phase7.effect/0">>,
    combination => intersect}.
workspace_invocation(Prefix) -> #{operation => <<"workspace.write">>,
    workspace_id => <<"workspace-a">>, path_prefix => Prefix}.
model_invocation() -> #{operation => <<"model.complete">>, model_id => <<"model-a">>}.

context(State) -> maps:merge(alang_phase4_grants:runtime_context(maps:get(store, State)), #{
    session_id => <<"phase7-session">>, artifact_digest => binary:copy(<<"a">>, 64),
    owner_pid => self(), task_id => <<"task:Phase7.effect/0">>, presenter_pid => self()
}).

quickcheck(Property, Count) -> proper:quickcheck(Property,
    [{numtests, Count}, {max_size, 32}, quiet]).
digest(Term) -> hex(crypto:hash(sha256, term_to_binary(Term, [deterministic]))).
hex(Binary) -> << <<(hex_digit(Nibble))>> || <<Nibble:4>> <= Binary >>.
hex_digit(Nibble) when Nibble < 10 -> $0 + Nibble;
hex_digit(Nibble) -> $a + Nibble - 10.
