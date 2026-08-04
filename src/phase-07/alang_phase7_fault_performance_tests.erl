-module(alang_phase7_fault_performance_tests).

-include_lib("eunit/include/eunit.hrl").

-export([run/0]).

complete_fault_matrix_test() ->
    Evidence = alang_phase7_fault_campaign:run(),
    ?assertEqual(63, maps:get(cases, Evidence)),
    ?assertEqual(true, maps:get(passed, Evidence)),
    ?assertEqual(ok, alang_phase7_fault_campaign:verify(
        alang_phase7_fault_campaign:matrix())).

performance_tails_and_pressure_test_() ->
    {timeout, 60, fun() ->
        Evidence = alang_phase7_bench:suite(),
        Metrics = maps:get(metrics, Evidence),
        Baselines = maps:get(baselines, Evidence),
        ?assertEqual(10, length(Metrics)),
        ?assertEqual(2, length(Baselines)),
        ?assert(lists:all(fun valid_metric/1, Metrics)),
        ?assert(lists:all(fun valid_metric/1, Baselines)),
        ?assertEqual(<<"workspace-adapter">>, maps:get(shared_external_adapter,
            maps:get(comparison, Evidence))),
        Pressure = maps:get(pressure, Evidence),
        ?assertEqual([1, 8, 32], [maps:get(sessions, Item) || Item <-
            maps:get(concurrent_sessions, Pressure)]),
        ?assertEqual([1, 64, 256], [maps:get(grants, Item) || Item <-
            maps:get(grant_store, Pressure)]),
        BinaryResults = maps:get(binary_boundaries, Pressure),
        ?assertEqual([true, true, true, true, false],
            [maps:get(accepted, Item) || Item <- BinaryResults]),
        Vm = maps:get(vm_snapshot, Pressure),
        ?assert(maps:get(total, maps:get(memory_bytes, Vm)) > 0),
        ?assert(maps:get(run_queue, Vm) >= 0),
        ?assertEqual(0, maps:get(message_queue_delta, Vm))
    end}.

percentile_definition_test() ->
    Samples = lists:seq(1, 100),
    ?assertEqual(50, alang_phase7_bench:percentile(Samples, 50)),
    ?assertEqual(95, alang_phase7_bench:percentile(Samples, 95)),
    ?assertEqual(99, alang_phase7_bench:percentile(Samples, 99)).

-spec run() -> map().
run() ->
    Faults = alang_phase7_fault_campaign:run(),
    Performance = alang_phase7_bench:suite(),
    #{format => alang_phase7_section_result_v1, section => <<"7.4">>,
        fault_cases => maps:get(cases, Faults), metrics => length(maps:get(metrics, Performance)),
        baselines => length(maps:get(baselines, Performance)),
        faults => Faults, performance => Performance,
        passed => maps:get(passed, Faults) andalso
            lists:all(fun valid_metric/1, maps:get(metrics, Performance)) andalso
            lists:all(fun valid_metric/1, maps:get(baselines, Performance))}.

valid_metric(Metric) ->
    Required = [name, unit, samples, p50, p95, p99, minimum, maximum, mean,
        total, throughput_per_second],
    lists:sort(maps:keys(Metric)) =:= lists:sort(Required) andalso
        maps:get(unit, Metric) =:= microsecond andalso maps:get(samples, Metric) > 0 andalso
        maps:get(minimum, Metric) =< maps:get(p50, Metric) andalso
        maps:get(p50, Metric) =< maps:get(p95, Metric) andalso
        maps:get(p95, Metric) =< maps:get(p99, Metric) andalso
        maps:get(p99, Metric) =< maps:get(maximum, Metric) andalso
        valid_throughput(maps:get(throughput_per_second, Metric)).

valid_throughput(unbounded_at_timer_resolution) -> true;
valid_throughput(Value) -> is_integer(Value) andalso Value > 0.
