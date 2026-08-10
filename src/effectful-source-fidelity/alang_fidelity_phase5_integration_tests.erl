-module(alang_fidelity_phase5_integration_tests).

-include_lib("eunit/include/eunit.hrl").

-define(BASE, "assets/effectful-source-fidelity").
-define(EVIDENCE_A,
    "build/effectful-source-fidelity/phase-05/evidence/reproduction-a.etf").
-define(EVIDENCE_B,
    "build/effectful-source-fidelity/phase-05/evidence/reproduction-b.etf").

complete_288_cell_fault_campaign_resumes_at_every_transition_test_() ->
    {timeout, 90, fun() ->
        {ok, Campaign} = alang_fidelity_offline_campaign:run(?BASE),
        Accounting = maps:get(accounting, Campaign),
        Validity = maps:get(validity, Campaign),
        ?assertEqual(288, maps:get(observations, Validity)),
        ?assertEqual(288, maps:get(scorable_primary_cells, Validity)),
        ?assertEqual(0, maps:get(hosted_calls, Validity)),
        ?assertEqual(true, maps:get(valid, Validity)),
        ?assertEqual(408, maps:get(calls, Accounting)),
        ?assertEqual(288, maps:get(primary_attempts, Accounting)),
        ?assertEqual(24, maps:get(retries, Accounting)),
        ?assertEqual(72, maps:get(repairs, Accounting)),
        ?assertEqual(24, maps:get(replacements, Accounting)),
        ?assertEqual(24, maps:get(uncertain_effects, Accounting)),
        ?assertEqual(842, maps:get(journal_records, Accounting)),
        Classes = classification_counts(maps:get(observations, Campaign)),
        ?assertEqual(168, maps:get(valid, Classes)),
        ?assertEqual(48, maps:get(malformed_json, Classes)),
        ?assertEqual(24, maps:get(schema_invalid, Classes)),
        ?assertEqual(24, maps:get(definitive_refusal, Classes)),
        ?assertEqual(24, maps:get(truncated, Classes)),
        assert_every_prefix_replays(
            maps:get(schedule, Campaign),
            maps:get(records, maps:get(journal, Campaign))
        )
    end}.

seeded_scoring_accounting_bootstrap_and_journal_defects_are_detected_test_() ->
    {timeout, 90, fun() ->
        {ok, Campaign} = alang_fidelity_offline_campaign:run(?BASE),
        lists:foreach(fun(Name) ->
            Mutated = alang_fidelity_phase5_mutation:apply(Name, Campaign),
            ?assertMatch(
                {error, _},
                alang_fidelity_offline_campaign:validate(?BASE, Mutated)
            )
        end, alang_fidelity_phase5_mutation:names())
    end}.

clean_erts_evidence_is_byte_identical_and_replays_without_network_test_() ->
    {timeout, 90, fun() ->
        {ok, BytesA} = file:read_file(?EVIDENCE_A),
        {ok, BytesB} = file:read_file(?EVIDENCE_B),
        ?assertEqual(BytesA, BytesB),
        {ok, Evidence} = alang_fidelity_evidence:read(?EVIDENCE_A),
        ?assertEqual(offline_fixture, maps:get(campaign_status, Evidence)),
        ?assertEqual(#{missing => 0, observed => 288, scheduled => 288, scored => 288},
            maps:get(completeness, Evidence)),
        Statistics = maps:get(statistics, Evidence),
        ?assertEqual(0, maps:get(hosted_calls, maps:get(validity, Statistics))),
        ?assertEqual(true, maps:get(valid, maps:get(validity, Statistics))),
        recompute_evidence(Evidence),
        ?assertEqual(false, has_forbidden_key(Evidence)),
        ?assertEqual(nomatch, binary:match(BytesA, <<"ALANG_SECTION_5_4_SECRET">>))
    end}.

