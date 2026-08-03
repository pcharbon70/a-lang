-module(alang_phase5_integration_tests).

-include_lib("eunit/include/eunit.hrl").

-define(TOOLCHAIN, "src/phase-01/toolchain.config").
-define(SESSION_ID, <<"phase5-integration-session">>).
-define(TASK_ID, <<"task:Workspace.write/0">>).

compiled_beam_workflow_completes_with_durable_evidence_test() ->
    Compiled = compiled_fixture(),
    with_fixture(Compiled, fun(Fixture) ->
        {Supervisor, Recovery, Topology, Workflow, Beam} = start_workflow(Fixture, none, undefined),
        try
            Generation = maps:get(generation, Recovery),
            Inbox = maps:get(inbox, Topology),
            ?assertEqual({error, stale_generation},
                alang_phase5_runtime_process:deliver(Inbox, envelope(Generation - 1))),
            Handler = handler(Workflow),
            {ok, Result} = alang_phase3_artifact:run(
                Beam, ?TASK_ID, #{}, runtime_options(Handler)),
            ExpectedDigest = maps:get(content_digest, Fixture),
            ?assertEqual({alang_data_v1, ok, ExpectedDigest}, maps:get(value, Result)),
            {ok, Completion} = alang_phase5_workflow:finalize(
                Workflow, maps:get(artifact_digest, Fixture)),
            ?assertEqual(maps:get(artifact_digest, Fixture), maps:get(artifact_digest, Completion)),
            WorkflowSnapshot = alang_phase5_workflow:snapshot(Workflow),
            ?assertEqual(completed, maps:get(terminal, maps:get(state, WorkflowSnapshot)))
        after
            safe_stop_workflow(Workflow),
            alang_phase5_session_sup:stop(Supervisor)
        end,
        Evidence = final_evidence(Fixture),
        ?assertEqual(ok, alang_phase5_failure_matrix:invariants(Evidence)),
        {ok, Snapshot} = read_store(Fixture),
        {ok, _Journal} = alang_phase5_journal:validate(
            maps:get(records, Snapshot), ?SESSION_ID),
        #{state := FinalState} = maps:get(checkpoint, Snapshot),
        ?assertEqual(completed, maps:get(terminal, FinalState)),
        ?assertEqual(none, maps:get(pending, FinalState)),
        ?assertEqual(0, maps:get(<<"workspace.write">>, maps:get(budgets, FinalState))),
        ?assertEqual(completion, maps:get(kind, lists:last(maps:get(records, Snapshot)))),
        ?assertMatch({completed, _}, completed_recovery(Fixture))
    end).

process_crash_matrix_preserves_safety_at_every_transition_test_() ->
    {timeout, 30, fun process_crash_matrix_preserves_safety_at_every_transition/0}.

process_crash_matrix_preserves_safety_at_every_transition() ->
    Compiled = compiled_fixture(),
    Stages = alang_phase5_failure_matrix:stages(),
    Results = [run_process_crash_case(Compiled, Stage) || Stage <- Stages],
    ?assertEqual(Stages, [maps:get(stage, Result) || Result <- Results]),
    lists:foreach(fun(Result) ->
        ?assertEqual(true, maps:get(journal_valid, Result)),
        ?assert(maps:get(output_count, Result) =< 1),
        ?assertEqual(false, maps:get(false_completion, Result))
    end, Results).

isolated_erts_node_kill_recovers_completed_workspace_receipt_test_() ->
    {timeout, 30, fun isolated_erts_node_kill_recovers_completed_workspace_receipt/0}.

isolated_erts_node_kill_recovers_completed_workspace_receipt() ->
    Compiled = compiled_fixture(),
    with_fixture(Compiled, fun(Fixture) ->
        ConfigPath = write_node_config(Fixture),
        {Port, OsPid} = launch_node_fixture(ConfigPath),
        ok = await_node_marker(Port, 300),
        ok = kill_os_process(OsPid),
        ok = await_port_exit(Port, 300),
        {ok, Supervisor, Recovery} = alang_phase5_resume:resume(resume_options(Fixture)),
        try
            Reconciliation = maps:get(reconciliation, Recovery),
            ?assertEqual(recovered_result, maps:get(decision, Reconciliation)),
            ?assertEqual(1, operation_count(Fixture)),
            ?assertEqual({ok, maps:get(content, Fixture)}, file:read_file(maps:get(target, Fixture))),
            {ok, Snapshot} = read_store_live(maps:get(durable_store,
                element(2, alang_phase5_session_sup:topology(Supervisor)))),
            ?assert(lists:member(effect_result,
                [maps:get(kind, Record) || Record <- maps:get(records, Snapshot)]))
        after
            alang_phase5_session_sup:stop(Supervisor)
        end
    end).

store_adapter_and_duplicate_failure_sequences_remain_bounded_test() ->
    Compiled = compiled_fixture(),
    with_fixture(Compiled, fun(Fixture) ->
        {ok, Store} = alang_phase5_store:start(maps:get(store_options, Fixture)),
        try
            ok = alang_phase5_store:inject_test_fault(Store, unavailable_once),
            ?assertEqual({error, store_unavailable}, alang_phase5_store:read(Store, deadline())),
            ok = alang_phase5_store:inject_test_fault(Store, timeout_once),
            ?assertEqual({error, store_timeout}, alang_phase5_store:read(Store, deadline())),
            {ok, Snapshot} = alang_phase5_store:read(Store, deadline()),
            [First | _] = maps:get(records, Snapshot),
            {ok, DuplicateAck} = alang_phase5_store:append(Store, First, deadline()),
            ?assertEqual(duplicate, maps:get(status, DuplicateAck)),
            ?assertEqual(0, maps:get(message_queue_len,
                maps:from_list([process_info(Store, message_queue_len)])))
        after
            alang_phase5_store:stop(Store)
        end,
        Sequence = [noise_before, adapter_crash, duplicate_write, noise_after],
        Violates = fun(Events) -> lists:member(duplicate_write, Events) end,
        ?assertEqual([duplicate_write], alang_phase5_failure_matrix:minimize(Sequence, Violates))
    end).

run_process_crash_case(Compiled, Stage) ->
    ResultHolder = self(),
    with_fixture(Compiled, fun(Fixture) ->
        {Supervisor, _Recovery, _Topology, Workflow, Beam} =
            start_workflow(Fixture, Stage, ResultHolder),
        Handler = handler(Workflow),
        Runner = spawn(fun() ->
            ResultHolder ! {artifact_result, Stage,
                alang_phase3_artifact:run(Beam, ?TASK_ID, #{}, runtime_options(Handler))}
        end),
        Finalizer = await_failure_stage(
            Stage, Workflow, Runner, ResultHolder, maps:get(artifact_digest, Fixture)),
        kill_workflow_at_hook(Stage, Workflow),
        await_interrupted_call(Stage, Runner, Finalizer),
        alang_phase5_session_sup:stop(Supervisor),
        {ok, Snapshot} = read_store(Fixture),
        JournalValid = case alang_phase5_journal:validate(maps:get(records, Snapshot), ?SESSION_ID) of
            {ok, _} -> true;
            _ -> false
        end,
        #{state := DurableState} = maps:get(checkpoint, Snapshot),
        OutputCount = operation_count(Fixture),
        ExpectedOutput = case lists:member(Stage,
            [after_mutation, after_result_commit, after_checkpoint, before_terminal, after_terminal]) of
            true -> 1;
            false -> 0
        end,
        ?assertEqual(ExpectedOutput, OutputCount),
        {ok, Recovery} = alang_phase5_recovery:recover(Snapshot, maps:get(expected, Fixture)),
        ExpectedTerminal = case Stage of after_terminal -> completed; _ -> running end,
        ?assertEqual(ExpectedTerminal, maps:get(terminal, maps:get(state, Recovery))),
        #{
            stage => Stage,
            journal_valid => JournalValid,
            output_count => OutputCount,
            pending => maps:get(pending, DurableState),
            false_completion => maps:get(terminal, DurableState) =:= completed andalso
                Stage =/= after_terminal
        }
    end).

await_failure_stage(Stage, Workflow, _Runner, ResultHolder, ArtifactDigest) when
    Stage =:= before_terminal; Stage =:= after_terminal
->
    receive
        {artifact_result, Stage, {ok, _Result}} -> ok
    after 10000 -> error({artifact_runner_stuck, Stage})
    end,
    spawn(fun() ->
        ResultHolder ! {finalize_result, Stage,
            capture_finalize(Workflow, ArtifactDigest)}
    end);
await_failure_stage(_Stage, _Workflow, _Runner, _ResultHolder, _ArtifactDigest) -> none.

capture_finalize(Workflow, ArtifactDigest) ->
    try alang_phase5_workflow:finalize(Workflow, ArtifactDigest) of
        Result -> Result
    catch
        exit:Reason -> {interrupted, Reason}
    end.

kill_workflow_at_hook(Stage, Workflow) ->
        receive
            {phase5_workflow_hook, Stage, Workflow} -> ok
        after 10000 -> error({missing_failure_hook, Stage})
        end,
        Monitor = erlang:monitor(process, Workflow),
        exit(Workflow, kill),
        receive {'DOWN', Monitor, process, Workflow, killed} -> ok
        after 2000 -> error(workflow_not_killed)
        end.

await_interrupted_call(Stage, Runner, none) ->
        receive {artifact_result, Stage, _Result} -> ok after 5000 -> error(artifact_runner_stuck) end,
        ?assertNot(is_process_alive(Runner));
await_interrupted_call(Stage, _Runner, Finalizer) ->
    receive {finalize_result, Stage, _Result} -> ok after 5000 -> error(finalizer_stuck) end,
    ?assertNot(is_process_alive(Finalizer)).

compiled_fixture() ->
    {ok, TransitionId} = alang_phase5_journal:transition_id(?SESSION_ID, 1),
    {ok, OperationId} = alang_phase5_journal:operation_id(?SESSION_ID, TransitionId, 0),
    Content = <<"phase-5 durable compiled result">>,
    Ir = alang_phase4_integration_fixture:workspace_ir(
        <<"workspace-a">>, <<"results/phase-5.md">>, Content, OperationId),
    Context = #{
        source_sha256 => stable_digest(<<"phase5-integration-fixture">>),
        capability_manifest => #{
            effects => [<<"workspace.write">>],
            requirements => [<<"workspace:write">>]
        }
    },
    {ok, Compiled} = alang_phase3_backend:compile_ir(Ir, Context, ?TOOLCHAIN),
    Beam = maps:get(beam, Compiled),
    {ok, Inspection} = alang_phase3_artifact:inspect(Beam),
    #{
        beam => Beam,
        inspection => Inspection,
        artifact_digest => maps:get(beam_sha256, Inspection),
        manifest => maps:get(capability_manifest, maps:get(metadata, Inspection)),
        operation_id => OperationId,
        content => Content,
        content_digest => stable_digest(Content),
        grant_id => stable_digest(<<"phase5-integration-grant">>)
    }.

