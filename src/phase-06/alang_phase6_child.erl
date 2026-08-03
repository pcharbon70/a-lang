-module(alang_phase6_child).

-export([await/2, cancel/1, snapshot/1, start/6, validate_result/2, validate_spec/1]).

-spec start(pid(), pid(), term(), map(), map(), function()) ->
    {ok, map()} | {error, atom()}.
start(Supervisor, Broker, ParentGrant, Spec, Restriction, Handler) when
    is_pid(Supervisor), is_pid(Broker), is_function(Handler, 3)
->
    case validate_start(Spec, Restriction) of
        ok -> start_worker(Supervisor, Broker, ParentGrant, Spec, Restriction, Handler);
        {error, _} = Error -> Error
    end;
start(_Supervisor, _Broker, _ParentGrant, _Spec, _Restriction, _Handler) ->
    {error, invalid_child_start}.

start_worker(Supervisor, Broker, ParentGrant, Spec, Restriction, Handler) ->
    case alang_phase6_child_sup:start_child(Supervisor, self(), Spec, Handler) of
        {ok, Worker} ->
            Monitor = erlang:monitor(process, Worker),
            Binding = #{
                owner_pid => Worker,
                session_id => maps:get(session_id, Spec),
                artifact_digest => maps:get(artifact_digest, Spec),
                task_id => maps:get(child_task_id, Spec)
            },
            case alang_phase4_broker:restrict_child_grant(
                Broker, ParentGrant, Restriction, Binding
            ) of
                {ok, ChildGrant} -> assign_worker(Broker, Worker, Monitor, ChildGrant, Spec);
                {error, Reason} ->
                    erlang:demonitor(Monitor, [flush]),
                    gen_server:stop(Worker),
                    {error, Reason}
            end;
        {error, Reason} -> {error, normalize_start_error(Reason)}
    end.

assign_worker(Broker, Worker, Monitor, ChildGrant, Spec) ->
    CorrelationId = correlation_id(Spec),
    ReplyFence = make_ref(),
    Context = maps:merge(alang_phase4_broker:runtime_context(Broker), #{
        session_id => maps:get(session_id, Spec),
        artifact_digest => maps:get(artifact_digest, Spec),
        owner_pid => Worker,
        task_id => maps:get(child_task_id, Spec),
        presenter_pid => Worker,
        request_deadline => maps:get(deadline, Spec),
        cancelled => false,
        correlation_id => CorrelationId
    }),
    case alang_phase6_child_worker:assign(
        Worker, CorrelationId, ReplyFence, ChildGrant, Context
    ) of
        ok ->
            Handle = #{
                format => alang_child_handle_v1,
                pid => Worker,
                monitor => Monitor,
                reply_fence => ReplyFence,
                parent_task_id => maps:get(parent_task_id, Spec),
                child_task_id => maps:get(child_task_id, Spec),
                session_id => maps:get(session_id, Spec),
                correlation_id => CorrelationId,
                deadline => maps:get(deadline, Spec)
            },
            case alang_phase6_child_worker:begin_execution(Worker) of
                ok -> {ok, Handle};
                {error, Reason} ->
                    cancel(Handle),
                    {error, Reason}
            end;
        {error, Reason} ->
            erlang:demonitor(Monitor, [flush]),
            gen_server:stop(Worker),
            {error, Reason}
    end.

-spec await(map(), non_neg_integer()) -> {ok, map()} | {error, atom()}.
await(Handle, Timeout) when is_integer(Timeout), Timeout >= 0 ->
    case valid_handle(Handle) of
        true ->
            DeadlineWait = max(0, maps:get(deadline, Handle) - erlang:monotonic_time(millisecond)),
            await_loop(Handle, min(Timeout, DeadlineWait), erlang:monotonic_time(millisecond));
        false -> {error, invalid_child_handle}
    end;
await(_Handle, _Timeout) -> {error, invalid_child_timeout}.

await_loop(Handle, Timeout, Started) ->
    Pid = maps:get(pid, Handle),
    Monitor = maps:get(monitor, Handle),
    ReplyFence = maps:get(reply_fence, Handle),
    receive
        {alang_child_reply_v1, Pid, ReplyFence, Envelope} ->
            case valid_envelope(Envelope, Handle) of
                true ->
                    erlang:demonitor(Monitor, [flush]),
                    {ok, maps:get(result, Envelope)};
                false -> await_remaining(Handle, Timeout, Started)
            end;
        {'DOWN', Monitor, process, Pid, _Reason} -> {error, child_terminated}
    after Timeout ->
        cancel(Handle),
        flush_child(Handle),
        {error, child_timeout}
    end.

