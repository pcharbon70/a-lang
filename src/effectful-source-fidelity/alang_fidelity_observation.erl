-module(alang_fidelity_observation).

-export([
    attach_repair/2,
    missing/1,
    normalize/2,
    repair_request/3
]).

-define(MAX_OUTPUT_BYTES, 8192).

-spec normalize(map(), map()) -> {ok, map()} | {error, term()}.
normalize(Cell, Result) when is_map(Cell), is_map(Result) ->
    try
        validate_identity(Cell, Result),
        Attempt = normalize_attempt(Cell, Result),
        {ok, finalize_bundle(bundle(Cell, Attempt, none))}
    catch
        throw:{observation_error, Reason} -> {error, Reason};
        error:{badkey, Key} -> {error, {missing_observation_field, Key}}
    end;
normalize(_, _) -> {error, invalid_observation_input}.

-spec missing(map()) -> {ok, map()} | {error, term()}.
missing(Cell) when is_map(Cell) ->
    try
        Attempt = finalize_attempt(#{
            format => alang_fidelity_attempt_observation_v1,
            attempt_class => primary,
            operation_id => none,
            classification => missing_cell,
            diagnostic_code => missing_cell,
            submission => not_submitted,
            scorable => false,
            valid => false,
            normalized => none,
            canonical_json => <<>>,
            canonical_digest => <<>>,
            provider_result_digest => <<>>,
            usage => #{input_tokens => 0, output_tokens => 0},
            latency_ms => 0,
            cost_microusd => 0
        }),
        {ok, finalize_bundle(bundle(Cell, Attempt, none))}
    catch
        error:{badkey, Key} -> {error, {missing_observation_field, Key}}
    end;
missing(_) -> {error, invalid_cell}.

