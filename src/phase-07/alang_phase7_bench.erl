-module(alang_phase7_bench).

-export([benchmark/3, environment/0, percentile/2, pressure/0, suite/0]).

-define(TOOLCHAIN, "src/phase-01/toolchain.config").

-spec benchmark(binary(), pos_integer(), fun((pos_integer()) -> term())) -> map().
benchmark(Name, Count, Function) when is_binary(Name), is_integer(Count), Count > 0,
    is_function(Function, 1)
->
    _ = [Function(Index) || Index <- lists:seq(1, erlang:min(3, Count))],
    Samples = [begin {Micros, _Result} = timer:tc(Function, [Index]), Micros end
        || Index <- lists:seq(1, Count)],
    Sorted = lists:sort(Samples),
    Total = lists:sum(Sorted),
    #{name => Name, unit => microsecond, samples => Count,
        p50 => percentile(Sorted, 50), p95 => percentile(Sorted, 95),
        p99 => percentile(Sorted, 99), minimum => hd(Sorted), maximum => lists:last(Sorted),
        mean => Total div Count, total => Total,
        throughput_per_second => case Total of
            0 -> unbounded_at_timer_resolution;
            _ -> (Count * 1000000) div Total
        end}.

-spec percentile([non_neg_integer()], 1..100) -> non_neg_integer().
percentile(Sorted, Percent) when is_list(Sorted), Sorted =/= [],
    is_integer(Percent), Percent >= 1, Percent =< 100
->
    Index = (length(Sorted) * Percent + 99) div 100,
    lists:nth(Index, Sorted).

-spec suite() -> map().
suite() ->
    Fixture = compiled_fixture(),
    Base = temporary_root(),
    InitialMailbox = mailbox_length(),
    {BrokerFun, BrokerCleanup} = broker_benchmark(),
    try
        {AdapterFun, AdapterCleanup} = adapter_benchmark(Base),
        try
            Metrics0 = [
                benchmark(<<"compile">>, 12, fun(Index) -> compile_fixture(Index) end),
                benchmark(<<"inspect-load-purge">>, 30, fun(_Index) -> load_once(Fixture) end),
                benchmark(<<"task-start-complete">>, 30,
                    fun(Index) -> run_once(Fixture, Index) end),
                benchmark(<<"message-round-trip">>, 300, fun(Index) -> round_trip(Index) end),
                benchmark(<<"grant-resolution">>, 300, grant_benchmark()),
                benchmark(<<"broker-decision">>, 100, BrokerFun),
                benchmark(<<"journal-transition">>, 300, journal_benchmark()),
                benchmark(<<"workspace-adapter">>, 30, AdapterFun),
                benchmark(<<"journal-recovery">>, 60, recovery_benchmark()),
                benchmark(<<"completion-verifier">>, 100, verifier_benchmark(Base))
            ],
            Baselines = [
                benchmark(<<"typed-control-transition">>, 300,
                    fun typed_control_transition/1),
                benchmark(<<"typed-effect-validation">>, 300,
                    fun typed_effect_validation/1)
            ],
            #{format => alang_phase7_performance_v1, environment => environment(),
                metrics => Metrics0, baselines => Baselines,
                comparison => #{shared_external_adapter => <<"workspace-adapter">>,
                    interpretation => control_plane_costs_are_reported_separately},
                pressure => pressure(Fixture, InitialMailbox),
                caveat => single_host_characterization_not_a_service_level_objective}
        after
            AdapterCleanup()
        end
    after
        BrokerCleanup(),
        _ = file:del_dir_r(Base)
    end.

-spec pressure() -> map().
pressure() -> pressure(compiled_fixture(), mailbox_length()).

-spec environment() -> map().
environment() -> #{otp_release => list_to_binary(erlang:system_info(otp_release)),
    erts_version => list_to_binary(erlang:system_info(version)),
    schedulers => erlang:system_info(schedulers_online),
    logical_processors => erlang:system_info(logical_processors_available),
    word_size => erlang:system_info(wordsize),
    time_warp_mode => erlang:system_info(time_warp_mode)}.

compiled_fixture() ->
    Case = alang_phase7_generators:case_from_seed(pure_ir, 42),
    Ir = maps:get(ir, Case),
    {ok, Compiled} = alang_phase3_backend:compile_ir(Ir,
        #{source_sha256 => digest({bench, 42}), capability_manifest => manifest(Ir)}, ?TOOLCHAIN),
    #{beam => maps:get(beam, Compiled), task_id => maps:get(task_id, Case),
        inputs => maps:get(inputs, Case)}.

