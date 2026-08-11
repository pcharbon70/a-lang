-module(alang_compact_power).

-export([audit/1, load/1]).

-define(Z_ONE_SIDED_95, 1.6448536269514722).

-spec load(file:filename()) -> {ok, map()} | {error, term()}.
load(Path) ->
    case alang_fidelity_json:decode_file(Path) of
        {ok, Design} ->
            case validate(Design) of
                ok -> {ok, Design};
                {error, _} = Error -> Error
            end;
        {error, _} = Error -> Error
    end.

-spec audit(map()) -> {ok, map()} | {error, term()}.
audit(Design) ->
    try
        ok = checked(validate(Design)),
        Counts = maps:get(<<"candidate_case_counts">>, Design),
        Scenarios = maps:get(<<"scenarios">>, Design),
        Seed = maps:get(<<"seed">>, Design),
        Results = [scenario_results(Scenario, Counts, Design, Seed + Index * 100000)
            || {Scenario, Index} <- indexed(Scenarios)],
        SelectionId = maps:get(<<"selection_scenario">>, Design),
        Selection = hd([R || R <- Results, maps:get(<<"id">>, R) =:= SelectionId]),
        MinimumPower = maps:get(<<"minimum_central_power">>, Design),
        Selected = select_count(maps:get(<<"case_counts">>, Selection), MinimumPower),
        {ok, #{
            <<"format">> => <<"alang-compact-power-audit-v1">>,
            <<"method">> => maps:get(<<"method">>, Design),
            <<"simulations">> => maps:get(<<"simulations">>, Design),
            <<"noninferiority_margin">> => maps:get(<<"noninferiority_margin">>, Design),
            <<"minimum_central_power">> => MinimumPower,
            <<"selected_cases">> => Selected,
            <<"case_block_size">> => maps:get(<<"case_block_size">>, Design),
            <<"scenario_results">> => Results
        }}
    catch
        throw:{power_error, Reason} -> {error, Reason};
        error:{badmatch, Reason} -> {error, {power_audit_failed, Reason}}
    end.

validate(Design) ->
    try
        Keys = [
            <<"format">>, <<"seed">>, <<"simulations">>, <<"confidence_percent">>,
            <<"noninferiority_margin">>, <<"minimum_central_power">>,
            <<"case_block_size">>, <<"candidate_case_counts">>,
            <<"protocols_per_case">>, <<"repetitions_per_case">>,
            <<"selection_scenario">>, <<"method">>, <<"scenarios">>
        ],
        closed(Design, Keys, []),
        exact(maps:get(<<"format">>, Design), <<"alang-compact-power-design-v1">>, [<<"format">>]),
        positive_integer(maps:get(<<"seed">>, Design), [<<"seed">>]),
        positive_integer(maps:get(<<"simulations">>, Design), [<<"simulations">>]),
        exact(maps:get(<<"confidence_percent">>, Design), 95, [<<"confidence_percent">>]),
        exact(maps:get(<<"noninferiority_margin">>, Design), -0.05, [<<"noninferiority_margin">>]),
        exact(maps:get(<<"minimum_central_power">>, Design), 0.80, [<<"minimum_central_power">>]),
        exact(maps:get(<<"case_block_size">>, Design), 24, [<<"case_block_size">>]),
        exact(maps:get(<<"candidate_case_counts">>, Design), [24, 48, 72], [<<"candidate_case_counts">>]),
        exact(maps:get(<<"protocols_per_case">>, Design), 4, [<<"protocols_per_case">>]),
        exact(maps:get(<<"repetitions_per_case">>, Design), 2, [<<"repetitions_per_case">>]),
        exact(maps:get(<<"selection_scenario">>, Design), <<"central">>, [<<"selection_scenario">>]),
        exact(maps:get(<<"method">>, Design), <<"paired-case-cluster-normal-simulation">>, [<<"method">>]),
        validate_scenarios(maps:get(<<"scenarios">>, Design)),
        ok
    catch throw:{power_contract_error, Path, Reason} ->
        {error, {power_contract_error, Path, Reason}}
    end.

validate_scenarios(Scenarios) ->
    ensure(is_list(Scenarios) andalso length(Scenarios) =:= 3, [<<"scenarios">>], expected_three_scenarios),
    exact([maps:get(<<"id">>, S) || S <- Scenarios], [<<"optimistic">>, <<"central">>, <<"adverse">>], [<<"scenarios">>]),
    lists:foreach(fun({Scenario, Index}) ->
        Path = [<<"scenarios">>, Index],
        Keys = [<<"id">>, <<"both_correct">>, <<"readable_only_correct">>, <<"compact_only_correct">>, <<"both_incorrect">>],
        closed(Scenario, Keys, Path),
        Probabilities = [maps:get(Key, Scenario) || Key <- tl(Keys)],
        lists:foreach(fun(Value) -> ensure(is_number(Value) andalso Value >= 0 andalso Value =< 1, Path, invalid_probability) end, Probabilities),
        ensure(abs(lists:sum(Probabilities) - 1.0) < 1.0e-9, Path, probabilities_do_not_sum_to_one),
        ensure(maps:get(<<"readable_only_correct">>, Scenario) =:= maps:get(<<"compact_only_correct">>, Scenario), Path, central_effect_not_zero)
    end, indexed(Scenarios)).

