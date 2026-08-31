-module(alang_mnemonic_runner).

-export([attempt/1, new/4, next/1, prepare/5, record_result/2, replacement/2,
    replay/2, snapshot/1]).

-define(CAMPAIGN, "assets/token-positive-mnemonic-promotion/campaign").
-define(CORPUS, "assets/token-positive-mnemonic-promotion/corpus/confirmatory-corpus-v1.json").

-spec new(file:filename(), map(), map(), [map()]) -> {ok, map()} | {error, term()}.
new(Root, Evidence, Environment, Inventory) ->
    try
        {ok, Token} = checked(alang_mnemonic_live_gate:authorize(
            Evidence, Root, Environment, Inventory)),
        {ok, Schedule} = checked(alang_mnemonic_schedule:materialize(
            filename:join(Root, ?CAMPAIGN))),
        {ok, #{format => alang_mnemonic_runner_v1, root => Root,
            qualification_digest => maps:get(<<"qualification_digest">>, Token),
            schedule_digest => maps:get(<<"schedule_digest">>, Schedule),
            cells => maps:get(<<"cells">>, Schedule), cursor => 0, pending => none,
            calls => 0, compute_ms => 0, replacements => #{}, dispositions => #{},
            invalid => false}}
    catch throw:{mnemonic_runner_error, Reason} -> {error, {mnemonic_runner_error, Reason}} end.

