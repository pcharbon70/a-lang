-module(alang_mnemonic_phase3_mutation).

-export([run/1]).

-spec run(file:filename()) -> {ok, map()} | {error, term()}.
run(Root) ->
    try
        {Case, Oracle} = fixture(Root),
        {P0, P1} = observations(Case, Oracle, Root),
        Policy = decode(filename:join([Root, "assets", "token-positive-mnemonic-promotion",
            "campaign", "campaign-policy-v1.json"])),
        Profiles = decode(filename:join([Root, "assets", "token-positive-mnemonic-promotion",
            "campaign", "provider-profiles-v1.json"])),
        Results = [
            item(<<"qualification-digest-drift">>, authorization_drift(Root)),
            item(<<"model-manifest-drift">>, inventory_drift(Profiles)),
            item(<<"duplicate-submission">>, is_error(alang_mnemonic_runner:next(
                #{pending => #{request => pending}}))),
            item(<<"ambiguous-transport">>, ambiguous_transport()),
            item(<<"missing-usage">>, is_error(alang_mnemonic_observation:validate_usage(missing))),
            item(<<"estimated-usage">>, is_error(alang_mnemonic_observation:validate_usage(
                (usage(10, 2))#{<<"estimated">> := true}))),
            item(<<"inconsistent-usage">>, is_error(alang_mnemonic_observation:validate_usage(
                (usage(10, 2))#{<<"total_tokens">> := 99}))),
            item(<<"swapped-pairing">>, is_error(alang_mnemonic_observation:pair(P0, P0))),
            item(<<"altered-response">>, altered_response(Case, Oracle, Root)),
            item(<<"score-drift">>, replay_drift(P0, P1, <<"score">>)),
            item(<<"safety-omission">>, replay_drift(P0, P1, <<"safety">>)),
            item(<<"replay-gap">>, is_error(alang_mnemonic_replay:build([P0],
                [maps:get(<<"cell">>, P0), maps:get(<<"cell">>, P1)]))),
            item(<<"input-byte-ceiling">>, limit_excess(Policy, input_bytes)),
            item(<<"response-byte-ceiling">>, limit_excess(Policy, response_bytes)),
            item(<<"output-token-ceiling">>, limit_excess(Policy, output_tokens)),
            item(<<"time-ceiling">>, limit_excess(Policy, timeout_ms)),
            item(<<"request-ceiling">>, request_excess(Policy)),
            item(<<"compute-ceiling">>, compute_excess(Policy)),
            item(<<"replacement-ceiling">>, is_error(alang_mnemonic_runner:replacement(
                #{pending => none, replacements => #{<<"trial">> => 2}}, <<"trial">>)))
        ],
        Names = [N || {N, true} <- Results], Total = length(Results),
        ensure(length(Names) =:= Total, {undetected, [N || {N, false} <- Results]}),
        {ok, #{<<"format">> => <<"alang-token-positive-phase-3-mutation-v1">>,
            <<"detected">> => Total, <<"total">> => Total,
            <<"all_detected">> => true, <<"names">> => Names}}
    catch Class:Reason -> {error, {mnemonic_phase3_mutation_error, Class, Reason}} end.

authorization_drift(Root) ->
    Contract = decode(filename:join([Root, "assets", "token-positive-mnemonic-promotion",
        "phase-02", "contracts", "authorization-v1.json"])),
    is_error(alang_mnemonic_authorization:validate(
        Contract#{<<"qualification_digest">> := zeros()})).
inventory_drift(Profiles) ->
    Inventory = [maps:with([<<"model_id">>, <<"manifest_sha256">>], P)
        || P <- maps:get(<<"profiles">>, Profiles)],
    [First | Rest] = Inventory,
    is_error(alang_mnemonic_live_gate:validate_inventory(Profiles,
        [First#{<<"manifest_sha256">> := zeros()} | Rest])).
ambiguous_transport() ->
    Request = #{<<"operation_id">> => zeros(), <<"cell_index">> => 0,
        <<"trial_id">> => <<"trial">>},
    State = #{pending => Request, dispositions => #{}, cursor => 0,
        replacements => #{}, invalid => false},
    {ok, Mutant} = alang_mnemonic_runner:record_result(State,
        #{<<"operation_id">> => zeros(), <<"provider_state">> => <<"uncertain">>}),
    maps:get(invalid, Mutant).
altered_response(Case, Oracle, Root) ->
    Cell = cell(Case, <<"P0">>, 0, <<"trial-p0">>), Request = request(Cell),
    Response = alang_mnemonic_protocol:oracle_response(<<"comprehension">>, <<"P0">>, Oracle),
    Result = result(Request, Response, usage(10, 2)),
    is_error(alang_mnemonic_observation:normalize(Cell, Request,
        Result#{<<"response_sha256">> := zeros()}, Oracle, Root)).
replay_drift(P0, P1, Key) ->
    Mutant = P0#{Key := #{}}, Cells = [maps:get(<<"cell">>, P0), maps:get(<<"cell">>, P1)],
    is_error(alang_mnemonic_replay:build([Mutant, P1], Cells)).
limit_excess(Policy, Key) ->
    P = projection(), is_error(alang_mnemonic_limits:admit(Policy,
        #{calls => 0, compute_ms => 0}, P#{Key := maps:get(Key, P) + 1})).
request_excess(Policy) -> is_error(alang_mnemonic_limits:admit(Policy,
    #{calls => 3072, compute_ms => 0}, projection())).
compute_excess(Policy) -> is_error(alang_mnemonic_limits:admit(Policy,
    #{calls => 0, compute_ms => 6400 * 60000}, projection())).
projection() -> #{input_bytes => 32768, response_bytes => 8192,
    output_tokens => 8192, timeout_ms => 120000}.

observations(Case, Oracle, Root) ->
    {observation(Case, Oracle, Root, <<"P0">>, 0, <<"trial-p0">>, 100),
     observation(Case, Oracle, Root, <<"P1">>, 1, <<"trial-p1">>, 90)}.
observation(Case, Oracle, Root, Condition, Index, Trial, Input) ->
    Cell = cell(Case, Condition, Index, Trial), Request = request(Cell),
    Response = alang_mnemonic_protocol:oracle_response(<<"comprehension">>, Condition, Oracle),
    {ok, O} = alang_mnemonic_observation:normalize(Cell, Request,
        result(Request, Response, usage(Input, 20)), Oracle, Root), O.
cell(Case, Condition, Index, Trial) -> #{<<"index">> => Index,
    <<"trial_id">> => Trial, <<"case_id">> => maps:get(<<"id">>, Case),
    <<"model_family">> => <<"mixtral">>, <<"protocol">> => <<"comprehension">>,
    <<"condition">> => Condition, <<"repetition">> => 1,
    <<"runtime_family">> => maps:get(<<"runtime_family">>, Case),
    <<"stratum">> => maps:get(<<"stratum">>, Case)}.
request(Cell) -> #{<<"operation_id">> => alang_fidelity_json:digest(Cell),
    <<"trial_id">> => maps:get(<<"trial_id">>, Cell), <<"model_id">> => <<"mixtral:8x7b">>}.
result(Request, Response, Usage) -> #{<<"format">> =>
    <<"alang-token-positive-provider-result-v1">>,
    <<"operation_id">> => maps:get(<<"operation_id">>, Request),
    <<"trial_id">> => maps:get(<<"trial_id">>, Request),
    <<"model_id">> => maps:get(<<"model_id">>, Request),
    <<"provider_state">> => <<"definitive">>, <<"response">> => Response,
    <<"response_sha256">> => hex(crypto:hash(sha256, Response)),
    <<"usage">> => Usage, <<"diagnostic">> => <<>>, <<"latency_ms">> => 1}.
usage(I, O) -> #{<<"estimated">> => false, <<"prompt_tokens">> => I,
    <<"output_tokens">> => O, <<"total_tokens">> => I + O}.
fixture(Root) ->
    C = decode(filename:join([Root, "assets", "token-positive-mnemonic-promotion",
        "corpus", "confirmatory-corpus-v1.json"])), Case = hd(maps:get(<<"cases">>, C)),
    {Case, alang_mnemonic_corpus:oracle(Case)}.
decode(Path) -> {ok, V} = alang_fidelity_json:decode_file(Path), V.
item(Name, Pass) -> {Name, Pass}.
is_error({error, _}) -> true;
is_error(_) -> false.
ensure(true, _Reason) -> ok;
ensure(false, Reason) -> erlang:error(Reason).
zeros() -> <<"0000000000000000000000000000000000000000000000000000000000000000">>.
hex(Bytes) -> alang_fidelity_json:hex(Bytes).
