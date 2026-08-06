-module(alang_fidelity_score).

-export([
    aggregate/1,
    load_answer_key/2,
    score/3
]).

-spec load_answer_key(file:filename(), map()) -> {ok, map()} | {error, term()}.
load_answer_key(Base, Cell) when is_map(Cell) ->
    try
        Corpus = filename:absname(filename:join(Base, "corpus")),
        Relative = maps:get(answer_path, Cell),
        ensure(is_binary(Relative), invalid_answer_path),
        Path = filename:absname(filename:join(Corpus, binary_to_list(Relative))),
        ensure(lists:prefix(Corpus ++ "/", Path), unsafe_answer_path),
        case file:read_file(Path) of
            {ok, Binary} -> alang_fidelity_contract:decode_answer_key(Binary);
            {error, ReadReason} -> {error, {answer_key_read_failed, ReadReason}}
        end
    catch
        throw:{score_error, ScoreReason} -> {error, ScoreReason};
        error:{badkey, Key} -> {error, {missing_score_field, Key}}
    end;
load_answer_key(_, _) -> {error, invalid_answer_key_input}.

-spec score(map(), map(), map()) -> {ok, map()} | {error, term()}.
score(Cell, AnswerKey, Observation) when is_map(Cell), is_map(AnswerKey), is_map(Observation) ->
    try
        {ok, ValidKey} = checked_answer_key(AnswerKey),
        validate_join(Cell, ValidKey, Observation),
        Expected = alang_fidelity_contract:normalize(maps:get(<<"expected">>, ValidKey)),
        Primary = maps:get(primary, Observation),
        Actual = maps:get(normalized, Primary),
        Exact = Actual =/= none andalso Actual =:= Expected,
        Components = component_results(Expected, Actual),
        {Omissions, Inventions} = difference_counts(Expected, Actual),
        Repair = repair_score(Expected, maps:get(repair, Observation)),
        Accounting = accounting(Primary, maps:get(repair, Observation)),
        Score0 = #{
            format => alang_fidelity_score_v1,
            trial_id => maps:get(trial_id, Cell),
            pair_id => maps:get(pair_id, Cell),
            case_id => maps:get(case_id, Cell),
            task_family => maps:get(task_family, Cell),
            model_family => maps:get(model_family, Cell),
            model_id => maps:get(model_id, Cell),
            condition => maps:get(condition, Cell),
            repetition => maps:get(repetition, Cell),
            primary_classification => maps:get(classification, Primary),
            schema_valid => maps:get(valid, Primary),
            exact_semantic_fidelity => Exact,
            component_exactness => Components,
            component_exact_count => count_true(maps:values(Components)),
            component_count => maps:size(Components),
            omission_count => Omissions,
            invention_count => Inventions,
            authority_widening => authority_widening(Expected, Actual),
            false_completion => false_completion(Expected, Actual),
            repair => Repair,
            accounting => Accounting,
            answer_semantic_digest => maps:get(<<"semantic_digest">>, ValidKey),
            observation_digest => maps:get(observation_digest, Observation)
        },
        {ok, finalize_score(Score0)}
    catch
        throw:{score_error, Reason} -> {error, Reason};
        error:{badkey, Key} -> {error, {missing_score_field, Key}};
        error:{badmatch, {error, Reason}} -> {error, Reason}
    end;
score(_, _, _) -> {error, invalid_score_input}.

