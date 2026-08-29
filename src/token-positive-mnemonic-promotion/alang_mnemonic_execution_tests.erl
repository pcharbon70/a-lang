-module(alang_mnemonic_execution_tests).

-include_lib("eunit/include/eunit.hrl").

exact_inventory_authorizes_and_drift_fails_test_() ->
    {timeout, 30, fun exact_inventory_authorizes_and_drift_fails/0}.
exact_inventory_authorizes_and_drift_fails() ->
    Evidence = qualification(), Inventory = inventory(),
    {ok, Token} = alang_mnemonic_live_gate:authorize(Evidence, ".", env(), Inventory),
    ?assertEqual(true, maps:get(<<"authorized">>, Token)),
    Extra = #{<<"model_id">> => <<"unregistered-local-model">>,
        <<"manifest_sha256">> => zeros()},
    ?assertMatch({ok, _}, alang_mnemonic_live_gate:authorize(
        Evidence, ".", env(), [Extra | Inventory])),
    [First | Rest] = Inventory,
    Drift = [First#{<<"manifest_sha256">> := zeros()} | Rest],
    ?assertMatch({error, _}, alang_mnemonic_live_gate:authorize(Evidence, ".", env(), Drift)),
    ?assertMatch({error, _}, alang_mnemonic_live_gate:authorize(Evidence, ".", #{}, Inventory)).

ollama_inventory_and_response_are_closed_test_() ->
    {timeout, 30, fun ollama_inventory_and_response_are_closed/0}.
ollama_inventory_and_response_are_closed() ->
    Body = <<"{\"models\":[{\"name\":\"mixtral:8x7b\",\"digest\":\"sha256:a3b6bef0f836ff29ddb576a80eeb1b7def43ec9b809466f62e96adb871fe8498\"},{\"name\":\"hf.co/unsloth/Ornith-1.0-35B-GGUF:UD-Q5_K_M\",\"digest\":\"6959cafd1e245e8fd083f223c951d6f1e3c778b13d1ad33b4919f3c465927a25\"}]}">>,
    ?assertEqual({ok, inventory()}, alang_mnemonic_live_gate:decode_inventory(Body)),
    {ok, State} = alang_mnemonic_runner:new(".", qualification(), env(), inventory()),
    {ok, Request, _} = alang_mnemonic_runner:prepare(State, qualification(), env(), inventory(), primary),
    Model = maps:get(<<"model_id">>, Request),
    Response = iolist_to_binary([<<"{\"model\":">>, quote(Model),
        <<",\"done\":true,\"message\":{\"content\":\"{}\"},\"prompt_eval_count\":11,\"eval_count\":3}">>]),
    {ok, Result} = alang_mnemonic_ollama:decode_response(Request, Response),
    ?assertEqual(14, maps:get(<<"total_tokens">>, maps:get(<<"usage">>, Result))),
    {ok, RequestBytes} = alang_mnemonic_ollama:request_body(Request),
    {ok, RequestValue} = alang_fidelity_json:decode(RequestBytes),
    ?assertEqual(false, maps:get(<<"stream">>, RequestValue)),
    Options = maps:get(<<"options">>, RequestValue),
    ?assertEqual(false, maps:is_key(<<"stream">>, Options)),
    ?assertEqual(maps:get(<<"seed">>, Request), maps:get(<<"seed">>, Options)),
    ?assertMatch({error, submission_not_authorized}, alang_mnemonic_ollama:submit(#{}, Request)).

runner_preserves_order_and_replacement_rule_test_() ->
    {timeout, 60, fun runner_preserves_order_and_replacement_rule/0}.
runner_preserves_order_and_replacement_rule() ->
    {ok, State0} = alang_mnemonic_runner:new(".", qualification(), env(), inventory()),
    {ok, Cell0} = alang_mnemonic_runner:next(State0),
    {ok, Request0, State1} = alang_mnemonic_runner:prepare(State0,
        qualification(), env(), inventory(), primary),
    ?assertEqual(maps:get(<<"trial_id">>, Cell0), maps:get(<<"trial_id">>, Request0)),
    Result0 = result(Request0, <<"not_submitted">>),
    {ok, State2} = alang_mnemonic_runner:record_result(State1, Result0),
    {ok, _} = alang_mnemonic_runner:replacement(State2, maps:get(<<"trial_id">>, Request0)),
    {ok, Request1, State3} = alang_mnemonic_runner:prepare(State2,
        qualification(), env(), inventory(), replacement),
    {ok, State4} = alang_mnemonic_runner:record_result(State3,
        result(Request1, <<"definitive">>)),
    {ok, Cell1} = alang_mnemonic_runner:next(State4),
    ?assertEqual(maps:get(<<"index">>, Cell0) + 1, maps:get(<<"index">>, Cell1)).

journal_is_hash_chained_and_rejects_mutation_test() ->
    Q = maps:get(<<"qualification_digest">>, qualification()),
    {ok, Schedule} = alang_mnemonic_schedule:materialize(
        "assets/token-positive-mnemonic-promotion/campaign"),
    D = maps:get(<<"schedule_digest">>, Schedule),
    {ok, J0} = alang_mnemonic_journal:new(Q, D),
    Cell = hd(maps:get(<<"cells">>, Schedule)),
    Request = #{<<"operation_id">> => zeros(), <<"trial_id">> =>
        maps:get(<<"trial_id">>, Cell), <<"cell_index">> => maps:get(<<"index">>, Cell)},
    Payload = #{attempt => primary, cell => Cell, request => Request,
        request_digest => alang_fidelity_json:digest(Request)},
    {ok, Record, J1} = alang_mnemonic_journal:append(J0, trial_intent, Payload, 1),
    ?assertMatch({ok, _}, alang_mnemonic_journal:validate([Record], Q, D)),
    Mutant = Record#{timestamp_ms := 2},
    ?assertMatch({error, record_digest_mismatch},
        alang_mnemonic_journal:validate([Mutant], Q, D)),
    ?assertEqual(1, maps:get(next_sequence, J1)).

campaign_journals_definitive_result_and_resumes_test_() ->
    {timeout, 60, fun campaign_journals_definitive_result_and_resumes/0}.
campaign_journals_definitive_result_and_resumes() ->
    RunRoot = run_root("definitive"), clean_run(RunRoot),
    {ok, State0} = alang_mnemonic_campaign:start(".", RunRoot, env(), inventory()),
    Submit = fun(_Token, Request) -> {ok, provider_result(Request, <<"definitive">>)} end,
    {ok, _Result, State1} = alang_mnemonic_campaign:submit_next(State0, Submit),
    Snapshot = alang_mnemonic_campaign:snapshot(State1),
    ?assertEqual(1, maps:get(cursor, maps:get(runner, Snapshot))),
    ?assertEqual(2, maps:get(journal_records, Snapshot)),
    {ok, Resumed} = alang_mnemonic_campaign:resume(".", RunRoot, env(), inventory()),
    ?assertEqual(alang_mnemonic_campaign:snapshot(State1),
        alang_mnemonic_campaign:snapshot(Resumed)),
    clean_run(RunRoot).

campaign_links_one_not_submitted_replacement_test_() ->
    {timeout, 90, fun campaign_links_one_not_submitted_replacement/0}.
campaign_links_one_not_submitted_replacement() ->
    RunRoot = run_root("replacement"), clean_run(RunRoot),
    {ok, State0} = alang_mnemonic_campaign:start(".", RunRoot, env(), inventory()),
    NotSubmitted = fun(_Token, Request) ->
        {ok, provider_result(Request, <<"not_submitted">>)} end,
    {ok, _, State1} = alang_mnemonic_campaign:submit_next(State0, NotSubmitted),
    ?assertEqual(replacement, alang_mnemonic_runner:attempt(maps:get(runner, State1))),
    Definitive = fun(_Token, Request) ->
        {ok, provider_result(Request, <<"definitive">>)} end,
    {ok, _, State2} = alang_mnemonic_campaign:submit_next(State1, Definitive),
    Snapshot = alang_mnemonic_campaign:snapshot(State2),
    ?assertEqual(1, maps:get(cursor, maps:get(runner, Snapshot))),
    ?assertEqual(5, maps:get(journal_records, Snapshot)),
    clean_run(RunRoot).

result(Request, State) -> #{<<"operation_id">> => maps:get(<<"operation_id">>, Request),
    <<"provider_state">> => State, <<"latency_ms">> => 1}.
provider_result(Request, State) ->
    Response = case State of <<"definitive">> -> <<"{}">>; _ -> <<>> end,
    Usage = case State of
        <<"definitive">> -> #{<<"estimated">> => false, <<"prompt_tokens">> => 10,
            <<"output_tokens">> => 2, <<"total_tokens">> => 12};
        _ -> missing
    end,
    #{<<"format">> => <<"alang-token-positive-provider-result-v1">>,
      <<"operation_id">> => maps:get(<<"operation_id">>, Request),
      <<"trial_id">> => maps:get(<<"trial_id">>, Request),
      <<"model_id">> => maps:get(<<"model_id">>, Request),
      <<"provider_state">> => State, <<"response">> => Response,
      <<"response_sha256">> => alang_fidelity_json:hex(crypto:hash(sha256, Response)),
      <<"usage">> => Usage, <<"diagnostic">> => <<>>, <<"latency_ms">> => 1}.