await_remaining(Handle, Timeout, Started) ->
    Elapsed = erlang:monotonic_time(millisecond) - Started,
    await_loop(Handle, max(0, Timeout - Elapsed), erlang:monotonic_time(millisecond)).

-spec cancel(map()) -> ok | {error, atom()}.
cancel(Handle) ->
    case valid_handle(Handle) of
        true ->
            alang_phase6_child_worker:cancel(
                maps:get(pid, Handle), maps:get(correlation_id, Handle)),
            ok;
        false -> {error, invalid_child_handle}
    end.

-spec snapshot(map()) -> map().
snapshot(Handle) -> maps:without([pid, monitor, reply_fence], Handle).

-spec validate_spec(map()) -> ok | {error, atom()}.
validate_spec(#{
    format := alang_child_spec_v1,
    parent_task_id := ParentTaskId,
    child_task_id := ChildTaskId,
    session_id := SessionId,
    artifact_digest := ArtifactDigest,
    deadline := Deadline,
    input := #{topic := Topic, source_draft := SourceDraft} = Input,
    output_schema := #{format := alang_output_schema_v1, id := markdown_draft_v1,
        max_bytes := MaxBytes, required_sections := RequiredSections} = Schema,
    completion_predicate := #{format := alang_child_completion_v1,
        required_section := RequiredSection, minimum_bytes := MinimumBytes} = Predicate,
    capability_summary := #{operations := Operations, constraints := Constraints} = Summary
} = Spec) when map_size(Spec) =:= 10, map_size(Input) =:= 2, map_size(Schema) =:= 4,
    map_size(Predicate) =:= 3, map_size(Summary) =:= 2, is_list(RequiredSections),
    is_list(Operations), is_list(Constraints) ->
    case valid_id(ParentTaskId) andalso valid_id(ChildTaskId) andalso
        ParentTaskId =/= ChildTaskId andalso valid_id(SessionId) andalso
        valid_digest(ArtifactDigest) andalso is_integer(Deadline) andalso
        Deadline > erlang:monotonic_time(millisecond) andalso
        valid_binary(Topic, 1, 4096) andalso valid_binary(SourceDraft, 0, 32768) andalso
        is_integer(MaxBytes) andalso MaxBytes > 0 andalso MaxBytes =< 65536 andalso
        RequiredSections =/= [] andalso length(RequiredSections) =< 16 andalso
        lists:all(fun valid_id/1, RequiredSections) andalso
        valid_id(RequiredSection) andalso lists:member(RequiredSection, RequiredSections) andalso
        is_integer(MinimumBytes) andalso MinimumBytes >= 0 andalso MinimumBytes =< MaxBytes andalso
        Operations =/= [] andalso length(Operations) =< 4 andalso
        lists:all(fun valid_operation/1, Operations) andalso
        length(Operations) =:= length(lists:usort(Operations)) andalso
        length(Constraints) =< 16 andalso lists:all(fun valid_constraint/1, Constraints) andalso
        not alang_phase6_context:contains_prohibited(Spec)
    of
        true -> ok;
        false -> {error, invalid_child_specification}
    end;
validate_spec(_Spec) -> {error, invalid_child_specification}.

-spec validate_result(map(), map()) -> ok | {error, atom()}.
validate_result(Spec, #{format := alang_child_result_v1, status := complete,
    output := Output, evidence_digest := EvidenceDigest} = Result) when map_size(Result) =:= 4 ->
    Schema = maps:get(output_schema, Spec),
    Predicate = maps:get(completion_predicate, Spec),
    Sections = maps:get(required_sections, Schema),
    case valid_binary(Output, maps:get(minimum_bytes, Predicate), maps:get(max_bytes, Schema)) andalso
        valid_utf8(Output) andalso lists:all(fun(Section) ->
            required_section_nonempty(Output, Section)
        end, Sections) andalso EvidenceDigest =:= digest_binary(Output)
    of
        true -> ok;
        false -> {error, invalid_child_result}
    end;
validate_result(_Spec, #{format := alang_child_result_v1, status := Status,
    reason := Reason} = Result) when map_size(Result) =:= 3 ->
    case lists:member(Status, [incomplete, failed, cancelled]) andalso
        lists:member(Reason, [deadline_exhausted, cancelled, handler_exception,
            invalid_child_result, child_terminated, model_failure, verification_failure])
    of
        true -> ok;
        false -> {error, invalid_child_result}
    end;
validate_result(_Spec, _Result) -> {error, invalid_child_result}.

validate_start(Spec, Restriction) ->
    case {validate_spec(Spec), validate_restriction_summary(Spec, Restriction)} of
        {ok, ok} -> ok;
        {{error, _} = Error, _} -> Error;
        {_, {error, _} = Error} -> Error
    end.