compile_fixture(Index) ->
    Case = alang_phase7_generators:case_from_seed(pure_ir, Index),
    Ir = maps:get(ir, Case),
    {ok, _} = alang_phase3_backend:compile_ir(Ir,
        #{source_sha256 => digest({bench_compile, Index}), capability_manifest => manifest(Ir)},
        ?TOOLCHAIN),
    ok.

load_once(#{beam := Beam}) ->
    {ok, Module, _} = alang_phase3_artifact:load(Beam),
    ok = alang_phase3_artifact:purge(Module).

run_once(#{beam := Beam, task_id := TaskId, inputs := Inputs}, Index) ->
    {ok, _} = alang_phase3_artifact:run(Beam, TaskId, Inputs,
        #{handler => fun(_Operation, _Arguments) -> {error, <<"unexpected">>} end,
            session_id => <<"phase7-bench-", (integer_to_binary(Index))/binary>>,
            timeout => 2000, max_in_flight => 1, max_mailbox => 32,
            max_trace_events => 32}),
    ok.

round_trip(Index) ->
    Parent = self(),
    Pid = spawn(fun() -> receive {Parent, Value} -> Parent ! {self(), Value} end end),
    Pid ! {Parent, Index},
    receive {Pid, Index} -> ok after 1000 -> error(round_trip_timeout) end.

grant_benchmark() ->
    Now = erlang:monotonic_time(millisecond),
    Spec = grant_spec(Now, 1000),
    Store0 = alang_phase4_grants:new_store(1),
    {ok, Grant, Store1} = alang_phase4_grants:issue(Store0, Spec, Now),
    Context = maps:merge(alang_phase4_grants:runtime_context(Store1), #{
        session_id => maps:get(session_id, Spec), artifact_digest => maps:get(artifact_digest, Spec),
        owner_pid => self(), task_id => maps:get(task_id, Spec), presenter_pid => self()}),
    fun(_Index) -> {ok, _Resolved, _Store} = alang_phase4_grants:resolve(
        Store1, Grant, Context, Now), ok end.

broker_benchmark() ->
    {ok, Broker} = alang_phase4_broker:start_link(broker_options()),
    Now = erlang:monotonic_time(millisecond),
    Spec = grant_spec(Now, 1000),
    {ok, Grant} = alang_phase4_broker:issue_grant(Broker, Spec),
    BaseContext = maps:merge(alang_phase4_broker:runtime_context(Broker), #{
        session_id => maps:get(session_id, Spec), artifact_digest => maps:get(artifact_digest, Spec),
        owner_pid => self(), task_id => maps:get(task_id, Spec), presenter_pid => self(),
        request_deadline => Now + 10000, cancelled => false}),
    Function = fun(Index) ->
        Context = BaseContext#{correlation_id => <<"bench-", (integer_to_binary(Index))/binary>>},
        Args = product({<<"workspace-a">>, <<"notes/bench.md">>, <<"x">>,
            <<"bench-op-", (integer_to_binary(Index))/binary>>}),
        {ok, Authorization} = alang_phase4_broker:authorize(Broker, Grant,
            #{effects => [<<"workspace.write">>], requirements => []},
            <<"workspace.write">>, Args, Context),
        ok = alang_phase4_broker:complete(Broker, Authorization, succeeded)
    end,
    {Function, fun() -> safe_stop_broker(Broker) end}.

