-module(alang_phase8_demo).

-export([main/0, run/1]).

-define(TOOLCHAIN, "src/phase-01/toolchain.config").
-define(FIXTURES, "src/phase-08/fixtures").
-define(SOURCE_TASK, <<"task:Counter.successor/1">>).
-define(CHILD_TASK, <<"task:phase8.child/0">>).
-define(WORKSPACE_TASK, <<"task:Workspace.write/0">>).
-define(PARENT_SESSION, <<"phase8-parent-session">>).
-define(CHILD_SESSION, <<"phase8-child-session">>).
-define(WORKSPACE_SESSION, <<"phase8-workspace-session">>).

-spec main() -> no_return().
main() ->
    Output = case init:get_plain_arguments() of
        [Path] -> Path;
        [] -> "build/phase-08/demo";
        Arguments -> fail_main({invalid_arguments, Arguments})
    end,
    case run(Output) of
        {ok, Evidence} ->
            io:format("phase8_demo_ok evidence_sha256=~s output=~s~n",
                [maps:get(evidence_digest, Evidence), Output]),
            halt(0);
        {error, Reason} -> fail_main(Reason)
    end.

-spec run(file:filename()) -> {ok, map()} | {error, term()}.
run(Output0) ->
    try
        Output = prepare_output(Output0),
        Fixtures = load_fixtures(),
        Source = compile_source_program(Fixtures),
        Programs = compile_effect_programs(Fixtures),
        Execution = execute_workflow(Output, Fixtures, Source, Programs),
        Evidence0 = evidence(Fixtures, Source, Programs, Execution),
        Evidence = Evidence0#{evidence_digest => digest(Evidence0)},
        ok = verify_expected(maps:get(expected, Fixtures), Evidence),
        ok = write_bundle(Output, Fixtures, Source, Programs, Evidence),
        {ok, Evidence}
    catch
        Class:Reason:Stack -> {error, #{class => Class, reason => Reason,
            stack_digest => digest(Stack)}}
    end.

fail_main(Reason) ->
    io:format(standard_error, "phase8_demo_error ~tp~n", [Reason]),
    halt(1).

prepare_output(Output0) ->
    Output = filename:absname(Output0),
    Root = filename:absname("build/phase-08"),
    Prefix = Root ++ "/",
    true = lists:prefix(Prefix, Output),
    _ = file:del_dir_r(Output),
    ok = filelib:ensure_dir(filename:join(Output, ".keep")),
    Output.

load_fixtures() ->
    #{model => consult_one("model-fixture.config"),
        grants => consult_one("grant-fixture.config"),
        manifests => consult_one("expected-manifest.config"),
        trace => consult_one("expected-trace.config"),
        expected => consult_one("expected.config"),
        source_path => filename:join(?FIXTURES, "demo.alang"),
        output_path => filename:join(?FIXTURES, "expected-output.txt")}.

consult_one(Name) ->
    {ok, [Term]} = file:consult(filename:join(?FIXTURES, Name)),
    Term.

compile_source_program(Fixtures) ->
    {ok, SourceBinary} = file:read_file(maps:get(source_path, Fixtures)),
    {ok, Product} = alang_phase2_compiler:compile_source(SourceBinary),
    Manifest = maps:get(source, maps:get(manifests, Fixtures)),
    {ok, Compiled} = alang_phase3_backend:compile_ir(maps:get(ir, Product),
        #{source_sha256 => digest_binary(SourceBinary), capability_manifest => Manifest},
        ?TOOLCHAIN),
    Beam = maps:get(beam, Compiled),
    {ok, Inspection} = alang_phase3_artifact:inspect(Beam),
    {ok, Runtime} = alang_phase3_artifact:run(Beam, ?SOURCE_TASK,
        #{<<"value">> => 41}, runtime_options(fun unexpected_effect/2, ?PARENT_SESSION)),
    #{source => SourceBinary, product => Product, beam => Beam,
        inspection => Inspection, runtime => Runtime, manifest => Manifest}.

