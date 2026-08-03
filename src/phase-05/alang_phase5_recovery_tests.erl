-module(alang_phase5_recovery_tests).

-include_lib("eunit/include/eunit.hrl").

-define(TOOLCHAIN, "src/phase-01/toolchain.config").

validated_snapshot_recovers_fresh_generation_test() ->
    with_fixture(fun(Fixture) ->
        {ok, Snapshot} = read_snapshot(Fixture),
        {ok, Recovery} = alang_phase5_recovery:recover(Snapshot, maps:get(expected, Fixture)),
        ?assertEqual(2, maps:get(generation, Recovery)),
        ?assertEqual(2, maps:get(generation, maps:get(state, Recovery))),
        ?assertEqual(0, maps:get(replayed_records, Recovery)),
        ?assertEqual(#{}, maps:get(known_results, Recovery))
    end).

fresh_supervision_tree_and_generation_fencing_test() ->
    with_fixture(fun(Fixture) ->
        Options = resume_options(Fixture, true),
        {ok, Supervisor1, Recovery1} = alang_phase5_resume:resume(Options),
        {ok, Topology1} = await_topology(Supervisor1, 100),
        Generation1 = maps:get(generation, Recovery1),
        Inbox1 = maps:get(inbox, Topology1),
        Snapshot1 = alang_phase5_runtime_process:snapshot(Inbox1),
        Envelope1 = envelope(Generation1, $a, $b),
        ?assertEqual({ok, accepted}, alang_phase5_runtime_process:deliver(Inbox1, Envelope1)),
        ?assertEqual({ok, duplicate}, alang_phase5_runtime_process:deliver(Inbox1, Envelope1)),
        ?assertEqual(
            {error, correlation_conflict},
            alang_phase5_runtime_process:deliver(Inbox1, Envelope1#{payload_digest := digest($c)})
        ),
        Pids1 = topology_pids(Topology1),
        ok = alang_phase5_session_sup:stop(Supervisor1),
        await_dead(Pids1, 100),
        {ok, Supervisor2, Recovery2} = alang_phase5_resume:resume(Options),
        try
            {ok, Topology2} = await_topology(Supervisor2, 100),
            Generation2 = maps:get(generation, Recovery2),
            ?assertEqual(Generation1 + 1, Generation2),
            Inbox2 = maps:get(inbox, Topology2),
            ?assertEqual(
                {error, stale_generation},
                alang_phase5_runtime_process:deliver(Inbox2, Envelope1)
            ),
            ?assertEqual(
                {error, future_generation},
                alang_phase5_runtime_process:deliver(Inbox2, envelope(Generation2 + 1, $d, $e))
            ),
            Snapshot2 = alang_phase5_runtime_process:snapshot(Inbox2),
            ?assertNotEqual(maps:get(pid, Snapshot1), maps:get(pid, Snapshot2)),
            ?assertNotEqual(maps:get(timer, Snapshot1), maps:get(timer, Snapshot2)),
            lists:foreach(fun(Pid) -> ?assertNot(lists:member(Pid, Pids1)) end,
                topology_pids(Topology2)),
            {ok, AdapterStatus} = maps:get(adapter_status, Topology2),
            ?assertEqual(beam_sidecar, maps:get(runtime, maps:get(isolation, AdapterStatus)))
        after
            alang_phase5_session_sup:stop(Supervisor2)
        end
    end).

missing_artifact_is_quarantined_before_supervision_test() ->
    with_fixture(fun(Fixture) ->
        Missing = filename:join(maps:get(base, Fixture), "missing.beam"),
        Expected = (maps:get(expected, Fixture))#{artifact_path := Missing},
        ?assertMatch(
            {error, {recovery_rejected, artifact_missing, _}},
            alang_phase5_resume:resume(
                (resume_options(Fixture, false))#{expected := Expected}
            )
        ),
        ?assertEqual([], filelib:wildcard(filename:join([maps:get(workspace, Fixture), "**", "*.md"])))
    end).

unpublished_transition_and_conflicting_terminal_are_quarantined_test() ->
    with_fixture(fun(Fixture) ->
        {ok, Store} = alang_phase5_store:start(maps:get(store_options, Fixture)),
        {ok, Snapshot0} = alang_phase5_store:read(Store, deadline()),
        {ok, Journal0} = alang_phase5_journal:validate(
            maps:get(records, Snapshot0),
            maps:get(session_id, Snapshot0)
        ),
        {ok, TransitionId} = alang_phase5_journal:transition_id(<<"phase5-session">>, 2),
        {ok, Transition, Journal1} = alang_phase5_journal:append(
            Journal0,
            transition,
            1,
            #{transition_id => TransitionId, state_digest => digest($d)},
            2
        ),
        {ok, _} = alang_phase5_store:append(Store, Transition, deadline()),
        alang_phase5_store:stop(Store),
        {ok, Snapshot1} = read_snapshot(Fixture),
        ?assertMatch(
            {error, {recovery_rejected, unpublished_transition, _}},
            alang_phase5_recovery:recover(Snapshot1, maps:get(expected, Fixture))
        ),
        _ = Journal1
    end).

effect_suffix_is_folded_without_dispatch_test() ->
    with_fixture(fun(Fixture) ->
        {ok, Store} = alang_phase5_store:start(maps:get(store_options, Fixture)),
        {ok, Snapshot0} = alang_phase5_store:read(Store, deadline()),
        {ok, Journal0} = alang_phase5_journal:validate(
            maps:get(records, Snapshot0),
            maps:get(session_id, Snapshot0)
        ),
        {ok, TransitionId} = alang_phase5_journal:transition_id(<<"phase5-session">>, 1),
        {ok, OperationId} = alang_phase5_journal:operation_id(<<"phase5-session">>, TransitionId, 0),
        Entries = [
            {effect_intent, #{transition_id => TransitionId, operation_id => OperationId,
                operation => <<"workspace.write">>, payload_digest => digest($d)}},
            {authorization, #{operation_id => OperationId, decision => allowed,
                decision_digest => digest($e)}},
            {submission, #{operation_id => OperationId, adapter_identity => <<"workspace-v1">>,
                payload_digest => digest($d)}},
            {effect_result, #{operation_id => OperationId, outcome => succeeded,
                result_digest => digest($f)}}
        ],
        _Journal = lists:foldl(
            fun({Kind, Payload}, Journal) ->
                {ok, Record, Next} = alang_phase5_journal:append(Journal, Kind, 1, Payload, 2),
                {ok, _} = alang_phase5_store:append(Store, Record, deadline()),
                Next
            end,
            Journal0,
            Entries
        ),
        alang_phase5_store:stop(Store),
        {ok, Snapshot1} = read_snapshot(Fixture),
        {ok, Recovery} = alang_phase5_recovery:recover(Snapshot1, maps:get(expected, Fixture)),
        Pending = maps:get(pending, maps:get(state, Recovery)),
        ?assertEqual(submitted, maps:get(stage, Pending)),
        ?assertMatch(#{OperationId := #{outcome := succeeded}}, maps:get(known_results, Recovery)),
        ?assertEqual([], filelib:wildcard(filename:join([maps:get(workspace, Fixture), "**", "*.md"])))
    end).

