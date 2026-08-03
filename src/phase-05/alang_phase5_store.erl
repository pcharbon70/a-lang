-module(alang_phase5_store).
-behaviour(gen_server).

-include_lib("kernel/include/file.hrl").

-export([
    append/3,
    checkpoint/4,
    inject_test_fault/2,
    read/2,
    start/1,
    start_link/1,
    status/1,
    stop/1
]).
-export([handle_call/3, handle_cast/2, handle_info/2, init/1, terminate/2]).

-define(CALL_TIMEOUT, 2500).
-define(MAX_MAILBOX, 32).
-define(DEFAULT_RECORD_BYTES, 65536).
-define(DEFAULT_CHECKPOINT_BYTES, 262144).
-define(DEFAULT_RECORDS, 100000).
-define(POINTER_FILE, "checkpoint.current").
-define(RECORDS_DIR, "records").

-spec start_link(map()) -> gen_server:start_ret().
start_link(Options) -> gen_server:start_link(?MODULE, Options, []).

-spec start(map()) -> gen_server:start_ret().
start(Options) -> gen_server:start(?MODULE, Options, []).

-spec append(pid(), map(), integer()) -> {ok, map()} | {error, atom()} | {error, tuple()}.
append(Store, Record, Deadline) -> bounded_call(Store, {append, Record}, Deadline).

-spec checkpoint(pid(), map(), non_neg_integer(), integer()) ->
    {ok, map()} | {error, atom()} | {error, tuple()}.
checkpoint(Store, State, Sequence, Deadline) ->
    bounded_call(Store, {checkpoint, State, Sequence}, Deadline).

-spec read(pid(), integer()) -> {ok, map()} | {error, atom()} | {error, tuple()}.
read(Store, Deadline) -> bounded_call(Store, read, Deadline).

-spec inject_test_fault(pid(), atom()) -> ok | {error, atom()}.
inject_test_fault(Store, Fault) -> gen_server:call(Store, {inject_test_fault, Fault}, ?CALL_TIMEOUT).

-spec status(pid()) -> map().
status(Store) -> gen_server:call(Store, status, ?CALL_TIMEOUT).

-spec stop(pid()) -> ok.
stop(Store) -> gen_server:stop(Store).