compile_effect_programs(Fixtures) ->
    Model = maps:get(model, Fixtures),
    Manifests = maps:get(manifests, Fixtures),
    ChildIr = alang_phase6_integration_fixture:model_ir(?CHILD_TASK,
        maps:get(model_id, Model), maps:get(instruction, Model),
        maps:get(operation_id, Model)),
    Child = compile_ir(ChildIr, <<"phase8-child-source">>,
        maps:get(child, Manifests)),
    {ok, TransitionId} = alang_phase5_journal:transition_id(?WORKSPACE_SESSION, 1),
    {ok, OperationId} = alang_phase5_journal:operation_id(
        ?WORKSPACE_SESSION, TransitionId, 0),
    {ok, Content} = file:read_file(maps:get(output_path, Fixtures)),
    WorkspaceIr = alang_phase4_integration_fixture:workspace_ir(
        <<"workspace-a">>, <<"reports/poc-result.md">>, Content, OperationId),
    Workspace = compile_ir(WorkspaceIr, <<"phase8-workspace-source">>,
        maps:get(workspace, Manifests)),
    #{child => Child, workspace => Workspace, workspace_operation_id => OperationId,
        output => Content}.

compile_ir(Ir, SourceIdentity, Manifest) ->
    {ok, Compiled} = alang_phase3_backend:compile_ir(Ir,
        #{source_sha256 => digest_binary(SourceIdentity), capability_manifest => Manifest},
        ?TOOLCHAIN),
    Beam = maps:get(beam, Compiled),
    {ok, Inspection} = alang_phase3_artifact:inspect(Beam),
    #{ir => Ir, beam => Beam, inspection => Inspection, manifest => Manifest,
        artifact_digest => maps:get(beam_sha256, Inspection)}.

execute_workflow(Output, Fixtures, Source, Programs) ->
    WorkspaceRoot = filename:join(Output, "workspace"),
    StoreRoot = filename:join(Output, "durable-store"),
    ok = filelib:ensure_dir(filename:join([WorkspaceRoot, "reports", ".keep"])),
    Deadline = erlang:monotonic_time(millisecond) + 60000,
    Request = model_request(maps:get(model, Fixtures), Deadline),
    {ok, RequestDigest} = alang_phase6_model_protocol:request_digest(Request),
    Profile = maps:get(profile, Request),
    MockOptions = #{profiles => [Profile], max_calls => 1,
        fixtures => #{RequestDigest => #{status => success,
            output => maps:get(output, Programs)}}},
    BrokerOptions = broker_options(WorkspaceRoot),
    {ok, Broker} = alang_phase4_broker:start_link(BrokerOptions),
    {ok, Mock} = alang_phase6_mock_model:start_link(MockOptions),
    {ok, ChildSupervisor} = alang_phase6_child_sup:start_link(),
    try
        ParentSpec = parent_grant_spec(Fixtures, Source, Deadline),
        {ok, ParentGrant} = alang_phase4_broker:issue_grant(Broker, ParentSpec),
        {ChildResult, ChildRuntime, ChildSnapshot} = execute_child(
            Fixtures, Programs, Request, Broker, Mock, ChildSupervisor,
            ParentGrant, Deadline),
        WorkspaceExecution = execute_workspace(Output, StoreRoot, WorkspaceRoot,
            Fixtures, Programs, Broker, ParentGrant, Deadline),
        Audit = normalize_audit(alang_phase4_broker:audit(Broker)),
        #{child_result => ChildResult, child_runtime => ChildRuntime,
            child_snapshot => ChildSnapshot, model_status => alang_phase6_mock_model:status(Mock),
            broker_audit => Audit, workspace => WorkspaceExecution}
    after
        alang_phase6_child_sup:stop(ChildSupervisor),
        alang_phase6_mock_model:stop(Mock),
        gen_server:stop(Broker)
    end.

