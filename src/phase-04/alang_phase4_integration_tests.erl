-module(alang_phase4_integration_tests).

-include_lib("eunit/include/eunit.hrl").

-define(TOOLCHAIN, "src/phase-01/toolchain.config").
-define(TASK_ID, <<"task:Workspace.write/0">>).
-define(SESSION_ID, <<"phase4-integration-session">>).

compiled_beam_effect_runs_only_through_broker_and_adapter_test() ->
    with_workspace(fun(Root, _Outside, BeamDir) ->
        Content = <<"phase-4 authorized result">>,
        Compiled = compiled_fixture(Content),
        Beam = maps:get(beam, Compiled),
        {ok, Inspection} = alang_phase3_artifact:inspect(Beam),
        Metadata = maps:get(metadata, Inspection),
        Manifest = maps:get(capability_manifest, Metadata),
        ArtifactDigest = maps:get(beam_sha256, Inspection),
        {ok, Supervisor} = alang_phase4_broker_sup:start_link(
            broker_options(Root, BeamDir, [<<"workspace-a">>])
        ),
        try
            {ok, Broker} = alang_phase4_broker_sup:broker(Supervisor),
            Now = erlang:monotonic_time(millisecond),
            Spec = grant_spec(self(), Now, 1, <<"workspace-a">>, [<<"results">>],
                ?SESSION_ID, ArtifactDigest, ?TASK_ID),
            {ok, Grant} = alang_phase4_broker:issue_grant(Broker, Spec),
            Parent = self(),
            Handler = fun(Operation, Arguments, GatewayContext) ->
                Parent ! {beam_ownership, process_evidence(Broker, GatewayContext)},
                Context = broker_context(Broker, Spec, GatewayContext),
                alang_phase4_broker:request(
                    Broker,
                    Grant,
                    Manifest,
                    Operation,
                    Arguments,
                    Context
                )
            end,
            {ok, Result} = alang_phase3_artifact:run(
                Beam,
                ?TASK_ID,
                #{},
                runtime_options(Handler, ?SESSION_ID)
            ),
            Digest = hex(crypto:hash(sha256, Content)),
            ?assertEqual({alang_data_v1, ok, Digest}, maps:get(value, Result)),
            Target = filename:join([Root, "results", "phase-4.md"]),
            ?assertEqual({ok, Content}, file:read_file(Target)),
            ?assertEqual([Target], filelib:wildcard(filename:join([Root, "results", "*"]))),
            assert_trace_kinds(maps:get(trace, Result),
                [task_start, effect_intent, effect_result, completion]),
            Audit = alang_phase4_broker:audit(Broker),
            assert_audit_path(Audit),
            {ok, AdapterEvents} = alang_phase4_broker:adapter_events(Broker),
            ?assertEqual([request, success], [maps:get(kind, Event) || Event <- AdapterEvents]),
            {ok, AdapterStatus} = alang_phase4_broker:adapter_status(Broker),
            ?assertEqual(beam_sidecar,
                maps:get(runtime, maps:get(isolation, AdapterStatus))),
            Evidence = receive
                {beam_ownership, Snapshot} -> Snapshot
            after 1000 -> error(missing_beam_ownership_evidence)
            end,
            assert_beam_ownership(Evidence, Inspection),
            ?assertEqual(false, code:is_loaded(alang_phase3_program_v1))
        after
            alang_phase4_broker_sup:stop(Supervisor)
        end
    end).

