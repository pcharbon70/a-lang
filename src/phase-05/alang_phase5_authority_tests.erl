-module(alang_phase5_authority_tests).

-include_lib("eunit/include/eunit.hrl").

restoration_preserves_or_reduces_authority_test() ->
    {ok, Supervisor} = alang_phase4_broker_sup:start_link(broker_options()),
    try
        {ok, Broker} = alang_phase4_broker_sup:broker(Supervisor),
        NowUtc = erlang:system_time(millisecond),
        NowMonotonic = erlang:monotonic_time(millisecond),
        State = state(NowUtc),
        {ok, Restored} = alang_phase5_authority:restore(
            Broker, State, self(), NowUtc, NowMonotonic),
        References = maps:get(references, Restored),
        ?assertEqual([digest($a)], maps:keys(References)),
        Reference = maps:get(digest($a), References),
        {ok, Description} = alang_phase4_broker:describe_grant(Broker, Reference),
        ?assertEqual(2, maps:get(<<"workspace.write">>, maps:get(remaining_budgets, Description))),
        ?assert(alang_phase4_grants:authority_subset(
            maps:get(invocations, Description),
            maps:get(invocations, active_descriptor(NowUtc))
        )),
        Decisions = maps:get(decisions, Restored),
        ?assert(lists:member(#{grant_id => digest($b), decision => skipped, reason => revoked},
            Decisions)),
        ?assert(lists:member(#{grant_id => digest($c), decision => skipped, reason => expired},
            Decisions)),
        ?assert(lists:member(#{grant_id => digest($d), decision => skipped, reason => exhausted},
            Decisions))
    after
        alang_phase4_broker_sup:stop(Supervisor)
    end.

fresh_broker_issues_fresh_generation_bound_references_test() ->
    NowUtc = erlang:system_time(millisecond),
    State = (state(NowUtc))#{authority := [active_descriptor(NowUtc)], revocations := []},
    {ok, Supervisor1} = alang_phase4_broker_sup:start_link(broker_options()),
    {ok, Broker1} = alang_phase4_broker_sup:broker(Supervisor1),
    {ok, Restored1} = alang_phase5_authority:restore(Broker1, State, self(), NowUtc,
        erlang:monotonic_time(millisecond)),
    Reference1 = maps:get(digest($a), maps:get(references, Restored1)),
    Context1 = maps:get(runtime_context, Restored1),
    alang_phase4_broker_sup:stop(Supervisor1),
    {ok, Supervisor2} = alang_phase4_broker_sup:start_link(broker_options()),
    try
        {ok, Broker2} = alang_phase4_broker_sup:broker(Supervisor2),
        {ok, Restored2} = alang_phase5_authority:restore(Broker2, State, self(), NowUtc,
            erlang:monotonic_time(millisecond)),
        Reference2 = maps:get(digest($a), maps:get(references, Restored2)),
        Context2 = maps:get(runtime_context, Restored2),
        ?assertNotEqual(Reference1, Reference2),
        ?assertNotEqual(Context1, Context2),
        ?assertEqual({error, unknown_grant}, alang_phase4_broker:describe_grant(Broker2, Reference1)),
        ?assertMatch({ok, _}, alang_phase4_broker:describe_grant(Broker2, Reference2))
    after
        alang_phase4_broker_sup:stop(Supervisor2)
    end.

invalid_or_widening_descriptors_fail_closed_test() ->
    NowUtc = erlang:system_time(millisecond),
    Descriptor = active_descriptor(NowUtc),
    ?assertEqual(
        {error, invalid_authority_descriptor},
        alang_phase5_authority:validate_descriptor(Descriptor#{budgets := #{
            <<"workspace.write">> => 1000001
        }})
    ),
    ?assertEqual(
        {error, invalid_authority_descriptor},
        alang_phase5_authority:validate_descriptor(Descriptor#{invocations := [#{
            operation => <<"arbitrary.call">>, workspace_id => <<"workspace-a">>, path_prefix => []
        }]})
    ).

state(NowUtc) ->
    {ok, State} = alang_phase5_state:new(#{
        session_id => <<"authority-session">>,
        program => #{
            artifact_digest => digest($f),
            module_name => <<"alang_phase3_program_v1">>,
            abi_version => 1,
            state_schema => 1
        },
        logical_state => <<"ready">>,
        budgets => #{<<"workspace.write">> => 2},
        authority => [
            active_descriptor(NowUtc),
            (active_descriptor(NowUtc))#{grant_id := digest($b)},
            (active_descriptor(NowUtc))#{grant_id := digest($c), expires_at := NowUtc - 1},
            (active_descriptor(NowUtc))#{grant_id := digest($d), budgets := #{
                <<"workspace.write">> => 0
            }}
        ],
        revocations => [digest($b)]
    }),
    State.

active_descriptor(NowUtc) -> #{
    grant_id => digest($a),
    invocations => [#{
        operation => <<"workspace.write">>,
        workspace_id => <<"workspace-a">>,
        path_prefix => [<<"results">>]
    }],
    budgets => #{<<"workspace.write">> => 2},
    expires_at => NowUtc + 60000,
    task_id => <<"task:Workspace.write/0">>,
    combination => deny
}.

broker_options() -> #{
    limits => #{
        max_pending => 8,
        max_pending_per_session => 2,
        max_mailbox => 256,
        max_audit => 128,
        authorization_ttl_ms => 1000
    },
    policy => #{
        version => <<"phase5-policy-v1">>,
        workspaces => [<<"workspace-a">>],
        models => [<<"model-a">>]
    }
}.

digest(Character) -> binary:copy(<<Character>>, 64).