future_journal_generation_is_quarantined_test() ->
    with_fixture(fun(Fixture) ->
        {ok, Store} = alang_phase5_store:start(maps:get(store_options, Fixture)),
        {ok, Snapshot0} = alang_phase5_store:read(Store, deadline()),
        {ok, Journal0} = alang_phase5_journal:validate(
            maps:get(records, Snapshot0),
            maps:get(session_id, Snapshot0)
        ),
        {ok, Record, _Journal1} = alang_phase5_journal:append(
            Journal0,
            observation,
            2,
            #{observation_digest => digest($9)},
            2
        ),
        {ok, _} = alang_phase5_store:append(Store, Record, deadline()),
        alang_phase5_store:stop(Store),
        {ok, Snapshot1} = read_snapshot(Fixture),
        ?assertMatch(
            {error, {recovery_rejected, {future_journal_generation, 1, 2}, _}},
            alang_phase5_recovery:recover(Snapshot1, maps:get(expected, Fixture))
        )
    end).

with_fixture(Fun) ->
    Base = filename:join(
        filename:absname("build/phase-05/recovery-tests"),
        integer_to_list(erlang:system_time(nanosecond)) ++ "-" ++
            integer_to_list(erlang:unique_integer([monotonic, positive]))
    ),
    StoreRoot = filename:join(Base, "store"),
    Workspace = filename:join(Base, "workspace"),
    ok = filelib:ensure_dir(filename:join([Workspace, "results", ".keep"])),
    {Beam, ArtifactDigest} = compiled_artifact(),
    ArtifactPath = filename:join(Base, "program.beam"),
    ok = file:write_file(ArtifactPath, Beam),
    StoreOptions = #{root => StoreRoot, session_id => <<"phase5-session">>, test_faults => true},
    State = state(ArtifactDigest),
    initialize_store(StoreOptions, State, ArtifactDigest),
    Fixture = #{
        base => Base,
        store_options => StoreOptions,
        workspace => Workspace,
        expected => #{
            state_schema => 1,
            abi_version => 1,
            artifact_digest => ArtifactDigest,
            module_name => <<"alang_phase3_program_v1">>,
            artifact_path => ArtifactPath
        }
    },
    try Fun(Fixture)
    after
        _ = file:del_dir_r(Base)
    end.