least_authority_denials_do_not_reach_the_adapter_test() ->
    with_workspace(fun(Root, _Outside, BeamDir) ->
        {ok, Supervisor} = alang_phase4_broker_sup:start_link(
            broker_options(Root, BeamDir, [<<"workspace-a">>])
        ),
        try
            {ok, Broker} = alang_phase4_broker_sup:broker(Supervisor),
            Now = erlang:monotonic_time(millisecond),
            Digest = binary:copy(<<"a">>, 64),
            Spec = grant_spec(self(), Now, 5, <<"workspace-a">>, [<<"allowed">>],
                <<"session-a">>, Digest, <<"task:a">>),
            {ok, Grant} = alang_phase4_broker:issue_grant(Broker, Spec),
            Context = direct_context(Broker, Spec, Now + 5000, false, <<"denial">>),
            AllowedArguments = workspace_arguments(
                <<"workspace-a">>, <<"allowed/result.md">>, <<"denied">>, <<"denied-op">>
            ),
            Manifest = manifest([<<"workspace.write">>]),
            {ok, BeforeGrant} = alang_phase4_broker:describe_grant(Broker, Grant),
            {ok, BeforeEvents} = alang_phase4_broker:adapter_events(Broker),
            Denials = [
                alang_phase4_broker:request(Broker, make_ref(), Manifest,
                    <<"workspace.write">>, AllowedArguments, Context),
                alang_phase4_broker:request(Broker, Grant, Manifest,
                    <<"workspace.write">>, AllowedArguments,
                    Context#{session_id := <<"wrong-session">>, correlation_id := <<"wrong-session">>}),
                alang_phase4_broker:request(Broker, Grant, Manifest,
                    <<"workspace.write">>, workspace_arguments(
                        <<"workspace-a">>, <<"outside/result.md">>, <<"denied">>, <<"scope-op">>
                    ), Context#{correlation_id := <<"scope">>}),
                alang_phase4_broker:request(Broker, Grant, manifest([<<"model.complete">>]),
                    <<"workspace.write">>, AllowedArguments,
                    Context#{correlation_id := <<"undeclared">>}),
                alang_phase4_broker:request(Broker, Grant, Manifest,
                    <<"workspace.write">>, AllowedArguments,
                    Context#{request_deadline := Now - 1, correlation_id := <<"expired">>})
            ],
            ?assertEqual([
                denial(unknown_grant),
                denial(binding_mismatch),
                denial(scope_mismatch),
                denial(undeclared_effect),
                denial(expired_deadline)
            ], Denials),
            {ok, AfterGrant} = alang_phase4_broker:describe_grant(Broker, Grant),
            ?assertEqual(maps:get(remaining_budgets, BeforeGrant),
                maps:get(remaining_budgets, AfterGrant)),
            {ok, AfterEvents} = alang_phase4_broker:adapter_events(Broker),
            ?assertEqual(length(BeforeEvents), length(AfterEvents)),
            ?assertEqual(false, filelib:is_file(filename:join([Root, "allowed", "result.md"]))),
            ?assertEqual(false, filelib:is_file(filename:join([Root, "outside", "result.md"]))),

            RevokedSpec = Spec#{task_id := <<"task:revoked">>},
            {ok, Revoked} = alang_phase4_broker:issue_grant(Broker, RevokedSpec),
            {ok, 1} = alang_phase4_broker:revoke_grant(Broker, Revoked),
            ?assertEqual(denial(revoked_grant), alang_phase4_broker:request(
                Broker, Revoked, Manifest, <<"workspace.write">>, AllowedArguments,
                direct_context(Broker, RevokedSpec, Now + 5000, false, <<"revoked">>)
            )),

            PolicySpec = grant_spec(self(), Now, 1, <<"workspace-b">>, [],
                <<"session-policy">>, Digest, <<"task:policy">>),
            {ok, PolicyGrant} = alang_phase4_broker:issue_grant(Broker, PolicySpec),
            ?assertEqual(denial(policy_denied), alang_phase4_broker:request(
                Broker, PolicyGrant, Manifest, <<"workspace.write">>, workspace_arguments(
                    <<"workspace-b">>, <<"policy.md">>, <<"denied">>, <<"policy-op">>
                ), direct_context(Broker, PolicySpec, Now + 5000, false, <<"policy">>)
            )),

            BudgetSpec = grant_spec(self(), Now, 1, <<"workspace-a">>, [<<"allowed">>],
                <<"session-budget">>, Digest, <<"task:budget">>),
            {ok, BudgetGrant} = alang_phase4_broker:issue_grant(Broker, BudgetSpec),
            BudgetContext = direct_context(Broker, BudgetSpec, Now + 5000, false, <<"budget-1">>),
            {ok, _ArtifactDigest} = alang_phase4_broker:request(
                Broker, BudgetGrant, Manifest, <<"workspace.write">>, workspace_arguments(
                    <<"workspace-a">>, <<"allowed/budget.md">>, <<"first">>, <<"budget-op-1">>
                ), BudgetContext
            ),
            ?assertEqual(denial(exhausted_budget), alang_phase4_broker:request(
                Broker, BudgetGrant, Manifest, <<"workspace.write">>, workspace_arguments(
                    <<"workspace-a">>, <<"allowed/budget.md">>, <<"second">>, <<"budget-op-2">>
                ), BudgetContext#{correlation_id := <<"budget-2">>}
            )),
            ?assertEqual({ok, <<"first">>},
                file:read_file(filename:join([Root, "allowed", "budget.md"]))),
            assert_adapter_pid_without_seal_cannot_dispatch(Broker, Root),
            assert_direct_module_import_is_rejected()
        after
            alang_phase4_broker_sup:stop(Supervisor)
        end
    end).

stale_grant_after_broker_restart_has_no_effect_test() ->
    with_workspace(fun(Root, _Outside, BeamDir) ->
        Options = broker_options(Root, BeamDir, [<<"workspace-a">>]),
        {ok, Supervisor} = alang_phase4_broker_sup:start_link(Options),
        try
            {ok, Broker1} = alang_phase4_broker_sup:broker(Supervisor),
            Now = erlang:monotonic_time(millisecond),
            Digest = binary:copy(<<"a">>, 64),
            Spec = grant_spec(self(), Now, 1, <<"workspace-a">>, [],
                <<"stale-session">>, Digest, <<"task:stale">>),
            {ok, StaleGrant} = alang_phase4_broker:issue_grant(Broker1, Spec),
            Monitor = erlang:monitor(process, Broker1),
            exit(Broker1, kill),
            receive {'DOWN', Monitor, process, Broker1, killed} -> ok
            after 1000 -> error(broker_restart_timeout)
            end,
            {ok, Broker2} = await_new_broker(Supervisor, Broker1, 100),
            Context = direct_context(Broker2, Spec,
                erlang:monotonic_time(millisecond) + 2000, false, <<"stale">>),
            ?assertEqual(denial(unknown_grant), alang_phase4_broker:request(
                Broker2, StaleGrant, manifest([<<"workspace.write">>]),
                <<"workspace.write">>, workspace_arguments(
                    <<"workspace-a">>, <<"stale.md">>, <<"no">>, <<"stale-op">>
                ), Context
            )),
            ?assertEqual(false, filelib:is_file(filename:join(Root, "stale.md"))),
            ?assert(is_process_alive(Broker2))
        after
            alang_phase4_broker_sup:stop(Supervisor)
        end
    end).

compiled_fixture(Content) ->
    Ir = alang_phase4_integration_fixture:workspace_ir(
        <<"workspace-a">>,
        <<"results/phase-4.md">>,
        Content,
        <<"phase4-write-1">>
    ),
    CapabilityManifest = #{
        effects => [<<"workspace.write">>],
        requirements => [<<"workspace:write">>]
    },
    Context = #{
        source_sha256 => hex(crypto:hash(sha256, <<"phase-4-integration-fixture">>)),
        capability_manifest => CapabilityManifest
    },
    {ok, Compiled} = alang_phase3_backend:compile_ir(Ir, Context, ?TOOLCHAIN),
    Compiled.

runtime_options(Handler, SessionId) -> #{
    handler => Handler,
    session_id => SessionId,
    timeout => 5000,
    max_in_flight => 1,
    max_mailbox => 32,
    max_trace_events => 64
}.

broker_options(Root, BeamDir, Workspaces) -> #{
    limits => #{
        max_pending => 8,
        max_pending_per_session => 2,
        max_mailbox => 256,
        max_audit => 256,
        authorization_ttl_ms => 4000
    },
    policy => #{
        version => <<"phase4-policy-v1">>,
        workspaces => Workspaces,
        models => [<<"model-a">>]
    },
    adapter => adapter_config(Root, BeamDir)
}.

