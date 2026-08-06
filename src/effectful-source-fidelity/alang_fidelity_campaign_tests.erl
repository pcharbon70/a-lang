-module(alang_fidelity_campaign_tests).

-include_lib("eunit/include/eunit.hrl").

-define(BASE, "assets/effectful-source-fidelity").

frozen_schedule_has_288_balanced_opaque_cells_test() ->
    {ok, Schedule} = alang_fidelity_campaign:materialize(?BASE),
    Cells = maps:get(cells, Schedule),
    ?assertEqual(288, length(Cells)),
    ?assertMatch({ok, _}, alang_fidelity_campaign:validate_schedule(Schedule)),
    lists:foreach(fun(Model) ->
        ModelCells = [Cell || Cell <- Cells, maps:get(model_family, Cell) =:= Model],
        ?assertEqual(144, length(ModelCells)),
        ?assertEqual(72, length([Cell || Cell <- ModelCells, maps:get(condition, Cell) =:= alang])),
        ?assertEqual(72, length([Cell || Cell <- ModelCells, maps:get(condition, Cell) =:= json]))
    end, [anthropic, openai]),
    lists:foreach(fun(Cell) ->
        TrialId = maps:get(trial_id, Cell),
        ?assertEqual(64, byte_size(TrialId)),
        ?assertEqual(nomatch, binary:match(TrialId, maps:get(case_id, Cell)))
    end, Cells).

schedule_and_requests_are_byte_reproducible_test() ->
    {ok, First} = alang_fidelity_campaign:materialize(?BASE),
    {ok, Second} = alang_fidelity_campaign:materialize(?BASE),
    ?assertEqual(term_to_binary(First, [deterministic]), term_to_binary(Second, [deterministic])),
    [Alang] = lists:sublist([Cell || Cell <- maps:get(cells, First), maps:get(condition, Cell) =:= alang], 1),
    Request = maps:get(request, Alang),
    ?assert(binary:match(Request, <<"--- BEGIN RESULT SCHEMA ---">>) =/= nomatch),
    ?assertEqual(nomatch, binary:match(Request, <<"model-visible-begin">>)),
    ?assertEqual(nomatch, binary:match(Request, <<"semantic-sha256">>)).