with_fixture(Compiled, Fun) ->
    Base = filename:join(
        filename:absname("build/phase-05/integration-tests"),
        integer_to_list(erlang:system_time(nanosecond)) ++ "-" ++
            integer_to_list(erlang:unique_integer([monotonic, positive]))
    ),
    Workspace = filename:join(Base, "workspace"),
    StoreRoot = filename:join(Base, "store"),
    ok = filelib:ensure_dir(filename:join([Workspace, "results", ".keep"])),
    ArtifactPath = filename:join(Base, "program.beam"),
    ok = file:write_file(ArtifactPath, maps:get(beam, Compiled)),
    StoreOptions = #{root => StoreRoot, session_id => ?SESSION_ID, test_faults => true},
    State = initial_state(Compiled),
    initialize_store(StoreOptions, State, maps:get(artifact_digest, Compiled)),
    Fixture = maps:merge(Compiled, #{
        base => Base,
        workspace => Workspace,
        store_options => StoreOptions,
        artifact_path => ArtifactPath,
        target => filename:join([Workspace, "results", "phase-5.md"]),
        expected => #{
            state_schema => 1,
            abi_version => 1,
            artifact_digest => maps:get(artifact_digest, Compiled),
            module_name => <<"alang_phase3_program_v1">>,
            artifact_path => ArtifactPath
        }
    }),
    try Fun(Fixture)
    after _ = file:del_dir_r(Base)
    end.

