-module(alang_phase7_campaign).

-export([commands/0, run/0]).

-spec commands() -> [binary()].
commands() -> [
    <<"make test-section-7-1">>,
    <<"make test-section-7-2">>,
    <<"make test-section-7-3">>,
    <<"make test-section-7-4">>,
    <<"make test-section-7-5">>,
    <<"make test">>
].

-spec run() -> map().
run() ->
    Law = alang_phase7_law_tests:run(),
    State = alang_phase7_state_property_tests:run(),
    Adversarial = alang_phase7_adversarial_tests:run(),
    FaultPerformance = alang_phase7_fault_performance_tests:run(),
    Mutation = alang_phase7_mutation:run(),
    Sections = [Law, State, Adversarial, FaultPerformance, Mutation],
    #{format => alang_phase7_campaign_v1,
        commands => commands(),
        tools => tool_versions(),
        counts => #{generated_cases => 1468, fixed_attacks => 30,
            fault_cases => maps:get(fault_cases, FaultPerformance),
            seeded_defects => maps:get(defects, Mutation),
            performance_metrics => maps:get(metrics, FaultPerformance),
            comparison_baselines => maps:get(baselines, FaultPerformance),
            total_validation_cases => 1578},
        replay => #{case_seed_field => present,
            proper_engine_seed => not_persisted_when_campaign_passes,
            failing_counterexamples => proper_shrunk_value},
        limits => #{proper_max_size => 32, source_bytes => 1048576,
            model_context_candidates => 128, workspace_content_bytes => 65536,
            benchmark_sessions => 32, benchmark_grants => 256,
            test_timeouts_milliseconds => #{runtime => 2000, adapter => 1000}},
        sections => Sections,
        environment => maps:get(environment,
            maps:get(performance, FaultPerformance)),
        caveats => [generated_testing_is_not_proof,
            local_mutants_do_not_estimate_global_mutation_score,
            performance_is_single_host_characterization,
            passing_proper_engine_seed_is_not_persisted],
        passed => lists:all(fun section_passed/1, Sections) andalso
            alang_phase7_adversarial:surface_clean(Sections, [])}.

section_passed(#{passed := true}) -> true;
section_passed(_) -> false.

tool_versions() ->
    _ = application:load(proper),
    Proper = case application:get_key(proper, vsn) of
        {ok, Version} -> iolist_to_binary(Version);
        undefined -> unknown
    end,
    maps:merge(read_tool_versions(), #{proper => Proper,
        architecture => list_to_binary(erlang:system_info(system_architecture))}).

read_tool_versions() ->
    case file:read_file(".tool-versions") of
        {ok, Binary} -> maps:from_list([tool_version(Line) || Line <-
            binary:split(Binary, <<"\n">>, [global]), Line =/= <<>>]);
        {error, _Reason} -> #{}
    end.

tool_version(Line) ->
    [Name, Version] = binary:split(Line, <<" ">>, [global, trim_all]),
    {tool_name(Name), Version}.

tool_name(<<"erlang">>) -> erlang;
tool_name(<<"rebar">>) -> rebar.