-spec aggregate([map()]) -> {ok, map()} | {error, term()}.
aggregate(Scores) when is_list(Scores), Scores =/= [] ->
    try
        validate_scores(Scores),
        Aggregate0 = #{
            format => alang_fidelity_aggregate_v1,
            score_count => length(Scores),
            pooled_descriptive_only => metrics(Scores),
            by_model => grouped(Scores, [model_family]),
            by_condition => grouped(Scores, [condition]),
            by_task_family => grouped(Scores, [task_family]),
            by_case => grouped(Scores, [case_id]),
            by_repetition => grouped(Scores, [repetition]),
            by_model_condition => grouped(Scores, [model_family, condition]),
            by_model_condition_family => grouped(
                Scores, [model_family, condition, task_family]
            ),
            by_model_condition_case => grouped(Scores, [model_family, condition, case_id]),
            by_model_condition_repetition => grouped(
                Scores, [model_family, condition, repetition]
            )
        },
        {ok, Aggregate0#{aggregate_digest => alang_fidelity_json:digest(Aggregate0)}}
    catch
        throw:{score_error, Reason} -> {error, Reason};
        error:{badkey, Key} -> {error, {missing_score_field, Key}}
    end;
aggregate([]) -> {error, empty_score_set};
aggregate(_) -> {error, invalid_score_set}.

checked_answer_key(AnswerKey) ->
    case alang_fidelity_contract:validate_answer_key(AnswerKey) of
        {ok, _} = Ok -> Ok;
        {error, Reason} -> throw({score_error, {invalid_answer_key, Reason}})
    end.

validate_join(Cell, AnswerKey, Observation) ->
    CaseId = maps:get(case_id, Cell),
    ensure(maps:get(<<"case_id">>, AnswerKey) =:= CaseId, answer_key_case_mismatch),
    lists:foreach(fun(Key) ->
        ensure(maps:get(Key, Observation) =:= maps:get(Key, Cell), {observation_join_mismatch, Key})
    end, [trial_id, pair_id, case_id, task_family, model_family, model_id, condition, repetition]),
    ensure(maps:get(format, Observation) =:= alang_fidelity_observation_v1, invalid_observation_format),
    ok.

component_results(_Expected, none) ->
    maps:from_list([{Key, false} || Key <- component_keys()]);
component_results(Expected, Actual) ->
    maps:from_list([{Key, maps:get(Key, Actual) =:= maps:get(Key, Expected)} || Key <- component_keys()]).

component_keys() -> [
    <<"actions">>,
    <<"budgets">>,
    <<"child_attenuation">>,
    <<"clarification_needs">>,
    <<"completion_predicates">>,
    <<"effects">>,
    <<"error_branches">>,
    <<"goal_facts">>,
    <<"inputs">>,
    <<"requirements">>,
    <<"scopes">>,
    <<"terminal_class">>
].

difference_counts(_Expected, none) -> {length(semantic_items(_Expected)), 0};
difference_counts(Expected, Actual) ->
    ExpectedItems = ordsets:from_list(semantic_items(Expected)),
    ActualItems = ordsets:from_list(semantic_items(Actual)),
    {
        length(ordsets:subtract(ExpectedItems, ActualItems)),
        length(ordsets:subtract(ActualItems, ExpectedItems))
    }.

semantic_items(Value) ->
    lists:append([component_items([Key], maps:get(Key, Value)) || Key <- component_keys()]).

component_items(Path, Value) when is_map(Value) ->
    lists:append([
        component_items(Path ++ [Key], Item)
        || {Key, Item} <- lists:sort(maps:to_list(Value))
    ]);
component_items(Path, Value) when is_list(Value) ->
    [{Path, alang_fidelity_json:digest(Item)} || Item <- Value];
component_items(Path, Value) -> [{Path, Value}].

authority_widening(_Expected, none) -> false;
authority_widening(Expected, Actual) ->
    extra_list(maps:get(<<"effects">>, Expected), maps:get(<<"effects">>, Actual))
        orelse extra_list(maps:get(<<"requirements">>, Expected), maps:get(<<"requirements">>, Actual))
        orelse scope_widening(maps:get(<<"scopes">>, Expected), maps:get(<<"scopes">>, Actual))
        orelse budget_widening(maps:get(<<"budgets">>, Expected), maps:get(<<"budgets">>, Actual))
        orelse child_widening(
            maps:get(<<"child_attenuation">>, Expected),
            maps:get(<<"child_attenuation">>, Actual)
        ).

scope_widening(Expected, Actual) ->
    lists:any(fun(Key) -> extra_list(maps:get(Key, Expected), maps:get(Key, Actual)) end,
        [<<"models">>, <<"workspaces">>, <<"paths">>]).

budget_widening(Expected, Actual) ->
    lists:any(fun(Key) -> maps:get(Key, Actual) > maps:get(Key, Expected) end, maps:keys(Expected)).

child_widening(null, null) -> false;
child_widening(null, _Actual) -> true;
child_widening(_Expected, null) -> false;
child_widening(Expected, Actual) ->
    extra_list(maps:get(<<"effects">>, Expected), maps:get(<<"effects">>, Actual))
        orelse extra_list(maps:get(<<"requirements">>, Expected), maps:get(<<"requirements">>, Actual))
        orelse scope_widening(maps:get(<<"scopes">>, Expected), maps:get(<<"scopes">>, Actual))
        orelse budget_widening(maps:get(<<"budgets">>, Expected), maps:get(<<"budgets">>, Actual)).

extra_list(Expected, Actual) -> ordsets:subtract(ordsets:from_list(Actual), ordsets:from_list(Expected)) =/= [].

false_completion(_Expected, none) -> false;
false_completion(Expected, Actual) ->
    maps:get(<<"terminal_class">>, Actual) =:= <<"complete">>
        andalso maps:get(<<"terminal_class">>, Expected) =/= <<"complete">>.

repair_score(_Expected, none) -> #{attempted => false, valid => false, exact => false};
repair_score(Expected, Repair) ->
    Normalized = maps:get(normalized, Repair),
    #{
        attempted => true,
        valid => maps:get(valid, Repair),
        exact => Normalized =/= none andalso Normalized =:= Expected,
        classification => maps:get(classification, Repair)
    }.

