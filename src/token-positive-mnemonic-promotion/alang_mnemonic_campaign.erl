-module(alang_mnemonic_campaign).

-export([preflight/2, resume/4, run/1, snapshot/1, start/4, submit_next/2]).

-define(POLICY, "assets/token-positive-mnemonic-promotion/campaign/campaign-policy-v1.json").

-spec preflight(file:filename(), map()) -> {ok, map()} | {error, term()}.
preflight(Root, Environment) ->
    try
        {ok, Qualification} = checked(alang_mnemonic_qualification:build(Root)),
        {ok, Preliminary} = checked(alang_mnemonic_authorization:authorize(
            Qualification, Root, Environment)),
        Policy = decode(filename:join(Root, ?POLICY)),
        Endpoint = maps:get(<<"endpoint">>, maps:get(<<"live_opt_in">>, Policy)),
        {ok, Inventory} = checked(alang_mnemonic_ollama:probe(Preliminary, Endpoint)),
        {ok, Token} = checked(alang_mnemonic_live_gate:authorize(
            Qualification, Root, Environment, Inventory)),
        {ok, #{qualification => Qualification, inventory => Inventory,
            token => Token, policy => Policy}}
    catch
        error:{badkey, Key} -> {error, {mnemonic_campaign_error, {missing_field, Key}}};
        throw:{mnemonic_campaign_error, Reason} -> {error, {mnemonic_campaign_error, Reason}}
    end.

-spec start(file:filename(), file:filename(), map(), [map()]) ->
    {ok, map()} | {error, term()}.
start(Root, RunRoot, Environment, Inventory) ->
    try
        ensure(no_records(RunRoot), existing_campaign_records),
        {ok, Qualification} = checked(alang_mnemonic_qualification:build(Root)),
        {ok, Token} = checked(alang_mnemonic_live_gate:authorize(
            Qualification, Root, Environment, Inventory)),
        {ok, Runner} = checked(alang_mnemonic_runner:new(
            Root, Qualification, Environment, Inventory)),
        {ok, Schedule} = checked(alang_mnemonic_schedule:materialize(filename:join(
            Root, "assets/token-positive-mnemonic-promotion/campaign"))),
        {ok, Journal} = checked(alang_mnemonic_journal:new(
            maps:get(<<"qualification_digest">>, Qualification),
            maps:get(<<"schedule_digest">>, Schedule))),
        Policy = decode(filename:join(Root, ?POLICY)),
        {ok, state(Root, RunRoot, Environment, Inventory, Qualification,
            Token, Policy, Runner, Journal)}
    catch
        error:{badmatch, Reason} -> {error, {mnemonic_campaign_error, Reason}};
        throw:{mnemonic_campaign_error, Reason} ->
            {error, {mnemonic_campaign_error, Reason}}
    end.

-spec resume(file:filename(), file:filename(), map(), [map()]) ->
    {ok, map()} | {error, term()}.
resume(Root, RunRoot, Environment, Inventory) ->
    try
        {ok, Qualification} = checked(alang_mnemonic_qualification:build(Root)),
        {ok, Token} = checked(alang_mnemonic_live_gate:authorize(
            Qualification, Root, Environment, Inventory)),
        {ok, Runner0} = checked(alang_mnemonic_runner:new(
            Root, Qualification, Environment, Inventory)),
        {ok, Journal} = checked(alang_mnemonic_journal:load(
            RunRoot, maps:get(<<"qualification_digest">>, Qualification))),
        {ok, Runner} = checked(alang_mnemonic_runner:replay(
            Runner0, maps:get(records, Journal))),
        Policy = decode(filename:join(Root, ?POLICY)),
        State = state(Root, RunRoot, Environment, Inventory, Qualification,
            Token, Policy, Runner, Journal),
        case maps:get(pending, Runner) of
            none -> {ok, State};
            _ ->
                case invalidate(State, uncertain_resumed_submission) of
                    {error, uncertain_resumed_submission, Invalid} ->
                        {error, {mnemonic_campaign_error,
                            uncertain_resumed_submission}, Invalid};
                    {error, JournalReason, _} ->
                        {error, {mnemonic_campaign_error, JournalReason}}
                end
        end
    catch
        error:{badmatch, Reason} -> {error, {mnemonic_campaign_error, Reason}};
        throw:{mnemonic_campaign_error, Reason} ->
            {error, {mnemonic_campaign_error, Reason}}
    end.

