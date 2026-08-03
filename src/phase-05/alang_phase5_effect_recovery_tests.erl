-module(alang_phase5_effect_recovery_tests).

-include_lib("eunit/include/eunit.hrl").

durable_receipt_closes_crash_after_mutation_window_test() ->
    with_workspace(fun(Root, Config) ->
        Seal = make_ref(),
        {ok, Adapter} = alang_phase4_workspace_adapter:start(self(), Config, Seal),
        try
            ok = alang_phase4_workspace_adapter:inject_test_fault(
                Adapter, Seal, crash_after_mutation),
            Decoded = decoded(<<"phase5-crash-op">>, <<"durable-content">>),
            ?assertMatch(
                {error, {adapter_exit, outcome_unknown}},
                alang_phase4_workspace_adapter:dispatch(Adapter, Seal, Decoded, deadline())
            ),
            ok = await_adapter_ready(Adapter, 100),
            Query = query(<<"phase5-crash-op">>, <<"durable-content">>),
            {ok, Lookup} = alang_phase4_workspace_adapter:lookup(
                Adapter, Seal, Query, deadline()),
            ?assertEqual(completed, maps:get(status, Lookup)),
            ?assertEqual({ok, <<"durable-content">>},
                file:read_file(filename:join([Root, "results", "effect.md"])))
        after
            _ = alang_phase4_workspace_adapter:stop(Adapter, Seal)
        end,
        Seal2 = make_ref(),
        {ok, Restarted} = alang_phase4_workspace_adapter:start(self(), Config, Seal2),
        try
            {ok, RestartedLookup} = alang_phase4_workspace_adapter:lookup(
                Restarted, Seal2, query(<<"phase5-crash-op">>, <<"durable-content">>), deadline()),
            ?assertEqual(completed, maps:get(status, RestartedLookup))
        after
            _ = alang_phase4_workspace_adapter:stop(Restarted, Seal2)
        end
    end).

missing_and_divergent_receipts_are_distinguished_test() ->
    with_workspace(fun(Root, Config) ->
        Seal = make_ref(),
        {ok, Adapter} = alang_phase4_workspace_adapter:start(self(), Config, Seal),
        try
            {ok, Missing} = alang_phase4_workspace_adapter:lookup(
                Adapter, Seal, query(<<"never-submitted">>, <<"content">>), deadline()),
            ?assertEqual(not_submitted, maps:get(status, Missing)),
            ok = alang_phase4_workspace_adapter:inject_test_fault(
                Adapter, Seal, crash_after_mutation),
            Decoded = decoded(<<"divergent-op">>, <<"expected">>),
            ?assertMatch({error, {_Class, outcome_unknown}},
                alang_phase4_workspace_adapter:dispatch(Adapter, Seal, Decoded, deadline())),
            ok = file:write_file(filename:join([Root, "results", "effect.md"]), <<"divergent">>),
            ok = await_adapter_ready(Adapter, 100),
            {ok, Divergent} = alang_phase4_workspace_adapter:lookup(
                Adapter, Seal, query(<<"divergent-op">>, <<"expected">>), deadline()),
            ?assertEqual(outcome_unknown, maps:get(status, Divergent))
        after
            _ = alang_phase4_workspace_adapter:stop(Adapter, Seal)
        end
    end).