qualification() ->
    {ok, Value} = alang_fidelity_json:decode_file(filename:join(["build",
        "token-positive-mnemonic-promotion", "phase-02", "evidence", "qualification-a.json"])), Value.
env() -> #{<<"ALANG_ALLOW_MNEMONIC_MODEL_CALLS">> => <<"1">>}.
inventory() -> [
    #{<<"model_id">> => <<"mixtral:8x7b">>, <<"manifest_sha256">> =>
        <<"a3b6bef0f836ff29ddb576a80eeb1b7def43ec9b809466f62e96adb871fe8498">>},
    #{<<"model_id">> => <<"hf.co/unsloth/Ornith-1.0-35B-GGUF:UD-Q5_K_M">>,
      <<"manifest_sha256">> => <<"6959cafd1e245e8fd083f223c951d6f1e3c778b13d1ad33b4919f3c465927a25">>}].
quote(Binary) -> <<"\"", Binary/binary, "\"">>.
zeros() -> <<"0000000000000000000000000000000000000000000000000000000000000000">>.
run_root(Name) -> filename:join(["build", "token-positive-mnemonic-promotion",
    "phase-03", "test-" ++ Name]).
clean_run(Root) ->
    Directory = filename:join(Root, "records"),
    lists:foreach(fun file:delete/1, filelib:wildcard(filename:join(Directory, "*.etf"))),
    _ = file:del_dir(Directory), _ = file:del_dir(Root), ok.