-spec submit_next(map(), fun((map(), map()) -> {ok, map()} | {error, term()})) ->
    {ok, map(), map()} | {done, map()} | {error, term(), map()}.
submit_next(State, Submit) when is_function(Submit, 2) ->
    Runner0 = maps:get(runner, State),
    case alang_mnemonic_runner:next(Runner0) of
        {done, _} -> {done, State};
        {error, Reason} -> {error, Reason, State};
        {ok, Cell} -> submit_cell(State, Cell, Submit)
    end.

-spec run(map()) -> {ok, map()} | {error, term(), map()}.
run(State) ->
    case submit_next(State, fun alang_mnemonic_ollama:submit/2) of
        {ok, _Result, Updated} -> run(Updated);
        {done, Updated} -> {ok, Updated};
        {error, Reason, Updated} -> {error, Reason, Updated}
    end.

-spec snapshot(map()) -> map().
snapshot(State) -> #{runner => alang_mnemonic_runner:snapshot(maps:get(runner, State)),
    journal_head => maps:get(head_digest, maps:get(journal, State)),
    journal_records => length(maps:get(records, maps:get(journal, State))),
    qualification_digest => maps:get(<<"qualification_digest">>,
        maps:get(qualification, State))}.

submit_cell(State, Cell, Submit) ->
    Runner0 = maps:get(runner, State), Attempt = alang_mnemonic_runner:attempt(Runner0),
    Projection = projection(State, Cell),
    case alang_mnemonic_limits:admit(maps:get(policy, State), Runner0, Projection) of
        ok ->
            {ok, Request, Runner1} = alang_mnemonic_runner:prepare(Runner0,
                maps:get(qualification, State), maps:get(environment, State),
                maps:get(inventory, State), Attempt),
            Intent = #{attempt => Attempt, cell => Cell, request => Request,
                request_digest => alang_fidelity_json:digest(Request)},
            Prepared = State#{runner := Runner1},
            case append_replacement(Prepared, Attempt, Request) of
                {ok, Linked} -> append_intent(Linked, Intent, Request, Submit);
                {error, Reason, Failed} -> {error, Reason, Failed}
            end;
        {error, Reason} -> invalidate(State, Reason)
    end.

append_intent(State, Intent, Request, Submit) ->
    case append(State, trial_intent, Intent) of
                {ok, IntentState} -> submit_intent(IntentState, Request, Submit);
                {error, Reason, Failed} -> {error, Reason, Failed}
    end.

append_replacement(State, primary, _Request) -> {ok, State};
append_replacement(State, replacement, Request) ->
    TrialId = maps:get(<<"trial_id">>, Request),
    case previous_operation(State, TrialId) of
        {ok, Parent} -> append(State, replacement_link, #{
            operation_id => maps:get(<<"operation_id">>, Request),
            parent_operation_id => Parent,
            reason => transport_failure_before_response,
            trial_id => TrialId});
        {error, Reason} -> {error, Reason, State}
    end.

previous_operation(State, TrialId) ->
    Results = [maps:get(result, maps:get(payload, Record)) || Record <-
        lists:reverse(maps:get(records, maps:get(journal, State))),
        maps:get(kind, Record) =:= trial_result,
        maps:get(<<"trial_id">>, maps:get(result, maps:get(payload, Record))) =:= TrialId],
    case Results of
        [Result | _] ->
            case maps:get(<<"provider_state">>, Result) of
                <<"not_submitted">> -> {ok, maps:get(<<"operation_id">>, Result)};
                _ -> {error, replacement_parent_missing}
            end;
        _ -> {error, replacement_parent_missing}
    end.

submit_intent(State, Request, Submit) ->
    Token = maps:get(token, State),
    Result = try Submit(Token, Request) of
        {ok, Value} -> Value;
        {error, SubmitReason} -> uncertain_result(Request, SubmitReason)
    catch Class:CaughtReason -> uncertain_result(Request, {Class, CaughtReason}) end,
    Payload = #{result => Result, result_digest => alang_fidelity_json:digest(Result)},
    case append(State, trial_result, Payload) of
        {ok, ResultState} -> apply_result(ResultState, Result);
        {error, Reason, Failed} -> {error, Reason, Failed}
    end.