initial_state(Compiled) ->
    {ok, State} = alang_phase5_state:new(#{
        session_id => ?SESSION_ID,
        generation => 1,
        program => #{
            artifact_digest => maps:get(artifact_digest, Compiled),
            module_name => <<"alang_phase3_program_v1">>,
            abi_version => 1,
            state_schema => 1
        },
        logical_state => #{<<"stage">> => <<"ready">>},
        budgets => #{<<"workspace.write">> => 1},
        deadline => erlang:system_time(millisecond) + 600000,
        authority => [#{
            grant_id => maps:get(grant_id, Compiled),
            invocations => [#{operation => <<"workspace.write">>, workspace_id => <<"workspace-a">>,
                path_prefix => [<<"results">>]}],
            budgets => #{<<"workspace.write">> => 1},
            expires_at => erlang:system_time(millisecond) + 600000,
            task_id => ?TASK_ID,
            combination => deny
        }]
    }),
    State.

initialize_store(StoreOptions, State, ArtifactDigest) ->
    {ok, Store} = alang_phase5_store:start(StoreOptions),
    {ok, Journal0} = alang_phase5_journal:new(?SESSION_ID),
    {ok, StateDigest} = alang_phase5_state:checkpoint_digest(State),
    {ok, Creation, Journal1} = alang_phase5_journal:append(
        Journal0, session_created, 1,
        #{state_digest => StateDigest, artifact_digest => ArtifactDigest},
        erlang:system_time(millisecond)),
    {ok, _} = alang_phase5_store:append(Store, Creation, deadline()),
    {ok, CheckpointRecord, Journal2} = alang_phase5_journal:append(
        Journal1, checkpoint, 1, #{state_digest => StateDigest},
        erlang:system_time(millisecond)),
    {ok, _} = alang_phase5_store:append(Store, CheckpointRecord, deadline()),
    {ok, _} = alang_phase5_store:checkpoint(
        Store, State, maps:get(next_sequence, Journal2), deadline()),
    alang_phase5_store:stop(Store).

