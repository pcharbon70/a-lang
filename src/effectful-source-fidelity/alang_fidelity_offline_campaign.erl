-module(alang_fidelity_offline_campaign).

-export([run/1, validate/2]).

-define(PRICE_TABLE, #{
    anthropic => #{input_microusd_per_million => 1000000,
        output_microusd_per_million => 2000000},
    openai => #{input_microusd_per_million => 1000000,
        output_microusd_per_million => 2000000}
}).

-spec run(file:filename()) -> {ok, map()} | {error, term()}.
run(Base) ->
    try
        {ok, Schedule} = checked_schedule(Base),
        {ok, Runner0} = alang_fidelity_campaign_runner:new(Schedule),
        {ok, Journal0} = alang_fidelity_campaign_journal:new(maps:get(schedule_digest, Schedule)),
        {ok, _Start, Journal1} = append(Journal0, campaign_started, #{
            primary_cells => 288,
            schedule_digest => maps:get(schedule_digest, Schedule)
        }),
        {ok, Runner, Journal2, Observations0} = execute_cells(
            Base, Runner0, Journal1, []
        ),
        Observations = lists:reverse(Observations0),
        Scores = score_all(Base, maps:get(cells, Schedule), Observations),
        {ok, Aggregate} = alang_fidelity_score:aggregate(Scores),
        {ok, Bootstrap} = alang_fidelity_bootstrap:compute(Scores),
        RunnerSummary = runner_summary(Runner),
        Accounting = accounting(RunnerSummary, Journal2),
        AnalysisDigest = alang_fidelity_json:digest(#{
            schedule_digest => maps:get(schedule_digest, Schedule),
            observations => Observations,
            scores => Scores,
            aggregate => Aggregate,
            bootstrap => Bootstrap,
            accounting => Accounting
        }),
        {ok, _Close, Journal} = append(Journal2, campaign_closed, #{
            call_count => maps:get(calls, RunnerSummary),
            cost_microusd => maps:get(cost_microusd, RunnerSummary),
            evidence_digest => AnalysisDigest,
            valid => true
        }),
        Validity = validity(Schedule, Observations, Scores, RunnerSummary, Journal),
        Result0 = #{
            format => alang_fidelity_offline_campaign_v1,
            schedule => Schedule,
            observations => Observations,
            scores => Scores,
            aggregate => Aggregate,
            bootstrap => Bootstrap,
            accounting => Accounting#{journal_records => length(maps:get(records, Journal))},
            validity => Validity,
            journal => Journal,
            runner_summary => RunnerSummary,
            analysis_digest => AnalysisDigest
        },
        Result = finalize(Result0),
        {ok, _} = validate_result(Base, Result),
        {ok, Result}
    catch
        throw:{offline_campaign_error, Reason} -> {error, Reason};
        error:{badkey, Key} -> {error, {missing_offline_campaign_field, Key}};
        error:{badmatch, {error, MatchReason}} -> {error, MatchReason}
    end.

-spec validate(file:filename(), map()) -> {ok, map()} | {error, term()}.
validate(Base, Result) when is_map(Result) ->
    try validate_result(Base, Result) of
        {ok, _} = Ok -> Ok
    catch
        throw:{offline_campaign_error, Reason} -> {error, Reason};
        error:{badkey, Key} -> {error, {missing_offline_campaign_field, Key}};
        error:{badmatch, {error, MatchReason}} -> {error, MatchReason}
    end;
validate(_, _) -> {error, invalid_offline_campaign}.

checked_schedule(Base) ->
    case alang_fidelity_campaign:materialize(Base) of
        {ok, _} = Ok -> Ok;
        {error, Reason} -> throw({offline_campaign_error, {schedule_failed, Reason}})
    end.

execute_cells(Base, Runner, Journal, Observations) ->
    case alang_fidelity_campaign_runner:next(Runner) of
        {done, FinalRunner} -> {ok, FinalRunner, Journal, Observations};
        {ok, Cell} ->
            Scenario = scenario(maps:get(index, Cell)),
            {ok, UpdatedRunner, UpdatedJournal, Observation} = execute_cell(
                Base, Cell, Scenario, Runner, Journal
            ),
            execute_cells(Base, UpdatedRunner, UpdatedJournal, [Observation | Observations]);
        {error, Reason} -> {error, Reason}
    end.