phase5_offline_path_is_beam_resident_and_has_no_foreign_process_import_test() ->
    Modules = [
        alang_fidelity_adapter_fault_tests,
        alang_fidelity_mixtral_adapter,
        alang_fidelity_bootstrap,
        alang_fidelity_campaign,
        alang_fidelity_campaign_journal,
        alang_fidelity_campaign_runner,
        alang_fidelity_evidence,
        alang_fidelity_https,
        alang_fidelity_https_fixture,
        alang_fidelity_observation,
        alang_fidelity_offline_campaign,
        alang_fidelity_ornith_adapter,
        alang_fidelity_phase5_mutation,
        alang_fidelity_phase5_worker,
        alang_fidelity_score
    ],
    lists:foreach(fun(Module) ->
        Path = code:which(Module),
        ?assert(is_list(Path)),
        ?assertEqual(".beam", filename:extension(Path)),
        {ok, {Module, [{imports, Imports}]}} = beam_lib:chunks(Path, [imports]),
        ?assertEqual(false, lists:member({erlang, open_port, 2}, Imports)),
        ?assertEqual(false, lists:member({os, cmd, 1}, Imports))
    end, Modules).

assert_every_prefix_replays(Schedule, Records) ->
    Digest = maps:get(schedule_digest, Schedule),
    assert_prefixes(Schedule, Digest, Records, []).

assert_prefixes(_Schedule, _Digest, [], _PrefixRev) -> ok;
assert_prefixes(Schedule, Digest, [Record | Rest], PrefixRev) ->
    Prefix = lists:reverse([Record | PrefixRev]),
    Copy = binary_to_term(term_to_binary(Prefix, [deterministic]), [safe]),
    ?assertMatch({ok, _}, alang_fidelity_campaign_journal:validate(Copy, Digest)),
    ?assertMatch({ok, _}, alang_fidelity_campaign_runner:replay(Schedule, Copy)),
    assert_prefixes(Schedule, Digest, Rest, [Record | PrefixRev]).

classification_counts(Observations) ->
    lists:foldl(fun(Observation, Acc) ->
        Classification = maps:get(classification, maps:get(primary, Observation)),
        Acc#{Classification => maps:get(Classification, Acc, 0) + 1}
    end, #{}, Observations).

recompute_evidence(Evidence) ->
    Schedule = maps:get(schedule, Evidence),
    Cells = maps:get(cells, Schedule),
    Observations = maps:get(observations, Evidence),
    ObservationIndex = maps:from_list([
        {maps:get(trial_id, Observation), Observation} || Observation <- Observations
    ]),
    Scores = [begin
        {ok, Key} = alang_fidelity_score:load_answer_key(?BASE, Cell),
        {ok, Score} = alang_fidelity_score:score(
            Cell, Key, maps:get(maps:get(trial_id, Cell), ObservationIndex)
        ),
        Score
    end || Cell <- Cells],
    ?assertEqual(Scores, maps:get(scores, Evidence)),
    {ok, Aggregate} = alang_fidelity_score:aggregate(Scores),
    {ok, Bootstrap} = alang_fidelity_bootstrap:compute(Scores),
    Statistics = maps:get(statistics, Evidence),
    ?assertEqual(Aggregate, maps:get(aggregate, Statistics)),
    ?assertEqual(Bootstrap, maps:get(bootstrap, Statistics)),
    Journal = maps:get(campaign_journal, Evidence),
    ?assertMatch({ok, _}, alang_fidelity_campaign_journal:validate(
        maps:get(records, Journal), maps:get(schedule_digest, Schedule)
    )),
    {ok, Replayed} = alang_fidelity_campaign_runner:replay(
        Schedule, maps:get(records, Journal)
    ),
    ?assertEqual(288, maps:get(completed_primary_cells, Replayed)),
    ?assertEqual(408, maps:get(calls, Replayed)),
    ?assertEqual(61762, maps:get(cost_microusd, Replayed)).

has_forbidden_key(Value) when is_map(Value) ->
    Forbidden = [authorization, headers, raw_http_envelope, raw_envelope,
        hidden_reasoning, api_key, credential, provider_request_id,
        provider_response_id, response_id],
    lists:any(fun({Key, Item}) ->
        lists:member(Key, Forbidden) orelse has_forbidden_key(Item)
    end, maps:to_list(Value));
has_forbidden_key(Value) when is_list(Value) -> lists:any(fun has_forbidden_key/1, Value);
has_forbidden_key(Value) when is_tuple(Value) -> has_forbidden_key(tuple_to_list(Value));
has_forbidden_key(_Value) -> false.