init(Options) ->
    process_flag(trap_exit, true),
    case validate_options(Options) of
        {ok, Config} ->
            case open_store(Config) of
                {ok, Durable} -> {ok, Config#{durable => Durable, fault => none}};
                {error, Reason} -> {stop, {store_open_failed, Reason}}
            end;
        {error, Reason} -> {stop, Reason}
    end.

handle_call({inject_test_fault, Fault}, _From, #{test_faults := true} = State) when
    Fault =:= unavailable_once; Fault =:= timeout_once
-> {reply, ok, State#{fault := Fault}};
handle_call({inject_test_fault, _Fault}, _From, State) ->
    {reply, {error, test_faults_disabled}, State};
handle_call({append, Record}, _From, State) ->
    case take_fault(State) of
        {unavailable, Updated} -> {reply, {error, store_unavailable}, Updated};
        {timeout, Updated} -> {reply, {error, store_timeout}, Updated};
        {none, Updated} ->
            {Reply, Next} = append_record(Record, Updated),
            {reply, Reply, Next}
    end;
handle_call({checkpoint, SessionState, Sequence}, _From, State) ->
    case take_fault(State) of
        {unavailable, Updated} -> {reply, {error, store_unavailable}, Updated};
        {timeout, Updated} -> {reply, {error, store_timeout}, Updated};
        {none, Updated} ->
            {Reply, Next} = publish_checkpoint(SessionState, Sequence, Updated),
            {reply, Reply, Next}
    end;
handle_call(read, _From, State) ->
    case take_fault(State) of
        {unavailable, Updated} -> {reply, {error, store_unavailable}, Updated};
        {timeout, Updated} -> {reply, {error, store_timeout}, Updated};
        {none, Updated} -> {reply, durable_read(Updated), Updated}
    end;
handle_call(status, _From, State) ->
    Durable = maps:get(durable, State),
    {reply, #{
        format => alang_store_status_v1,
        session_id => maps:get(session_id, State),
        next_sequence => maps:get(next_sequence, Durable),
        head_digest => maps:get(head_digest, Durable),
        has_checkpoint => maps:get(checkpoint, Durable) =/= none,
        fault => maps:get(fault, State)
    }, State};
handle_call(_Request, _From, State) -> {reply, {error, unsupported_store_call}, State}.

handle_cast(_Message, State) -> {noreply, State}.
handle_info(_Message, State) -> {noreply, State}.
terminate(_Reason, _State) -> ok.

bounded_call(Store, Request, Deadline) when is_pid(Store), is_integer(Deadline) ->
    Remaining = Deadline - erlang:monotonic_time(millisecond),
    case {Remaining > 0, process_info(Store, message_queue_len)} of
        {false, _} -> {error, deadline_exceeded};
        {true, {message_queue_len, Length}} when Length >= ?MAX_MAILBOX -> {error, store_backpressure};
        {true, {message_queue_len, _Length}} ->
            Timeout = erlang:min(Remaining, ?CALL_TIMEOUT),
            try gen_server:call(Store, Request, Timeout) of
                Reply -> Reply
            catch
                exit:{timeout, _} -> {error, store_timeout};
                exit:{noproc, _} -> {error, store_unavailable};
                exit:{normal, _} -> {error, store_unavailable}
            end;
        {true, undefined} -> {error, store_unavailable}
    end;
bounded_call(_Store, _Request, _Deadline) -> {error, invalid_store_request}.

validate_options(Options) when is_map(Options) ->
    Root = maps:get(root, Options, undefined),
    SessionId = maps:get(session_id, Options, undefined),
    Config = #{
        root => Root,
        session_id => SessionId,
        max_record_bytes => maps:get(max_record_bytes, Options, ?DEFAULT_RECORD_BYTES),
        max_checkpoint_bytes => maps:get(max_checkpoint_bytes, Options, ?DEFAULT_CHECKPOINT_BYTES),
        max_records => maps:get(max_records, Options, ?DEFAULT_RECORDS),
        test_faults => maps:get(test_faults, Options, false)
    },
    case valid_config(Config) of
        true -> {ok, Config};
        false -> {error, invalid_store_configuration}
    end;
validate_options(_Options) -> {error, invalid_store_configuration}.

valid_config(#{root := Root, session_id := SessionId, max_record_bytes := MaxRecord,
    max_checkpoint_bytes := MaxCheckpoint, max_records := MaxRecords, test_faults := TestFaults}) ->
    is_list(Root) andalso filename:pathtype(Root) =:= absolute andalso
        is_binary(SessionId) andalso byte_size(SessionId) > 0 andalso byte_size(SessionId) =< 128 andalso
        is_integer(MaxRecord) andalso MaxRecord >= 512 andalso MaxRecord =< ?DEFAULT_RECORD_BYTES andalso
        is_integer(MaxCheckpoint) andalso MaxCheckpoint >= 1024 andalso
            MaxCheckpoint =< ?DEFAULT_CHECKPOINT_BYTES andalso
        is_integer(MaxRecords) andalso MaxRecords > 0 andalso MaxRecords =< ?DEFAULT_RECORDS andalso
        is_boolean(TestFaults).

open_store(Config) ->
    Root = maps:get(root, Config),
    RecordsDir = filename:join(Root, ?RECORDS_DIR),
    case ensure_directory(RecordsDir) of
        ok -> load_durable(Config, RecordsDir);
        {error, _} = Error -> Error
    end.