apply_result(State, Result) ->
    case alang_mnemonic_runner:record_result(maps:get(runner, State), Result) of
        {ok, Runner} ->
            Updated = State#{runner := Runner},
            case maps:get(<<"provider_state">>, Result) of
                <<"uncertain">> -> invalidate(Updated, uncertain_submission);
                _ -> {ok, Result, Updated}
            end;
        {error, Reason} -> invalidate(State, Reason)
    end.

append(State, Kind, Payload) ->
    case alang_mnemonic_journal:append_file(maps:get(run_root, State),
            maps:get(journal, State), Kind, Payload) of
        {ok, _Record, Journal} -> {ok, State#{journal := Journal}};
        {error, Reason} -> {error, Reason, State}
    end.

invalidate(State, Reason) ->
    Payload = #{reason => unicode:characters_to_binary(io_lib:format("~tp", [Reason]))},
    case append(State, invalid_campaign, Payload) of
        {ok, Updated} -> {error, Reason, Updated#{runner :=
            (maps:get(runner, Updated))#{invalid := true}}};
        {error, JournalReason, Failed} -> {error, {Reason, JournalReason}, Failed}
    end.

projection(State, Cell) ->
    Policy = maps:get(policy, State), Limits = maps:get(<<"per_request_ceilings">>, Policy),
    {ok, Prompt} = alang_mnemonic_protocol:materialize(case_for(State, Cell),
        oracle_for(State, Cell), maps:get(<<"condition">>, Cell),
        maps:get(<<"protocol">>, Cell), maps:get(root, State)),
    #{input_bytes => byte_size(maps:get(<<"bytes">>, Prompt)),
      response_bytes => maps:get(<<"accepted_response_bytes">>, Limits),
      output_tokens => maps:get(<<"max_output_tokens">>, Limits),
      timeout_ms => maps:get(<<"timeout_ms">>, Limits)}.

case_for(State, Cell) ->
    Corpus = decode(filename:join([maps:get(root, State), "assets",
        "token-positive-mnemonic-promotion", "corpus", "confirmatory-corpus-v1.json"])),
    [Case] = [C || C <- maps:get(<<"cases">>, Corpus),
        maps:get(<<"id">>, C) =:= maps:get(<<"case_id">>, Cell)], Case.
oracle_for(State, Cell) -> alang_mnemonic_corpus:oracle(case_for(State, Cell)).

state(Root, RunRoot, Environment, Inventory, Qualification, Token, Policy,
        Runner, Journal) ->
    #{format => alang_mnemonic_live_campaign_v1, root => Root, run_root => RunRoot,
      environment => Environment, inventory => Inventory,
      qualification => Qualification, token => Token, policy => Policy,
      runner => Runner, journal => Journal}.

uncertain_result(Request, Reason) ->
    Diagnostic = unicode:characters_to_binary(io_lib:format("~tp", [Reason])),
    #{<<"format">> => <<"alang-token-positive-provider-result-v1">>,
      <<"operation_id">> => maps:get(<<"operation_id">>, Request),
      <<"trial_id">> => maps:get(<<"trial_id">>, Request),
      <<"model_id">> => maps:get(<<"model_id">>, Request),
      <<"provider_state">> => <<"uncertain">>, <<"response">> => <<>>,
      <<"response_sha256">> => hex(crypto:hash(sha256, <<>>)),
      <<"usage">> => missing, <<"diagnostic">> => Diagnostic,
      <<"latency_ms">> => 0}.

no_records(RunRoot) -> filelib:wildcard(filename:join([RunRoot, "records", "*.etf"])) =:= [].
decode(Path) -> {ok, Value} = checked(alang_fidelity_json:decode_file(Path)), Value.
checked({ok, _} = Result) -> Result;
checked({error, Reason}) -> fail(Reason).
ensure(true, _Reason) -> ok;
ensure(false, Reason) -> fail(Reason).
fail(Reason) -> throw({mnemonic_campaign_error, Reason}).
hex(Bytes) -> alang_fidelity_json:hex(Bytes).
