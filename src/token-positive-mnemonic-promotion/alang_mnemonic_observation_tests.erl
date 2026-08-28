-module(alang_mnemonic_observation_tests).

-include_lib("eunit/include/eunit.hrl").

provider_usage_and_score_are_exact_test() ->
    {Case, Oracle} = fixture(), Cell = cell(Case, <<"P0">>, 0, <<"trial-p0">>),
    Response = alang_mnemonic_protocol:oracle_response(<<"comprehension">>, <<"P0">>, Oracle),
    Request = request(Cell), Result = result(Request, Response, usage(101, 19)),
    {ok, Observation} = alang_mnemonic_observation:normalize(
        Cell, Request, Result, Oracle, "."),
    ?assertEqual(120, maps:get(<<"total_tokens">>, maps:get(<<"usage">>, Observation))),
    ?assertEqual(true, maps:get(<<"exact">>, maps:get(<<"score">>, Observation))),
    ?assertEqual(true, maps:get(<<"safe">>, maps:get(<<"safety">>, Observation))).

missing_estimated_and_inconsistent_usage_fail_test() ->
    {Case, Oracle} = fixture(), Cell = cell(Case, <<"P0">>, 0, <<"trial-p0">>),
    Response = alang_mnemonic_protocol:oracle_response(<<"comprehension">>, <<"P0">>, Oracle),
    Request = request(Cell), Base = result(Request, Response, usage(10, 2)),
    lists:foreach(fun(U) -> ?assertMatch({error, _},
        alang_mnemonic_observation:normalize(Cell, Request, Base#{<<"usage">> := U},
            Oracle, ".")) end, [missing, (usage(10, 2))#{<<"estimated">> := true},
                (usage(10, 2))#{<<"total_tokens">> := 99}]).

paired_tokens_and_candidate_only_budget_widening_test() ->
    {Case, Oracle} = fixture(),
    P0 = observation(Case, Oracle, <<"P0">>, 0, <<"trial-p0">>, Oracle, 100, 20),
    Budgets = maps:get(<<"budgets">>, Oracle),
    P1Value = Oracle#{<<"budgets">> := Budgets#{<<"steps">> :=
        maps:get(<<"steps">>, Budgets) + 1}},
    P1 = observation(Case, Oracle, <<"P1">>, 1, <<"trial-p1">>, P1Value, 92, 20),
    {ok, Pair} = alang_mnemonic_observation:pair(P0, P1),
    ?assertEqual(true, maps:get(<<"candidate_input_nonworse">>, Pair)),
    ?assertEqual(true, maps:get(<<"candidate_only_safety_failure">>, Pair)),
    ?assert(lists:member(<<"budget-widening">>,
        maps:get(<<"candidate_safety_failures">>, Pair))).

offline_replay_is_deterministic_and_rejects_gaps_test() ->
    {Case, Oracle} = fixture(),
    P0 = observation(Case, Oracle, <<"P0">>, 0, <<"trial-p0">>, Oracle, 100, 20),
    P1 = observation(Case, Oracle, <<"P1">>, 1, <<"trial-p1">>, Oracle, 90, 20),
    Cells = [maps:get(<<"cell">>, P0), maps:get(<<"cell">>, P1)],
    {ok, A} = alang_mnemonic_replay:build([P1, P0], Cells),
    {ok, B} = alang_mnemonic_replay:build([P0, P1], Cells),
    ?assertEqual(A, B),
    ?assertMatch({error, _}, alang_mnemonic_replay:build([P0], Cells)),
    ?assertMatch({error, _}, alang_mnemonic_replay:build([P0, P0], Cells)).

observation(Case, Oracle, Condition, Index, Trial, Value, Input, Output) ->
    Cell = cell(Case, Condition, Index, Trial), Request = request(Cell),
    Response = alang_mnemonic_protocol:oracle_response(<<"comprehension">>, Condition, Value),
    {ok, O} = alang_mnemonic_observation:normalize(Cell, Request,
        result(Request, Response, usage(Input, Output)), Oracle, "."), O.
cell(Case, Condition, Index, Trial) -> #{<<"index">> => Index,
    <<"trial_id">> => Trial, <<"case_id">> => maps:get(<<"id">>, Case),
    <<"model_family">> => <<"mixtral">>, <<"protocol">> => <<"comprehension">>,
    <<"condition">> => Condition, <<"repetition">> => 1,
    <<"runtime_family">> => maps:get(<<"runtime_family">>, Case),
    <<"stratum">> => maps:get(<<"stratum">>, Case)}.
request(Cell) -> #{<<"operation_id">> => alang_fidelity_json:digest(Cell),
    <<"trial_id">> => maps:get(<<"trial_id">>, Cell),
    <<"model_id">> => <<"mixtral:8x7b">>}.
result(Request, Response, Usage) -> #{
    <<"format">> => <<"alang-token-positive-provider-result-v1">>,
    <<"operation_id">> => maps:get(<<"operation_id">>, Request),
    <<"trial_id">> => maps:get(<<"trial_id">>, Request),
    <<"model_id">> => maps:get(<<"model_id">>, Request),
    <<"provider_state">> => <<"definitive">>, <<"response">> => Response,
    <<"response_sha256">> => alang_fidelity_json:hex(crypto:hash(sha256, Response)),
    <<"usage">> => Usage, <<"diagnostic">> => <<>>}.
usage(Input, Output) -> #{<<"estimated">> => false, <<"prompt_tokens">> => Input,
    <<"output_tokens">> => Output, <<"total_tokens">> => Input + Output}.
fixture() ->
    {ok, Corpus} = alang_fidelity_json:decode_file(
        "assets/token-positive-mnemonic-promotion/corpus/confirmatory-corpus-v1.json"),
    Case = hd(maps:get(<<"cases">>, Corpus)), {Case, alang_mnemonic_corpus:oracle(Case)}.