ensure_directory(Directory) ->
    case filelib:ensure_dir(filename:join(Directory, "placeholder")) of
        ok ->
            case file:read_link_info(Directory) of
                {ok, #file_info{type = directory}} -> ok;
                {ok, #file_info{type = symlink}} -> {error, symlink_store_path};
                _ -> {error, invalid_store_path}
            end;
        {error, _Reason} -> {error, store_unavailable}
    end.

load_durable(Config, RecordsDir) ->
    SessionId = maps:get(session_id, Config),
    case read_records(RecordsDir, maps:get(max_record_bytes, Config), maps:get(max_records, Config)) of
        {ok, Records} ->
            case alang_phase5_journal:validate(Records, SessionId) of
                {ok, Journal} ->
                    case read_checkpoint(Config) of
                        {ok, Checkpoint} ->
                            {ok, #{
                                records_dir => RecordsDir,
                                records => Records,
                                next_sequence => maps:get(next_sequence, Journal),
                                head_digest => maps:get(head_digest, Journal),
                                checkpoint => Checkpoint
                            }};
                        {error, _} = Error -> Error
                    end;
                {error, Reason} -> {error, {corrupt_journal, Reason}}
            end;
        {error, _} = Error -> Error
    end.

append_record(Record, State) ->
    Durable = maps:get(durable, State),
    Next = maps:get(next_sequence, Durable),
    case maps:get(sequence, Record, invalid) of
        Sequence when is_integer(Sequence), Sequence < Next -> duplicate_record(Record, State);
        Sequence when Sequence =:= Next -> commit_new_record(Record, State);
        Sequence when is_integer(Sequence) -> {{error, {sequence_conflict, Next, Sequence}}, State};
        _ -> {{error, invalid_journal_record}, State}
    end.

duplicate_record(Record, State) ->
    Durable = maps:get(durable, State),
    Sequence = maps:get(sequence, Record),
    Existing = lists:nth(Sequence + 1, maps:get(records, Durable)),
    case maps:get(record_digest, Existing) =:= maps:get(record_digest, Record, different) of
        true -> {{ok, journal_ack(Existing, duplicate)}, State};
        false -> {{error, {sequence_conflict, Sequence}}, State}
    end.

commit_new_record(Record, State) ->
    Durable = maps:get(durable, State),
    SessionId = maps:get(session_id, State),
    Sequence = maps:get(next_sequence, Durable),
    Previous = maps:get(head_digest, Durable),
    Encoded = term_to_binary(Record, [deterministic]),
    case {
        length(maps:get(records, Durable)) < maps:get(max_records, State),
        byte_size(Encoded) =< maps:get(max_record_bytes, State),
        alang_phase5_journal:validate_append(Record, SessionId, Sequence, Previous)
    } of
        {false, _, _} -> {{error, store_record_limit}, State};
        {_, false, _} -> {{error, record_too_large}, State};
        {true, true, ok} -> write_new_record(Record, Encoded, State);
        {true, true, {error, Reason}} -> {{error, Reason}, State}
    end.

write_new_record(Record, Encoded, State) ->
    Durable = maps:get(durable, State),
    RecordsDir = maps:get(records_dir, Durable),
    Sequence = maps:get(sequence, Record),
    Final = filename:join(RecordsDir, sequence_name(Sequence)),
    case atomic_publish(Final, Encoded) of
        ok ->
            Records = maps:get(records, Durable) ++ [Record],
            UpdatedDurable = Durable#{
                records := Records,
                next_sequence := Sequence + 1,
                head_digest := maps:get(record_digest, Record)
            },
            {{ok, journal_ack(Record, committed)}, State#{durable := UpdatedDurable}};
        {error, Reason} -> {{error, Reason}, State}
    end.

publish_checkpoint(SessionState, Sequence, State) ->
    Durable = maps:get(durable, State),
    MaxCheckpointBytes = maps:get(max_checkpoint_bytes, State),
    case {
        is_integer(Sequence) andalso Sequence >= 0 andalso Sequence =< maps:get(next_sequence, Durable),
        alang_phase5_state:durable_encoding(SessionState)
    } of
        {false, _} -> {{error, invalid_checkpoint_sequence}, State};
        {true, {error, Reason}} -> {{error, Reason}, State};
        {true, {ok, Encoded}} when byte_size(Encoded) > MaxCheckpointBytes ->
            {{error, checkpoint_too_large}, State};
        {true, {ok, Encoded}} -> write_checkpoint(SessionState, Sequence, Encoded, State)
    end.

write_checkpoint(SessionState, Sequence, Encoded, State) ->
    Root = maps:get(root, State),
    {ok, Digest} = alang_phase5_state:checkpoint_digest(SessionState),
    Filename = checkpoint_name(Sequence, Digest),
    Final = filename:join(Root, Filename),
    Pointer = #{
        format => alang_checkpoint_pointer_v1,
        session_id => maps:get(session_id, State),
        sequence => Sequence,
        state_digest => Digest,
        filename => list_to_binary(Filename)
    },
    PointerBinary = term_to_binary(Pointer, [deterministic]),
    case atomic_publish(Final, Encoded) of
        ok ->
            case atomic_replace(filename:join(Root, ?POINTER_FILE), PointerBinary) of
                ok ->
                    Checkpoint = #{state => SessionState, pointer => Pointer},
                    Durable = maps:get(durable, State),
                    Ack = #{
                        format => alang_checkpoint_ack_v1,
                        session_id => maps:get(session_id, State),
                        sequence => Sequence,
                        state_digest => Digest
                    },
                    {{ok, Ack}, State#{durable := Durable#{checkpoint := Checkpoint}}};
                {error, Reason} -> {{error, Reason}, State}
            end;
        {error, Reason} -> {{error, Reason}, State}
    end.

durable_read(State) ->
    Durable = maps:get(durable, State),
    {ok, #{
        format => alang_store_snapshot_v1,
        session_id => maps:get(session_id, State),
        records => maps:get(records, Durable),
        checkpoint => maps:get(checkpoint, Durable),
        next_sequence => maps:get(next_sequence, Durable),
        head_digest => maps:get(head_digest, Durable)
    }}.

