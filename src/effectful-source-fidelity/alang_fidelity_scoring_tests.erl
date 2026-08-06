-module(alang_fidelity_scoring_tests).

-include_lib("eunit/include/eunit.hrl").

-define(BASE, "assets/effectful-source-fidelity").

exact_response_normalizes_and_scores_without_llm_judge_test() ->
    Cell = first_cell(),
    {ok, Key} = alang_fidelity_score:load_answer_key(?BASE, Cell),
    {ok, Result} = success(Cell, maps:get(<<"expected">>, Key), primary, exact),
    {ok, Observation} = alang_fidelity_observation:normalize(Cell, Result),
    Primary = maps:get(primary, Observation),
    ?assertEqual(valid, maps:get(classification, Primary)),
    ?assertMatch(<<"{\"actions\":" , _/binary>>, maps:get(canonical_json, Primary)),
    {ok, Score} = alang_fidelity_score:score(Cell, Key, Observation),
    ?assertEqual(true, maps:get(exact_semantic_fidelity, Score)),
    ?assertEqual(12, maps:get(component_exact_count, Score)),
    ?assertEqual(0, maps:get(omission_count, Score)),
    ?assertEqual(0, maps:get(invention_count, Score)).

repair_is_secondary_and_never_replaces_primary_failure_test() ->
    Cell = first_cell(),
    {ok, Key} = alang_fidelity_score:load_answer_key(?BASE, Cell),
    PrimaryRequest = request(Cell, primary, malformed),
    {ok, PrimaryResult} = protocol_success(PrimaryRequest, <<"SECRET-RAW-OUTPUT">>),
    {ok, Observation0} = alang_fidelity_observation:normalize(Cell, PrimaryResult),
    ?assertEqual(malformed_json,
        maps:get(classification, maps:get(primary, Observation0))),
    RepairOperation = operation_id(Cell, repair),
    {ok, RepairRequest} = alang_fidelity_observation:repair_request(
        PrimaryRequest, Observation0, RepairOperation
    ),
    RepairPrompt = maps:get(prompt, RepairRequest),
    ?assert(binary:match(RepairPrompt, maps:get(prompt, PrimaryRequest)) =/= nomatch),
    ?assertEqual(nomatch, binary:match(RepairPrompt, <<"SECRET-RAW-OUTPUT">>)),
    {ok, RepairResult} = protocol_success(
        RepairRequest, encode(maps:get(<<"expected">>, Key))
    ),
    {ok, Observation} = alang_fidelity_observation:attach_repair(Observation0, RepairResult),
    {ok, Score} = alang_fidelity_score:score(Cell, Key, Observation),
    ?assertEqual(false, maps:get(exact_semantic_fidelity, Score)),
    ?assertEqual(malformed_json, maps:get(primary_classification, Score)),
    ?assertEqual(#{attempted => true, classification => valid, exact => true, valid => true},
        maps:get(repair, Score)).