scenario_results(Scenario, Counts, Design, Seed) ->
    {CountResults, _State} = lists:mapfoldl(fun(Count, State0) ->
        {Power, State1} = estimate_power(Scenario, Count, Design, State0),
        {#{<<"cases">> => Count, <<"estimated_power">> => Power}, State1}
    end, rand:seed_s(exsplus, seed_tuple(Seed)), Counts),
    #{<<"id">> => maps:get(<<"id">>, Scenario), <<"case_counts">> => CountResults}.

estimate_power(Scenario, Cases, Design, State0) ->
    Simulations = maps:get(<<"simulations">>, Design),
    Observations = maps:get(<<"protocols_per_case">>, Design) * maps:get(<<"repetitions_per_case">>, Design),
    Margin = maps:get(<<"noninferiority_margin">>, Design),
    {Passes, State} = simulate(Simulations, Cases, Observations, Scenario, Margin, 0, State0),
    {Passes / Simulations, State}.

simulate(0, _Cases, _Observations, _Scenario, _Margin, Passes, State) -> {Passes, State};
simulate(Remaining, Cases, Observations, Scenario, Margin, Passes, State0) ->
    {Means, State1} = case_means(Cases, Observations, Scenario, [], State0),
    Lower = lower_bound(Means),
    NewPasses = case Lower > Margin of true -> Passes + 1; false -> Passes end,
    simulate(Remaining - 1, Cases, Observations, Scenario, Margin, NewPasses, State1).

case_means(0, _Observations, _Scenario, Acc, State) -> {Acc, State};
case_means(Remaining, Observations, Scenario, Acc, State0) ->
    {Sum, State1} = observations(Observations, Scenario, 0, State0),
    case_means(Remaining - 1, Observations, Scenario, [Sum / Observations | Acc], State1).

observations(0, _Scenario, Sum, State) -> {Sum, State};
observations(Remaining, Scenario, Sum, State0) ->
    {Uniform, State1} = rand:uniform_s(State0),
    ReadableOnly = maps:get(<<"readable_only_correct">>, Scenario),
    CompactOnly = maps:get(<<"compact_only_correct">>, Scenario),
    Difference = case Uniform of
        U when U =< ReadableOnly -> -1;
        U when U =< ReadableOnly + CompactOnly -> 1;
        _ -> 0
    end,
    observations(Remaining - 1, Scenario, Sum + Difference, State1).

lower_bound(Values) ->
    N = length(Values),
    Mean = lists:sum(Values) / N,
    Variance = lists:sum([math:pow(Value - Mean, 2) || Value <- Values]) / (N - 1),
    Mean - ?Z_ONE_SIDED_95 * math:sqrt(Variance / N).

select_count([], _Minimum) -> throw({power_error, no_candidate_meets_central_power});
select_count([#{<<"cases">> := Cases, <<"estimated_power">> := Power} | _], Minimum) when Power >= Minimum -> Cases;
select_count([_ | Rest], Minimum) -> select_count(Rest, Minimum).

seed_tuple(Seed) -> {Seed band 16#3fffffff, (Seed * 17 + 11) band 16#3fffffff, (Seed * 31 + 7) band 16#3fffffff}.
indexed(List) -> lists:zip(List, lists:seq(0, length(List) - 1)).
checked(ok) -> ok;
checked({error, Reason}) -> throw({power_error, Reason}).
closed(Value, Keys, Path) ->
    ensure(is_map(Value), Path, expected_object),
    Actual = maps:keys(Value),
    ensure(Actual -- Keys =:= [], Path, {unknown_fields, lists:sort(Actual -- Keys)}),
    ensure(Keys -- Actual =:= [], Path, {missing_fields, lists:sort(Keys -- Actual)}).
exact(Value, Expected, Path) -> ensure(Value =:= Expected, Path, {expected_frozen_value, Expected, Value}).
positive_integer(Value, Path) -> ensure(is_integer(Value) andalso Value > 0, Path, expected_positive_integer).
ensure(true, _Path, _Reason) -> ok;
ensure(false, Path, Reason) -> throw({power_contract_error, Path, Reason}).