execute_child(Fixtures, Programs, Request, Broker, Mock, ChildSupervisor,
    ParentGrant, Deadline) ->
    Child = maps:get(child, Programs),
    Model = maps:get(model, Fixtures),
    Spec = child_spec(Child, Model, Deadline),
    Restriction0 = maps:get(child, maps:get(grants, Fixtures)),
    Restriction = Restriction0#{deadline => Deadline - 1000},
    Collector = self(),
    Handler = fun(_AssignedSpec, ChildGrant, ChildContext) ->
        RuntimeHandler = model_handler(Broker, ChildGrant, ChildContext,
            Mock, Request, maps:get(manifest, Child)),
        case alang_phase3_artifact:run(maps:get(beam, Child), ?CHILD_TASK, #{},
            runtime_options(RuntimeHandler, ?CHILD_SESSION)) of
            {ok, Runtime} ->
                Collector ! {phase8_child_runtime, Runtime},
                Output = maps:get(value, Runtime),
                #{format => alang_child_result_v1, status => complete, output => Output,
                    evidence_digest => digest_binary(Output)};
            {error, _Reason} ->
                #{format => alang_child_result_v1, status => failed, reason => model_failure}
        end
    end,
    {ok, Handle} = alang_phase6_child:start(ChildSupervisor, Broker, ParentGrant,
        Spec, Restriction, Handler),
    Snapshot = alang_phase6_child:snapshot(Handle),
    {ok, Result} = alang_phase6_child:await(Handle, 5000),
    Runtime = receive
        {phase8_child_runtime, ChildRuntime} -> ChildRuntime
    after 2000 -> error(child_runtime_evidence_missing)
    end,
    {Result, Runtime, Snapshot}.

model_handler(Broker, Grant, Binding, Mock, Request, Manifest) ->
    fun(<<"model.complete">> = Operation, Arguments, GatewayContext) ->
        {ok, Decoded} = alang_phase4_effect_registry:decode_abi(Operation, Arguments),
        RequestOperation = maps:get(operation_id, Request),
        RequestOperation = maps:get(operation_id, maps:get(arguments, Decoded)),
        Context = maps:merge(Binding, #{
            presenter_pid => maps:get(requester_pid, GatewayContext),
            request_deadline => maps:get(deadline, GatewayContext),
            cancelled => false,
            correlation_id => maps:get(correlation_id, GatewayContext)}),
        {ok, Authorization} = alang_phase4_broker:authorize(
            Broker, Grant, Manifest, Operation, Arguments, Context),
        {ok, Result} = alang_phase6_mock_model:complete(
            Mock, Request, maps:get(deadline, GatewayContext)),
        ok = alang_phase4_broker:complete(Broker, Authorization, succeeded),
        {ok, maps:get(output, Result)}
    end.