adapter_config(Root, BeamDir) -> #{
    workspace_id => <<"workspace-a">>,
    root => list_to_binary(Root),
    beam_dir => list_to_binary(BeamDir),
    test_faults => false,
    limits => #{
        max_request_bytes => 98304,
        max_response_bytes => 4096,
        max_content_bytes => 65536,
        max_cache_entries => 128,
        request_timeout_ms => 2000,
        address_space_bytes => 2147483648,
        cpu_seconds => 5,
        open_files => 64,
        file_size_bytes => 67108864,
        processes => 4096
    }
}.

grant_spec(Owner, Now, Budget, WorkspaceId, Prefix, SessionId, ArtifactDigest, TaskId) -> #{
    invocations => [#{
        operation => <<"workspace.write">>,
        workspace_id => WorkspaceId,
        path_prefix => Prefix
    }],
    budgets => #{<<"workspace.write">> => Budget},
    deadline => Now + 10000,
    owner_pid => Owner,
    session_id => SessionId,
    artifact_digest => ArtifactDigest,
    task_id => TaskId,
    combination => deny
}.

broker_context(Broker, Spec, GatewayContext) ->
    maps:merge(alang_phase4_broker:runtime_context(Broker), #{
        session_id => maps:get(session_id, GatewayContext),
        artifact_digest => maps:get(artifact_digest, Spec),
        owner_pid => maps:get(owner_pid, Spec),
        task_id => maps:get(task_id, GatewayContext),
        presenter_pid => maps:get(requester_pid, GatewayContext),
        request_deadline => maps:get(deadline, GatewayContext),
        cancelled => false,
        correlation_id => maps:get(correlation_id, GatewayContext)
    }).