read_records(RecordsDir, MaxBytes, MaxRecords) ->
    case file:list_dir(RecordsDir) of
        {ok, Names} ->
            RecordNames = lists:sort([Name || Name <- Names, filename:extension(Name) =:= ".rec"]),
            case length(RecordNames) =< MaxRecords of
                true -> read_record_files(RecordsDir, RecordNames, MaxBytes, []);
                false -> {error, store_record_limit}
            end;
        {error, _Reason} -> {error, store_unavailable}
    end.

read_record_files(_Directory, [], _MaxBytes, Acc) -> {ok, lists:reverse(Acc)};
read_record_files(Directory, [Name | Rest], MaxBytes, Acc) ->
    Path = filename:join(Directory, Name),
    case read_safe_term(Path, MaxBytes) of
        {ok, Record} -> read_record_files(Directory, Rest, MaxBytes, [Record | Acc]);
        {error, Reason} -> {error, {corrupt_record_file, list_to_binary(Name), Reason}}
    end.

read_checkpoint(Config) ->
    Root = maps:get(root, Config),
    PointerPath = filename:join(Root, ?POINTER_FILE),
    case file:read_link_info(PointerPath) of
        {error, enoent} -> {ok, none};
        {ok, #file_info{type = regular}} -> read_checkpoint_pointer(Config, PointerPath);
        _ -> {error, corrupt_checkpoint_pointer}
    end.

read_checkpoint_pointer(Config, PointerPath) ->
    ConfigSessionId = maps:get(session_id, Config),
    case read_safe_term(PointerPath, 4096) of
        {ok, #{
            format := alang_checkpoint_pointer_v1,
            session_id := SessionId,
            sequence := Sequence,
            state_digest := Digest,
            filename := Filename
        } = Pointer} when SessionId =:= ConfigSessionId, is_integer(Sequence),
            Sequence >= 0, is_binary(Filename), byte_size(Filename) =< 256
        ->
            CheckpointPath = filename:join(maps:get(root, Config), binary_to_list(Filename)),
            case read_safe_term(CheckpointPath, maps:get(max_checkpoint_bytes, Config)) of
                {ok, SessionState} -> validate_loaded_checkpoint(SessionState, Digest, Pointer);
                {error, Reason} -> {error, {corrupt_checkpoint, Reason}}
            end;
        {ok, _Other} -> {error, corrupt_checkpoint_pointer};
        {error, Reason} -> {error, {corrupt_checkpoint_pointer, Reason}}
    end.