execute_workspace(Output, StoreRoot, WorkspaceRoot, Fixtures, Programs,
    Broker, ParentGrant, Deadline) ->
    Workspace = maps:get(workspace, Programs),
    Owner = spawn(fun owner_loop/0),
    try
        Restriction0 = maps:get(workspace, maps:get(grants, Fixtures)),
        Restriction = Restriction0#{deadline => Deadline - 500},
        Binding = #{owner_pid => Owner, session_id => ?WORKSPACE_SESSION,
            artifact_digest => maps:get(artifact_digest, Workspace),
            task_id => ?WORKSPACE_TASK},
        {ok, Grant} = alang_phase4_broker:restrict_child_grant(
            Broker, ParentGrant, Restriction, Binding),
        GrantId = digest({phase8_workspace_grant, maps:get(artifact_digest, Workspace)}),
        StoreOptions = #{root => StoreRoot, session_id => ?WORKSPACE_SESSION,
            test_faults => false},
        State = workspace_state(Workspace, GrantId),
        ok = initialize_store(StoreOptions, State, maps:get(artifact_digest, Workspace)),
        {ok, Store} = alang_phase5_store:start(StoreOptions),
        {ok, Workflow} = alang_phase5_workflow:start(#{store => Store,
            broker => Broker, state => State, grant => Grant, grant_id => GrantId,
            manifest => maps:get(manifest, Workspace),
            artifact_digest => maps:get(artifact_digest, Workspace),
            task_id => ?WORKSPACE_TASK, owner_pid => Owner,
            failure_stage => none, controller => undefined}),
        try
            RuntimeHandler = fun(Operation, Arguments, GatewayContext) ->
                alang_phase5_workflow:handle_effect(
                    Workflow, Operation, Arguments, GatewayContext)
            end,
            {ok, Runtime} = alang_phase3_artifact:run(maps:get(beam, Workspace),
                ?WORKSPACE_TASK, #{}, runtime_options(RuntimeHandler, ?WORKSPACE_SESSION)),
            Snapshot0 = alang_phase5_workflow:snapshot(Workflow),
            {ok, Completion} = alang_phase5_workflow:finalize(
                Workflow, maps:get(artifact_digest, Workspace)),
            {ok, StoreSnapshot} = alang_phase5_store:read(Store, deadline()),
            {ok, _Journal} = alang_phase5_journal:validate(
                maps:get(records, StoreSnapshot), ?WORKSPACE_SESSION),
            OutputDigest = digest_binary(maps:get(output, Programs)),
            JournalEvidence = #{format => alang_workspace_result_evidence_v1,
                operation_id => maps:get(workspace_operation_id, Programs),
                operation => <<"workspace.write">>,
                relative_path => <<"reports/poc-result.md">>,
                artifact_digest => OutputDigest,
                result_digest => maps:get(result_digest, Snapshot0), outcome => succeeded},
            {ok, Witness} = alang_phase6_verifier:verify(#{
                format => alang_completion_spec_v1,
                workspace_root => WorkspaceRoot,
                relative_path => <<"reports/poc-result.md">>,
                expected_digest => OutputDigest, max_bytes => 4096,
                required_section => <<"Findings">>, journal_result => JournalEvidence}),
            #{runtime => Runtime, completion => Completion, witness => Witness,
                journal => normalize_journal(maps:get(records, StoreSnapshot)),
                output_file => filename:join(Output, "workspace/reports/poc-result.md")}
        after
            safe_stop_workflow(Workflow),
            alang_phase5_store:stop(Store)
        end
    after
        Owner ! stop
    end.

workspace_state(Workspace, GrantId) ->
    {ok, State} = alang_phase5_state:new(#{session_id => ?WORKSPACE_SESSION,
        generation => 1,
        program => #{artifact_digest => maps:get(artifact_digest, Workspace),
            module_name => <<"alang_phase3_program_v1">>, abi_version => 1,
            state_schema => 1},
        logical_state => #{<<"stage">> => <<"ready">>},
        budgets => #{<<"workspace.write">> => 1},
        deadline => erlang:system_time(millisecond) + 600000,
        authority => [#{grant_id => GrantId,
            invocations => [#{operation => <<"workspace.write">>,
                workspace_id => <<"workspace-a">>, path_prefix => [<<"reports">>]}],
            budgets => #{<<"workspace.write">> => 1},
            expires_at => erlang:system_time(millisecond) + 600000,
            task_id => ?WORKSPACE_TASK, combination => deny}]}),
    State.