closed_observation_taxonomy_covers_definitive_and_transport_failures_test() ->
    Cell = first_cell(),
    Refusal = observation_class(Cell, definitive_refusal, definitive),
    Truncated = observation_class(Cell, truncated, definitive),
    Transport = observation_class(Cell, timeout, not_submitted),
    Uncertain = observation_class(Cell, timeout, uncertain),
    {ok, SchemaResult} = success(Cell, #{}, primary, invalid_schema),
    {ok, SchemaObservation} = alang_fidelity_observation:normalize(Cell, SchemaResult),
    {ok, Utf8Result} = success(Cell, <<255>>, primary, invalid_utf8),
    {ok, Utf8Observation} = alang_fidelity_observation:normalize(Cell, Utf8Result),
    {ok, Missing} = alang_fidelity_observation:missing(Cell),
    ?assertEqual(definitive_refusal, Refusal),
    ?assertEqual(truncated, Truncated),
    ?assertEqual(transport_failure, Transport),
    ?assertEqual(uncertain_submission, Uncertain),
    ?assertEqual(schema_invalid,
        maps:get(classification, maps:get(primary, SchemaObservation))),
    ?assertEqual(malformed_json,
        maps:get(classification, maps:get(primary, Utf8Observation))),
    ?assertEqual(missing_cell, maps:get(classification, maps:get(primary, Missing))).

scorer_counts_semantic_differences_and_safety_failures_test() ->
    Cell = cell(<<"ad-missing-information">>),
    {ok, Key} = alang_fidelity_score:load_answer_key(?BASE, Cell),
    Expected = maps:get(<<"expected">>, Key),
    Scopes0 = maps:get(<<"scopes">>, Expected),
    Actual = Expected#{
        <<"goal_facts">> := [<<"Invented completion claim">>],
        <<"scopes">> := Scopes0#{<<"paths">> := [<<"/outside-authority">>]},
        <<"terminal_class">> := <<"complete">>
    },
    {ok, Result} = success(Cell, Actual, primary, widened),
    {ok, Observation} = alang_fidelity_observation:normalize(Cell, Result),
    {ok, Score} = alang_fidelity_score:score(Cell, Key, Observation),
    ?assertEqual(false, maps:get(exact_semantic_fidelity, Score)),
    ?assert(maps:get(omission_count, Score) > 0),
    ?assert(maps:get(invention_count, Score) > 0),
    ?assertEqual(true, maps:get(authority_widening, Score)),
    ?assertEqual(true, maps:get(false_completion, Score)).

aggregates_report_registered_dimensions_and_accounting_test() ->
    [Cell1, Cell2 | _] = cells(),
    Score1 = exact_score(Cell1),
    Score2 = exact_score(Cell2),
    {ok, Aggregate} = alang_fidelity_score:aggregate([Score1, Score2]),
    ?assertEqual(2, maps:get(score_count, Aggregate)),
    ?assert(maps:is_key(by_model, Aggregate)),
    ?assert(maps:is_key(by_condition, Aggregate)),
    ?assert(maps:is_key(by_task_family, Aggregate)),
    ?assert(maps:is_key(by_case, Aggregate)),
    ?assert(maps:is_key(by_repetition, Aggregate)),
    Pooled = maps:get(pooled_descriptive_only, Aggregate),
    ?assertEqual(#{basis_points => 10000, denominator => 2, numerator => 2},
        maps:get(exact_semantic_fidelity, Pooled)).

paired_bootstrap_is_seeded_stratified_and_reproducible_test_() ->
    {timeout, 30, fun() ->
        Scores = synthetic_scores(),
        {ok, First} = alang_fidelity_bootstrap:compute(Scores),
        {ok, Second} = alang_fidelity_bootstrap:compute(Scores),
        ?assertEqual(term_to_binary(First, [deterministic]),
            term_to_binary(Second, [deterministic])),
        ?assertEqual(20260805, maps:get(seed, First)),
        ?assertEqual(10000, maps:get(resamples, First)),
        lists:foreach(fun(Model) ->
            Interval = maps:get(Model, maps:get(models, First)),
            ?assertEqual(100000000, maps:get(observed_difference_pp_micros, Interval)),
            ?assertEqual(100000000, maps:get(lower_pp_micros, Interval)),
            ?assertEqual(100000000, maps:get(upper_pp_micros, Interval))
        end, [anthropic, openai])
    end}.

evidence_is_redacted_bounded_and_safe_to_replay_test_() ->
    {timeout, 30, fun() ->
        {ok, Schedule} = alang_fidelity_campaign:materialize(?BASE),
        Cell = hd(maps:get(cells, Schedule)),
        {ok, Key} = alang_fidelity_score:load_answer_key(?BASE, Cell),
        {ok, Result} = success(Cell, maps:get(<<"expected">>, Key), primary, evidence),
        {ok, Observation} = alang_fidelity_observation:normalize(Cell, Result),
        {ok, Score} = alang_fidelity_score:score(Cell, Key, Observation),
        {ok, Aggregate} = alang_fidelity_score:aggregate([Score]),
        Statistics = #{aggregate => Aggregate, bootstrap => not_computed_for_partial_campaign},
        Options = #{campaign_status => partial, provenance => #{campaign_mode => offline_fixture}},
        {ok, Evidence} = alang_fidelity_evidence:build(
            ?BASE, Schedule, [Observation], [Score], Statistics, Options
        ),
        Path = filename:join(
            "build/effectful-source-fidelity/phase-05/evidence",
            "section-5-3-test.etf"
        ),
        {ok, _} = alang_fidelity_evidence:write(Path, Evidence),
        {ok, Replayed} = alang_fidelity_evidence:read(Path),
        ?assertEqual(term_to_binary(Evidence, [deterministic]),
            term_to_binary(Replayed, [deterministic])),
        ?assertEqual(
            {error, secret_retention_detected},
            alang_fidelity_evidence:build(
                ?BASE, Schedule, [Observation], [Score], Statistics,
                Options#{secrets => [maps:get(case_id, Cell)]}
            )
        ),
        ?assertMatch(
            {error, {forbidden_evidence_key, headers}},
            alang_fidelity_evidence:build(
                ?BASE, Schedule, [Observation], [Score], Statistics#{headers => []}, Options
            )
        )
    end}.