direct_context(Broker, Spec, Deadline, Cancelled, CorrelationId) ->
    maps:merge(alang_phase4_broker:runtime_context(Broker), #{
        session_id => maps:get(session_id, Spec),
        artifact_digest => maps:get(artifact_digest, Spec),
        owner_pid => maps:get(owner_pid, Spec),
        task_id => maps:get(task_id, Spec),
        presenter_pid => self(),
        request_deadline => Deadline,
        cancelled => Cancelled,
        correlation_id => CorrelationId
    }).

workspace_arguments(WorkspaceId, Path, Content, OperationId) ->
    {alang_data_v1, product, {WorkspaceId, Path, Content, OperationId}}.

manifest(Effects) -> #{effects => Effects, requirements => []}.

denial(Reason) -> {error, {alang_broker_denial_v1, Reason}}.

process_evidence(Broker, Context) -> #{
    handler => process_snapshot(self()),
    requester => process_snapshot(maps:get(requester_pid, Context)),
    gateway => process_snapshot(maps:get(gateway_pid, Context)),
    broker => process_snapshot(Broker),
    generated_module => code:is_loaded(alang_phase3_program_v1),
    otp_release => list_to_binary(erlang:system_info(otp_release)),
    erts_version => list_to_binary(erlang:system_info(version))
}.

process_snapshot(Pid) -> #{pid => Pid, info => process_info(Pid, [status, current_function])}.

assert_beam_ownership(Evidence, Inspection) ->
    lists:foreach(
        fun(Key) ->
            Snapshot = maps:get(Key, Evidence),
            ?assert(is_pid(maps:get(pid, Snapshot))),
            ?assertMatch([{status, _}, {current_function, {_, _, _}}], maps:get(info, Snapshot))
        end,
        [handler, requester, gateway, broker]
    ),
    ?assertMatch({file, _}, maps:get(generated_module, Evidence)),
    ?assertEqual(<<"29">>, maps:get(otp_release, Evidence)),
    ?assertEqual([], maps:get(imports, Inspection) -- alang_phase3_contract:allowed_beam_imports()),
    ?assertNot(lists:any(
        fun({Module, _Function, _Arity}) ->
            Module =:= alang_phase4_broker orelse Module =:= alang_phase4_workspace_adapter
        end,
        maps:get(imports, Inspection)
    )),
    lists:foreach(
        fun(Module) ->
            Path = code:which(Module),
            ?assert(is_list(Path)),
            ?assert(filename:extension(Path) =:= ".beam")
        end,
        [
            alang_phase3_lowering,
            alang_phase3_backend,
            alang_phase3_abi,
            alang_phase4_effect_registry,
            alang_phase4_grants,
            alang_phase4_broker,
            alang_phase4_workspace_adapter,
            alang_phase4_workspace_sidecar
        ]
    ).