execute_cell(Base, Cell, exact, Runner0, Journal0) ->
    {Intent, Request, Runner1, Journal1} = begin_attempt(Cell, primary, Runner0, Journal0),
    Result = exact_result(Base, Cell, Request),
    {ok, Observation} = alang_fidelity_observation:normalize(Cell, Result),
    {Runner, Journal} = finish_attempt(
        Runner1, Journal1, Result, primary_classification(Observation)
    ),
    ensure(maps:get(operation_id, Intent) =:= maps:get(operation_id, Result), intent_result_mismatch),
    {ok, Runner, Journal, Observation};
execute_cell(Base, Cell, semantic_miss, Runner0, Journal0) ->
    {_Intent, Request, Runner1, Journal1} = begin_attempt(Cell, primary, Runner0, Journal0),
    Result = semantic_miss_result(Base, Cell, Request),
    {ok, Observation} = alang_fidelity_observation:normalize(Cell, Result),
    {Runner, Journal} = finish_attempt(
        Runner1, Journal1, Result, primary_classification(Observation)
    ),
    {ok, Runner, Journal, Observation};
execute_cell(Base, Cell, malformed_repair, Runner0, Journal0) ->
    {_Intent, PrimaryRequest, Runner1, Journal1} = begin_attempt(
        Cell, primary, Runner0, Journal0
    ),
    PrimaryResult = success(PrimaryRequest, <<"not-json">>, maps:get(index, Cell)),
    {ok, PrimaryObservation} = alang_fidelity_observation:normalize(Cell, PrimaryResult),
    {Runner2, Journal2} = finish_attempt(
        Runner1, Journal1, PrimaryResult, primary_classification(PrimaryObservation)
    ),
    {RepairIntent, _Ignored, Runner3, Journal3} = begin_attempt(
        Cell, repair, Runner2, Journal2
    ),
    {ok, RepairRequest} = alang_fidelity_observation:repair_request(
        PrimaryRequest, PrimaryObservation, maps:get(operation_id, RepairIntent)
    ),
    RepairResult = exact_result(Base, Cell, RepairRequest),
    {ok, Observation} = alang_fidelity_observation:attach_repair(
        PrimaryObservation, RepairResult
    ),
    {Runner, Journal} = finish_attempt(
        Runner3, Journal3, RepairResult,
        maps:get(classification, maps:get(repair, Observation))
    ),
    {ok, Runner, Journal, Observation};
execute_cell(_Base, Cell, schema_repair_failure, Runner0, Journal0) ->
    {_Intent, PrimaryRequest, Runner1, Journal1} = begin_attempt(
        Cell, primary, Runner0, Journal0
    ),
    PrimaryResult = success(PrimaryRequest, <<"{}">>, maps:get(index, Cell)),
    {ok, PrimaryObservation} = alang_fidelity_observation:normalize(Cell, PrimaryResult),
    {Runner2, Journal2} = finish_attempt(
        Runner1, Journal1, PrimaryResult, primary_classification(PrimaryObservation)
    ),
    {RepairIntent, _Ignored, Runner3, Journal3} = begin_attempt(
        Cell, repair, Runner2, Journal2
    ),
    {ok, RepairRequest} = alang_fidelity_observation:repair_request(
        PrimaryRequest, PrimaryObservation, maps:get(operation_id, RepairIntent)
    ),
    RepairResult = success(RepairRequest, <<"still-not-json">>, maps:get(index, Cell)),
    {ok, Observation} = alang_fidelity_observation:attach_repair(
        PrimaryObservation, RepairResult
    ),
    {Runner, Journal} = finish_attempt(Runner3, Journal3, RepairResult, repair_failure),
    {ok, Runner, Journal, Observation};
execute_cell(_Base, Cell, refusal, Runner0, Journal0) ->
    definitive_failure(Cell, definitive_refusal, Runner0, Journal0);
execute_cell(_Base, Cell, truncated, Runner0, Journal0) ->
    definitive_failure(Cell, truncated, Runner0, Journal0);