start_workflow(Fixture, FailureStage, Controller) ->
    {ok, Supervisor, Recovery} = alang_phase5_resume:resume(resume_options(Fixture)),
    {ok, Topology} = alang_phase5_session_sup:topology(Supervisor),
    Authority = maps:get(recovered_authority, Recovery),
    Grant = maps:get(maps:get(grant_id, Fixture), maps:get(references, Authority)),
    {ok, Workflow} = alang_phase5_workflow:start(#{
        store => maps:get(durable_store, Topology),
        broker => maps:get(broker, Topology),
        state => maps:get(state, Recovery),
        grant => Grant,
        grant_id => maps:get(grant_id, Fixture),
        manifest => maps:get(manifest, Fixture),
        artifact_digest => maps:get(artifact_digest, Fixture),
        task_id => ?TASK_ID,
        owner_pid => maps:get(coordinator, Topology),
        failure_stage => FailureStage,
        controller => Controller
    }),
    {Supervisor, Recovery, Topology, Workflow, maps:get(beam, Fixture)}.

resume_options(Fixture) -> #{
    store_options => maps:get(store_options, Fixture),
    expected => maps:get(expected, Fixture),
    broker_options => broker_options(Fixture)
}.

broker_options(Fixture) -> #{
    limits => #{max_pending => 8, max_pending_per_session => 2, max_mailbox => 256,
        max_audit => 256, authorization_ttl_ms => 4000},
    policy => #{version => <<"phase5-policy-v1">>, workspaces => [<<"workspace-a">>],
        models => [<<"model-a">>]},
    adapter => #{
        workspace_id => <<"workspace-a">>,
        root => list_to_binary(maps:get(workspace, Fixture)),
        beam_dir => list_to_binary(filename:absname("build/phase-04/runtime")),
        test_faults => true,
        limits => #{max_request_bytes => 98304, max_response_bytes => 4096,
            max_content_bytes => 65536, max_cache_entries => 128,
            request_timeout_ms => 2000, address_space_bytes => 2147483648,
            cpu_seconds => 5, open_files => 64, file_size_bytes => 67108864,
            processes => 4096}
    }
}.

handler(Workflow) -> fun(Operation, Arguments, GatewayContext) ->
    alang_phase5_workflow:handle_effect(Workflow, Operation, Arguments, GatewayContext)
end.

runtime_options(Handler) -> #{
    handler => Handler,
    session_id => ?SESSION_ID,
    timeout => 10000,
    max_in_flight => 1,
    max_mailbox => 32,
    max_trace_events => 128
}.

read_store(Fixture) ->
    {ok, Store} = alang_phase5_store:start(maps:get(store_options, Fixture)),
    try alang_phase5_store:read(Store, deadline())
    after alang_phase5_store:stop(Store)
    end.

read_store_live(Store) -> alang_phase5_store:read(Store, deadline()).

completed_recovery(Fixture) ->
    case alang_phase5_resume:resume(resume_options(Fixture)) of
        {completed, Recovery} -> {completed, Recovery};
        Other -> Other
    end.

final_evidence(Fixture) ->
    {ok, Snapshot} = read_store(Fixture),
    {ok, _} = alang_phase5_journal:validate(maps:get(records, Snapshot), ?SESSION_ID),
    #{state := State} = maps:get(checkpoint, Snapshot),
    #{
        operation_count => operation_count(Fixture),
        actual_artifact_digest => stable_digest(maps:get(content, Fixture)),
        expected_artifact_digest => maps:get(content_digest, Fixture),
        journal_valid => true,
        checkpoint_valid => alang_phase5_state:validate(State) =:= ok,
        pending => maps:get(pending, State),
        terminal => maps:get(terminal, State),
        remaining_budget => maps:get(<<"workspace.write">>, maps:get(budgets, State)),
        stale_rejected => true
    }.

