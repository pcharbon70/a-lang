-module(alang_compact_design_tests).

-include_lib("eunit/include/eunit.hrl").

power_audit_expands_underpowered_minimum_test_() ->
    {timeout, 30, fun() ->
        {ok, Design} = alang_compact_power:load(power_path()),
        {ok, Audit} = alang_compact_power:audit(Design),
        ?assertEqual(48, maps:get(<<"selected_cases">>, Audit)),
        Central = scenario(<<"central">>, Audit),
        ?assert(power(24, Central) < 0.80),
        ?assert(power(48, Central) >= 0.80)
    end}.

power_audit_is_deterministic_test_() ->
    {timeout, 30, fun() ->
        {ok, Design} = alang_compact_power:load(power_path()),
        ?assertEqual(alang_compact_power:audit(Design), alang_compact_power:audit(Design))
    end}.

power_threshold_mutation_is_rejected_test() ->
    {ok, Design} = alang_fidelity_json:decode_file(power_path()),
    ?assertMatch({error, _}, alang_compact_power:audit(Design#{<<"minimum_central_power">> => 0.79})).

schedule_has_registered_shape_test() ->
    {ok, Schedule} = alang_compact_schedule:materialize(campaign_dir()),
    Cells = maps:get(<<"cells">>, Schedule),
    ?assertEqual(2304, length(Cells)),
    ?assertEqual(1152, count(<<"model_family">>, <<"mixtral">>, Cells)),
    ?assertEqual(1152, count(<<"model_family">>, <<"ornith">>, Cells)),
    ?assertEqual(768, count(<<"condition">>, <<"R0">>, Cells)),
    ?assertEqual(768, count(<<"condition">>, <<"R3">>, Cells)),
    ?assertEqual(192, count(<<"condition">>, <<"R4">>, Cells)).

schedule_is_deterministic_and_opaque_test() ->
    {ok, First} = alang_compact_schedule:materialize(campaign_dir()),
    {ok, Second} = alang_compact_schedule:materialize(campaign_dir()),
    ?assertEqual(First, Second),
    Cells = maps:get(<<"cells">>, First),
    ?assert(lists:all(fun(Cell) ->
        Trial = maps:get(<<"trial_id">>, Cell),
        byte_size(Trial) =:= 24 andalso binary:match(Trial, maps:get(<<"condition">>, Cell)) =:= nomatch
    end, Cells)).

schedule_separates_semantic_cases_test() ->
    {ok, Schedule} = alang_compact_schedule:materialize(campaign_dir()),
    Cells = maps:get(<<"cells">>, Schedule),
    Pairs = lists:zip(lists:sublist(Cells, length(Cells) - 1), tl(Cells)),
    ?assert(lists:all(fun({A, B}) -> maps:get(<<"case_id">>, A) =/= maps:get(<<"case_id">>, B) end, Pairs)).

scenario(Id, Audit) -> hd([S || S <- maps:get(<<"scenario_results">>, Audit), maps:get(<<"id">>, S) =:= Id]).
power(Cases, Scenario) ->
    Result = hd([R || R <- maps:get(<<"case_counts">>, Scenario), maps:get(<<"cases">>, R) =:= Cases]),
    maps:get(<<"estimated_power">>, Result).
count(Key, Value, Cells) -> length([Cell || Cell <- Cells, maps:get(Key, Cell) =:= Value]).
power_path() -> filename:join([campaign_dir(), "power-design-v1.json"]).
campaign_dir() -> filename:join(["assets", "compact-projection-fidelity", "campaign"]).
