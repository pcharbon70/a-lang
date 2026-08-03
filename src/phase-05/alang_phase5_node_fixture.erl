-module(alang_phase5_node_fixture).

-export([main/0]).

-spec main() -> no_return().
main() ->
    case init:get_plain_arguments() of
        [ConfigPath] -> run(ConfigPath);
        _ -> halt(64)
    end.

run(ConfigPath) ->
    case read_config(ConfigPath) of
        {ok, Config} ->
            case alang_phase5_resume:resume(maps:get(resume_options, Config)) of
                {ok, Supervisor, Recovery} -> run_artifact(Supervisor, Recovery, Config);
                Error ->
                    io:format(standard_error, "PHASE5_NODE_RESUME_ERROR ~tw~n", [Error]),
                    halt(65)
            end;
        {error, Reason} ->
            io:format(standard_error, "PHASE5_NODE_CONFIG_ERROR ~tp~n", [Reason]),
            halt(64)
    end.

run_artifact(Supervisor, Recovery, Config) ->
    {ok, Topology} = alang_phase5_session_sup:topology(Supervisor),
    Authority = maps:get(recovered_authority, Recovery),
    Grant = maps:get(maps:get(grant_id, Config), maps:get(references, Authority)),
    {ok, Beam} = file:read_file(maps:get(artifact_path, Config)),
    {ok, Workflow} = alang_phase5_workflow:start(#{
        store => maps:get(durable_store, Topology),
        broker => maps:get(broker, Topology),
        state => maps:get(state, Recovery),
        grant => Grant,
        grant_id => maps:get(grant_id, Config),
        manifest => maps:get(manifest, Config),
        artifact_digest => maps:get(artifact_digest, Config),
        task_id => maps:get(task_id, Config),
        owner_pid => maps:get(coordinator, Topology),
        failure_stage => after_mutation,
        controller => self()
    }),
    Handler = fun(Operation, Arguments, GatewayContext) ->
        alang_phase5_workflow:handle_effect(Workflow, Operation, Arguments, GatewayContext)
    end,
    Parent = self(),
    _Runner = spawn(fun() ->
        Result = alang_phase3_artifact:run(
            Beam,
            maps:get(task_id, Config),
            #{},
            runtime_options(Handler, maps:get(session_id, Config))
        ),
        Parent ! {artifact_result, Result}
    end),
    receive
        {phase5_workflow_hook, after_mutation, Workflow} ->
            io:format("PHASE5_NODE_READY_AFTER_MUTATION~n", []),
            receive after infinity -> halt(0) end;
        {artifact_result, _Unexpected} -> halt(66)
    after 15000 -> halt(67)
    end.

read_config(Path) ->
    case file:read_file(Path) of
        {ok, Binary} when byte_size(Binary) =< 262144 ->
            _ = config_atom_vocabulary(),
            try binary_to_term(Binary, [safe]) of
                Config when is_map(Config) -> validate_config(Config);
                _Other -> {error, invalid_config}
            catch
                error:badarg -> {error, invalid_config}
            end;
        {ok, _TooLarge} -> {error, config_too_large};
        {error, _Reason} -> {error, config_unavailable}
    end.

validate_config(#{
    resume_options := #{
        store_options := StoreOptions,
        expected := Expected,
        broker_options := BrokerOptions
    },
    artifact_path := ArtifactPath,
    artifact_digest := ArtifactDigest,
    manifest := #{effects := Effects, requirements := Requirements},
    grant_id := GrantId,
    task_id := TaskId,
    session_id := SessionId
} = Config) when
    map_size(Config) =:= 7,
    is_map(StoreOptions),
    is_map(Expected),
    is_map(BrokerOptions),
    is_list(ArtifactPath),
    is_binary(ArtifactDigest),
    is_list(Effects),
    is_list(Requirements),
    is_binary(GrantId),
    is_binary(TaskId),
    is_binary(SessionId) ->
    {ok, Config};
validate_config(_Config) -> {error, invalid_config}.

%% binary_to_term/2 with the safe option accepts only atoms already present in
%% the fresh VM. This closed vocabulary admits the fixture's nested map keys
%% without permitting the configuration file to allocate arbitrary atoms.
config_atom_vocabulary() -> {
    resume_options, store_options, expected, broker_options,
    artifact_path, artifact_digest, manifest, effects, requirements,
    grant_id, task_id, session_id, root, test_faults,
    state_schema, abi_version, module_name,
    limits, max_pending, max_pending_per_session, max_mailbox, max_audit,
    authorization_ttl_ms, policy, version, workspaces, models, adapter,
    workspace_id, beam_dir, max_request_bytes, max_response_bytes,
    max_content_bytes, max_cache_entries, request_timeout_ms,
    address_space_bytes, cpu_seconds, open_files, file_size_bytes, processes
}.

runtime_options(Handler, SessionId) -> #{
    handler => Handler,
    session_id => SessionId,
    timeout => 10000,
    max_in_flight => 1,
    max_mailbox => 32,
    max_trace_events => 128
}.