exact_score(Cell) ->
    {ok, Key} = alang_fidelity_score:load_answer_key(?BASE, Cell),
    {ok, Result} = success(Cell, maps:get(<<"expected">>, Key), primary, aggregate),
    {ok, Observation} = alang_fidelity_observation:normalize(Cell, Result),
    {ok, Score} = alang_fidelity_score:score(Cell, Key, Observation),
    Score.

observation_class(Cell, Status, Submission) ->
    Request = request(Cell, primary, {Status, Submission}),
    {ok, Result} = alang_fidelity_provider_protocol:failure(
        Request, Status, Submission, <<"bounded-diagnostic">>, 7
    ),
    {ok, Observation} = alang_fidelity_observation:normalize(Cell, Result),
    maps:get(classification, maps:get(primary, Observation)).

success(Cell, Value, AttemptClass, Salt) ->
    Request = request(Cell, AttemptClass, Salt),
    Output = case is_binary(Value) of true -> Value; false -> encode(Value) end,
    protocol_success(Request, Output).

protocol_success(Request, Output) ->
    Prices = #{
        anthropic => #{input_microusd_per_million => 1000000,
            output_microusd_per_million => 2000000},
        openai => #{input_microusd_per_million => 1000000,
            output_microusd_per_million => 2000000}
    },
    alang_fidelity_provider_protocol:success(
        Request, Output, #{input_tokens => 100, output_tokens => 50},
        <<"completed">>, 11, Prices
    ).

request(Cell, AttemptClass, Salt) ->
    #{
        format => alang_fidelity_provider_request_v1,
        trial_id => maps:get(trial_id, Cell),
        operation_id => operation_id(Cell, Salt),
        attempt_class => AttemptClass,
        family => maps:get(model_family, Cell),
        model_id => maps:get(model_id, Cell),
        effort => medium,
        max_output_tokens => 8192,
        prompt => maps:get(request, Cell),
        deadline_ms => 120000
    }.

operation_id(Cell, Salt) -> alang_fidelity_json:digest({
    section_5_3_operation, maps:get(trial_id, Cell), Salt
}).

first_cell() -> hd(cells()).

cell(CaseId) -> hd([Cell || Cell <- cells(), maps:get(case_id, Cell) =:= CaseId]).

cells() ->
    {ok, Schedule} = alang_fidelity_campaign:materialize(?BASE),
    maps:get(cells, Schedule).

encode(Value) -> iolist_to_binary(json:encode(Value)).

synthetic_scores() ->
    Families = [
        <<"attenuated-delegation">>,
        <<"repair-and-publish">>,
        <<"single-model-artifact">>
    ],
    [#{
        model_family => Model,
        condition => Condition,
        task_family => Family,
        case_id => synthetic_case_id(Family, CaseNumber),
        repetition => Repetition,
        exact_semantic_fidelity => Condition =:= alang
    }
        || Model <- [anthropic, openai],
           Condition <- [alang, json],
           Family <- Families,
           CaseNumber <- lists:seq(1, 8),
           Repetition <- lists:seq(1, 3)].

synthetic_case_id(Family, Number) ->
    <<Family/binary, "-", (integer_to_binary(Number))/binary>>.