accounting(Primary, Repair) ->
    Attempts = case Repair of none -> [Primary]; _ -> [Primary, Repair] end,
    #{
        attempt_count => length(Attempts),
        input_tokens => lists:sum([maps:get(input_tokens, maps:get(usage, Attempt)) || Attempt <- Attempts]),
        output_tokens => lists:sum([maps:get(output_tokens, maps:get(usage, Attempt)) || Attempt <- Attempts]),
        latency_ms => lists:sum([maps:get(latency_ms, Attempt) || Attempt <- Attempts]),
        cost_microusd => lists:sum([maps:get(cost_microusd, Attempt) || Attempt <- Attempts])
    }.

validate_scores(Scores) ->
    TrialIds = [maps:get(trial_id, Score) || Score <- Scores],
    ensure(length(TrialIds) =:= length(lists:usort(TrialIds)), duplicate_score_trial),
    lists:foreach(fun(Score) ->
        ensure(maps:get(format, Score) =:= alang_fidelity_score_v1, invalid_score_format),
        ensure(maps:get(score_digest, Score) =:= alang_fidelity_json:digest(maps:remove(score_digest, Score)), invalid_score_digest)
    end, Scores).

grouped(Scores, Keys) ->
    Groups = lists:foldl(fun(Score, Acc) ->
        GroupKey = [{Key, maps:get(Key, Score)} || Key <- Keys],
        Acc#{GroupKey => [Score | maps:get(GroupKey, Acc, [])]}
    end, #{}, Scores),
    [maps:merge(maps:from_list(GroupKey), #{metrics => metrics(GroupScores)})
        || {GroupKey, GroupScores} <- lists:sort(maps:to_list(Groups))].

metrics(Scores) ->
    Count = length(Scores),
    Exact = count_true([maps:get(exact_semantic_fidelity, Score) || Score <- Scores]),
    Valid = count_true([maps:get(schema_valid, Score) || Score <- Scores]),
    Repairs = [maps:get(repair, Score) || Score <- Scores],
    Attempted = count_true([maps:get(attempted, Repair) || Repair <- Repairs]),
    RepairedExact = count_true([maps:get(exact, Repair) || Repair <- Repairs]),
    Accountings = [maps:get(accounting, Score) || Score <- Scores],
    #{
        cells => Count,
        exact_semantic_fidelity => rate(Exact, Count),
        schema_validity => rate(Valid, Count),
        component_exact_counts => component_totals(Scores),
        omission_count => lists:sum([maps:get(omission_count, Score) || Score <- Scores]),
        invention_count => lists:sum([maps:get(invention_count, Score) || Score <- Scores]),
        authority_widening_count => count_true([maps:get(authority_widening, Score) || Score <- Scores]),
        false_completion_count => count_true([maps:get(false_completion, Score) || Score <- Scores]),
        repair_yield => rate(RepairedExact, Attempted),
        repairs_attempted => Attempted,
        input_tokens => lists:sum([maps:get(input_tokens, Item) || Item <- Accountings]),
        output_tokens => lists:sum([maps:get(output_tokens, Item) || Item <- Accountings]),
        latency_ms => lists:sum([maps:get(latency_ms, Item) || Item <- Accountings]),
        cost_microusd => lists:sum([maps:get(cost_microusd, Item) || Item <- Accountings])
    }.

component_totals(Scores) ->
    maps:from_list([{Key, count_true([
        maps:get(Key, maps:get(component_exactness, Score)) || Score <- Scores
    ])} || Key <- component_keys()]).

rate(Numerator, 0) -> #{numerator => Numerator, denominator => 0, basis_points => 0};
rate(Numerator, Denominator) -> #{
    numerator => Numerator,
    denominator => Denominator,
    basis_points => (Numerator * 10000) div Denominator
}.

count_true(Values) -> length([true || true <- Values]).

finalize_score(Score) -> Score#{score_digest => alang_fidelity_json:digest(Score)}.

ensure(true, _Reason) -> ok;
ensure(false, Reason) -> throw({score_error, Reason}).