-spec next(map()) -> {ok, map()} | {done, map()} | {error, term()}.
next(#{invalid := true}) -> {error, invalid_campaign};
next(#{pending := Pending}) when Pending =/= none -> {error, submission_pending};
next(#{cursor := Cursor, cells := Cells} = State) when Cursor >= length(Cells) -> {done, State};
next(#{cursor := Cursor, cells := Cells}) -> {ok, lists:nth(Cursor + 1, Cells)}.

-spec attempt(map()) -> primary | replacement | {error, term()}.
attempt(#{pending := none, invalid := false} = State) ->
    case next(State) of
        {ok, Cell} ->
            TrialId = maps:get(<<"trial_id">>, Cell),
            case maps:get(TrialId, maps:get(replacements, State), 0) of
                0 -> primary;
                1 -> replacement;
                _ -> {error, replacement_ceiling}
            end;
        {done, _} -> {error, campaign_complete};
        {error, _} = Error -> Error
    end;
attempt(_) -> {error, invalid_campaign}.

-spec prepare(map(), map(), map(), [map()], primary | replacement) ->
    {ok, map(), map()} | {error, term()}.
prepare(#{pending := none, calls := Calls, invalid := false} = State,
        Evidence, Environment, Inventory, Attempt) when Calls < 3072 ->
    try
        {ok, Cell} = checked(next(State)),
        TrialId = maps:get(<<"trial_id">>, Cell),
        Count = maps:get(TrialId, maps:get(replacements, State), 0),
        ensure((Attempt =:= primary andalso Count =:= 0) orelse
            (Attempt =:= replacement andalso Count =:= 1), invalid_attempt_class),
        Root = maps:get(root, State), {Case, Oracle} = case_oracle(Root, Cell),
        {ok, Prompt} = checked(alang_mnemonic_protocol:materialize(Case, Oracle,
            maps:get(<<"condition">>, Cell), maps:get(<<"protocol">>, Cell), Root)),
        {ok, Request0} = checked(alang_mnemonic_live_gate:validate_submission(
            Cell, Evidence, Root, Environment, Inventory, maps:get(<<"bytes">>, Prompt))),
        Operation = alang_fidelity_json:digest({TrialId, Attempt, Calls}),
        Request = Request0#{<<"operation_id">> => Operation,
            <<"attempt">> => atom_to_binary(Attempt)},
        {ok, Request, State#{pending := Request, calls := Calls + 1}}
    catch throw:{mnemonic_runner_error, Reason} -> {error, {mnemonic_runner_error, Reason}} end;
prepare(#{pending := Pending}, _, _, _, _) when Pending =/= none -> {error, submission_pending};
prepare(#{calls := Calls}, _, _, _, _) when Calls >= 3072 -> {error, request_ceiling};
prepare(_, _, _, _, _) -> {error, invalid_campaign}.

-spec record_result(map(), map()) -> {ok, map()} | {error, term()}.
record_result(#{pending := none}, _) -> {error, no_pending_submission};
record_result(#{pending := Request} = State, Result) ->
    try
        exact(maps:get(<<"operation_id">>, Result), maps:get(<<"operation_id">>, Request),
            operation_id),
        ProviderState = maps:get(<<"provider_state">>, Result),
        Latency = maps:get(<<"latency_ms">>, Result),
        ensure(is_integer(Latency) andalso Latency >= 0, invalid_latency),
        ensure(lists:member(ProviderState,
            [<<"definitive">>, <<"not_submitted">>, <<"uncertain">>]), provider_state),
        CellIndex = maps:get(<<"cell_index">>, Request),
        TrialId = maps:get(<<"trial_id">>, Request),
        case ProviderState of
            <<"definitive">> ->
                {ok, State#{pending := none, cursor := maps:get(cursor, State) + 1,
                    compute_ms := maps:get(compute_ms, State) + Latency,
                    dispositions := (maps:get(dispositions, State))#{CellIndex => definitive}}};
            <<"uncertain">> -> {ok, State#{pending := none, invalid := true,
                compute_ms := maps:get(compute_ms, State) + Latency,
                dispositions := (maps:get(dispositions, State))#{CellIndex => uncertain}}};
            <<"not_submitted">> ->
                Replacements = maps:get(replacements, State),
                case maps:get(TrialId, Replacements, 0) of
                    0 -> {ok, State#{pending := none,
                        compute_ms := maps:get(compute_ms, State) + Latency,
                        replacements := Replacements#{TrialId => 1}}};
                    _ -> {ok, State#{pending := none, invalid := true,
                        compute_ms := maps:get(compute_ms, State) + Latency,
                        dispositions := (maps:get(dispositions, State))#{CellIndex => replacement_failed}}}
                end
        end
    catch
        error:{badkey, Key} -> {error, {mnemonic_runner_error, {missing_field, Key}}};
        throw:{mnemonic_runner_error, Reason} -> {error, {mnemonic_runner_error, Reason}}
    end.

-spec replacement(map(), binary()) -> {ok, map()} | {error, term()}.
replacement(#{pending := Request}, _) when Request =/= none -> {error, submission_pending};
replacement(State, TrialId) ->
    case maps:get(TrialId, maps:get(replacements, State), 0) of
        1 -> {ok, #{trial_id => TrialId, attempt => replacement,
            reason => no_definitive_response}};
        _ -> {error, replacement_not_authorized}
    end.

-spec replay(map(), [map()]) -> {ok, map()} | {error, term()}.
replay(State, Records) -> replay_records(Records, State).

-spec snapshot(map()) -> map().
snapshot(State) -> maps:without([cells, root], State).

replay_records([], State) -> {ok, State};
replay_records([#{kind := trial_intent, payload := Payload} | Rest], State) ->
    try
        Attempt = maps:get(attempt, Payload), Cell = maps:get(cell, Payload),
        Request = maps:get(request, Payload), Calls = maps:get(calls, State),
        {ok, ExpectedCell} = checked(next(State)),
        exact(Cell, ExpectedCell, replay_cell),
        exact(Attempt, attempt(State), replay_attempt),
        TrialId = maps:get(<<"trial_id">>, Cell),
        exact(maps:get(<<"trial_id">>, Request), TrialId, replay_trial),
        exact(maps:get(<<"cell_index">>, Request), maps:get(<<"index">>, Cell),
            replay_index),
        exact(maps:get(<<"operation_id">>, Request),
            alang_fidelity_json:digest({TrialId, Attempt, Calls}), replay_operation),
        replay_records(Rest, State#{pending := Request, calls := Calls + 1})
    catch throw:{mnemonic_runner_error, Reason} ->
        {error, {mnemonic_runner_error, Reason}}
    end;
replay_records([#{kind := trial_result, payload := Payload} | Rest], State) ->
    case record_result(State, maps:get(result, Payload)) of
        {ok, Updated} -> replay_records(Rest, Updated);
        {error, _} = Error -> Error
    end;
replay_records([#{kind := invalid_campaign} | Rest], State) ->
    replay_records(Rest, State#{invalid := true});
replay_records([#{kind := Kind} | Rest], State)
  when Kind =:= replacement_link; Kind =:= campaign_closed ->
    replay_records(Rest, State);
replay_records([_ | _], _State) -> {error, unsupported_journal_record}.

case_oracle(Root, Cell) ->
    Corpus = decode(filename:join(Root, ?CORPUS)),
    Id = maps:get(<<"case_id">>, Cell),
    [Case] = [C || C <- maps:get(<<"cases">>, Corpus), maps:get(<<"id">>, C) =:= Id],
    {Case, alang_mnemonic_corpus:oracle(Case)}.
decode(Path) -> {ok, Value} = checked(alang_fidelity_json:decode_file(Path)), Value.
checked({ok, _} = Result) -> Result;
checked({done, _}) -> fail(schedule_complete);
checked({error, Reason}) -> fail(Reason).
exact(Value, Expected, _Reason) when Value =:= Expected -> ok;
exact(Value, Expected, Reason) -> fail({expected, Reason, Expected, Value}).
ensure(true, _Reason) -> ok;
ensure(false, Reason) -> fail(Reason).
fail(Reason) -> throw({mnemonic_runner_error, Reason}).