validate_restriction_summary(Spec, #{invocations := Invocations, budgets := Budgets,
    deadline := Deadline} = Restriction) when map_size(Restriction) =:= 3,
    is_list(Invocations), is_map(Budgets), is_integer(Deadline) ->
    Operations = lists:usort([maps:get(operation, Invocation, invalid) || Invocation <- Invocations]),
    SummaryOperations = lists:sort(maps:get(operations, maps:get(capability_summary, Spec))),
    case lists:sort(Operations) =:= SummaryOperations andalso
        lists:sort(maps:keys(Budgets)) =:= SummaryOperations andalso
        Deadline =< maps:get(deadline, Spec)
    of
        true -> ok;
        false -> {error, child_capability_summary_mismatch}
    end;
validate_restriction_summary(_Spec, _Restriction) -> {error, invalid_child_restriction}.

valid_envelope(#{format := alang_child_reply_v1, parent_task_id := ParentTaskId,
    child_task_id := ChildTaskId, session_id := SessionId, correlation_id := CorrelationId,
    result := Result} = Envelope, Handle) when map_size(Envelope) =:= 6 ->
    ParentTaskId =:= maps:get(parent_task_id, Handle) andalso
        ChildTaskId =:= maps:get(child_task_id, Handle) andalso
        SessionId =:= maps:get(session_id, Handle) andalso
        CorrelationId =:= maps:get(correlation_id, Handle) andalso is_map(Result);
valid_envelope(_Envelope, _Handle) -> false.

valid_handle(#{format := alang_child_handle_v1, pid := Pid, monitor := Monitor,
    reply_fence := ReplyFence,
    parent_task_id := ParentTaskId, child_task_id := ChildTaskId, session_id := SessionId,
    correlation_id := CorrelationId, deadline := Deadline} = Handle) when map_size(Handle) =:= 9 ->
    is_pid(Pid) andalso is_reference(Monitor) andalso is_reference(ReplyFence) andalso
        valid_id(ParentTaskId) andalso
        valid_id(ChildTaskId) andalso valid_id(SessionId) andalso valid_id(CorrelationId) andalso
        is_integer(Deadline);
valid_handle(_Handle) -> false.

flush_child(Handle) ->
    Pid = maps:get(pid, Handle),
    Monitor = maps:get(monitor, Handle),
    ReplyFence = maps:get(reply_fence, Handle),
    receive
        {alang_child_reply_v1, Pid, ReplyFence, _Envelope} -> flush_child(Handle);
        {'DOWN', Monitor, process, Pid, _Reason} -> ok
    after 50 ->
        erlang:demonitor(Monitor, [flush]),
        ok
    end.

correlation_id(Spec) ->
    Digest = digest({child_correlation, maps:without([deadline], Spec)}),
    <<"child-", (binary:part(Digest, 0, 24))/binary>>.

required_section_nonempty(Output, Section) ->
    Heading = <<"## ", Section/binary>>,
    section_has_content(binary:split(Output, <<"\n">>, [global]), Heading, false).
section_has_content([], _Heading, _Inside) -> false;
section_has_content([Line | Rest], Heading, false) ->
    section_has_content(Rest, Heading, Line =:= Heading);
section_has_content([<<"#", _/binary>> | _Rest], _Heading, true) -> false;
section_has_content([Line | Rest], Heading, true) ->
    string:trim(binary_to_list(Line)) =/= [] orelse section_has_content(Rest, Heading, true).

valid_utf8(Output) -> is_binary(unicode:characters_to_binary(Output, utf8, utf8)).
valid_operation(Operation) -> lists:member(Operation, [<<"model.complete">>, <<"workspace.write">>]).
valid_constraint(Value) -> valid_binary(Value, 1, 256).
valid_id(Value) -> valid_binary(Value, 1, 128).
valid_binary(Value, Minimum, Maximum) ->
    is_binary(Value) andalso byte_size(Value) >= Minimum andalso byte_size(Value) =< Maximum.
valid_digest(Value) when is_binary(Value), byte_size(Value) =:= 64 ->
    lists:all(fun is_hex/1, binary_to_list(Value));
valid_digest(_Value) -> false.

normalize_start_error(_Reason) -> child_start_failed.
digest_binary(Binary) -> hex(crypto:hash(sha256, Binary)).
digest(Term) -> hex(crypto:hash(sha256, term_to_binary(Term, [deterministic]))).
is_hex(Character) when Character >= $0, Character =< $9 -> true;
is_hex(Character) when Character >= $a, Character =< $f -> true;
is_hex(_Character) -> false.
hex(Binary) -> << <<(hex_digit(Nibble))>> || <<Nibble:4>> <= Binary >>.
hex_digit(Nibble) when Nibble < 10 -> $0 + Nibble;
hex_digit(Nibble) -> $a + Nibble - 10.