reconciler_records_existing_result_without_second_write_test() ->
    with_recovery_fixture(fun(Fixture) ->
        Store = maps:get(store, Fixture),
        Broker = maps:get(broker, Fixture),
        Recovery = maps:get(recovery, Fixture),
        {ok, Reconciled} = alang_phase5_effect_recovery:reconcile(
            Store, Broker, Recovery, deadline()),
        #{decision := recovered_result, result_ack := Ack} = maps:get(reconciliation, Reconciled),
        {ok, Advanced} = alang_phase5_state:advance_effect(
            maps:get(state, Reconciled), Ack, done, #{<<"workspace.write">> => 0}),
        ?assertEqual(done, maps:get(logical_state, Advanced)),
        {ok, Snapshot} = alang_phase5_store:read(Store, deadline()),
        ?assertEqual([session_created, effect_result],
            [maps:get(kind, Record) || Record <- maps:get(records, Snapshot)]),
        {ok, Again} = alang_phase5_effect_recovery:reconcile(
            Store, Broker, Reconciled, deadline()),
        ?assertEqual(durable_result, maps:get(decision, maps:get(reconciliation, Again))),
        {ok, SnapshotAgain} = alang_phase5_store:read(Store, deadline()),
        ?assertEqual(2, length(maps:get(records, SnapshotAgain))),
        ?assertEqual({ok, <<"effect-content">>}, file:read_file(maps:get(target, Fixture)))
    end).

irreconcilable_target_pauses_with_durable_evidence_test() ->
    with_recovery_fixture(fun(Fixture) ->
        ok = file:write_file(maps:get(target, Fixture), <<"operator-divergence">>),
        {paused, Paused} = alang_phase5_effect_recovery:reconcile(
            maps:get(store, Fixture),
            maps:get(broker, Fixture),
            maps:get(recovery, Fixture),
            deadline()
        ),
        ?assertEqual(paused, maps:get(terminal, maps:get(state, Paused))),
        ?assertEqual(paused, maps:get(decision, maps:get(reconciliation, Paused))),
        {ok, Snapshot} = alang_phase5_store:read(maps:get(store, Fixture), deadline()),
        #{state := DurableState} = maps:get(checkpoint, Snapshot),
        ?assertEqual(paused, maps:get(terminal, DurableState)),
        ?assertEqual(failure, maps:get(kind, lists:last(maps:get(records, Snapshot))))
    end).

with_recovery_fixture(Fun) ->
    with_workspace(fun(Root, AdapterConfig) ->
        StoreRoot = filename:join(filename:dirname(Root), "store"),
        StoreOptions = #{root => StoreRoot, session_id => <<"effect-session">>, test_faults => true},
        {ok, Store} = alang_phase5_store:start(StoreOptions),
        BrokerOptions = broker_options(AdapterConfig),
        {ok, BrokerSupervisor} = alang_phase4_broker_sup:start_link(BrokerOptions),
        {ok, Broker} = alang_phase4_broker_sup:broker(BrokerSupervisor),
        Content = <<"effect-content">>,
        OperationId = digest($e),
        State = pending_state(OperationId, Content),
        initialize_store(Store, State),
        perform_workspace_write(Broker, OperationId, Content),
        Recovery = #{
            format => alang_recovery_plan_v1,
            state => State,
            generation => 2,
            known_results => #{},
            duplicate_decisions => [],
            replayed_records => 0,
            journal_next_sequence => 1,
            journal_head_digest => digest($0)
        },
        Fixture = #{
            store => Store,
            broker => Broker,
            recovery => Recovery,
            target => filename:join([Root, "results", "effect.md"])
        },
        try Fun(Fixture)
        after
            alang_phase5_store:stop(Store),
            alang_phase4_broker_sup:stop(BrokerSupervisor)
        end
    end).

initialize_store(Store, State) ->
    {ok, Journal0} = alang_phase5_journal:new(<<"effect-session">>),
    {ok, StateDigest} = alang_phase5_state:checkpoint_digest(State),
    {ok, Record, _} = alang_phase5_journal:append(
        Journal0,
        session_created,
        2,
        #{state_digest => StateDigest, artifact_digest => digest($a)},
        erlang:system_time(millisecond)
    ),
    {ok, _} = alang_phase5_store:append(Store, Record, deadline()),
    {ok, _} = alang_phase5_store:checkpoint(Store, State, 1, deadline()).

perform_workspace_write(Broker, OperationId, Content) ->
    Now = erlang:monotonic_time(millisecond),
    Spec = #{
        invocations => [#{operation => <<"workspace.write">>, workspace_id => <<"workspace-a">>,
            path_prefix => [<<"results">>]}],
        budgets => #{<<"workspace.write">> => 1},
        deadline => Now + 10000,
        owner_pid => self(),
        session_id => <<"effect-session">>,
        artifact_digest => digest($a),
        task_id => <<"task:Workspace.write/0">>,
        combination => deny
    },
    {ok, Grant} = alang_phase4_broker:issue_grant(Broker, Spec),
    Context = maps:merge(alang_phase4_broker:runtime_context(Broker), #{
        session_id => <<"effect-session">>,
        artifact_digest => digest($a),
        owner_pid => self(),
        task_id => <<"task:Workspace.write/0">>,
        presenter_pid => self(),
        request_deadline => Now + 5000,
        cancelled => false,
        correlation_id => <<"effect-correlation">>
    }),
    Arguments = {alang_data_v1, product, {
        <<"workspace-a">>, <<"results/effect.md">>, Content, OperationId
    }},
    {ok, _Digest} = alang_phase4_broker:request(
        Broker,
        Grant,
        #{effects => [<<"workspace.write">>], requirements => []},
        <<"workspace.write">>,
        Arguments,
        Context
    ).