validate_loaded_checkpoint(SessionState, Digest, Pointer) ->
    case {alang_phase5_state:validate(SessionState), alang_phase5_state:checkpoint_digest(SessionState)} of
        {ok, {ok, Digest}} -> {ok, #{state => SessionState, pointer => Pointer}};
        _ -> {error, checkpoint_digest_mismatch}
    end.

read_safe_term(Path, MaxBytes) ->
    case file:read_file_info(Path) of
        {ok, #file_info{type = regular, size = Size}} when Size =< MaxBytes ->
            case file:read_file(Path) of
                {ok, Binary} ->
                    try binary_to_term(Binary, [safe]) of
                        Term -> {ok, Term}
                    catch
                        error:badarg -> {error, invalid_external_term}
                    end;
                {error, _Reason} -> {error, store_unavailable}
            end;
        {ok, #file_info{size = Size}} when Size > MaxBytes -> {error, stored_value_too_large};
        {ok, _Info} -> {error, special_store_file};
        {error, _Reason} -> {error, store_unavailable}
    end.

atomic_publish(Final, Binary) ->
    Temp = temporary_name(Final),
    case write_synced(Temp, Binary, exclusive) of
        ok ->
            case file:rename(Temp, Final) of
                ok -> sync_directory(filename:dirname(Final));
                {error, eexist} ->
                    _ = file:delete(Temp),
                    {error, store_conflict};
                {error, _Reason} ->
                    _ = file:delete(Temp),
                    {error, store_unavailable}
            end;
        {error, _} = Error -> Error
    end.

atomic_replace(Final, Binary) ->
    Temp = temporary_name(Final),
    case write_synced(Temp, Binary, exclusive) of
        ok ->
            case file:rename(Temp, Final) of
                ok -> sync_directory(filename:dirname(Final));
                {error, _Reason} ->
                    _ = file:delete(Temp),
                    {error, store_unavailable}
            end;
        {error, _} = Error -> Error
    end.

write_synced(Path, Binary, exclusive) ->
    case file:open(Path, [write, binary, raw, exclusive]) of
        {ok, Device} ->
            Result = case file:write(Device, Binary) of
                ok -> file:sync(Device);
                {error, _Reason} -> {error, write_failed}
            end,
            _ = file:close(Device),
            case Result of
                ok -> ok;
                {error, _} ->
                    _ = file:delete(Path),
                    {error, store_unavailable}
            end;
        {error, _Reason} -> {error, store_unavailable}
    end.

sync_directory(Directory) ->
    Executable = "/usr/bin/sync",
    case filelib:is_regular(Executable) of
        true ->
            try open_port(
                {spawn_executable, Executable},
                [binary, exit_status, stderr_to_stdout, use_stdio, hide, {args, ["-d", Directory]}]
            ) of
                Port -> wait_for_directory_sync(Port, 0)
            catch
                error:_Reason -> {error, store_unavailable}
            end;
        false -> {error, store_unavailable}
    end.

wait_for_directory_sync(Port, OutputBytes) when OutputBytes =< 4096 ->
    receive
        {Port, {data, Binary}} -> wait_for_directory_sync(Port, OutputBytes + byte_size(Binary));
        {Port, {exit_status, 0}} -> ok;
        {Port, {exit_status, _Status}} -> {error, store_unavailable}
    after 1000 ->
        _ = erlang:port_close(Port),
        {error, store_unavailable}
    end;
wait_for_directory_sync(Port, _OutputBytes) ->
    _ = erlang:port_close(Port),
    {error, store_unavailable}.

journal_ack(Record, Status) -> #{
    format => alang_journal_ack_v1,
    kind => append,
    session_id => maps:get(session_id, Record),
    sequence => maps:get(sequence, Record),
    record_digest => maps:get(record_digest, Record),
    durability => synced,
    status => Status
}.

take_fault(#{fault := unavailable_once} = State) -> {unavailable, State#{fault := none}};
take_fault(#{fault := timeout_once} = State) -> {timeout, State#{fault := none}};
take_fault(State) -> {none, State}.

sequence_name(Sequence) -> lists:flatten(io_lib:format("~20..0B.rec", [Sequence])).

checkpoint_name(Sequence, Digest) ->
    lists:flatten(io_lib:format("checkpoint-~20..0B-~s.term", [Sequence, binary:part(Digest, 0, 16)])).

temporary_name(Final) ->
    Final ++ ".tmp-" ++ integer_to_list(erlang:unique_integer([monotonic, positive])).