initialize_store(StoreOptions, State, ArtifactDigest) ->
    {ok, Store} = alang_phase5_store:start(StoreOptions),
    try
        {ok, Journal0} = alang_phase5_journal:new(?WORKSPACE_SESSION),
        {ok, StateDigest} = alang_phase5_state:checkpoint_digest(State),
        {ok, Creation, Journal1} = alang_phase5_journal:append(Journal0,
            session_created, 1, #{state_digest => StateDigest,
                artifact_digest => ArtifactDigest}, erlang:system_time(millisecond)),
        {ok, _} = alang_phase5_store:append(Store, Creation, deadline()),
        {ok, Checkpoint, Journal2} = alang_phase5_journal:append(Journal1,
            checkpoint, 1, #{state_digest => StateDigest}, erlang:system_time(millisecond)),
        {ok, _} = alang_phase5_store:append(Store, Checkpoint, deadline()),
        {ok, _} = alang_phase5_store:checkpoint(Store, State,
            maps:get(next_sequence, Journal2), deadline()),
        ok
    after
        alang_phase5_store:stop(Store)
    end.

evidence(Fixtures, Source, Programs, Execution) ->
    Product = maps:get(product, Source),
    WorkspaceExecution = maps:get(workspace, Execution),
    #{format => alang_phase8_evidence_v1,
        source => #{task => ?SOURCE_TASK, input => 41,
            result => maps:get(value, maps:get(runtime, Source)),
            canonical_sha256 => digest_binary(maps:get(canonical, Product)),
            ir_sha256 => digest(maps:get(ir, Product)),
            observation => alang_phase7_observation:runtime(maps:get(runtime, Source))},
        artifacts => #{
            source => artifact_summary("source.beam", Source),
            child => artifact_summary("child.beam", maps:get(child, Programs)),
            workspace => artifact_summary("workspace.beam", maps:get(workspace, Programs))},
        manifests => maps:get(manifests, Fixtures),
        model => maps:get(model_status, Execution),
        child => #{result => maps:get(child_result, Execution),
            handle => normalize_child_handle(maps:get(child_snapshot, Execution)),
            observation => alang_phase7_observation:runtime(
                maps:get(child_runtime, Execution))},
        broker => #{audit => maps:get(broker_audit, Execution)},
        durability => #{journal => maps:get(journal, WorkspaceExecution),
            completion => normalize_completion(maps:get(completion, WorkspaceExecution))},
        workspace => #{relative_path => <<"reports/poc-result.md">>,
            artifact_digest => digest_binary(maps:get(output, Programs)),
            observation => alang_phase7_observation:runtime(
                maps:get(runtime, WorkspaceExecution))},
        completion_witness => maps:get(witness, WorkspaceExecution),
        normalized_stages => maps:get(stages, maps:get(trace, Fixtures)),
        security => #{network => disabled, secrets => none,
            capability_references_serialized => false},
        limits => #{model_calls => 1, workspace_writes => 1,
            child_tasks => 1, runtime_timeout_ms => 10000}}.

artifact_summary(File, #{beam := Beam, inspection := Inspection, manifest := Manifest}) ->
    Metadata = maps:get(metadata, Inspection),
    #{file => list_to_binary(File), beam_sha256 => maps:get(beam_sha256, Inspection),
        bytes => byte_size(Beam), module => maps:get(module, Inspection),
        policy => maps:get(policy, Inspection), abi => maps:get(abi, Metadata),
        manifest => Manifest}.