journal_benchmark() ->
    fun(Index) ->
        {ok, Journal} = alang_phase5_journal:new(
            <<"bench-journal-", (integer_to_binary(Index))/binary>>),
        {ok, _Record, _Next} = alang_phase5_journal:append(Journal, observation, 1,
            #{observation_digest => digest(Index)}, 1000 + Index),
        ok
    end.

adapter_benchmark(Base) ->
    Root = filename:join(Base, "workspace"),
    ok = filelib:ensure_dir(filename:join([Root, "bench", ".keep"])),
    Seal = make_ref(),
    {ok, Adapter} = alang_phase4_workspace_adapter:start(self(), adapter_config(Root), Seal),
    ok = await_adapter(Adapter, 100),
    Function = fun(Index) ->
        Segment = <<"item-", (integer_to_binary(Index))/binary, ".md">>,
        Decoded = decoded([<<"bench">>, Segment], <<"x">>,
            <<"adapter-bench-", (integer_to_binary(Index))/binary>>),
        {ok, _Receipt} = alang_phase4_workspace_adapter:dispatch(
            Adapter, Seal, Decoded, erlang:monotonic_time(millisecond) + 2000),
        ok
    end,
    {Function, fun() -> safe_stop_adapter(Adapter, Seal) end}.

typed_control_transition(Index) ->
    Current = #{state => ready, sequence => Index, result => undefined},
    #{state := ready, sequence := Index} = Current,
    Current#{state := completed, result := {ok, Index}}.

typed_effect_validation(Index) ->
    OperationId = <<"typed-baseline-", (integer_to_binary(Index))/binary>>,
    {ok, _Decoded} = alang_phase4_effect_registry:decode_abi(<<"workspace.write">>,
        product({<<"workspace-a">>, <<"notes/baseline.md">>, <<"x">>, OperationId})),
    ok.

await_adapter(_Adapter, 0) -> error(sidecar_not_ready);
await_adapter(Adapter, Attempts) ->
    case maps:get(sidecar_ready, alang_phase4_workspace_adapter:status(Adapter)) of
        true -> ok;
        false -> receive after 5 -> await_adapter(Adapter, Attempts - 1) end
    end.

safe_stop_adapter(Adapter, Seal) ->
    try alang_phase4_workspace_adapter:stop(Adapter, Seal)
    catch
        exit:_Reason -> ok
    end.

safe_stop_broker(Broker) ->
    try gen_server:stop(Broker)
    catch
        exit:_Reason -> ok
    end.

recovery_benchmark() ->
    Session = <<"phase7-recovery-bench">>,
    {ok, Journal0} = alang_phase5_journal:new(Session),
    {_Journal, Records} = lists:foldl(fun(Index, {Journal, Acc}) ->
        {ok, Record, Next} = alang_phase5_journal:append(Journal, observation, 1,
            #{observation_digest => digest({recovery, Index})}, 2000 + Index),
        {Next, Acc ++ [Record]}
    end, {Journal0, []}, lists:seq(1, 40)),
    fun(_Index) -> {ok, _} = alang_phase5_journal:validate(Records, Session), ok end.

verifier_benchmark(Base) ->
    Root = filename:join(Base, "verify"),
    Target = filename:join([Root, "reports", "result.md"]),
    ok = filelib:ensure_dir(Target),
    Content = <<"# Result\n\n## Findings\n\nVerified.\n">>,
    ok = file:write_file(Target, Content),
    ArtifactDigest = digest_binary(Content),
    Spec = #{format => alang_completion_spec_v1, workspace_root => Root,
        relative_path => <<"reports/result.md">>, expected_digest => ArtifactDigest,
        max_bytes => 4096, required_section => <<"Findings">>,
        journal_result => #{format => alang_workspace_result_evidence_v1,
            operation_id => <<"verify-bench">>, operation => <<"workspace.write">>,
            relative_path => <<"reports/result.md">>, artifact_digest => ArtifactDigest,
            result_digest => digest(result), outcome => succeeded}},
    fun(_Index) -> {ok, #{status := complete}} = alang_phase6_verifier:verify(Spec), ok end.

pressure(Fixture, InitialMailbox) -> #{
    concurrent_sessions => [concurrency(Fixture, Count) || Count <- [1, 8, 32]],
    grant_store => [grant_pressure(Count) || Count <- [1, 64, 256]],
    binary_boundaries => [binary_pressure(Bytes) || Bytes <- [64, 4096, 32768, 65536, 65537]],
    vm_snapshot => vm_snapshot(InitialMailbox),
    backpressure_gates => [phase3_gateway_in_flight, phase4_broker_pending,
        phase5_store_mailbox, workspace_port_timeout]
}.

vm_snapshot(InitialMailbox) ->
    FinalMailbox = mailbox_length(),
    #{memory_bytes => maps:from_list(erlang:memory()),
    run_queue => erlang:statistics(run_queue),
    message_queue_before => InitialMailbox, message_queue_after => FinalMailbox,
    message_queue_delta => FinalMailbox - InitialMailbox}.

mailbox_length() -> element(2, process_info(self(), message_queue_len)).

