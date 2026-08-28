-module(alang_mnemonic_runner).

-export([new/4, next/1, prepare/5, record_result/2, replacement/2]).

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
            calls => 0, replacements => #{}, dispositions => #{}, invalid => false}}
    catch throw:{mnemonic_runner_error, Reason} -> {error, {mnemonic_runner_error, Reason}} end.

-spec next(map()) -> {ok, map()} | {done, map()} | {error, term()}.
next(#{invalid := true}) -> {error, invalid_campaign};
next(#{pending := Pending}) when Pending =/= none -> {error, submission_pending};
next(#{cursor := Cursor, cells := Cells} = State) when Cursor >= length(Cells) -> {done, State};
next(#{cursor := Cursor, cells := Cells}) -> {ok, lists:nth(Cursor + 1, Cells)}.

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
        ensure(lists:member(ProviderState,
            [<<"definitive">>, <<"not_submitted">>, <<"uncertain">>]), provider_state),
        CellIndex = maps:get(<<"cell_index">>, Request),
        TrialId = maps:get(<<"trial_id">>, Request),
        case ProviderState of
            <<"definitive">> ->
                {ok, State#{pending := none, cursor := maps:get(cursor, State) + 1,
                    dispositions := (maps:get(dispositions, State))#{CellIndex => definitive}}};
            <<"uncertain">> -> {ok, State#{pending := none, invalid := true,
                dispositions := (maps:get(dispositions, State))#{CellIndex => uncertain}}};
            <<"not_submitted">> ->
                Replacements = maps:get(replacements, State),
                case maps:get(TrialId, Replacements, 0) of
                    0 -> {ok, State#{pending := none,
                        replacements := Replacements#{TrialId => 1}}};
                    _ -> {ok, State#{pending := none, invalid := true,
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
