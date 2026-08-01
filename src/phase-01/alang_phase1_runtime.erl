-module(alang_phase1_runtime).

-export([main/0, run_canonical/4, run_case/4]).

-define(GENERATED_MODULE, phase1_counter_v1).
-define(TIMEOUT_MILLISECONDS, 2000).

-type case_name() ::
    canonical_success
    | unsupported_abi
    | invalid_payload
    | oversized_payload
    | unavailable_operation
    | invalid_correlation
    | invalid_reply_target
    | malformed_envelope
    | unexpected_process_exit.
-type error_reason() :: term().
-type path() :: file:filename().

-spec main() -> no_return().
main() ->
    ArtifactDirectory = "build/phase-01/artifact",
    FixturePath = "src/phase-01/semantic-fixture.config",
    ToolchainPath = "src/phase-01/toolchain.config",
    EvidenceDirectory = "build/phase-01/evidence",
    case run_canonical(
        ArtifactDirectory,
        FixturePath,
        ToolchainPath,
        EvidenceDirectory
    ) of
        {ok, Evidence} ->
            print_normalized_trace(maps:get(normalized_trace, Evidence)),
            halt(0);
        {error, Reason} ->
            io:format(standard_error, "phase_1_runtime_error ~tp~n", [Reason]),
            halt(1)
    end.

-spec run_canonical(path(), path(), path(), path()) ->
    {ok, map()} | {error, error_reason()}.
run_canonical(ArtifactDirectory, FixturePath, ToolchainPath, EvidenceDirectory) ->
    case run_case(ArtifactDirectory, FixturePath, ToolchainPath, canonical_success) of
        {ok, Observation} ->
            case normalized_success_trace(Observation) of
                {ok, Lines} ->
                    Evidence = Observation#{normalized_trace => Lines},
                    case write_evidence(EvidenceDirectory, Evidence) of
                        ok -> {ok, Evidence};
                        {error, _} = Error -> Error
                    end;
                {error, _} = Error -> Error
            end;
        {error, _} = Error -> Error
    end.

-spec run_case(path(), path(), path(), case_name()) ->
    {ok, map()} | {error, error_reason()}.
run_case(ArtifactDirectory, FixturePath, ToolchainPath, CaseName) ->
    case alang_phase1_package:verify(ArtifactDirectory, FixturePath, ToolchainPath) of
        {ok, Verified} ->
            case load_verified_artifact(Verified) of
                {ok, LoadedFile} -> observe_case(CaseName, Verified, LoadedFile);
                {error, _} = Error -> Error
            end;
        {error, _} = Error -> Error
    end.

load_verified_artifact(Verified) ->
    BeamPath = maps:get(beam_path, Verified),
    Beam = maps:get(beam, Verified),
    _ = code:purge(?GENERATED_MODULE),
    _ = code:delete(?GENERATED_MODULE),
    case code:load_binary(?GENERATED_MODULE, BeamPath, Beam) of
        {module, ?GENERATED_MODULE} ->
            case code:is_loaded(?GENERATED_MODULE) of
                {file, LoadedFile} -> {ok, LoadedFile};
                false -> {error, generated_module_not_loaded}
            end;
        {error, Reason} ->
            {error, {beam_load_failed, Reason}}
    end.

observe_case(CaseName, Verified, LoadedFile) ->
    ReductionsBefore = reductions_total(),
    HarnessPid = self(),
    GeneratedPid = spawn(?GENERATED_MODULE, start, [HarnessPid]),
    Monitor = erlang:monitor(process, GeneratedPid),
    1 = erlang:trace(GeneratedPid, true, [running, procs, {tracer, HarnessPid}]),
    ProcessBefore = process_snapshot(GeneratedPid),
    dispatch_case(CaseName, GeneratedPid, HarnessPid),
    case collect(GeneratedPid, Monitor, deadline(), [], []) of
        {ok, Messages, SchedulerEvents, ExitReason} ->
            ReductionsAfter = reductions_total(),
            Observation = #{
                case_name => CaseName,
                classification => classify(Messages, ExitReason),
                messages => Messages,
                exit_reason => ExitReason,
                generated_pid => GeneratedPid,
                harness_pid => HarnessPid,
                node => node(),
                os_pid => list_to_binary(os:getpid()),
                scheduler_count => erlang:system_info(schedulers),
                scheduler_events => SchedulerEvents,
                scheduler_visible => scheduler_visible(SchedulerEvents),
                reductions_before => ReductionsBefore,
                reductions_after => ReductionsAfter,
                process_before => ProcessBefore,
                loaded_module => ?GENERATED_MODULE,
                loaded_file => LoadedFile,
                beam_sha256 => maps:get(beam_sha256, Verified),
                manifest_sha256 => maps:get(manifest_sha256, Verified),
                imports => maps:get(imports, maps:get(inspection, Verified)),
                toolchain => maps:get(toolchain, Verified),
                no_interpreter_proof => no_interpreter_proof(ProcessBefore, Verified)
            },
            {ok, Observation};
        {error, _} = Error -> Error
    end.

