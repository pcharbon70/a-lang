-module(alang_phase4_workspace_sidecar).

-include_lib("kernel/include/file.hrl").

-export([main/0]).

-define(MAX_SEGMENTS, 32).
-define(MAX_SEGMENT_BYTES, 128).
-define(MAX_TIMEOUT_MS, 60000).
-define(RECEIPT_DIR, ".alang-operations").

-spec main() -> no_return().
main() ->
    case parse_arguments(init:get_plain_arguments()) of
        {ok, Config0} ->
            case initialize_receipts(Config0) of
                {ok, Config} ->
                    Port = open_port({fd, 0, 1}, [binary, {packet, 4}, in, out, eof]),
                    true = erlang:port_command(
                        Port,
                        term_to_binary({alang_workspace_sidecar_v1, ready}, [deterministic])
                    ),
                    loop(Port, Config, #{});
                {error, _Reason} -> halt(66)
            end;
        {error, _Reason} -> halt(64)
    end.

loop(Port, Config, Cache) ->
    receive
        {Port, {data, Binary}} ->
            {Response, UpdatedCache} = handle_frame(Binary, Config, Cache),
            Encoded = term_to_binary(Response, [deterministic]),
            case byte_size(Encoded) =< maps:get(max_response_bytes, Config) of
                true ->
                    true = erlang:port_command(Port, Encoded),
                    loop(Port, Config, UpdatedCache);
                false -> halt(65)
            end;
        {Port, eof} -> halt(0);
        {'EXIT', Port, _Reason} -> halt(0);
        _Other -> loop(Port, Config, Cache)
    end.

handle_frame(Binary, Config, Cache) when byte_size(Binary) =< 98304 ->
    try binary_to_term(Binary, [safe]) of
        Request -> handle_request(Request, Config, Cache)
    catch
        error:badarg -> {error_response(<<"invalid">>, protocol_error), Cache}
    end;
handle_frame(_Binary, _Config, Cache) ->
    {error_response(<<"invalid">>, request_too_large), Cache}.

handle_request(
    {alang_workspace_request_v1, WorkspaceId, Segments, Content, OperationId, TimeoutMs},
    Config,
    Cache
) -> handle_write(WorkspaceId, Segments, Content, OperationId, TimeoutMs, normal, Config, Cache);
handle_request(
    {alang_workspace_request_v2, WorkspaceId, Segments, Content, OperationId, TimeoutMs,
        crash_after_mutation},
    #{test_faults := true} = Config,
    Cache
) -> handle_write(WorkspaceId, Segments, Content, OperationId, TimeoutMs,
    crash_after_mutation, Config, Cache);
handle_request(
    {alang_workspace_lookup_v1, WorkspaceId, Segments, OperationId, PayloadDigest,
        ArtifactDigest, TimeoutMs},
    Config,
    Cache
) ->
    case validate_lookup(WorkspaceId, Segments, OperationId, PayloadDigest, ArtifactDigest,
        TimeoutMs, Config) of
        ok -> {lookup_operation(Segments, OperationId, PayloadDigest, ArtifactDigest, Config), Cache};
        {error, Reason} -> {error_response(safe_operation_id(OperationId), Reason), Cache}
    end;
handle_request(_Request, _Config, Cache) ->
    {error_response(<<"invalid">>, invalid_request), Cache}.

handle_write(WorkspaceId, Segments, Content, OperationId, TimeoutMs, Mode, Config, Cache) ->
    case validate_request(WorkspaceId, Segments, Content, OperationId, TimeoutMs, Config) of
        ok -> idempotent_write(WorkspaceId, Segments, Content, OperationId, Mode, Config, Cache);
        {error, Reason} -> {error_response(safe_operation_id(OperationId), Reason), Cache}
    end.

validate_request(WorkspaceId, Segments, Content, OperationId, TimeoutMs, Config) ->
    case {
        WorkspaceId =:= maps:get(workspace_id, Config),
        valid_segments(Segments),
        is_binary(Content) andalso byte_size(Content) =< maps:get(max_content_bytes, Config),
        valid_id(OperationId),
        valid_timeout(TimeoutMs)
    } of
        {false, _, _, _, _} -> {error, wrong_workspace};
        {_, false, _, _, _} -> {error, invalid_path};
        {_, _, false, _, _} -> {error, content_too_large};
        {_, _, _, false, _} -> {error, invalid_operation_id};
        {_, _, _, _, false} -> {error, deadline_exceeded};
        {true, true, true, true, true} -> ok
    end.

validate_lookup(WorkspaceId, Segments, OperationId, PayloadDigest, ArtifactDigest,
    TimeoutMs, Config) ->
    case {
        WorkspaceId =:= maps:get(workspace_id, Config),
        valid_segments(Segments),
        valid_id(OperationId),
        valid_digest(PayloadDigest),
        valid_digest(ArtifactDigest),
        valid_timeout(TimeoutMs)
    } of
        {false, _, _, _, _, _} -> {error, wrong_workspace};
        {_, false, _, _, _, _} -> {error, invalid_path};
        {_, _, false, _, _, _} -> {error, invalid_operation_id};
        {_, _, _, false, _, _} -> {error, invalid_payload_digest};
        {_, _, _, _, false, _} -> {error, invalid_artifact_digest};
        {_, _, _, _, _, false} -> {error, deadline_exceeded};
        {true, true, true, true, true, true} -> ok
    end.

idempotent_write(WorkspaceId, Segments, Content, OperationId, Mode, Config, Cache) ->
    PayloadDigest = hex(crypto:hash(sha256, term_to_binary(
        {WorkspaceId, Segments, Content},
        [deterministic]
    ))),
    ArtifactDigest = hex(crypto:hash(sha256, Content)),
    case maps:find(OperationId, Cache) of
        {ok, #{payload_digest := PayloadDigest, result := Result}} ->
            {setelement(6, Result, replayed), Cache};
        {ok, _DifferentPayload} -> {error_response(OperationId, operation_conflict), Cache};
        error -> durable_idempotent_write(Segments, Content, OperationId, PayloadDigest,
            ArtifactDigest, Mode, Config, Cache)
    end.

durable_idempotent_write(Segments, Content, OperationId, PayloadDigest, ArtifactDigest,
    Mode, Config, Cache) ->
    case read_receipt(OperationId, Config) of
        not_found ->
            case receipt_count(Config) < maps:get(max_cache_entries, Config) of
                true -> execute_new_write(Segments, Content, OperationId, PayloadDigest,
                    ArtifactDigest, Mode, Config, Cache);
                false -> {error_response(OperationId, idempotency_cache_full), Cache}
            end;
        {ok, Receipt} -> replay_or_reconcile_write(Receipt, Segments, Content, OperationId,
            PayloadDigest, ArtifactDigest, Mode, Config, Cache);
        {error, Reason} -> {error_response(OperationId, Reason), Cache}
    end.

execute_new_write(Segments, Content, OperationId, PayloadDigest, ArtifactDigest, Mode,
    Config, Cache) ->
    Root = maps:get(root, Config),
    case resolve_target(Root, Segments) of
        {ok, Target} ->
            Prior = target_state(Target),
            case Prior of
                unavailable -> {error_response(OperationId, path_unavailable), Cache};
                _ ->
                    Receipt = #{
                        format => alang_workspace_receipt_v1,
                        workspace_id => maps:get(workspace_id, Config),
                        path_segments => Segments,
                        operation_id => OperationId,
                        payload_digest => PayloadDigest,
                        artifact_digest => ArtifactDigest,
                        bytes => byte_size(Content),
                        prior => Prior,
                        status => intent
                    },
                    case publish_new_receipt(Receipt, Config) of
                        ok -> execute_intended_write(Target, Content, Receipt, Mode, Config, Cache);
                        {error, Reason} -> {error_response(OperationId, Reason), Cache}
                    end
            end;
        {error, Reason} -> {error_response(OperationId, Reason), Cache}
    end.

execute_intended_write(Target, Content, Receipt, Mode, Config, Cache) ->
    OperationId = maps:get(operation_id, Receipt),
    case atomic_write(Target, Content, OperationId) of
        ok when Mode =:= crash_after_mutation -> halt(70);
        ok ->
            Completed = Receipt#{status := completed},
            case replace_receipt(Completed, Config) of
                ok -> successful_write(Completed, created, Cache);
                {error, Reason} -> {error_response(OperationId, Reason), Cache}
            end;
        {error, Reason} -> {error_response(OperationId, Reason), Cache}
    end.

replay_or_reconcile_write(Receipt, Segments, Content, OperationId, PayloadDigest,
    ArtifactDigest, Mode, Config, Cache) ->
    case receipt_matches(Receipt, Segments, OperationId, PayloadDigest, ArtifactDigest) of
        false -> {error_response(OperationId, operation_conflict), Cache};
        true ->
            case maps:get(status, Receipt) of
                completed -> successful_write(Receipt, replayed, Cache);
                intent -> reconcile_intent_for_write(Receipt, Content, Mode, Config, Cache)
            end
    end.

reconcile_intent_for_write(Receipt, Content, Mode, Config, Cache) ->
    {ok, Target} = resolve_target(maps:get(root, Config), maps:get(path_segments, Receipt)),
    Current = target_state(Target),
    Expected = #{digest => maps:get(artifact_digest, Receipt), bytes => maps:get(bytes, Receipt)},
    PriorState = maps:get(prior, Receipt),
    case Current of
        Expected ->
            Completed = Receipt#{status := completed},
            case replace_receipt(Completed, Config) of
                ok -> successful_write(Completed, replayed, Cache);
                {error, Reason} -> {error_response(maps:get(operation_id, Receipt), Reason), Cache}
            end;
        Prior when Prior =:= PriorState ->
            execute_intended_write(Target, Content, Receipt, Mode, Config, Cache);
        _ -> {error_response(maps:get(operation_id, Receipt), outcome_unknown), Cache}
    end.

successful_write(Receipt, Disposition, Cache) ->
    OperationId = maps:get(operation_id, Receipt),
    Result = {alang_workspace_result_v1, ok, OperationId,
        maps:get(artifact_digest, Receipt), maps:get(bytes, Receipt), Disposition},
    Entry = #{payload_digest => maps:get(payload_digest, Receipt), result => Result},
    {Result, Cache#{OperationId => Entry}}.

lookup_operation(Segments, OperationId, PayloadDigest, ArtifactDigest, Config) ->
    case read_receipt(OperationId, Config) of
        not_found -> lookup_result(OperationId, not_submitted, PayloadDigest, ArtifactDigest, undefined);
        {error, _Reason} -> lookup_result(OperationId, outcome_unknown, PayloadDigest,
            ArtifactDigest, undefined);
        {ok, Receipt} -> lookup_receipt(Receipt, Segments, OperationId, PayloadDigest,
            ArtifactDigest, Config)
    end.

lookup_receipt(Receipt, Segments, OperationId, PayloadDigest, ArtifactDigest, Config) ->
    case receipt_matches(Receipt, Segments, OperationId, PayloadDigest, ArtifactDigest) of
        false -> lookup_result(OperationId, conflict, PayloadDigest, ArtifactDigest, undefined);
        true ->
            {ok, Target} = resolve_target(maps:get(root, Config), Segments),
            Current = target_state(Target),
            Expected = #{digest => ArtifactDigest, bytes => maps:get(bytes, Receipt)},
            PriorState = maps:get(prior, Receipt),
            case {maps:get(status, Receipt), Current} of
                {completed, Expected} -> lookup_result(OperationId, completed, PayloadDigest,
                    ArtifactDigest, maps:get(bytes, Receipt));
                {completed, _Different} -> lookup_result(OperationId, outcome_unknown,
                    PayloadDigest, ArtifactDigest, undefined);
                {intent, Expected} ->
                    Completed = Receipt#{status := completed},
                    case replace_receipt(Completed, Config) of
                        ok -> lookup_result(OperationId, completed, PayloadDigest,
                            ArtifactDigest, maps:get(bytes, Receipt));
                        {error, _Reason} -> lookup_result(OperationId, outcome_unknown,
                            PayloadDigest, ArtifactDigest, undefined)
                    end;
                {intent, Prior} when Prior =:= PriorState ->
                    lookup_result(OperationId, not_submitted, PayloadDigest, ArtifactDigest, undefined);
                {intent, _Different} -> lookup_result(OperationId, outcome_unknown,
                    PayloadDigest, ArtifactDigest, undefined)
            end
    end.

receipt_matches(Receipt, Segments, OperationId, PayloadDigest, ArtifactDigest) ->
    maps:get(format, Receipt, invalid) =:= alang_workspace_receipt_v1 andalso
        maps:get(path_segments, Receipt, invalid) =:= Segments andalso
        maps:get(operation_id, Receipt, invalid) =:= OperationId andalso
        maps:get(payload_digest, Receipt, invalid) =:= PayloadDigest andalso
        maps:get(artifact_digest, Receipt, invalid) =:= ArtifactDigest.

initialize_receipts(Config) ->
    Directory = filename:join(maps:get(root, Config), ?RECEIPT_DIR),
    case file:read_link_info(Directory) of
        {ok, #file_info{type = directory}} -> {ok, Config#{receipt_dir => Directory}};
        {ok, _Other} -> {error, invalid_receipt_directory};
        {error, enoent} ->
            case file:make_dir(Directory) of
                ok ->
                    case sync_directory(maps:get(root, Config)) of
                        ok -> {ok, Config#{receipt_dir => Directory}};
                        {error, _} = Error -> Error
                    end;
                {error, _Reason} -> {error, receipt_unavailable}
            end;
        {error, _Reason} -> {error, receipt_unavailable}
    end.

read_receipt(OperationId, Config) ->
    Path = receipt_path(OperationId, Config),
    case file:read_file_info(Path) of
        {error, enoent} -> not_found;
        {ok, #file_info{type = regular, size = Size}} when Size =< 4096 ->
            case file:read_file(Path) of
                {ok, Binary} ->
                    try binary_to_term(Binary, [safe]) of
                        Receipt ->
                            case valid_receipt(Receipt, Config) of
                                true -> {ok, Receipt};
                                false -> {error, receipt_corrupt}
                            end
                    catch
                        error:badarg -> {error, receipt_corrupt}
                    end;
                {error, _Reason} -> {error, receipt_unavailable}
            end;
        {ok, _Other} -> {error, receipt_corrupt};
        {error, _Reason} -> {error, receipt_unavailable}
    end.

valid_receipt(Receipt, Config) when is_map(Receipt), map_size(Receipt) =:= 9 ->
    lists:sort(maps:keys(Receipt)) =:= lists:sort([
        format, workspace_id, path_segments, operation_id, payload_digest,
        artifact_digest, bytes, prior, status
    ]) andalso
        maps:get(format, Receipt) =:= alang_workspace_receipt_v1 andalso
        maps:get(workspace_id, Receipt) =:= maps:get(workspace_id, Config) andalso
        valid_segments(maps:get(path_segments, Receipt)) andalso
        valid_id(maps:get(operation_id, Receipt)) andalso
        valid_digest(maps:get(payload_digest, Receipt)) andalso
        valid_digest(maps:get(artifact_digest, Receipt)) andalso
        is_integer(maps:get(bytes, Receipt)) andalso maps:get(bytes, Receipt) >= 0 andalso
        valid_target_state(maps:get(prior, Receipt)) andalso
        lists:member(maps:get(status, Receipt), [intent, completed]);
valid_receipt(_Receipt, _Config) -> false.

publish_new_receipt(Receipt, Config) ->
    atomic_publish(receipt_path(maps:get(operation_id, Receipt), Config),
        term_to_binary(Receipt, [deterministic]), exclusive).

replace_receipt(Receipt, Config) ->
    atomic_publish(receipt_path(maps:get(operation_id, Receipt), Config),
        term_to_binary(Receipt, [deterministic]), replace).

receipt_path(OperationId, Config) ->
    Name = binary_to_list(hex(crypto:hash(sha256, OperationId))) ++ ".term",
    filename:join(maps:get(receipt_dir, Config), Name).

receipt_count(Config) ->
    length(filelib:wildcard(filename:join(maps:get(receipt_dir, Config), "*.term"))).

resolve_target(Root, Segments) ->
    case file:read_link_info(Root) of
        {ok, #file_info{type = directory}} -> walk_parent(Root, Segments);
        {ok, #file_info{type = symlink}} -> {error, symlink_escape};
        {ok, _Other} -> {error, invalid_workspace_root};
        {error, _Reason} -> {error, invalid_workspace_root}
    end.

walk_parent(_Root, []) -> {error, invalid_path};
walk_parent(Root, [Final]) -> validate_target(filename:join(Root, binary_to_list(Final)));
walk_parent(Root, [Segment | Rest]) ->
    Next = filename:join(Root, binary_to_list(Segment)),
    case file:read_link_info(Next) of
        {ok, #file_info{type = directory}} -> walk_parent(Next, Rest);
        {ok, #file_info{type = symlink}} -> {error, symlink_escape};
        {ok, _Other} -> {error, special_file};
        {error, enoent} -> {error, missing_parent};
        {error, _Reason} -> {error, path_unavailable}
    end.

validate_target(Target) ->
    case file:read_link_info(Target) of
        {ok, #file_info{type = regular}} -> {ok, Target};
        {ok, #file_info{type = symlink}} -> {error, symlink_escape};
        {ok, _Other} -> {error, special_file};
        {error, enoent} -> {ok, Target};
        {error, _Reason} -> {error, path_unavailable}
    end.

target_state(Target) ->
    case file:read_link_info(Target) of
        {error, enoent} -> missing;
        {ok, #file_info{type = regular}} ->
            case file:read_file(Target) of
                {ok, Content} -> #{digest => hex(crypto:hash(sha256, Content)), bytes => byte_size(Content)};
                {error, _Reason} -> unavailable
            end;
        _ -> unavailable
    end.

valid_target_state(missing) -> true;
valid_target_state(#{digest := Digest, bytes := Bytes}) ->
    valid_digest(Digest) andalso is_integer(Bytes) andalso Bytes >= 0;
valid_target_state(_) -> false.

atomic_write(Target, Content, OperationId) ->
    Parent = filename:dirname(Target),
    TempName = ".alang-" ++ binary_to_list(binary:part(hex(crypto:hash(sha256, OperationId)), 0, 24)) ++
        ".tmp",
    Temp = filename:join(Parent, TempName),
    case file:open(Temp, [write, binary, raw, exclusive]) of
        {ok, Device} -> write_and_rename(Device, Temp, Target, Content);
        {error, eexist} -> {error, temporary_file_conflict};
        {error, _Reason} -> {error, write_failed}
    end.

write_and_rename(Device, Temp, Target, Content) ->
    Outcome = case file:write(Device, Content) of
        ok -> file:sync(Device);
        {error, _WriteReason} -> {error, write_failed}
    end,
    _ = file:close(Device),
    case Outcome of
        ok ->
            case file:rename(Temp, Target) of
                ok ->
                    case sync_directory(filename:dirname(Target)) of
                        ok -> ok;
                        {error, _} -> {error, write_failed}
                    end;
                {error, _RenameReason} ->
                    _ = file:delete(Temp),
                    {error, write_failed}
            end;
        {error, _} ->
            _ = file:delete(Temp),
            {error, write_failed}
    end.

atomic_publish(Final, Binary, Mode) ->
    Temp = Final ++ ".tmp-" ++ integer_to_list(erlang:unique_integer([monotonic, positive])),
    case file:open(Temp, [write, binary, raw, exclusive]) of
        {ok, Device} ->
            Outcome = case file:write(Device, Binary) of
                ok -> file:sync(Device);
                {error, _Reason} -> {error, receipt_unavailable}
            end,
            _ = file:close(Device),
            publish_renamed(Outcome, Temp, Final, Mode);
        {error, _Reason} -> {error, receipt_unavailable}
    end.

publish_renamed(ok, Temp, Final, exclusive) ->
    case file:read_link_info(Final) of
        {error, enoent} -> publish_rename(Temp, Final);
        _ ->
            _ = file:delete(Temp),
            {error, operation_conflict}
    end;
publish_renamed(ok, Temp, Final, replace) -> publish_rename(Temp, Final);
publish_renamed({error, _}, Temp, _Final, _Mode) ->
    _ = file:delete(Temp),
    {error, receipt_unavailable}.

publish_rename(Temp, Final) ->
    case file:rename(Temp, Final) of
        ok -> sync_directory(filename:dirname(Final));
        {error, _Reason} ->
            _ = file:delete(Temp),
            {error, receipt_unavailable}
    end.

sync_directory(Directory) ->
    case filelib:is_regular("/usr/bin/sync") of
        true ->
            try open_port({spawn_executable, "/usr/bin/sync"},
                [binary, exit_status, stderr_to_stdout, use_stdio, hide,
                    {args, ["-d", Directory]}]) of
                Port -> wait_sync(Port, 0)
            catch
                error:_Reason -> {error, receipt_unavailable}
            end;
        false -> {error, receipt_unavailable}
    end.

wait_sync(Port, Bytes) when Bytes =< 4096 ->
    receive
        {Port, {data, Binary}} -> wait_sync(Port, Bytes + byte_size(Binary));
        {Port, {exit_status, 0}} -> ok;
        {Port, {exit_status, _Status}} -> {error, receipt_unavailable}
    after 1000 ->
        _ = erlang:port_close(Port),
        {error, receipt_unavailable}
    end;
wait_sync(Port, _Bytes) ->
    _ = erlang:port_close(Port),
    {error, receipt_unavailable}.

valid_segments([?RECEIPT_DIR | _Rest]) -> false;
valid_segments(Segments) when
    is_list(Segments), Segments =/= [], length(Segments) =< ?MAX_SEGMENTS
-> lists:all(fun valid_segment/1, Segments);
valid_segments(_) -> false.

valid_segment(Segment) ->
    valid_id(Segment) andalso Segment =/= <<".">> andalso Segment =/= <<"..">> andalso
        binary:match(Segment, <<"/">>) =:= nomatch andalso
        binary:match(Segment, <<"\\">>) =:= nomatch andalso
        binary:match(Segment, <<0>>) =:= nomatch.

valid_timeout(TimeoutMs) ->
    is_integer(TimeoutMs) andalso TimeoutMs > 0 andalso TimeoutMs =< ?MAX_TIMEOUT_MS.

valid_id(Value) ->
    is_binary(Value) andalso byte_size(Value) > 0 andalso byte_size(Value) =< ?MAX_SEGMENT_BYTES.

valid_digest(Value) when is_binary(Value), byte_size(Value) =:= 64 ->
    lists:all(fun is_hex/1, binary_to_list(Value));
valid_digest(_) -> false.

is_hex(Character) when Character >= $0, Character =< $9 -> true;
is_hex(Character) when Character >= $a, Character =< $f -> true;
is_hex(_) -> false.

safe_operation_id(OperationId) when is_binary(OperationId), byte_size(OperationId) =< 128 -> OperationId;
safe_operation_id(_) -> <<"invalid">>.

error_response(OperationId, Reason) ->
    {alang_workspace_result_v1, error, OperationId, Reason}.

lookup_result(OperationId, Status, PayloadDigest, ArtifactDigest, Bytes) ->
    {alang_workspace_lookup_result_v1, OperationId, Status, PayloadDigest, ArtifactDigest, Bytes}.

parse_arguments([WorkspaceEncoded, Root, MaxContent, MaxResponse, MaxCache, TestFaults]) ->
    try
        WorkspaceId = base64:decode(list_to_binary(WorkspaceEncoded)),
        Config = #{
            workspace_id => WorkspaceId,
            root => Root,
            max_content_bytes => list_to_integer(MaxContent),
            max_response_bytes => list_to_integer(MaxResponse),
            max_cache_entries => list_to_integer(MaxCache),
            test_faults => parse_boolean(TestFaults)
        },
        case valid_config(Config) of
            true -> {ok, Config};
            false -> {error, invalid_configuration}
        end
    catch
        _:_ -> {error, invalid_arguments}
    end;
parse_arguments(_) -> {error, invalid_arguments}.

parse_boolean("true") -> true;
parse_boolean("false") -> false;
parse_boolean(_Value) -> invalid.

valid_config(#{workspace_id := WorkspaceId, root := Root, max_content_bytes := MaxContent,
    max_response_bytes := MaxResponse, max_cache_entries := MaxCache, test_faults := TestFaults}) ->
    valid_id(WorkspaceId) andalso filename:pathtype(Root) =:= absolute andalso
        is_integer(MaxContent) andalso MaxContent > 0 andalso MaxContent =< 65536 andalso
        is_integer(MaxResponse) andalso MaxResponse >= 512 andalso MaxResponse =< 4096 andalso
        is_integer(MaxCache) andalso MaxCache > 0 andalso MaxCache =< 1024 andalso
        is_boolean(TestFaults).

hex(Binary) ->
    iolist_to_binary([io_lib:format("~2.16.0b", [Byte]) || <<Byte>> <= Binary]).