pending_state(OperationId, Content) ->
    PayloadDigest = payload_digest(Content),
    ArtifactDigest = artifact_digest(Content),
    {ok, State0} = alang_phase5_state:new(#{
        session_id => <<"effect-session">>,
        generation => 2,
        program => #{artifact_digest => digest($a), module_name => <<"alang_phase3_program_v1">>,
            abi_version => 1, state_schema => 1},
        logical_state => waiting,
        budgets => #{<<"workspace.write">> => 0}
    }),
    {ok, Intent} = alang_phase5_state:begin_effect(State0, #{
        operation_id => OperationId,
        transition_id => digest($d),
        operation => <<"workspace.write">>,
        payload_digest => PayloadDigest,
        recovery => #{kind => workspace_write, workspace_id => <<"workspace-a">>,
            path_segments => [<<"results">>, <<"effect.md">>],
            artifact_digest => ArtifactDigest}
    }),
    {ok, Authorized} = alang_phase5_state:mark_effect(Intent, OperationId, authorized, undefined),
    {ok, Submitted} = alang_phase5_state:mark_effect(
        Authorized, OperationId, submitted, <<"workspace-v1">>),
    Submitted.

with_workspace(Fun) ->
    Base = filename:join(
        filename:absname("build/phase-05/effect-recovery-tests"),
        integer_to_list(erlang:system_time(nanosecond)) ++ "-" ++
            integer_to_list(erlang:unique_integer([monotonic, positive]))
    ),
    Root = filename:join(Base, "workspace"),
    ok = filelib:ensure_dir(filename:join([Root, "results", ".keep"])),
    Config = adapter_config(Root),
    try Fun(Root, Config)
    after _ = file:del_dir_r(Base)
    end.

adapter_config(Root) -> #{
    workspace_id => <<"workspace-a">>,
    root => list_to_binary(Root),
    beam_dir => list_to_binary(filename:dirname(code:which(alang_phase4_workspace_sidecar))),
    test_faults => true,
    limits => #{
        max_request_bytes => 98304,
        max_response_bytes => 4096,
        max_content_bytes => 65536,
        max_cache_entries => 128,
        request_timeout_ms => 1000,
        address_space_bytes => 2147483648,
        cpu_seconds => 5,
        open_files => 64,
        file_size_bytes => 67108864,
        processes => 4096
    }
}.

broker_options(AdapterConfig) -> #{
    limits => #{max_pending => 8, max_pending_per_session => 2, max_mailbox => 256,
        max_audit => 128, authorization_ttl_ms => 1000},
    policy => #{version => <<"phase5-policy-v1">>, workspaces => [<<"workspace-a">>],
        models => [<<"model-a">>]},
    adapter => AdapterConfig#{test_faults := false}
}.

decoded(OperationId, Content) -> #{
    operation_tag => workspace_write,
    adapter => workspace_adapter,
    arguments => #{workspace_id => <<"workspace-a">>,
        path_segments => [<<"results">>, <<"effect.md">>],
        content => Content, operation_id => OperationId}
}.

query(OperationId, Content) -> #{
    workspace_id => <<"workspace-a">>,
    path_segments => [<<"results">>, <<"effect.md">>],
    operation_id => OperationId,
    payload_digest => payload_digest(Content),
    artifact_digest => artifact_digest(Content)
}.

payload_digest(Content) ->
    hex(crypto:hash(sha256, term_to_binary(
        {<<"workspace-a">>, [<<"results">>, <<"effect.md">>], Content}, [deterministic]))).

artifact_digest(Content) -> hex(crypto:hash(sha256, Content)).

await_adapter_ready(_Adapter, 0) -> error(adapter_not_ready);
await_adapter_ready(Adapter, Attempts) ->
    case maps:get(sidecar_ready, alang_phase4_workspace_adapter:status(Adapter)) of
        true -> ok;
        false ->
            timer:sleep(10),
            await_adapter_ready(Adapter, Attempts - 1)
    end.

deadline() -> erlang:monotonic_time(millisecond) + 3000.

digest(Character) -> binary:copy(<<Character>>, 64).

hex(Binary) -> << <<(hex_digit(Nibble))>> || <<Nibble:4>> <= Binary >>.

hex_digit(Nibble) when Nibble < 10 -> $0 + Nibble;
hex_digit(Nibble) -> $a + Nibble - 10.