dispatch_case(canonical_success, Pid, ReplyTo) ->
    Pid ! {alang_v1, run, <<"phase-1-success">>, ReplyTo, {input, 41}};
dispatch_case(unsupported_abi, Pid, ReplyTo) ->
    Pid ! {alang_v2, run, <<"phase-1-unsupported">>, ReplyTo, {input, 41}};
dispatch_case(invalid_payload, Pid, ReplyTo) ->
    Pid ! {alang_v1, run, <<"phase-1-payload">>, ReplyTo, {input, not_an_integer}};
dispatch_case(oversized_payload, Pid, ReplyTo) ->
    Oversized = binary:copy(<<"x">>, 2048),
    Pid ! {alang_v1, run, <<"phase-1-oversized">>, ReplyTo, {input, Oversized}};
dispatch_case(unavailable_operation, Pid, ReplyTo) ->
    Pid ! {alang_v1, run, <<"phase-1-operation">>, ReplyTo, {operation, model_call}};
dispatch_case(invalid_correlation, Pid, ReplyTo) ->
    Pid ! {alang_v1, run, <<>>, ReplyTo, {input, 41}};
dispatch_case(invalid_reply_target, Pid, _ReplyTo) ->
    Pid ! {alang_v1, run, <<"phase-1-reply">>, not_a_pid, {input, 41}};
dispatch_case(malformed_envelope, Pid, _ReplyTo) ->
    Pid ! malformed;
dispatch_case(unexpected_process_exit, Pid, _ReplyTo) ->
    exit(Pid, kill).

collect(Pid, Monitor, Deadline, Messages, SchedulerEvents) ->
    Remaining = erlang:max(0, Deadline - erlang:monotonic_time(millisecond)),
    receive
        {'DOWN', Monitor, process, Pid, ExitReason} ->
            {FinalMessages, FinalSchedulerEvents} = drain_after_down(
                Pid,
                Messages,
                SchedulerEvents
            ),
            {
                ok,
                lists:reverse(FinalMessages),
                lists:reverse(FinalSchedulerEvents),
                ExitReason
            };
        {alang_v1, trace, _Correlation, _Event} = Message ->
            collect(Pid, Monitor, Deadline, [Message | Messages], SchedulerEvents);
        {alang_v1, result, _Correlation, _Result} = Message ->
            collect(Pid, Monitor, Deadline, [Message | Messages], SchedulerEvents);
        {trace, Pid, in, Location} ->
            collect(Pid, Monitor, Deadline, Messages, [{in, Location} | SchedulerEvents]);
        {trace, Pid, out, Location} ->
            collect(Pid, Monitor, Deadline, Messages, [{out, Location} | SchedulerEvents]);
        {trace, Pid, exit, Reason} ->
            collect(Pid, Monitor, Deadline, Messages, [{exit, Reason} | SchedulerEvents]);
        {trace, Pid, Event, Detail} ->
            collect(Pid, Monitor, Deadline, Messages, [{Event, Detail} | SchedulerEvents])
    after Remaining ->
        exit(Pid, kill),
        receive
            {'DOWN', Monitor, process, Pid, _Reason} -> ok
        after ?TIMEOUT_MILLISECONDS -> ok
        end,
        {error, {runtime_timeout, Pid}}
    end.

drain_after_down(Pid, Messages, SchedulerEvents) ->
    receive
        {alang_v1, trace, _Correlation, _Event} = Message ->
            drain_after_down(Pid, [Message | Messages], SchedulerEvents);
        {alang_v1, result, _Correlation, _Result} = Message ->
            drain_after_down(Pid, [Message | Messages], SchedulerEvents);
        {trace, Pid, in, Location} ->
            drain_after_down(Pid, Messages, [{in, Location} | SchedulerEvents]);
        {trace, Pid, out, Location} ->
            drain_after_down(Pid, Messages, [{out, Location} | SchedulerEvents]);
        {trace, Pid, exit, Reason} ->
            drain_after_down(Pid, Messages, [{exit, Reason} | SchedulerEvents]);
        {trace, Pid, Event, Detail} ->
            drain_after_down(Pid, Messages, [{Event, Detail} | SchedulerEvents])
    after 10 ->
        {Messages, SchedulerEvents}
    end.