concurrency(#{beam := Beam, task_id := TaskId, inputs := Inputs}, Count) ->
    {ok, Module, _} = alang_phase3_artifact:load(Beam),
    Parent = self(),
    {Micros, _} = timer:tc(fun() ->
        [spawn(fun() -> Parent ! {bench_session, alang_phase3_launcher:run(Module,
            TaskId, Inputs, #{handler => fun(_O, _A) -> {error, <<"unexpected">>} end,
                timeout => 2000, max_in_flight => 1, max_mailbox => 32,
                max_trace_events => 32})} end) || _ <- lists:seq(1, Count)],
        gather_sessions(Count)
    end),
    ok = alang_phase3_artifact:purge(Module),
    #{sessions => Count, elapsed_microseconds => Micros, completed => Count}.

gather_sessions(0) -> ok;
gather_sessions(Count) ->
    receive {bench_session, {ok, _}} -> gather_sessions(Count - 1)
    after 5000 -> error({missing_benchmark_sessions, Count}) end.

grant_pressure(Count) ->
    Now = erlang:monotonic_time(millisecond),
    {Store, _Refs} = lists:foldl(fun(Index, {Current, Refs}) ->
        Spec = (grant_spec(Now, 1))#{session_id :=
            <<"pressure-", (integer_to_binary(Index))/binary>>},
        {ok, Ref, Next} = alang_phase4_grants:issue(Current, Spec, Now),
        {Next, [Ref | Refs]}
    end, {alang_phase4_grants:new_store(1), []}, lists:seq(1, Count)),
    #{grants => Count, encoded_bytes => erlang:external_size(Store)}.

binary_pressure(Bytes) ->
    Content = binary:copy(<<"x">>, Bytes),
    Result = alang_phase4_effect_registry:decode_abi(<<"workspace.write">>,
        product({<<"workspace-a">>, <<"notes/pressure.md">>, Content, <<"pressure">>})),
    #{bytes => Bytes, accepted => element(1, Result) =:= ok}.

temporary_root() -> filename:join(filename:absname("build/phase-07/bench"),
    integer_to_list(erlang:unique_integer([positive, monotonic]))).

grant_spec(Now, Budget) -> #{invocations => [#{operation => <<"workspace.write">>,
    workspace_id => <<"workspace-a">>, path_prefix => [<<"notes">>]}],
    budgets => #{<<"workspace.write">> => Budget}, deadline => Now + 60000,
    owner_pid => self(), session_id => <<"phase7-bench">>,
    artifact_digest => binary:copy(<<"b">>, 64), task_id => <<"task:Phase7.bench/0">>,
    combination => deny}.

broker_options() -> #{limits => #{max_pending => 8, max_pending_per_session => 4,
    max_mailbox => 256, max_audit => 512, authorization_ttl_ms => 2000},
    policy => #{version => <<"phase7-bench-policy">>, workspaces => [<<"workspace-a">>],
        models => [<<"model-a">>]}}.

adapter_config(Root) -> #{workspace_id => <<"workspace-a">>, root => list_to_binary(Root),
    beam_dir => list_to_binary(filename:dirname(code:which(alang_phase4_workspace_sidecar))),
    test_faults => false, limits => #{max_request_bytes => 98304,
        max_response_bytes => 4096, max_content_bytes => 65536,
        max_cache_entries => 128, request_timeout_ms => 1000,
        address_space_bytes => 2147483648, cpu_seconds => 5, open_files => 64,
        file_size_bytes => 67108864, processes => 4096}}.

decoded(Path, Content, OperationId) -> #{format => alang_decoded_effect_v1,
    registry_version => 1, operation => <<"workspace.write">>, operation_tag => workspace_write,
    request_schema => alang_workspace_write_v1, adapter => workspace_adapter,
    trace_name => <<"effect.workspace.write">>, requirement => <<"workspace:write">>,
    resource => #{workspace_id => <<"workspace-a">>, path_segments => Path},
    arguments => #{workspace_id => <<"workspace-a">>, path_segments => Path,
        content => Content, operation_id => OperationId}, operation_id => OperationId}.

manifest(#{tasks := Tasks}) -> #{effects => lists:usort(lists:append(
    [maps:get(effects, Task) || Task <- Tasks])), requirements => lists:usort(lists:append(
    [maps:get(requirements, Task) || Task <- Tasks]))}.
product(Values) -> {alang_data_v1, product, Values}.
digest_binary(Binary) -> hex(crypto:hash(sha256, Binary)).
digest(Term) -> hex(crypto:hash(sha256, term_to_binary(Term, [deterministic]))).
hex(Binary) -> << <<(hex_digit(Nibble))>> || <<Nibble:4>> <= Binary >>.
hex_digit(Nibble) when Nibble < 10 -> $0 + Nibble;
hex_digit(Nibble) -> $a + Nibble - 10.
