-module(alang_fidelity_validity_tests).

-include_lib("eunit/include/eunit.hrl").

valid_campaign_passes_all_predicates_test() ->
    {ok, Campaign} = alang_fidelity_offline_campaign:run(asset_root()),
    {ok, Valid, Result} = alang_fidelity_validity:evaluate(Campaign),
    ?assertEqual(valid, Valid),
    ?assertEqual(0, maps:get(failed_count, Result)),
    ?assertEqual(14, maps:get(predicate_count, Result)),
    ?assert(is_map(maps:get(tables, Result))),
    ?assert(is_map(maps:get(primary, maps:get(tables, Result)))),
    ?assert(is_map(maps:get(secondary, maps:get(tables, Result)))).

frozen_analysis_tables_have_digests_test() ->
    {ok, Campaign} = alang_fidelity_offline_campaign:run(asset_root()),
    {ok, valid, Result} = alang_fidelity_validity:evaluate(Campaign),
    Tables = maps:get(tables, Result),
    Primary = maps:get(primary, Tables),
    Secondary = maps:get(secondary, Tables),
    ?assert(is_binary(maps:get(table_digest, Primary))),
    ?assert(is_binary(maps:get(aggregate_digest, Secondary))),
    ?assert(is_binary(maps:get(bootstrap_digest, Secondary))),
    ?assert(is_binary(maps:get(accounting_digest, Secondary))),
    ?assert(is_binary(maps:get(analysis_digest, Tables))).

invalid_campaign_format_is_detected_test() ->
    {ok, Campaign} = alang_fidelity_offline_campaign:run(asset_root()),
    Mutant = Campaign#{format := <<"corrupted-format-v99">>},
    {ok, invalid, Result} = alang_fidelity_validity:evaluate(Mutant),
    ?assert(maps:get(failed_count, Result) >= 1),
    Report = maps:get(report, Result),
    ?assert(lists:member(exact_format, maps:get(failed_predicates, Report))).

insufficient_observations_is_detected_test() ->
    {ok, Campaign} = alang_fidelity_offline_campaign:run(asset_root()),
    Observations = maps:get(observations, Campaign),
    [_First | Rest] = Observations,
    Mutant = Campaign#{observations := Rest},
    {ok, invalid, Result} = alang_fidelity_validity:evaluate(Mutant),
    ?assert(maps:get(failed_count, Result) >= 1),
    Report = maps:get(report, Result),
    ?assert(lists:member(complete_primary_observations, maps:get(failed_predicates, Report))).

call_ceiling_exceeded_is_detected_test() ->
    {ok, Campaign} = alang_fidelity_offline_campaign:run(asset_root()),
    Accounting = maps:get(accounting, Campaign),
    Mutant = Campaign#{accounting := Accounting#{calls := 577}},
    {ok, invalid, Result} = alang_fidelity_validity:evaluate(Mutant),
    ?assert(maps:get(failed_count, Result) >= 1),
    Report = maps:get(report, Result),
    ?assert(lists:member(call_ceiling_respected, maps:get(failed_predicates, Report))).

cost_ceiling_exceeded_is_detected_test() ->
    {ok, Campaign} = alang_fidelity_offline_campaign:run(asset_root()),
    Accounting = maps:get(accounting, Campaign),
    Mutant = Campaign#{accounting := Accounting#{cost_microusd := 200000001}},
    {ok, invalid, Result} = alang_fidelity_validity:evaluate(Mutant),
    ?assert(maps:get(failed_count, Result) >= 1),
    Report = maps:get(report, Result),
    ?assert(lists:member(cost_ceiling_respected, maps:get(failed_predicates, Report))).

asset_root() ->
    filename:join(["assets", "effectful-source-fidelity"]).