initialize_store(StoreOptions, State, ArtifactDigest) ->
    {ok, Store} = alang_phase5_store:start(StoreOptions),
    {ok, Journal0} = alang_phase5_journal:new(<<"phase5-session">>),
    {ok, StateDigest} = alang_phase5_state:checkpoint_digest(State),
    {ok, Record, _Journal1} = alang_phase5_journal:append(
        Journal0,
        session_created,
        1,
        #{state_digest => StateDigest, artifact_digest => ArtifactDigest},
        1
    ),
    {ok, _} = alang_phase5_store:append(Store, Record, deadline()),
    {ok, _} = alang_phase5_store:checkpoint(Store, State, 1, deadline()),
    alang_phase5_store:stop(Store).

read_snapshot(Fixture) ->
    {ok, Store} = alang_phase5_store:start(maps:get(store_options, Fixture)),
    try alang_phase5_store:read(Store, deadline())
    after alang_phase5_store:stop(Store)
    end.

resume_options(Fixture, AdapterEnabled) -> #{
    store_options => maps:get(store_options, Fixture),
    expected => maps:get(expected, Fixture),
    broker_options => broker_options(Fixture, AdapterEnabled)
}.

broker_options(Fixture, AdapterEnabled) ->
    Base = #{
        limits => #{
            max_pending => 8,
            max_pending_per_session => 2,
            max_mailbox => 256,
            max_audit => 256,
            authorization_ttl_ms => 4000
        },
        policy => #{
            version => <<"phase5-policy-v1">>,
            workspaces => [<<"workspace-a">>],
            models => [<<"model-a">>]
        }
    },
    case AdapterEnabled of
        false -> Base;
        true -> Base#{adapter => adapter_config(maps:get(workspace, Fixture))}
    end.

adapter_config(Workspace) -> #{
    workspace_id => <<"workspace-a">>,
    root => list_to_binary(Workspace),
    beam_dir => list_to_binary(filename:dirname(code:which(alang_phase4_workspace_sidecar))),
    test_faults => false,
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

compiled_artifact() ->
    Ir = alang_phase4_integration_fixture:workspace_ir(
        <<"workspace-a">>,
        <<"results/recovery.md">>,
        <<"not-dispatched-during-recovery">>,
        <<"phase5-recovery-op">>
    ),
    Context = #{
        source_sha256 => hex(crypto:hash(sha256, <<"phase5-recovery-fixture">>)),
        capability_manifest => #{
            effects => [<<"workspace.write">>],
            requirements => [<<"workspace:write">>]
        }
    },
    {ok, Compiled} = alang_phase3_backend:compile_ir(Ir, Context, ?TOOLCHAIN),
    Beam = maps:get(beam, Compiled),
    {ok, Inspection} = alang_phase3_artifact:inspect(Beam),
    {Beam, maps:get(beam_sha256, Inspection)}.

state(ArtifactDigest) ->
    {ok, State} = alang_phase5_state:new(#{
        session_id => <<"phase5-session">>,
        generation => 1,
        program => #{
            artifact_digest => ArtifactDigest,
            module_name => <<"alang_phase3_program_v1">>,
            abi_version => 1,
            state_schema => 1
        },
        logical_state => ready,
        observations => [],
        budgets => #{<<"workspace.write">> => 1},
        deadline => 2000000000000
    }),
    State.

envelope(Generation, CorrelationCharacter, PayloadCharacter) -> #{
    format => alang_runtime_envelope_v1,
    generation => Generation,
    correlation_id => digest(CorrelationCharacter),
    payload_digest => digest(PayloadCharacter),
    payload => #{kind => reply}
}.

await_topology(_Supervisor, 0) -> {error, topology_timeout};
await_topology(Supervisor, Attempts) ->
    case alang_phase5_session_sup:topology(Supervisor) of
        {ok, #{adapter_status := {ok, #{sidecar_ready := true}}} = Topology} -> {ok, Topology};
        {ok, #{adapter_status := {error, adapter_unavailable}} = Topology} -> {ok, Topology};
        _ ->
            timer:sleep(10),
            await_topology(Supervisor, Attempts - 1)
    end.

topology_pids(Topology) -> [maps:get(Key, Topology) || Key <-
    [durable_store, broker_supervisor, broker, coordinator, inbox, trace]].

await_dead([], _Attempts) -> ok;
await_dead(_Pids, 0) -> error(processes_still_alive);
await_dead(Pids, Attempts) ->
    case [Pid || Pid <- Pids, is_process_alive(Pid)] of
        [] -> ok;
        Alive ->
            timer:sleep(10),
            await_dead(Alive, Attempts - 1)
    end.

deadline() -> erlang:monotonic_time(millisecond) + 2000.

digest(Character) -> binary:copy(<<Character>>, 64).

hex(Binary) -> << <<(hex_digit(Nibble))>> || <<Nibble:4>> <= Binary >>.

hex_digit(Nibble) when Nibble < 10 -> $0 + Nibble;
hex_digit(Nibble) -> $a + Nibble - 10.