classify(Messages, normal) ->
    case lists:reverse(Messages) of
        [{alang_v1, result, _Correlation, {ok, _Value}} | _] -> ok;
        [{alang_v1, result, _Correlation, {error, Failure}} | _] -> Failure;
        _ -> {unclassified, normal}
    end;
classify(_Messages, {rejected, Failure}) ->
    Failure;
classify(_Messages, _ExitReason) ->
    unexpected_process_exit.

normalized_success_trace(#{
    messages := [
        {alang_v1, trace, <<"phase-1-success">>, received},
        {alang_v1, trace, <<"phase-1-success">>, {transition, waiting, completed}},
        {alang_v1, result, <<"phase-1-success">>, {ok, 42}}
    ],
    exit_reason := normal,
    loaded_module := ?GENERATED_MODULE,
    scheduler_visible := true,
    no_interpreter_proof := #{passed := true}
}) ->
    {ok, [
        <<"loaded phase1_counter_v1">>,
        <<"spawned phase1_counter_v1:start/1">>,
        <<"trace phase-1-success received">>,
        <<"trace phase-1-success waiting -> completed">>,
        <<"result phase-1-success ok 42">>,
        <<"down normal">>
    ]};
normalized_success_trace(Observation) ->
    {error, {canonical_observation_mismatch, Observation}}.

no_interpreter_proof(ProcessBefore, Verified) ->
    Imports = maps:get(imports, maps:get(inspection, Verified)),
    Stack = proplists:get_value(current_stacktrace, ProcessBefore, []),
    StackModules = lists:usort([
        Module
     || Frame <- Stack,
        is_tuple(Frame),
        tuple_size(Frame) >= 1,
        Module <- [element(1, Frame)],
        is_atom(Module)
    ]),
    ForbiddenModules = [erl_eval, elixir, gleam],
    ForbiddenImports = [
        Import
     || {Module, _Function, _Arity} = Import <- Imports,
        lists:member(Module, ForbiddenModules)
    ],
    ForbiddenStack = [
        Module
     || Module <- StackModules,
        lists:member(Module, ForbiddenModules)
    ],
    CurrentFunction = proplists:get_value(current_function, ProcessBefore),
    Passed =
        ForbiddenImports =:= [] andalso
        ForbiddenStack =:= [] andalso
        CurrentFunction =:= {?GENERATED_MODULE, start, 1},
    #{
        passed => Passed,
        artifact_verified_before_load => true,
        loader => code_load_binary,
        current_function => CurrentFunction,
        stack_modules => StackModules,
        forbidden_imports => ForbiddenImports,
        forbidden_stack_modules => ForbiddenStack,
        generated_imports => Imports
    }.

process_snapshot(Pid) ->
    case process_info(Pid, [
        current_function,
        current_stacktrace,
        initial_call,
        reductions,
        links,
        message_queue_len,
        status
    ]) of
        undefined -> [];
        Information -> Information
    end.

scheduler_visible(Events) ->
    lists:any(
        fun({in, {?GENERATED_MODULE, start, 1}}) -> true;
           ({in, {?GENERATED_MODULE, start, 1, _Location}}) -> true;
           (_) -> false
        end,
        Events
    ).

reductions_total() ->
    {Total, _SinceLastCall} = erlang:statistics(reductions),
    Total.

deadline() ->
    erlang:monotonic_time(millisecond) + ?TIMEOUT_MILLISECONDS.

write_evidence(Directory, Evidence) ->
    TermPath = filename:join(Directory, "canonical-success.etf"),
    TracePath = filename:join(Directory, "canonical-success.txt"),
    case filelib:ensure_dir(TermPath) of
        ok ->
            TermBytes = term_to_binary(Evidence, [deterministic]),
            TraceBytes = normalized_trace_bytes(maps:get(normalized_trace, Evidence)),
            case file:write_file(TermPath, TermBytes, [binary]) of
                ok ->
                    case file:write_file(TracePath, TraceBytes, [binary]) of
                        ok -> ok;
                        {error, Reason} -> {error, {trace_evidence_write_failed, Reason}}
                    end;
                {error, Reason} ->
                    {error, {term_evidence_write_failed, Reason}}
            end;
        {error, Reason} ->
            {error, {evidence_directory_create_failed, Reason}}
    end.

normalized_trace_bytes(Lines) ->
    iolist_to_binary([[Line, <<"\n">>] || Line <- Lines]).

print_normalized_trace(Lines) ->
    lists:foreach(fun(Line) -> io:format("~s~n", [Line]) end, Lines).