execute_cell(Base, Cell, retry, Runner0, Journal0) ->
    {_Intent, PrimaryRequest, Runner1, Journal1} = begin_attempt(
        Cell, primary, Runner0, Journal0
    ),
    PrimaryResult = failure(PrimaryRequest, timeout, not_submitted),
    {ok, InitialObservation} = alang_fidelity_observation:normalize(Cell, PrimaryResult),
    {Runner2, Journal2} = finish_attempt(
        Runner1, Journal1, PrimaryResult, primary_classification(InitialObservation)
    ),
    {_RetryIntent, RetryRequest, Runner3, Journal3} = begin_attempt(
        Cell, retry, Runner2, Journal2
    ),
    RetryResult = exact_result(Base, Cell, RetryRequest),
    {ok, Observation} = alang_fidelity_observation:normalize(Cell, RetryResult),
    {Runner, Journal} = finish_attempt(
        Runner3, Journal3, RetryResult, primary_classification(Observation)
    ),
    {ok, Runner, Journal, Observation};
execute_cell(Base, Cell, replacement, Runner0, Journal0) ->
    {PrimaryIntent, PrimaryRequest, Runner1, Journal1} = begin_attempt(
        Cell, primary, Runner0, Journal0
    ),
    PrimaryResult = failure(PrimaryRequest, timeout, uncertain),
    {ok, InitialObservation} = alang_fidelity_observation:normalize(Cell, PrimaryResult),
    {Runner2, Journal2} = finish_attempt(
        Runner1, Journal1, PrimaryResult, primary_classification(InitialObservation)
    ),
    {ReplacementIntent, ReplacementRequest, Runner3, Journal3} = begin_attempt(
        Cell, replacement, Runner2, Journal2
    ),
    {ok, _Link, Journal4} = append(Journal3, replacement_link, #{
        link_class => no_definitive_response,
        operation_id => maps:get(operation_id, ReplacementIntent),
        parent_operation_id => maps:get(operation_id, PrimaryIntent),
        trial_id => maps:get(trial_id, ReplacementIntent)
    }),
    ReplacementResult = exact_result(Base, Cell, ReplacementRequest),
    {ok, Observation} = alang_fidelity_observation:normalize(Cell, ReplacementResult),
    {Runner, Journal} = finish_attempt(
        Runner3, Journal4, ReplacementResult, primary_classification(Observation)
    ),
    {ok, Runner, Journal, Observation}.

definitive_failure(Cell, Status, Runner0, Journal0) ->
    {_Intent, Request, Runner1, Journal1} = begin_attempt(Cell, primary, Runner0, Journal0),
    Result = failure(Request, Status, definitive),
    {ok, Observation} = alang_fidelity_observation:normalize(Cell, Result),
    {Runner, Journal} = finish_attempt(
        Runner1, Journal1, Result, primary_classification(Observation)
    ),
    {ok, Runner, Journal, Observation}.

begin_attempt(Cell, AttemptClass, Runner, Journal) ->
    {ok, Intent, UpdatedRunner} = alang_fidelity_campaign_runner:intent(
        Runner, AttemptClass
    ),
    ensure(maps:get(trial_id, Intent) =:= maps:get(trial_id, Cell), trial_order_mismatch),
    {ok, _Record, UpdatedJournal} = append(Journal, trial_intent, Intent),
    {Intent, request(Cell, Intent), UpdatedRunner, UpdatedJournal}.

finish_attempt(Runner, Journal, ProviderResult, Classification) ->
    Result = runner_result(ProviderResult, Classification),
    {ok, UpdatedRunner} = alang_fidelity_campaign_runner:record_result(Runner, Result),
    {ok, _Record, UpdatedJournal} = append(
        Journal, trial_result, result_payload(Result)
    ),
    {UpdatedRunner, UpdatedJournal}.

request(Cell, Intent) ->
    #{
        format => alang_fidelity_provider_request_v1,
        trial_id => maps:get(trial_id, Cell),
        operation_id => maps:get(operation_id, Intent),
        attempt_class => maps:get(attempt_class, Intent),
        family => maps:get(model_family, Cell),
        model_id => maps:get(model_id, Cell),
        effort => medium,
        max_output_tokens => 8192,
        prompt => maps:get(request, Cell),
        deadline_ms => 120000
    }.

