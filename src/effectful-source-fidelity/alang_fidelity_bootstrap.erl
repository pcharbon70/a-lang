-module(alang_fidelity_bootstrap).

-export([compute/1]).

-define(SEED, 20260805).
-define(RESAMPLES, 10000).
-define(PP_MICROS, 1000000).

-spec compute([map()]) -> {ok, map()} | {error, term()}.
compute(Scores) when is_list(Scores) ->
    try
        {Index, FamilyCases} = validate_and_index(Scores),
        State0 = rand:seed_s(exsss, {?SEED, ?SEED + 1, ?SEED + 2}),
        {Samples, _State} = resamples(?RESAMPLES, State0, Index, FamilyCases, #{
            anthropic => [], openai => []
        }),
        Models = maps:from_list([{Model, interval(Model, Index, FamilyCases, maps:get(Model, Samples))}
            || Model <- [anthropic, openai]]),
        Result0 = #{
            format => alang_fidelity_paired_bootstrap_v1,
            seed => ?SEED,
            seed_tuple => [?SEED, ?SEED + 1, ?SEED + 2],
            resamples => ?RESAMPLES,
            sampling_unit => semantic_case,
            strata => task_family,
            cases_per_stratum => 8,
            repetitions_retained => 3,
            interval => nearest_rank_percentile_95,
            unit => percentage_point_micros,
            models => Models,
            resample_digest => alang_fidelity_json:digest(Samples)
        },
        {ok, Result0#{bootstrap_digest => alang_fidelity_json:digest(Result0)}}
    catch
        throw:{bootstrap_error, Reason} -> {error, Reason};
        error:{badkey, Key} -> {error, {missing_bootstrap_field, Key}}
    end;
compute(_) -> {error, invalid_score_set}.

validate_and_index(Scores) ->
    ensure(length(Scores) =:= 288, {expected_score_count, 288, length(Scores)}),
    Families = [
        <<"attenuated-delegation">>,
        <<"repair-and-publish">>,
        <<"single-model-artifact">>
    ],
    FamilyCases = maps:from_list([{Family, family_cases(Family, Scores)} || Family <- Families]),
    ensure(lists:all(fun(Cases) -> length(Cases) =:= 8 end, maps:values(FamilyCases)), invalid_family_case_count),
    KeysAndValues = [
        begin
            ensure(lists:member(maps:get(model_family, Score), [anthropic, openai]), invalid_model_family),
            ensure(lists:member(maps:get(condition, Score), [alang, json]), invalid_condition),
            Repetition = maps:get(repetition, Score),
            ensure(is_integer(Repetition) andalso Repetition >= 1 andalso Repetition =< 3, invalid_repetition),
            Exact = maps:get(exact_semantic_fidelity, Score),
            ensure(is_boolean(Exact), invalid_exact_score),
            {
                {
                    maps:get(model_family, Score),
                    maps:get(condition, Score),
                    maps:get(case_id, Score),
                    Repetition
                },
                bool_integer(Exact)
            }
        end
        || Score <- Scores
    ],
    Index = maps:from_list(KeysAndValues),
    ensure(maps:size(Index) =:= 288, duplicate_bootstrap_cell),
    ExpectedKeys = [
        {Model, Condition, CaseId, Repetition}
        || Model <- [anthropic, openai],
           Condition <- [alang, json],
           Family <- Families,
           CaseId <- maps:get(Family, FamilyCases),
           Repetition <- lists:seq(1, 3)
    ],
    ensure(lists:sort(maps:keys(Index)) =:= lists:sort(ExpectedKeys), incomplete_bootstrap_grid),
    {Index, FamilyCases}.

family_cases(Family, Scores) ->
    Cases = lists:usort([
        maps:get(case_id, Score)
        || Score <- Scores, maps:get(task_family, Score) =:= Family
    ]),
    lists:foreach(fun(CaseId) ->
        CaseFamilies = lists:usort([
            maps:get(task_family, Score)
            || Score <- Scores, maps:get(case_id, Score) =:= CaseId
        ]),
        ensure(CaseFamilies =:= [Family], {case_in_multiple_families, CaseId})
    end, Cases),
    Cases.

resamples(0, State, _Index, _FamilyCases, Samples) ->
    {maps:map(fun(_Model, Values) -> lists:reverse(Values) end, Samples), State};
resamples(Remaining, State0, Index, FamilyCases, Samples0) ->
    {SelectedCases, State1} = select_cases(FamilyCases, State0),
    Samples = maps:map(fun(Model, Values) ->
        [difference_pp_micros(Index, Model, SelectedCases) | Values]
    end, Samples0),
    resamples(Remaining - 1, State1, Index, FamilyCases, Samples).

select_cases(FamilyCases, State0) ->
    {SelectedByFamily, State1} = lists:mapfoldl(fun(Family, State) ->
        Cases = maps:get(Family, FamilyCases),
        sample_eight(Cases, 8, State, [])
    end, State0, lists:sort(maps:keys(FamilyCases))),
    {lists:append(SelectedByFamily), State1}.

sample_eight(_Cases, 0, State, Acc) -> {lists:reverse(Acc), State};
sample_eight(Cases, Remaining, State0, Acc) ->
    {Position, State1} = rand:uniform_s(8, State0),
    sample_eight(Cases, Remaining - 1, State1, [lists:nth(Position, Cases) | Acc]).

difference_pp_micros(Index, Model, Cases) ->
    Alang = condition_total(Index, Model, alang, Cases),
    Json = condition_total(Index, Model, json, Cases),
    scale_difference(Alang - Json, length(Cases) * 3).

condition_total(Index, Model, Condition, Cases) ->
    lists:sum([
        maps:get({Model, Condition, CaseId, Repetition}, Index)
        || CaseId <- Cases, Repetition <- lists:seq(1, 3)
    ]).

scale_difference(Difference, Denominator) ->
    (Difference * 100 * ?PP_MICROS) div Denominator.

interval(Model, Index, FamilyCases, Values) ->
    Sorted = lists:sort(Values),
    AllCases = lists:append([maps:get(Family, FamilyCases) || Family <- lists:sort(maps:keys(FamilyCases))]),
    #{
        observed_difference_pp_micros => difference_pp_micros(Index, Model, AllCases),
        lower_pp_micros => lists:nth(250, Sorted),
        median_pp_micros => lists:nth(5000, Sorted),
        upper_pp_micros => lists:nth(9750, Sorted)
    }.

bool_integer(true) -> 1;
bool_integer(false) -> 0.

ensure(true, _Reason) -> ok;
ensure(false, Reason) -> throw({bootstrap_error, Reason}).
