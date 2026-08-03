-module(alang_phase4_workspace_adapter).

-include_lib("kernel/include/file.hrl").

-behaviour(gen_server).

-export([
    dispatch/4,
    events/1,
    inject_test_fault/3,
    lookup/4,
    start/3,
    status/1,
    stop/2
]).
-export([handle_call/3, handle_cast/2, handle_info/2, init/1, terminate/2]).

-define(CALL_TIMEOUT, 5000).

-spec start(pid(), map(), reference()) -> gen_server:start_ret().
start(Broker, Config, Seal) -> gen_server:start(?MODULE, {Broker, Config, Seal}, []).

-spec dispatch(pid(), reference(), map(), integer()) -> {ok, map()} | {error, term()}.
dispatch(Adapter, Seal, Decoded, Deadline) ->
    gen_server:call(Adapter, {dispatch, Seal, Decoded, Deadline}, ?CALL_TIMEOUT).

-spec lookup(pid(), reference(), map(), integer()) -> {ok, map()} | {error, term()}.
lookup(Adapter, Seal, Query, Deadline) ->
    gen_server:call(Adapter, {lookup, Seal, Query, Deadline}, ?CALL_TIMEOUT).

-spec inject_test_fault(pid(), reference(), atom()) -> ok | {error, atom()}.
inject_test_fault(Adapter, Seal, Fault) ->
    gen_server:call(Adapter, {inject_test_fault, Seal, Fault}, ?CALL_TIMEOUT).

-spec status(pid()) -> map().
status(Adapter) -> gen_server:call(Adapter, status, ?CALL_TIMEOUT).

-spec events(pid()) -> [map()].
events(Adapter) -> gen_server:call(Adapter, events, ?CALL_TIMEOUT).

-spec stop(pid(), reference()) -> ok | {error, atom()}.
stop(Adapter, Seal) -> gen_server:call(Adapter, {stop, Seal}, ?CALL_TIMEOUT).