exact_result(Base, Cell, Request) ->
    {ok, Key} = alang_fidelity_score:load_answer_key(Base, Cell),
    success(Request, encode(maps:get(<<"expected">>, Key)), maps:get(index, Cell)).

semantic_miss_result(Base, Cell, Request) ->
    {ok, Key} = alang_fidelity_score:load_answer_key(Base, Cell),
    Expected = maps:get(<<"expected">>, Key),
    [_First | Rest] = maps:get(<<"goal_facts">>, Expected),
    Actual = Expected#{<<"goal_facts">> := [<<"Seeded semantic mismatch">> | Rest]},
    success(Request, encode(Actual), maps:get(index, Cell)).

success(Request, Output, Index) ->
    {ok, Result} = alang_fidelity_provider_protocol:success(
        Request,
        Output,
        #{input_tokens => 100 + (Index rem 17), output_tokens => 40 + (Index rem 11)},
        <<"completed">>,
        10 + (Index rem 13),
        ?PRICE_TABLE
    ),
    Result.

failure(Request, Status, Submission) ->
    {ok, Result} = alang_fidelity_provider_protocol:failure(
        Request, Status, Submission, <<"offline-scripted-fault">>, 3
    ),
    Result.

runner_result(ProviderResult, Classification) ->
    Result0 = ProviderResult#{status := Classification},
    Result0#{result_digest := alang_fidelity_provider_protocol:result_digest(Result0)}.

result_payload(Result) ->
    Usage = maps:get(usage, Result),
    #{
        trial_id => maps:get(trial_id, Result),
        operation_id => maps:get(operation_id, Result),
        result_digest => maps:get(result_digest, Result),
        status => maps:get(status, Result),
        submission => maps:get(submission, Result),
        input_tokens => maps:get(input_tokens, Usage),
        output_tokens => maps:get(output_tokens, Usage),
        cost_microusd => maps:get(cost_microusd, Result)
    }.

append(Journal, Kind, Payload) ->
    alang_fidelity_campaign_journal:append(
        Journal, Kind, Payload, maps:get(next_sequence, Journal)
    ).

score_all(Base, Cells, Observations) ->
    ObservationIndex = maps:from_list([
        {maps:get(trial_id, Observation), Observation} || Observation <- Observations
    ]),
    [begin
        {ok, Key} = alang_fidelity_score:load_answer_key(Base, Cell),
        {ok, Score} = alang_fidelity_score:score(
            Cell, Key, maps:get(maps:get(trial_id, Cell), ObservationIndex)
        ),
        Score
    end || Cell <- Cells].

validity(Schedule, Observations, Scores, RunnerSummary, Journal) ->
    Scorable = length([
        true || Observation <- Observations,
        maps:get(scorable, maps:get(primary, Observation)) =:= true
    ]),
    #{
        format => alang_fidelity_offline_validity_v1,
        offline_fixture_only => true,
        hosted_calls => 0,
        exact_schedule => length(maps:get(cells, Schedule)) =:= 288,
        observations => length(Observations),
        scores => length(Scores),
        scorable_primary_cells => Scorable,
        runner_complete => maps:get(cursor, RunnerSummary) =:= 288,
        call_ceiling_respected => maps:get(calls, RunnerSummary) =< 576,
        cost_ceiling_respected => maps:get(cost_microusd, RunnerSummary) =< 200000000,
        journal_records => length(maps:get(records, Journal)),
        valid => Scorable =:= 288 andalso maps:get(cursor, RunnerSummary) =:= 288
    }.

accounting(RunnerSummary, Journal) ->
    Records = maps:get(records, Journal),
    Intents = [maps:get(payload, Record) || Record <- Records,
        maps:get(kind, Record) =:= trial_intent],
    Results = [maps:get(payload, Record) || Record <- Records,
        maps:get(kind, Record) =:= trial_result],
    #{
        calls => maps:get(calls, RunnerSummary),
        cost_microusd => maps:get(cost_microusd, RunnerSummary),
        completed_primary_cells => maps:get(completed_primary_cells, RunnerSummary),
        input_tokens => lists:sum([maps:get(input_tokens, Result) || Result <- Results]),
        output_tokens => lists:sum([maps:get(output_tokens, Result) || Result <- Results]),
        primary_attempts => attempt_count(primary, Intents),
        retries => attempt_count(retry, Intents),
        repairs => attempt_count(repair, Intents),
        replacements => attempt_count(replacement, Intents),
        uncertain_effects => length([true || Result <- Results,
            maps:get(submission, Result) =:= uncertain]),
        journal_records_before_close => length([true || Record <- Records,
            maps:get(kind, Record) =/= campaign_closed])
    }.

