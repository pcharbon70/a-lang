-module(alang_mnemonic_replay).

-export([build/2, build_from_records/3, from_records/2, validate/2]).

-spec build_from_records([map()], [map()], file:filename()) ->
    {ok, map()} | {error, term()}.
build_from_records(Records, Cells, Root) ->
    case from_records(Records, Root) of
        {ok, Observations} -> build(Observations, Cells);
        {error, _} = Error -> Error
    end.

-spec from_records([map()], file:filename()) -> {ok, [map()]} | {error, term()}.
from_records(Records, Root) ->
    try
        Intents = [maps:get(payload, R) || R <- Records,
            maps:get(kind, R) =:= trial_intent],
        Results = [maps:get(result, maps:get(payload, R)) || R <- Records,
            maps:get(kind, R) =:= trial_result],
        IntentIds = [maps:get(<<"operation_id">>, maps:get(request, I)) || I <- Intents],
        ResultIds = [maps:get(<<"operation_id">>, R) || R <- Results],
        ensure(unique(IntentIds), duplicate_intent_operation),
        ensure(unique(ResultIds), duplicate_result_operation),
        ensure(lists:all(fun(Id) -> lists:member(Id, IntentIds) end, ResultIds),
            result_without_intent),
        Observations = [observation(Result, Intents, Root) || Result <- Results,
            maps:get(<<"provider_state">>, Result) =:= <<"definitive">>],
        {ok, lists:sort(fun(A, B) -> index(A) < index(B) end, Observations)}
    catch
        error:{badkey, Key} -> {error, {mnemonic_replay_error, {missing_field, Key}}};
        throw:{mnemonic_replay_error, Reason} ->
            {error, {mnemonic_replay_error, Reason}}
    end.

-spec build([map()], [map()]) -> {ok, map()} | {error, term()}.
build(Observations, Cells) ->
    try
        ok = checked(validate(Observations, Cells)),
        Ordered = lists:sort(fun(A, B) -> index(A) < index(B) end, Observations),
        Pairs = pair_all(Ordered),
        Body = #{<<"format">> => <<"alang-token-positive-observation-replay-v1">>,
            <<"scheduled_cells">> => length(Cells),
            <<"definitive_observations">> => length(Ordered),
            <<"observation_digest">> => alang_fidelity_json:digest(Ordered),
            <<"usage_digest">> => alang_fidelity_json:digest(
                [maps:get(<<"usage">>, O) || O <- Ordered]),
            <<"score_digest">> => alang_fidelity_json:digest(
                [maps:get(<<"score">>, O) || O <- Ordered]),
            <<"safety_digest">> => alang_fidelity_json:digest(
                [maps:get(<<"safety">>, O) || O <- Ordered]),
            <<"pairs">> => Pairs,
            <<"candidate_only_safety_failures">> => length([P || P <- Pairs,
                maps:get(<<"candidate_only_safety_failure">>, P)]),
            <<"complete">> => true},
        {ok, Body#{<<"replay_digest">> => alang_fidelity_json:digest(Body)}}
    catch throw:{mnemonic_replay_error, Reason} ->
        {error, {mnemonic_replay_error, Reason}}
    end.

-spec validate([map()], [map()]) -> ok | {error, term()}.
validate(Observations, Cells) ->
    try
        ensure(length(Observations) =:= length(Cells), observation_gap),
        Indices = [index(O) || O <- Observations],
        ensure(length(Indices) =:= length(lists:usort(Indices)), duplicate_observation),
        TrialIds = [maps:get(<<"trial_id">>, maps:get(<<"cell">>, O)) || O <- Observations],
        ensure(length(TrialIds) =:= length(lists:usort(TrialIds)), duplicate_trial),
        Expected = lists:sort([identity(C) || C <- Cells]),
        Actual = lists:sort([identity(maps:get(<<"cell">>, O)) || O <- Observations]),
        ensure(Actual =:= Expected, unscheduled_observation),
        ensure(lists:all(fun(O) -> maps:get(<<"first_response_preserved">>, O, false)
            andalso maps:get(<<"observation_digest">>, O, invalid) =:=
                alang_fidelity_json:digest(maps:remove(<<"observation_digest">>, O)) end,
            Observations), observation_digest_mismatch),
        ok
    catch throw:{mnemonic_replay_error, Reason} -> {error, {mnemonic_replay_error, Reason}} end.

pair_all(Observations) ->
    Keys = lists:usort([pair_key(maps:get(<<"cell">>, O)) || O <- Observations]),
    [begin
        Group = [O || O <- Observations, pair_key(maps:get(<<"cell">>, O)) =:= Key],
        ensure(length(Group) =:= 2, unpaired_observation),
        {ok, Pair} = checked(alang_mnemonic_observation:pair(hd(Group), lists:nth(2, Group))), Pair
    end || Key <- Keys].
pair_key(Cell) -> {maps:get(<<"case_id">>, Cell), maps:get(<<"model_family">>, Cell),
    maps:get(<<"protocol">>, Cell), maps:get(<<"repetition">>, Cell)}.
identity(Cell) -> maps:with([<<"index">>, <<"trial_id">>, <<"case_id">>,
    <<"model_family">>, <<"protocol">>, <<"condition">>, <<"repetition">>], Cell).
index(O) -> maps:get(<<"index">>, maps:get(<<"cell">>, O)).
observation(Result, Intents, Root) ->
    Operation = maps:get(<<"operation_id">>, Result),
    Matches = [I || I <- Intents,
        maps:get(<<"operation_id">>, maps:get(request, I)) =:= Operation],
    ensure(length(Matches) =:= 1, intent_result_pairing),
    Intent = hd(Matches), Cell = maps:get(cell, Intent), Request = maps:get(request, Intent),
    Oracle = oracle(Cell, Root),
    {ok, Observation} = checked(alang_mnemonic_observation:normalize(
        Cell, Request, Result, Oracle, Root)), Observation.
oracle(Cell, Root) ->
    {ok, Corpus} = checked(alang_fidelity_json:decode_file(filename:join([Root,
        "assets", "token-positive-mnemonic-promotion", "corpus",
        "confirmatory-corpus-v1.json"]))),
    [Case] = [C || C <- maps:get(<<"cases">>, Corpus),
        maps:get(<<"id">>, C) =:= maps:get(<<"case_id">>, Cell)],
    alang_mnemonic_corpus:oracle(Case).
unique(Values) -> length(Values) =:= length(lists:usort(Values)).
checked(ok) -> ok;
checked({ok, _} = Result) -> Result;
checked({error, Reason}) -> fail(Reason).
ensure(true, _Reason) -> ok;
ensure(false, Reason) -> fail(Reason).
fail(Reason) -> throw({mnemonic_replay_error, Reason}).
