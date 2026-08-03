-module(alang_phase4_workspace_sidecar).

-include_lib("kernel/include/file.hrl").

-export([main/0]).

-define(MAX_SEGMENTS, 32).
-define(MAX_SEGMENT_BYTES, 128).
-define(MAX_TIMEOUT_MS, 60000).

-spec main() -> no_return().
main() ->
    case parse_arguments(init:get_plain_arguments()) of
        {ok, Config} ->
            Port = open_port({fd, 0, 1}, [binary, {packet, 4}, in, out, eof]),
            true = erlang:port_command(
                Port,
                term_to_binary({alang_workspace_sidecar_v1, ready}, [deterministic])
            ),
            loop(Port, Config, #{});
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
) ->
    case validate_request(WorkspaceId, Segments, Content, OperationId, TimeoutMs, Config) of
        ok -> idempotent_write(WorkspaceId, Segments, Content, OperationId, Config, Cache);
        {error, Reason} -> {error_response(safe_operation_id(OperationId), Reason), Cache}
    end;
handle_request(_Request, _Config, Cache) ->
    {error_response(<<"invalid">>, invalid_request), Cache}.

validate_request(WorkspaceId, Segments, Content, OperationId, TimeoutMs, Config) ->
    case {
        WorkspaceId =:= maps:get(workspace_id, Config),
        valid_segments(Segments),
        is_binary(Content) andalso byte_size(Content) =< maps:get(max_content_bytes, Config),
        valid_id(OperationId),
        is_integer(TimeoutMs) andalso TimeoutMs > 0 andalso TimeoutMs =< ?MAX_TIMEOUT_MS
    } of
        {false, _, _, _, _} -> {error, wrong_workspace};
        {_, false, _, _, _} -> {error, invalid_path};
        {_, _, false, _, _} -> {error, content_too_large};
        {_, _, _, false, _} -> {error, invalid_operation_id};
        {_, _, _, _, false} -> {error, deadline_exceeded};
        {true, true, true, true, true} -> ok
    end.

idempotent_write(WorkspaceId, Segments, Content, OperationId, Config, Cache) ->
    PayloadDigest = crypto:hash(sha256, term_to_binary(
        {WorkspaceId, Segments, Content},
        [deterministic]
    )),
    case maps:find(OperationId, Cache) of
        {ok, #{payload_digest := PayloadDigest, result := Result}} ->
            {setelement(6, Result, replayed), Cache};
        {ok, _DifferentPayload} -> {error_response(OperationId, operation_conflict), Cache};
        error ->
            case map_size(Cache) < maps:get(max_cache_entries, Config) of
                true -> execute_write(Segments, Content, OperationId, PayloadDigest, Config, Cache);
                false -> {error_response(OperationId, idempotency_cache_full), Cache}
            end
    end.

execute_write(Segments, Content, OperationId, PayloadDigest, Config, Cache) ->
    Root = maps:get(root, Config),
    case resolve_target(Root, Segments) of
        {ok, Target} ->
            case atomic_write(Target, Content, OperationId) of
                ok ->
                    Digest = hex(crypto:hash(sha256, Content)),
                    Result = {alang_workspace_result_v1, ok, OperationId, Digest,
                        byte_size(Content), created},
                    Entry = #{payload_digest => PayloadDigest, result => Result},
                    {Result, Cache#{OperationId => Entry}};
                {error, Reason} -> {error_response(OperationId, Reason), Cache}
            end;
        {error, Reason} -> {error_response(OperationId, Reason), Cache}
    end.

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
        ok ->
            case file:sync(Device) of
                ok -> ok;
                {error, _SyncReason} -> {error, write_failed}
            end;
        {error, _WriteReason} -> {error, write_failed}
    end,
    _ = file:close(Device),
    case Outcome of
        ok ->
            case file:rename(Temp, Target) of
                ok -> ok;
                {error, _RenameReason} ->
                    _ = file:delete(Temp),
                    {error, write_failed}
            end;
        {error, _} = Error ->
            _ = file:delete(Temp),
            Error
    end.

valid_segments(Segments) when
    is_list(Segments),
    Segments =/= [],
    length(Segments) =< ?MAX_SEGMENTS
-> lists:all(fun valid_segment/1, Segments);
valid_segments(_) -> false.

valid_segment(Segment) ->
    valid_id(Segment) andalso Segment =/= <<".">> andalso Segment =/= <<"..">> andalso
        binary:match(Segment, <<"/">>) =:= nomatch andalso
        binary:match(Segment, <<"\\">>) =:= nomatch andalso
        binary:match(Segment, <<0>>) =:= nomatch.

valid_id(Value) ->
    is_binary(Value) andalso byte_size(Value) > 0 andalso byte_size(Value) =< ?MAX_SEGMENT_BYTES.

safe_operation_id(OperationId) when is_binary(OperationId), byte_size(OperationId) =< 128 -> OperationId;
safe_operation_id(_) -> <<"invalid">>.

error_response(OperationId, Reason) ->
    {alang_workspace_result_v1, error, OperationId, Reason}.

parse_arguments([WorkspaceEncoded, Root, MaxContent, MaxResponse, MaxCache]) ->
    try
        WorkspaceId = base64:decode(list_to_binary(WorkspaceEncoded)),
        Config = #{
            workspace_id => WorkspaceId,
            root => Root,
            max_content_bytes => list_to_integer(MaxContent),
            max_response_bytes => list_to_integer(MaxResponse),
            max_cache_entries => list_to_integer(MaxCache)
        },
        case valid_config(Config) of
            true -> {ok, Config};
            false -> {error, invalid_configuration}
        end
    catch
        _:_ -> {error, invalid_arguments}
    end;
parse_arguments(_) -> {error, invalid_arguments}.

valid_config(#{workspace_id := WorkspaceId, root := Root, max_content_bytes := MaxContent,
    max_response_bytes := MaxResponse, max_cache_entries := MaxCache}) ->
    valid_id(WorkspaceId) andalso filename:pathtype(Root) =:= absolute andalso
        is_integer(MaxContent) andalso MaxContent > 0 andalso MaxContent =< 65536 andalso
        is_integer(MaxResponse) andalso MaxResponse >= 512 andalso MaxResponse =< 4096 andalso
        is_integer(MaxCache) andalso MaxCache > 0 andalso MaxCache =< 1024.

hex(Binary) ->
    iolist_to_binary([io_lib:format("~2.16.0b", [Byte]) || <<Byte>> <= Binary]).