normalize_audit(#{events := Events}) ->
    [maps:with([sequence, operation, decision, reason], Event) || Event <- Events,
        lists:member(maps:get(decision, Event), [allow, deny, completion])].

normalize_journal(Records) ->
    [maps:with([sequence, generation, kind], Record) || Record <- Records].

normalize_child_handle(Handle) ->
    maps:with([format, session_id, child_task_id, parent_task_id, correlation_id],
        Handle).

normalize_completion(Completion) ->
    maps:with([artifact_digest, journal_records], Completion).

verify_expected(Expected, Evidence) ->
    Source = maps:get(source, Evidence),
    Artifacts = maps:get(artifacts, Evidence),
    Checks = [
        {source_result, maps:get(source_result, Expected), maps:get(result, Source)},
        {source_canonical_sha256, maps:get(source_canonical_sha256, Expected),
            maps:get(canonical_sha256, Source)},
        {source_ir_sha256, maps:get(source_ir_sha256, Expected), maps:get(ir_sha256, Source)},
        {source_beam_sha256, maps:get(source_beam_sha256, Expected),
            maps:get(beam_sha256, maps:get(source, Artifacts))},
        {child_beam_sha256, maps:get(child_beam_sha256, Expected),
            maps:get(beam_sha256, maps:get(child, Artifacts))},
        {workspace_beam_sha256, maps:get(workspace_beam_sha256, Expected),
            maps:get(beam_sha256, maps:get(workspace, Artifacts))},
        {output_sha256, maps:get(output_sha256, Expected),
            maps:get(artifact_digest, maps:get(workspace, Evidence))},
        {witness_digest, maps:get(witness_digest, Expected),
            maps:get(witness_digest, maps:get(completion_witness, Evidence))},
        {evidence_digest, maps:get(evidence_digest, Expected),
            maps:get(evidence_digest, Evidence)}
    ],
    case [{Name, Wanted, Actual} || {Name, Wanted, Actual} <- Checks,
        Wanted =/= Actual] of
        [] -> ok;
        Differences -> error({expected_evidence_mismatch, Differences})
    end.

write_bundle(Output, Fixtures, Source, Programs, Evidence) ->
    Product = maps:get(product, Source),
    Writes = [
        file:write_file(filename:join(Output, "source.alang"), maps:get(source, Source)),
        file:write_file(filename:join(Output, "canonical-source.etf"),
            maps:get(canonical, Product)),
        file:write_file(filename:join(Output, "typed-task-ir.etf"),
            term_to_binary(maps:get(ir, Product), [deterministic])),
        file:write_file(filename:join(Output, "source.beam"), maps:get(beam, Source)),
        file:write_file(filename:join(Output, "child.beam"),
            maps:get(beam, maps:get(child, Programs))),
        file:write_file(filename:join(Output, "workspace.beam"),
            maps:get(beam, maps:get(workspace, Programs))),
        write_term(filename:join(Output, "evidence.config"), Evidence),
        file:write_file(filename:join(Output, "explanation.md"),
            explanation(Fixtures, Evidence))
    ],
    case [Error || Error <- Writes, Error =/= ok] of
        [] -> ok;
        Errors -> error({bundle_write_failed, Errors})
    end.

write_term(Path, Term) -> file:write_file(Path, io_lib:format("~tp.~n", [Term])).

explanation(Fixtures, Evidence) ->
    Model = maps:get(model, Fixtures),
    Workspace = maps:get(workspace, Evidence),
    Witness = maps:get(completion_witness, Evidence),
    io_lib:format("# A-Lang Phase 8 Demonstration\n\n"
        "## Task\n\nCompile `~s`, run input 41, delegate one bounded model task, and write "
        "the verified report.\n\n## Effects and authority\n\nThe source task is pure. "
        "The child receives only `model.complete` for `~s`; the workspace worker "
        "receives one `workspace.write` beneath `reports/`. Opaque grants are not "
        "serialized.\n\n## Result\n\nThe source result is ~p. The artifact at `~s` "
        "has SHA-256 `~s`. Completion is `~p` with witness `~s`.\n\n"
        "## Uncertainty\n\nNo effect remains uncertain. The model is deterministic, offline, "
        "and limited to one call.\n",
        [?SOURCE_TASK, maps:get(model_id, Model),
            maps:get(result, maps:get(source, Evidence)),
            maps:get(relative_path, Workspace), maps:get(artifact_digest, Workspace),
            maps:get(status, Witness), maps:get(witness_digest, Witness)]).

model_request(Model, Deadline) ->
    {ok, Slice} = alang_phase6_context:slice(#{
        goal => candidate(<<"goal">>, goal, public, instruction, maps:get(goal, Model)),
        inputs => [candidate(<<"source">>, input, task_local, data_only,
            maps:get(source, Model))],
        actions => [#{operation => <<"model.complete">>,
            requirement => <<"model:complete">>,
            constraints => [<<"model=fixture-model-v1">>]}],
        evidence => [], diagnostics => []},
        #{max_context_bytes => 8192, max_fragments => 8}),
    {ok, Request} = alang_phase6_model_protocol:new_request(#{
        operation_id => maps:get(operation_id, Model), profile => profile(Model),
        context => maps:get(fragments, Slice), instruction => maps:get(instruction, Model),
        output_schema => #{format => alang_output_schema_v1, id => markdown_draft_v1,
            max_bytes => 4096, required_sections => [<<"Findings">>]},
        deadline => Deadline, retry_class => repair_only,
        redaction_policy => #{format => alang_redaction_policy_v1,
            trace_content => digest_only, retain_provider_fields => []},
        provenance => #{format => alang_model_provenance_v1, task_id => ?CHILD_TASK,
            goal_digest => digest(maps:get(goal, Model)), parent_call_id => none}}),
    Request.