init({Broker, Config, Seal}) when is_pid(Broker), is_reference(Seal) ->
    process_flag(trap_exit, true),
    case validate_config(Config) of
        {ok, Normalized} ->
            BrokerMonitor = erlang:monitor(process, Broker),
            Base = #{
                broker => Broker,
                broker_monitor => BrokerMonitor,
                seal => Seal,
                config => Normalized,
                port => undefined,
                ready => false,
                pending => undefined,
                restarts => 0,
                events => [],
                fault => none
            },
            case launch_ready_port(Normalized) of
                {ok, Port} -> {ok, Base#{port := Port, ready := true}};
                {error, Reason} -> {stop, {adapter_launch_failed, Reason}}
            end;
        {error, Reason} -> {stop, Reason}
    end;
init(_) -> {stop, invalid_adapter_owner}.

handle_call({dispatch, Seal, Decoded, Deadline}, From, State) ->
    case authorized(Seal, From, State) of
        false -> {reply, {error, adapter_bypass_denied}, State};
        true -> dispatch_authorized(Decoded, Deadline, From, State)
    end;
handle_call({lookup, Seal, Query, Deadline}, From, State) ->
    case authorized(Seal, From, State) of
        false -> {reply, {error, adapter_bypass_denied}, State};
        true -> lookup_authorized(Query, Deadline, From, State)
    end;
handle_call({inject_test_fault, Seal, Fault}, From, State) ->
    case authorized(Seal, From, State) andalso maps:get(test_faults, maps:get(config, State)) of
        true when Fault =:= hang; Fault =:= malformed; Fault =:= crash;
            Fault =:= crash_after_mutation ->
            {reply, ok, State#{fault := Fault}};
        true -> {reply, {error, invalid_test_fault}, State};
        false -> {reply, {error, adapter_bypass_denied}, State}
    end;
handle_call(status, _From, State) ->
    Config = maps:get(config, State),
    {reply, #{
        format => alang_workspace_adapter_status_v1,
        workspace_id => maps:get(workspace_id, Config),
        isolation => #{filesystem => bubblewrap, resources => prlimit, runtime => beam_sidecar},
        limits => maps:get(limits, Config),
        port_alive => is_port(maps:get(port, State)),
        sidecar_ready => maps:get(ready, State),
        pending => maps:get(pending, State) =/= undefined,
        restarts => maps:get(restarts, State)
    }, State};
handle_call(events, _From, State) -> {reply, lists:reverse(maps:get(events, State)), State};
handle_call({stop, Seal}, From, State) ->
    case authorized(Seal, From, State) of
        true -> {stop, normal, ok, State};
        false -> {reply, {error, adapter_bypass_denied}, State}
    end;
handle_call(_Request, _From, State) -> {reply, {error, unsupported_adapter_call}, State}.

handle_cast(_Message, State) -> {noreply, State}.

handle_info({Port, {data, Binary}}, #{port := Port} = State) ->
    case ready_frame(Binary) of
        true -> {noreply, State#{ready := true}};
        false -> {noreply, handle_response(Binary, State)}
    end;
handle_info({adapter_timeout, Ticket}, State) ->
    {noreply, handle_timeout(Ticket, State)};
handle_info({inject_malformed, Port}, #{port := Port} = State) ->
    {noreply, handle_response(<<0, 1, 2>>, State)};
handle_info({Port, {exit_status, Status}}, #{port := Port} = State) ->
    {noreply, handle_port_exit({exit_status, Status}, State)};
handle_info({'EXIT', Port, Reason}, #{port := Port} = State) ->
    {noreply, handle_port_exit({port_exit, Reason}, State)};
handle_info({'DOWN', Monitor, process, Broker, _Reason},
    #{broker_monitor := Monitor, broker := Broker} = State) ->
    {stop, normal, State};
handle_info(_Message, State) -> {noreply, State}.

terminate(_Reason, State) ->
    cancel_pending_timer(maps:get(pending, State)),
    close_port(maps:get(port, State)),
    ok.

dispatch_authorized(_Decoded, _Deadline, _From, #{pending := Pending} = State) when
    Pending =/= undefined
-> {reply, {error, adapter_overloaded}, State};
dispatch_authorized(Decoded, Deadline, From, State) ->
    Now = erlang:monotonic_time(millisecond),
    Config = maps:get(config, State),
    case build_request(Decoded, Deadline, Now, Config) of
        {ok, Request, OperationId, Timeout} ->
            start_dispatch(dispatch, Request, OperationId, Timeout, From, State);
        {error, _} = Error -> {reply, Error, State}
    end.

lookup_authorized(_Query, _Deadline, _From, #{pending := Pending} = State) when
    Pending =/= undefined
-> {reply, {error, adapter_overloaded}, State};
lookup_authorized(Query, Deadline, From, State) ->
    Now = erlang:monotonic_time(millisecond),
    Config = maps:get(config, State),
    case build_lookup_request(Query, Deadline, Now, Config) of
        {ok, Request, OperationId, Timeout} ->
            start_dispatch(lookup, Request, OperationId, Timeout, From, State);
        {error, _} = Error -> {reply, Error, State}
    end.

start_dispatch(Kind, Request, OperationId, Timeout, From, State) ->
    case ensure_port(State) of
        {ok, Ready} ->
            Ticket = make_ref(),
            Timer = erlang:send_after(Timeout, self(), {adapter_timeout, Ticket}),
            Pending = #{
                kind => Kind,
                ticket => Ticket,
                from => From,
                timer => Timer,
                operation_id => OperationId,
                operation_hash => redacted(OperationId)
            },
            Started = record_event(request_event_kind(Kind), OperationId, undefined,
                Ready#{pending := Pending}),
            execute_fault_or_send(Request, Started);
        {error, Reason, Failed} -> {reply, {error, {adapter_unavailable, Reason}}, Failed}
    end.

request_event_kind(dispatch) -> request;
request_event_kind(lookup) -> lookup.

execute_fault_or_send(Request, #{fault := Fault, port := Port} = State) ->
    case Fault of
        none ->
            Encoded = term_to_binary(Request, [deterministic]),
            try erlang:port_command(Port, Encoded) of
                true -> {noreply, State};
                false -> finish_unknown({adapter_write_failed, outcome_unknown}, State)
            catch
                error:badarg -> finish_unknown({adapter_exit, outcome_unknown}, State)
            end;
        hang -> {noreply, State#{fault := none}};
        malformed ->
            self() ! {inject_malformed, Port},
            {noreply, State#{fault := none}};
        crash ->
            close_port(Port),
            {noreply, State#{fault := none}};
        crash_after_mutation ->
            CrashRequest = crash_after_mutation_request(Request),
            Encoded = term_to_binary(CrashRequest, [deterministic]),
            try erlang:port_command(Port, Encoded) of
                true -> {noreply, State#{fault := none}};
                false -> finish_unknown({adapter_write_failed, outcome_unknown}, State#{fault := none})
            catch
                error:badarg -> finish_unknown({adapter_exit, outcome_unknown}, State#{fault := none})
            end
    end.

crash_after_mutation_request(
    {alang_workspace_request_v1, WorkspaceId, Segments, Content, OperationId, Timeout}
) -> {alang_workspace_request_v2, WorkspaceId, Segments, Content, OperationId, Timeout,
    crash_after_mutation};
crash_after_mutation_request(Request) -> Request.

handle_response(_Binary, #{pending := undefined} = State) -> restart(protocol_desynchronization, State);
handle_response(Binary, State) ->
    Config = maps:get(config, State),
    case byte_size(Binary) =< maps:get(max_response_bytes, maps:get(limits, Config)) of
        false -> finish_and_restart({adapter_protocol_error, outcome_unknown}, protocol_oversize, State);
        true -> decode_response(Binary, State)
    end.

decode_response(Binary, State) ->
    try binary_to_term(Binary, [safe]) of
        Response -> validate_response(Response, State)
    catch
        error:badarg -> finish_and_restart({adapter_protocol_error, outcome_unknown}, malformed_response, State)
    end.

validate_response(
    {alang_workspace_result_v1, ok, OperationId, Digest, Bytes, Disposition},
    #{pending := #{kind := dispatch, operation_id := OperationId}} = State
) when
    is_binary(Digest), byte_size(Digest) =:= 64,
    is_integer(Bytes), Bytes >= 0, Bytes =< 65536,
    (Disposition =:= created orelse Disposition =:= replayed)
->
    case valid_hex(Digest) of
        true -> finish_success(#{
            operation_id => OperationId,
            digest => Digest,
            bytes => Bytes,
            disposition => Disposition
        }, State);
        false -> finish_and_restart({adapter_protocol_error, outcome_unknown}, invalid_digest, State)
    end;
validate_response(
    {alang_workspace_result_v1, error, OperationId, Reason},
    #{pending := #{operation_id := OperationId}} = State
) ->
    case valid_sidecar_reason(Reason) of
        true -> finish_error(Reason, State);
        false -> finish_and_restart({adapter_protocol_error, outcome_unknown}, invalid_reason, State)
    end;
validate_response(
    {alang_workspace_lookup_result_v1, OperationId, Status, PayloadDigest, ArtifactDigest, Bytes},
    #{pending := #{kind := lookup, operation_id := OperationId}} = State
) ->
    case valid_lookup_response(Status, PayloadDigest, ArtifactDigest, Bytes) of
        true -> finish_success(#{
            operation_id => OperationId,
            status => Status,
            payload_digest => PayloadDigest,
            artifact_digest => ArtifactDigest,
            bytes => Bytes
        }, State);
        false -> finish_and_restart({adapter_protocol_error, outcome_unknown},
            invalid_lookup_response, State)
    end;
validate_response(_Response, State) ->
    finish_and_restart({adapter_protocol_error, outcome_unknown}, response_mismatch, State).

finish_success(Result, State) ->
    Pending = maps:get(pending, State),
    cancel_pending_timer(Pending),
    gen_server:reply(maps:get(from, Pending), {ok, Result}),
    Detail = maps:get(disposition, Result, maps:get(status, Result, internal_failure)),
    record_event(success, maps:get(operation_id, Pending), Detail,
        State#{pending := undefined}).

finish_error(Reason, State) ->
    Pending = maps:get(pending, State),
    cancel_pending_timer(Pending),
    gen_server:reply(maps:get(from, Pending), {error, Reason}),
    record_event(denied, maps:get(operation_id, Pending), Reason, State#{pending := undefined}).

finish_unknown(Reason, State) ->
    Pending = maps:get(pending, State),
    cancel_pending_timer(Pending),
    gen_server:reply(maps:get(from, Pending), {error, Reason}),
    {noreply, record_event(unknown, maps:get(operation_id, Pending), Reason,
        State#{pending := undefined})}.

finish_and_restart(ReplyReason, RestartReason, State) ->
    Pending = maps:get(pending, State),
    cancel_pending_timer(Pending),
    gen_server:reply(maps:get(from, Pending), {error, ReplyReason}),
    restart(RestartReason, record_event(unknown, maps:get(operation_id, Pending),
        ReplyReason, State#{pending := undefined})).

handle_timeout(Ticket, #{pending := #{ticket := Ticket} = Pending} = State) ->
    gen_server:reply(maps:get(from, Pending), {error, {adapter_timeout, outcome_unknown}}),
    restart(timeout, record_event(unknown, maps:get(operation_id, Pending), timeout,
        State#{pending := undefined}));
handle_timeout(_Ticket, State) -> State.

handle_port_exit(Reason, #{pending := undefined} = State) -> restart(Reason, State#{port := undefined});
handle_port_exit(Reason, State) ->
    Pending = maps:get(pending, State),
    cancel_pending_timer(Pending),
    gen_server:reply(maps:get(from, Pending), {error, {adapter_exit, outcome_unknown}}),
    restart(Reason, record_event(unknown, maps:get(operation_id, Pending), Reason,
        State#{port := undefined, pending := undefined})).

restart(Reason, State) ->
    close_port(maps:get(port, State)),
    Restarted = State#{port := undefined, ready := false,
        restarts := maps:get(restarts, State) + 1},
    EventState = record_event(restart, <<"internal">>, Reason, Restarted),
    case launch_ready_port(maps:get(config, State)) of
        {ok, Port} -> EventState#{port := Port, ready := true};
        {error, _LaunchReason} -> EventState
    end.

ensure_port(#{port := Port} = State) when is_port(Port) -> {ok, State};
ensure_port(State) ->
    case launch_ready_port(maps:get(config, State)) of
        {ok, Port} -> {ok, State#{port := Port, ready := true}};
        {error, Reason} -> {error, Reason, State}
    end.

launch_ready_port(Config) ->
    case launch_port(Config) of
        {ok, Port} -> await_ready_port(Port);
        {error, _} = Error -> Error
    end.

await_ready_port(Port) ->
    receive
        {Port, {data, Binary}} ->
            case ready_frame(Binary) of
                true -> {ok, Port};
                false ->
                    close_port(Port),
                    {error, invalid_sidecar_handshake}
            end;
        {Port, {exit_status, Status}} -> {error, {sidecar_exit, Status}};
        {'EXIT', Port, Reason} -> {error, {sidecar_exit, Reason}}
    after 2000 ->
        close_port(Port),
        {error, sidecar_handshake_timeout}
    end.

build_request(#{operation_tag := workspace_write, adapter := workspace_adapter,
    arguments := Arguments}, Deadline, Now, Config) when is_integer(Deadline) ->
    case validate_arguments(Arguments, Config) of
        ok ->
            Limits = maps:get(limits, Config),
            Remaining = min(Deadline - Now, maps:get(request_timeout_ms, Limits)),
            case Remaining > 0 of
                true ->
                    OperationId = maps:get(operation_id, Arguments),
                    Request = {alang_workspace_request_v1,
                        maps:get(workspace_id, Arguments),
                        maps:get(path_segments, Arguments),
                        maps:get(content, Arguments),
                        OperationId,
                        Remaining},
                    case erlang:external_size(Request) =< maps:get(max_request_bytes, Limits) of
                        true -> {ok, Request, OperationId, Remaining};
                        false -> {error, adapter_request_too_large}
                    end;
                false -> {error, adapter_deadline_exceeded}
            end;
        {error, _} = Error -> Error
    end;
build_request(_Decoded, _Deadline, _Now, _Config) -> {error, invalid_adapter_request}.

build_lookup_request(Query, Deadline, Now, Config) when is_map(Query), is_integer(Deadline) ->
    case validate_lookup_query(Query, Config) of
        ok ->
            Limits = maps:get(limits, Config),
            Remaining = min(Deadline - Now, maps:get(request_timeout_ms, Limits)),
            case Remaining > 0 of
                true ->
                    OperationId = maps:get(operation_id, Query),
                    Request = {alang_workspace_lookup_v1,
                        maps:get(workspace_id, Query),
                        maps:get(path_segments, Query),
                        OperationId,
                        maps:get(payload_digest, Query),
                        maps:get(artifact_digest, Query),
                        Remaining},
                    case erlang:external_size(Request) =< maps:get(max_request_bytes, Limits) of
                        true -> {ok, Request, OperationId, Remaining};
                        false -> {error, adapter_request_too_large}
                    end;
                false -> {error, adapter_deadline_exceeded}
            end;
        {error, _} = Error -> Error
    end;
build_lookup_request(_Query, _Deadline, _Now, _Config) -> {error, invalid_adapter_request}.

validate_lookup_query(#{workspace_id := WorkspaceId, path_segments := Segments,
    operation_id := OperationId, payload_digest := PayloadDigest,
    artifact_digest := ArtifactDigest} = Query, Config) when map_size(Query) =:= 5 ->
    case WorkspaceId =:= maps:get(workspace_id, Config) andalso
        valid_segments(Segments) andalso valid_id(OperationId) andalso
        valid_digest(PayloadDigest) andalso valid_digest(ArtifactDigest)
    of
        true -> ok;
        false -> {error, invalid_adapter_request}
    end;
validate_lookup_query(_Query, _Config) -> {error, invalid_adapter_request}.

validate_arguments(#{workspace_id := WorkspaceId, path_segments := Segments,
    content := Content, operation_id := OperationId} = Arguments, Config) when map_size(Arguments) =:= 4 ->
    Limits = maps:get(limits, Config),
    case WorkspaceId =:= maps:get(workspace_id, Config) andalso
        valid_segments(Segments) andalso is_binary(Content) andalso
        byte_size(Content) =< maps:get(max_content_bytes, Limits) andalso valid_id(OperationId)
    of
        true -> ok;
        false -> {error, invalid_adapter_request}
    end;
validate_arguments(_Arguments, _Config) -> {error, invalid_adapter_request}.

launch_port(Config) ->
    Limits = maps:get(limits, Config),
    Root = binary_to_list(maps:get(root, Config)),
    BeamDir = binary_to_list(maps:get(beam_dir, Config)),
    case executables() of
        {ok, Prlimit, Bwrap, Erl} ->
            Arguments = [
                "--as=" ++ integer_to_list(maps:get(address_space_bytes, Limits)),
                "--cpu=" ++ integer_to_list(maps:get(cpu_seconds, Limits)),
                "--nofile=" ++ integer_to_list(maps:get(open_files, Limits)),
                "--fsize=" ++ integer_to_list(maps:get(file_size_bytes, Limits)),
                "--nproc=" ++ integer_to_list(maps:get(processes, Limits)),
                "--",
                Bwrap,
                "--die-with-parent",
                "--new-session",
                "--unshare-all",
                "--clearenv",
                "--setenv", "HOME", Root,
                "--setenv", "LANG", "C",
                "--setenv", "PATH", "/usr/bin:/bin",
                "--ro-bind", "/", "/",
                "--bind", Root, Root,
                "--proc", "/proc",
                "--dev", "/dev",
                "--chdir", Root,
                Erl,
                "+S", "1:1",
                "+SDio", "1",
                "+SDcpu", "1",
                "+hmax", "1048576",
                "+hmaxk", "true",
                "-noshell",
                "-noinput",
                "-pa", BeamDir,
                "-s", "alang_phase4_workspace_sidecar", "main",
                "-extra",
                binary_to_list(base64:encode(maps:get(workspace_id, Config))),
                Root,
                integer_to_list(maps:get(max_content_bytes, Limits)),
                integer_to_list(maps:get(max_response_bytes, Limits)),
                integer_to_list(maps:get(max_cache_entries, Limits)),
                atom_to_list(maps:get(test_faults, Config))
            ],
            try open_port({spawn_executable, Prlimit}, [
                binary,
                {packet, 4},
                use_stdio,
                exit_status,
                hide,
                {args, Arguments}
            ]) of
                Port -> {ok, Port}
            catch
                error:Reason -> {error, Reason}
            end;
        {error, _} = Error -> Error
    end.

executables() ->
    case {
        os:find_executable("prlimit"),
        os:find_executable("bwrap"),
        runtime_erl()
    } of
        {false, _, _} -> {error, prlimit_unavailable};
        {_, false, _} -> {error, bubblewrap_unavailable};
        {_, _, false} -> {error, erl_unavailable};
        {Prlimit, Bwrap, Erl} -> {ok, Prlimit, Bwrap, Erl}
    end.

runtime_erl() ->
    Candidate = filename:join([
        code:root_dir(),
        "erts-" ++ erlang:system_info(version),
        "bin",
        "erl"
    ]),
    case filelib:is_regular(Candidate) of
        true -> Candidate;
        false -> false
    end.

validate_config(#{workspace_id := WorkspaceId, root := Root, beam_dir := BeamDir,
    limits := Limits, test_faults := TestFaults} = Config) when map_size(Config) =:= 5 ->
    case {
        valid_id(WorkspaceId),
        valid_directory(Root),
        valid_directory(BeamDir),
        validate_limits(Limits),
        is_boolean(TestFaults)
    } of
        {true, true, true, ok, true} -> {ok, Config#{
            root := list_to_binary(filename:absname(binary_to_list(Root))),
            beam_dir := list_to_binary(filename:absname(binary_to_list(BeamDir)))
        }};
        _ -> {error, invalid_adapter_configuration}
    end;
validate_config(_) -> {error, invalid_adapter_configuration}.

validate_limits(#{
    max_request_bytes := MaxRequest,
    max_response_bytes := MaxResponse,
    max_content_bytes := MaxContent,
    max_cache_entries := MaxCache,
    request_timeout_ms := Timeout,
    address_space_bytes := AddressSpace,
    cpu_seconds := Cpu,
    open_files := OpenFiles,
    file_size_bytes := FileSize,
    processes := Processes
} = Limits) when
    map_size(Limits) =:= 10,
    is_integer(MaxRequest), MaxRequest >= 1024, MaxRequest =< 98304,
    is_integer(MaxResponse), MaxResponse >= 512, MaxResponse =< 4096,
    is_integer(MaxContent), MaxContent > 0, MaxContent =< 65536,
    is_integer(MaxCache), MaxCache > 0, MaxCache =< 1024,
    is_integer(Timeout), Timeout > 0, Timeout =< 60000,
    is_integer(AddressSpace), AddressSpace >= 2147483648, AddressSpace =< 4294967296,
    is_integer(Cpu), Cpu > 0, Cpu =< 60,
    is_integer(OpenFiles), OpenFiles >= 32, OpenFiles =< 256,
    is_integer(FileSize), FileSize >= 67108864, FileSize =< 134217728,
    is_integer(Processes), Processes >= 1024, Processes =< 4096
-> ok;
validate_limits(_) -> {error, invalid_adapter_limits}.

valid_directory(Path) when is_binary(Path) ->
    Absolute = filename:absname(binary_to_list(Path)),
    filename:pathtype(Absolute) =:= absolute andalso
        case file:read_link_info(Absolute) of
            {ok, #file_info{type = directory}} -> true;
            _ -> false
        end;
valid_directory(_) -> false.

authorized(Seal, {Caller, _Tag}, State) ->
    Seal =:= maps:get(seal, State) andalso Caller =:= maps:get(broker, State).

valid_segments([<<".alang-operations">> | _Rest]) -> false;
valid_segments(Segments) when is_list(Segments), Segments =/= [], length(Segments) =< 32 ->
    lists:all(fun valid_segment/1, Segments);
valid_segments(_) -> false.

valid_segment(Segment) ->
    valid_id(Segment) andalso Segment =/= <<".">> andalso Segment =/= <<"..">> andalso
        binary:match(Segment, <<"/">>) =:= nomatch andalso
        binary:match(Segment, <<"\\">>) =:= nomatch andalso
        binary:match(Segment, <<0>>) =:= nomatch.

valid_id(Value) -> is_binary(Value) andalso byte_size(Value) > 0 andalso byte_size(Value) =< 128.

valid_digest(Value) when is_binary(Value), byte_size(Value) =:= 64 -> valid_hex(Value);
valid_digest(_) -> false.

valid_hex(Digest) -> lists:all(fun is_hex/1, binary_to_list(Digest)).

is_hex(Character) when Character >= $0, Character =< $9 -> true;
is_hex(Character) when Character >= $a, Character =< $f -> true;
is_hex(_) -> false.

valid_sidecar_reason(wrong_workspace) -> true;
valid_sidecar_reason(invalid_request) -> true;
valid_sidecar_reason(invalid_path) -> true;
valid_sidecar_reason(content_too_large) -> true;
valid_sidecar_reason(invalid_operation_id) -> true;
valid_sidecar_reason(deadline_exceeded) -> true;
valid_sidecar_reason(operation_conflict) -> true;
valid_sidecar_reason(outcome_unknown) -> true;
valid_sidecar_reason(idempotency_cache_full) -> true;
valid_sidecar_reason(invalid_payload_digest) -> true;
valid_sidecar_reason(invalid_artifact_digest) -> true;
valid_sidecar_reason(invalid_receipt_directory) -> true;
valid_sidecar_reason(receipt_corrupt) -> true;
valid_sidecar_reason(receipt_unavailable) -> true;
valid_sidecar_reason(symlink_escape) -> true;
valid_sidecar_reason(invalid_workspace_root) -> true;
valid_sidecar_reason(special_file) -> true;
valid_sidecar_reason(missing_parent) -> true;
valid_sidecar_reason(path_unavailable) -> true;
valid_sidecar_reason(temporary_file_conflict) -> true;
valid_sidecar_reason(write_failed) -> true;
valid_sidecar_reason(protocol_error) -> true;
valid_sidecar_reason(request_too_large) -> true;
valid_sidecar_reason(_) -> false.

valid_lookup_response(Status, PayloadDigest, ArtifactDigest, Bytes) ->
    lists:member(Status, [completed, not_submitted, outcome_unknown, conflict]) andalso
        valid_digest(PayloadDigest) andalso valid_digest(ArtifactDigest) andalso
        ((is_integer(Bytes) andalso Bytes >= 0 andalso Bytes =< 65536) orelse Bytes =:= undefined).

ready_frame(Binary) ->
    try binary_to_term(Binary, [safe]) of
        {alang_workspace_sidecar_v1, ready} -> true;
        _Other -> false
    catch
        error:badarg -> false
    end.

record_event(Kind, OperationId, Detail, State) ->
    Event = #{
        format => alang_workspace_adapter_event_v1,
        kind => Kind,
        operation_hash => redacted(OperationId),
        detail => bounded_detail(Detail),
        monotonic_time => erlang:monotonic_time(millisecond)
    },
    State#{events := lists:sublist([Event | maps:get(events, State)], 128)}.

redacted(Value) ->
    Digest = crypto:hash(sha256, term_to_binary(Value, [deterministic])),
    binary:part(hex(Digest), 0, 24).

bounded_detail(Detail) when is_atom(Detail) -> Detail;
bounded_detail({_Class, outcome_unknown}) -> outcome_unknown;
bounded_detail(_) -> internal_failure.

hex(Binary) -> iolist_to_binary([io_lib:format("~2.16.0b", [Byte]) || <<Byte>> <= Binary]).

cancel_pending_timer(undefined) -> ok;
cancel_pending_timer(#{timer := Timer}) ->
    _ = erlang:cancel_timer(Timer),
    ok.

close_port(Port) when is_port(Port) ->
    try erlang:port_close(Port) catch error:badarg -> ok end;
close_port(_) -> ok.