operation_count(Fixture) ->
    length(filelib:wildcard(filename:join([
        maps:get(workspace, Fixture), ".alang-operations", "*.term"
    ]))).

write_node_config(Fixture) ->
    Config = #{
        resume_options => resume_options(Fixture),
        artifact_path => maps:get(artifact_path, Fixture),
        artifact_digest => maps:get(artifact_digest, Fixture),
        manifest => maps:get(manifest, Fixture),
        grant_id => maps:get(grant_id, Fixture),
        task_id => ?TASK_ID,
        session_id => ?SESSION_ID
    },
    Path = filename:join(maps:get(base, Fixture), "node-fixture.config"),
    ok = file:write_file(Path, term_to_binary(Config, [deterministic])),
    Path.

launch_node_fixture(ConfigPath) ->
    Erl = filename:join([code:root_dir(), "erts-" ++ erlang:system_info(version), "bin", "erl"]),
    Paths = [filename:absname(Path) || Path <- [
        "build/phase-01/bootstrap", "build/phase-02/compiler", "build/phase-03/compiler",
        "build/phase-04/runtime", "build/phase-05/runtime"
    ]],
    PathArguments = lists:append([["-pa", Path] || Path <- Paths]),
    Arguments = ["+S", "1:1", "+SDio", "1", "+SDcpu", "1", "-noshell", "-noinput"] ++
        PathArguments ++ ["-s", "alang_phase5_node_fixture", "main", "-extra", ConfigPath],
    Port = open_port({spawn_executable, Erl}, [binary, exit_status, stderr_to_stdout,
        use_stdio, hide, {line, 4096}, {args, Arguments}]),
    {os_pid, OsPid} = erlang:port_info(Port, os_pid),
    {Port, OsPid}.

await_node_marker(_Port, 0) -> {error, node_marker_timeout};
await_node_marker(Port, Attempts) ->
    receive
        {Port, {data, {eol, Line}}} ->
            case binary:match(Line, <<"PHASE5_NODE_READY_AFTER_MUTATION">>) of
                nomatch ->
                    case binary:match(Line, <<"PHASE5_NODE_">>) of
                        nomatch -> await_node_marker(Port, Attempts - 1);
                        _ -> {error, {node_fixture_error, Line}}
                    end;
                _ -> ok
            end;
        {Port, {data, {noeol, _Line}}} -> await_node_marker(Port, Attempts - 1);
        {Port, {exit_status, Status}} -> {error, {node_exited_early, Status}}
    after 50 -> await_node_marker(Port, Attempts - 1)
    end.

kill_os_process(OsPid) ->
    Port = open_port({spawn_executable, "/bin/kill"}, [exit_status, hide,
        {args, ["-KILL", integer_to_list(OsPid)]}]),
    receive
        {Port, {exit_status, 0}} -> ok;
        {Port, {exit_status, Status}} -> {error, {kill_failed, Status}}
    after 2000 -> {error, kill_timeout}
    end.

await_port_exit(_Port, 0) -> {error, node_exit_timeout};
await_port_exit(Port, Attempts) ->
    receive
        {Port, {exit_status, _Status}} -> ok;
        {Port, _Other} -> await_port_exit(Port, Attempts - 1)
    after 50 -> await_port_exit(Port, Attempts - 1)
    end.

safe_stop_workflow(Workflow) ->
    case is_process_alive(Workflow) of
        true -> alang_phase5_workflow:stop(Workflow);
        false -> ok
    end.

envelope(Generation) -> #{
    format => alang_runtime_envelope_v1,
    generation => Generation,
    correlation_id => stable_digest(<<"stale-correlation">>),
    payload_digest => stable_digest(<<"stale-payload">>),
    payload => stale
}.

deadline() -> erlang:monotonic_time(millisecond) + 3000.

stable_digest(Binary) when is_binary(Binary) -> hex(crypto:hash(sha256, Binary));
stable_digest(Term) -> hex(crypto:hash(sha256, term_to_binary(Term, [deterministic]))).

hex(Binary) -> << <<(hex_digit(Nibble))>> || <<Nibble:4>> <= Binary >>.

hex_digit(Nibble) when Nibble < 10 -> $0 + Nibble;
hex_digit(Nibble) -> $a + Nibble - 10.