profile(Model) -> #{format => alang_model_profile_v1,
    id => <<"phase8-mock-v1">>, provider_class => mock,
    model => maps:get(model_id, Model),
    sampling => #{temperature_milli => 0, top_p_milli => 1000},
    max_input_bytes => 16384, max_output_bytes => 8192, max_tokens => 8192,
    timeout_ms => 3000}.

candidate(Id, Kind, Visibility, Trust, Content) -> #{id => Id, kind => Kind,
    visibility => Visibility, provenance => digest({Id, Content}), trust => Trust,
    content => Content}.

child_spec(Child, Model, Deadline) -> #{format => alang_child_spec_v1,
    parent_task_id => ?SOURCE_TASK, child_task_id => ?CHILD_TASK,
    session_id => ?CHILD_SESSION, artifact_digest => maps:get(artifact_digest, Child),
    deadline => Deadline, input => #{topic => maps:get(goal, Model),
        source_draft => maps:get(source, Model)},
    output_schema => #{format => alang_output_schema_v1, id => markdown_draft_v1,
        max_bytes => 4096, required_sections => [<<"Findings">>]},
    completion_predicate => #{format => alang_child_completion_v1,
        required_section => <<"Findings">>, minimum_bytes => 32},
    capability_summary => #{operations => [<<"model.complete">>],
        constraints => [<<"model=fixture-model-v1">>, <<"calls<=1">>]}}.

parent_grant_spec(Fixtures, Source, Deadline) ->
    Parent0 = maps:get(parent, maps:get(grants, Fixtures)),
    Parent0#{deadline => Deadline, owner_pid => self(),
        session_id => ?PARENT_SESSION,
        artifact_digest => maps:get(beam_sha256, maps:get(inspection, Source)),
        task_id => ?SOURCE_TASK}.

broker_options(WorkspaceRoot) -> #{
    limits => #{max_pending => 8, max_pending_per_session => 4,
        max_mailbox => 256, max_audit => 256, authorization_ttl_ms => 4000},
    policy => #{version => <<"phase8-demo-policy-v1">>,
        workspaces => [<<"workspace-a">>], models => [<<"fixture-model-v1">>]},
    adapter => #{workspace_id => <<"workspace-a">>,
        root => list_to_binary(WorkspaceRoot),
        beam_dir => list_to_binary(filename:absname("build/phase-04/runtime")),
        test_faults => false,
        limits => #{max_request_bytes => 98304, max_response_bytes => 4096,
            max_content_bytes => 65536, max_cache_entries => 128,
            request_timeout_ms => 2000, address_space_bytes => 2147483648,
            cpu_seconds => 5, open_files => 64, file_size_bytes => 67108864,
            processes => 4096}}}.

runtime_options(Handler, SessionId) -> #{handler => Handler,
    session_id => SessionId, timeout => 10000, max_in_flight => 1,
    max_mailbox => 32, max_trace_events => 128}.

unexpected_effect(_Operation, _Arguments) -> {error, <<"unexpected-effect">>}.
owner_loop() -> receive stop -> ok end.
deadline() -> erlang:monotonic_time(millisecond) + 3000.

safe_stop_workflow(Workflow) ->
    case is_process_alive(Workflow) of
        true -> alang_phase5_workflow:stop(Workflow);
        false -> ok
    end.

digest_binary(Binary) -> hex(crypto:hash(sha256, Binary)).
digest(Term) -> hex(crypto:hash(sha256, term_to_binary(Term, [deterministic]))).
hex(Binary) -> << <<(hex_digit(Nibble))>> || <<Nibble:4>> <= Binary >>.
hex_digit(Nibble) when Nibble < 10 -> $0 + Nibble;
hex_digit(Nibble) -> $a + Nibble - 10.