attempt_count(Class, Intents) -> length([
    true || Intent <- Intents, maps:get(attempt_class, Intent) =:= Class
]).

runner_summary(Runner) -> maps:with([
    schedule_digest,
    cursor,
    pending,
    mode,
    calls,
    cost_microusd,
    completed_primary_cells,
    invalid
], Runner).

scenario(Index) ->
    lists:nth((Index rem 12) + 1, [
        exact,
        malformed_repair,
        schema_repair_failure,
        refusal,
        truncated,
        retry,
        replacement,
        semantic_miss,
        exact,
        malformed_repair,
        exact,
        exact
    ]).

primary_classification(Observation) ->
    maps:get(classification, maps:get(primary, Observation)).

validate_result(Base, Result) ->
    ensure(maps:get(format, Result) =:= alang_fidelity_offline_campaign_v1,
        invalid_offline_campaign_format),
    ensure(maps:get(offline_digest, Result) =:=
        alang_fidelity_json:digest(maps:remove(offline_digest, Result)),
        invalid_offline_campaign_digest),
    Schedule = maps:get(schedule, Result),
    {ok, _} = alang_fidelity_campaign:validate_schedule(Schedule),
    Observations = maps:get(observations, Result),
    Scores = maps:get(scores, Result),
    ensure(length(Observations) =:= 288, incomplete_offline_observations),
    ensure(length(Scores) =:= 288, incomplete_offline_scores),
    RecomputedScores = score_all(Base, maps:get(cells, Schedule), Observations),
    ensure(RecomputedScores =:= Scores, offline_score_mismatch),
    {ok, Aggregate} = alang_fidelity_score:aggregate(Scores),
    ensure(Aggregate =:= maps:get(aggregate, Result), offline_aggregate_mismatch),
    {ok, Bootstrap} = alang_fidelity_bootstrap:compute(Scores),
    ensure(Bootstrap =:= maps:get(bootstrap, Result), offline_bootstrap_mismatch),
    Journal = maps:get(journal, Result),
    {ok, _} = alang_fidelity_campaign_journal:validate(
        maps:get(records, Journal), maps:get(schedule_digest, Schedule)
    ),
    {ok, Replayed} = alang_fidelity_campaign_runner:replay(
        Schedule, maps:get(records, Journal)
    ),
    ensure(runner_summary(Replayed) =:= maps:get(runner_summary, Result),
        offline_runner_replay_mismatch),
    ExpectedAccounting = (accounting(Replayed, Journal))#{
        journal_records => length(maps:get(records, Journal))
    },
    ensure(ExpectedAccounting =:= maps:get(accounting, Result), offline_accounting_mismatch),
    ExpectedValidity = validity(
        Schedule, Observations, Scores, runner_summary(Replayed), Journal
    ),
    ensure(ExpectedValidity =:= maps:get(validity, Result), offline_validity_mismatch),
    ExpectedAnalysisDigest = alang_fidelity_json:digest(#{
        schedule_digest => maps:get(schedule_digest, Schedule),
        observations => Observations,
        scores => Scores,
        aggregate => Aggregate,
        bootstrap => Bootstrap,
        accounting => maps:remove(journal_records, ExpectedAccounting)
    }),
    ensure(ExpectedAnalysisDigest =:= maps:get(analysis_digest, Result),
        offline_analysis_digest_mismatch),
    {ok, Result}.

finalize(Result) -> Result#{offline_digest => alang_fidelity_json:digest(Result)}.

encode(Value) -> iolist_to_binary(json:encode(Value)).

ensure(true, _Reason) -> ok;
ensure(false, Reason) -> throw({offline_campaign_error, Reason}).