assert_audit_path(Audit) ->
    Events = maps:get(events, Audit),
    ?assert(lists:any(fun(#{decision := Decision, reason := Reason}) ->
        Decision =:= allow andalso Reason =:= allowed
    end, Events)),
    ?assert(lists:any(fun(#{decision := Decision, reason := Reason}) ->
        Decision =:= completion andalso Reason =:= succeeded
    end, Events)),
    ?assertNot(contains_reference(Audit)).

assert_adapter_pid_without_seal_cannot_dispatch(Broker, Root) ->
    BrokerState = sys:get_state(Broker),
    Adapter = maps:get(pid, maps:get(adapter, BrokerState)),
    Decoded = #{
        operation_tag => workspace_write,
        adapter => workspace_adapter,
        arguments => #{
            workspace_id => <<"workspace-a">>,
            path_segments => [<<"bypass.md">>],
            content => <<"no">>,
            operation_id => <<"bypass-op">>
        }
    },
    ?assertEqual({error, adapter_bypass_denied},
        alang_phase4_workspace_adapter:dispatch(
            Adapter,
            make_ref(),
            Decoded,
            erlang:monotonic_time(millisecond) + 1000
        )),
    ?assertEqual(false, filelib:is_file(filename:join(Root, "bypass.md"))).

assert_direct_module_import_is_rejected() ->
    Compiled = compiled_fixture(<<"inspection">>),
    Metadata = maps:get(metadata, Compiled),
    Forms = [
        {attribute, 1, module, alang_phase3_program_v1},
        {attribute, 1, export, [{execute, 3}]},
        {attribute, 1, alang_backend, Metadata},
        {function, 1, execute, 3, [
            {clause, 1, [{var, 1, '_'}, {var, 1, '_'}, {var, 1, 'ALANG_CONTEXT'}], [], [
                {call, 1, {remote, 1,
                    {atom, 1, alang_phase4_workspace_adapter},
                    {atom, 1, status}}, [{var, 1, 'ALANG_CONTEXT'}]}
            ]}
        ]}
    ],
    Options = [binary, deterministic, no_debug_info, no_docs, return_errors, return_warnings],
    {ok, alang_phase3_program_v1, Beam, []} = compile:forms(Forms, Options),
    ?assertEqual(
        {error, {forbidden_beam_imports, [{alang_phase4_workspace_adapter, status, 1}]}},
        alang_phase3_artifact:inspect(Beam)
    ).

assert_trace_kinds(Events, Expected) ->
    Actual = [maps:get(kind, Event) || Event <- Events],
    lists:foreach(fun(Kind) -> ?assert(lists:member(Kind, Actual)) end, Expected).

contains_reference(Term) when is_reference(Term) -> true;
contains_reference(Term) when is_map(Term) ->
    lists:any(fun contains_reference/1, maps:keys(Term) ++ maps:values(Term));
contains_reference(Term) when is_tuple(Term) -> contains_reference(tuple_to_list(Term));
contains_reference(Term) when is_list(Term) -> lists:any(fun contains_reference/1, Term);
contains_reference(_Term) -> false.

await_new_broker(_Supervisor, _Old, 0) -> {error, timeout};
await_new_broker(Supervisor, Old, Attempts) ->
    case alang_phase4_broker_sup:broker(Supervisor) of
        {ok, New} when New =/= Old -> {ok, New};
        _ -> receive after 5 -> await_new_broker(Supervisor, Old, Attempts - 1) end
    end.

with_workspace(Fun) ->
    Base = filename:absname(filename:join(["build", "phase-04", "integration-tests",
        integer_to_list(erlang:unique_integer([positive, monotonic]))])),
    Root = filename:join(Base, "workspace"),
    Outside = filename:join(Base, "outside"),
    ok = filelib:ensure_dir(filename:join([Root, "results", ".keep"])),
    ok = filelib:ensure_dir(filename:join([Root, "allowed", ".keep"])),
    ok = filelib:ensure_dir(filename:join(Outside, ".keep")),
    BeamDir = filename:dirname(code:which(alang_phase4_workspace_sidecar)),
    try Fun(Root, Outside, BeamDir)
    after
        ok = file:del_dir_r(Base)
    end.

hex(Binary) -> iolist_to_binary([io_lib:format("~2.16.0b", [Byte]) || <<Byte>> <= Binary]).