order_or_request_mutation_invalidates_schedule_test() ->
    {ok, Schedule} = alang_fidelity_campaign:materialize(?BASE),
    [First, Second | Rest] = maps:get(cells, Schedule),
    ?assertEqual(
        {error, invalid_schedule_indices},
        alang_fidelity_campaign:validate_schedule(Schedule#{cells := [Second, First | Rest]})
    ),
    Mutated = First#{request_digest := hex_id($f)},
    ?assertEqual(
        {error, schedule_digest_mismatch},
        alang_fidelity_campaign:validate_schedule(Schedule#{cells := [Mutated, Second | Rest]})
    ).

runner_bounds_retry_repair_and_replacement_test() ->
    {ok, Schedule} = alang_fidelity_campaign:materialize(?BASE),
    {ok, State0} = alang_fidelity_campaign_runner:new(Schedule),
    {ok, Intent0, State1} = alang_fidelity_campaign_runner:intent(State0, primary),
    {ok, State2} = alang_fidelity_campaign_runner:record_result(
        State1, result(Intent0, transport_failure, not_submitted)
    ),
    ?assertMatch({error, {illegal_attempt, retry, primary}}, alang_fidelity_campaign_runner:intent(State2, primary)),
    {ok, Retry, State3} = alang_fidelity_campaign_runner:intent(State2, retry),
    {ok, State4} = alang_fidelity_campaign_runner:record_result(
        State3, result(Retry, malformed_json, definitive)
    ),
    {ok, Repair, State5} = alang_fidelity_campaign_runner:intent(State4, repair),
    {ok, State6} = alang_fidelity_campaign_runner:record_result(
        State5, result(Repair, success, definitive)
    ),
    ?assertEqual(1, maps:get(completed_primary_cells, State6)),
    ?assertEqual(3, maps:get(calls, State6)),
    {ok, Primary2, State7} = alang_fidelity_campaign_runner:intent(State6, primary),
    {ok, State8} = alang_fidelity_campaign_runner:record_result(
        State7, result(Primary2, timeout, uncertain)
    ),
    {ok, Replacement, State9} = alang_fidelity_campaign_runner:intent(State8, replacement),
    ?assert(Replacement =/= Primary2),
    {ok, State10} = alang_fidelity_campaign_runner:record_result(
        State9, result(Replacement, success, definitive)
    ),
    ?assertEqual(2, maps:get(completed_primary_cells, State10)).

append_only_journal_replays_the_next_legal_action_test() ->
    {ok, Schedule} = alang_fidelity_campaign:materialize(?BASE),
    Digest = maps:get(schedule_digest, Schedule),
    Root = test_root(),
    {ok, Journal0} = alang_fidelity_campaign_journal:new(Digest),
    {ok, _Start, Journal1} = alang_fidelity_campaign_journal:append_file(
        Root, Journal0, campaign_started, #{primary_cells => 288, schedule_digest => Digest}
    ),
    {ok, State0} = alang_fidelity_campaign_runner:new(Schedule),
    {ok, Intent, State1} = alang_fidelity_campaign_runner:intent(State0, primary),
    {ok, _IntentRecord, Journal2} = alang_fidelity_campaign_journal:append_file(
        Root, Journal1, trial_intent, Intent
    ),
    Result = result(Intent, success, definitive),
    {ok, State2} = alang_fidelity_campaign_runner:record_result(State1, Result),
    Payload = result_payload(Result),
    {ok, _ResultRecord, _Journal3} = alang_fidelity_campaign_journal:append_file(
        Root, Journal2, trial_result, Payload
    ),
    {ok, Loaded} = alang_fidelity_campaign_journal:load(Root, Digest),
    {ok, Replayed} = alang_fidelity_campaign_runner:replay(Schedule, maps:get(records, Loaded)),
    ?assertEqual(alang_fidelity_campaign_runner:snapshot(State2), alang_fidelity_campaign_runner:snapshot(Replayed)),
    ?assertEqual(1, maps:get(completed_primary_cells, Replayed)).

selective_or_duplicate_results_are_rejected_test() ->
    {ok, Schedule} = alang_fidelity_campaign:materialize(?BASE),
    {ok, State0} = alang_fidelity_campaign_runner:new(Schedule),
    ?assertEqual({error, result_without_intent}, alang_fidelity_campaign_runner:record_result(State0, #{})),
    {ok, Intent, State1} = alang_fidelity_campaign_runner:intent(State0, primary),
    Bad = (result(Intent, success, definitive))#{trial_id := hex_id($e)},
    ?assertEqual({error, result_identity_mismatch}, alang_fidelity_campaign_runner:record_result(State1, Bad)).

result(Intent, Status, Submission) ->
    #{
        trial_id => maps:get(trial_id, Intent),
        operation_id => maps:get(operation_id, Intent),
        status => Status,
        submission => Submission,
        cost_microusd => 10,
        usage => #{input_tokens => 3, output_tokens => 2}
    }.

result_payload(Result) ->
    #{
        trial_id => maps:get(trial_id, Result),
        operation_id => maps:get(operation_id, Result),
        result_digest => alang_fidelity_json:digest(Result),
        status => maps:get(status, Result),
        submission => maps:get(submission, Result),
        input_tokens => maps:get(input_tokens, maps:get(usage, Result)),
        output_tokens => maps:get(output_tokens, maps:get(usage, Result)),
        cost_microusd => maps:get(cost_microusd, Result)
    }.

test_root() ->
    Unique = integer_to_list(erlang:unique_integer([positive])),
    filename:absname(filename:join("build/effectful-source-fidelity/phase-05/campaign-tests", Unique)).

hex_id(Character) -> list_to_binary(lists:duplicate(64, Character)).