-spec attach_repair(map(), map()) -> {ok, map()} | {error, term()}.
attach_repair(#{format := alang_fidelity_observation_v1, repair := none} = Observation, Result)
  when is_map(Result) ->
    try
        Primary = maps:get(primary, Observation),
        PrimaryClass = maps:get(classification, Primary),
        ensure(lists:member(PrimaryClass, [malformed_json, schema_invalid]), repair_not_eligible),
        ensure(maps:get(attempt_class, Result, invalid) =:= repair, invalid_repair_attempt_class),
        ensure(
            maps:get(operation_id, Result, invalid) =/= maps:get(operation_id, Primary),
            reused_repair_operation_id
        ),
        Cell = cell_from_observation(Observation),
        validate_identity(Cell, Result),
        Repair0 = normalize_attempt(Cell, Result),
        Repair = case maps:get(classification, Repair0) of
            valid -> Repair0;
            Cause -> finalize_attempt(Repair0#{
                classification := repair_failure,
                diagnostic_code := repair_failure,
                repair_failure_cause => Cause,
                valid := false,
                normalized := none,
                canonical_json := <<>>,
                canonical_digest := <<>>
            })
        end,
        {ok, finalize_bundle(Observation#{repair := Repair})}
    catch
        throw:{observation_error, Reason} -> {error, Reason};
        error:{badkey, Key} -> {error, {missing_observation_field, Key}}
    end;
attach_repair(#{repair := Repair}, _Result) when Repair =/= none -> {error, repair_already_recorded};
attach_repair(_, _) -> {error, invalid_primary_observation}.

-spec repair_request(map(), map(), binary()) -> {ok, map()} | {error, term()}.
repair_request(OriginalRequest, Observation, OperationId) when is_map(OriginalRequest) ->
    try
        Primary = maps:get(primary, Observation),
        Classification = maps:get(classification, Primary),
        ensure(lists:member(Classification, [malformed_json, schema_invalid]), repair_not_eligible),
        ensure(maps:get(trial_id, OriginalRequest) =:= maps:get(trial_id, Observation), trial_identity_mismatch),
        Diagnostic = atom_to_binary(Classification),
        OriginalPrompt = maps:get(prompt, OriginalRequest),
        RepairPrefix = <<
            "The previous output was rejected by deterministic validation as ",
            Diagnostic/binary,
            ". Correct only JSON syntax or schema conformance. Do not change, infer, "
            "or add task semantics. Return only the corrected JSON object.\n\n"
            "--- ORIGINAL IMMUTABLE REQUEST ---\n"
        >>,
        Request = OriginalRequest#{
            attempt_class := repair,
            operation_id := OperationId,
            prompt := <<RepairPrefix/binary, OriginalPrompt/binary>>
        },
        alang_fidelity_provider_protocol:validate_request(Request)
    catch
        throw:{observation_error, Reason} -> {error, Reason};
        error:{badkey, Key} -> {error, {missing_repair_field, Key}}
    end;
repair_request(_, _, _) -> {error, invalid_repair_input}.

normalize_attempt(Cell, Result) ->
    validate_accounting(Result),
    {Classification, Diagnostic, Normalized, Canonical, CanonicalDigest} = classify(Cell, Result),
    finalize_attempt(#{
        format => alang_fidelity_attempt_observation_v1,
        attempt_class => maps:get(attempt_class, Result),
        operation_id => maps:get(operation_id, Result),
        classification => Classification,
        diagnostic_code => Diagnostic,
        submission => maps:get(submission, Result),
        scorable => maps:get(submission, Result) =:= definitive,
        valid => Classification =:= valid,
        normalized => Normalized,
        canonical_json => Canonical,
        canonical_digest => CanonicalDigest,
        provider_result_digest => maps:get(
            result_digest,
            Result,
            alang_fidelity_provider_protocol:result_digest(Result)
        ),
        usage => maps:get(usage, Result),
        latency_ms => maps:get(latency_ms, Result),
        cost_microusd => maps:get(cost_microusd, Result)
    }).

classify(_Cell, #{submission := uncertain}) ->
    empty_classification(uncertain_submission);
classify(_Cell, #{submission := not_submitted}) ->
    empty_classification(transport_failure);
classify(Cell, #{submission := definitive, status := success, output := Output}) ->
    classify_output(Cell, Output);
classify(_Cell, #{submission := definitive, status := definitive_refusal}) ->
    empty_classification(definitive_refusal);
classify(_Cell, #{submission := definitive, status := truncated}) ->
    empty_classification(truncated);
classify(_Cell, #{submission := definitive}) ->
    empty_classification(transport_failure).

classify_output(_Cell, Output) when not is_binary(Output) ->
    empty_classification(malformed_json);
classify_output(_Cell, Output) when byte_size(Output) > ?MAX_OUTPUT_BYTES ->
    empty_classification(truncated);
classify_output(Cell, Output) ->
    case unicode:characters_to_binary(Output, utf8, utf8) of
        Output -> decode_output(Cell, Output);
        _ -> empty_classification(malformed_json)
    end.

decode_output(Cell, Output) ->
    case alang_fidelity_json:decode(Output) of
        {ok, Value} ->
            case alang_fidelity_contract:validate_comprehension(Value) of
                {ok, Valid} ->
                    case maps:get(<<"case_id">>, Valid) =:= maps:get(case_id, Cell) of
                        true ->
                            Normalized = alang_fidelity_contract:normalize(Valid),
                            {ok, Canonical} = alang_fidelity_json:encode_canonical(Normalized),
                            {valid, accepted, Normalized, Canonical,
                                alang_fidelity_json:hex(crypto:hash(sha256, Canonical))};
                        false -> empty_classification(schema_invalid)
                    end;
                {error, _} -> empty_classification(schema_invalid)
            end;
        {error, _} -> empty_classification(malformed_json)
    end.

empty_classification(Classification) -> {Classification, Classification, none, <<>>, <<>>}.

bundle(Cell, Primary, Repair) ->
    #{
        format => alang_fidelity_observation_v1,
        trial_id => maps:get(trial_id, Cell),
        pair_id => maps:get(pair_id, Cell),
        case_id => maps:get(case_id, Cell),
        task_family => maps:get(task_family, Cell),
        model_family => maps:get(model_family, Cell),
        model_id => maps:get(model_id, Cell),
        condition => maps:get(condition, Cell),
        repetition => maps:get(repetition, Cell),
        primary => Primary,
        repair => Repair
    }.

cell_from_observation(Observation) ->
    maps:with([
        trial_id,
        pair_id,
        case_id,
        task_family,
        model_family,
        model_id,
        condition,
        repetition
    ], Observation).

validate_identity(Cell, Result) ->
    ensure(maps:get(trial_id, Result, invalid) =:= maps:get(trial_id, Cell), trial_identity_mismatch),
    ensure(maps:get(family, Result, invalid) =:= maps:get(model_family, Cell), model_family_mismatch),
    ensure(maps:get(model_id, Result, invalid) =:= maps:get(model_id, Cell), model_identity_mismatch),
    ensure(
        lists:member(maps:get(attempt_class, Result, invalid), [primary, retry, repair, replacement]),
        invalid_attempt_class
    ),
    ensure(
        lists:member(maps:get(submission, Result, invalid), [definitive, not_submitted, uncertain]),
        invalid_submission
    ),
    ensure(is_atom(maps:get(status, Result, invalid)), invalid_status),
    ok.

validate_accounting(Result) ->
    Usage = maps:get(usage, Result, invalid),
    ensure(is_map(Usage), invalid_usage),
    ensure(nonnegative(maps:get(input_tokens, Usage, invalid)), invalid_input_tokens),
    ensure(nonnegative(maps:get(output_tokens, Usage, invalid)), invalid_output_tokens),
    ensure(nonnegative(maps:get(latency_ms, Result, invalid)), invalid_latency),
    ensure(nonnegative(maps:get(cost_microusd, Result, invalid)), invalid_cost),
    ok.

finalize_attempt(Attempt0) ->
    Attempt = maps:remove(attempt_digest, Attempt0),
    Attempt#{attempt_digest => alang_fidelity_json:digest(Attempt)}.

finalize_bundle(Bundle0) ->
    Bundle = maps:remove(observation_digest, Bundle0),
    Bundle#{observation_digest => alang_fidelity_json:digest(Bundle)}.

nonnegative(Value) -> is_integer(Value) andalso Value >= 0.

ensure(true, _Reason) -> ok;
ensure(false, Reason) -> throw({observation_error, Reason}).
