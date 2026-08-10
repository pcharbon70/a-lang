-module(alang_fidelity_provider_protocol).

-export([
    cost_microusd/3,
    failure/5,
    profile/1,
    redact/2,
    result_digest/1,
    success/6,
    validate_request/1
]).

-define(MAX_PROMPT_BYTES, 16384).
-define(MAX_OUTPUT_BYTES, 8192).

-spec profile(ornith | mixtral) -> map().
profile(ornith) ->
    #{
        family => ornith,
        provider => <<"Ollama">>,
        api => chat_completions,
        model_id => <<"ornith-1.0">>,
        effort => medium,
        endpoint => <<"http://localhost:11434/api/chat">>,
        model_endpoint => <<"http://localhost:11434/api/tags">>,
        max_output_tokens => 8192,
        accepted_output_bytes => ?MAX_OUTPUT_BYTES
    };
profile(mixtral) ->
    #{
        family => mixtral,
        provider => <<"Ollama">>,
        api => chat_completions,
        model_id => <<"mixtral-8x7b">>,
        effort => medium,
        endpoint => <<"http://localhost:11434/api/chat">>,
        model_endpoint => <<"http://localhost:11434/api/tags">>,
        max_output_tokens => 8192,
        accepted_output_bytes => ?MAX_OUTPUT_BYTES
    }.

-spec validate_request(term()) -> {ok, map()} | {error, term()}.
validate_request(Request) ->
    try
        Keys = [
            attempt_class,
            deadline_ms,
            effort,
            family,
            format,
            max_output_tokens,
            model_id,
            operation_id,
            prompt,
            trial_id
        ],
        ensure(is_map(Request), expected_request_map),
        ensure(lists:sort(maps:keys(Request)) =:= Keys, invalid_request_fields),
        ensure(maps:get(format, Request) =:= alang_fidelity_provider_request_v1, invalid_request_format),
        Family = maps:get(family, Request),
        ensure(lists:member(Family, [ornith, mixtral]), invalid_provider_family),
        Profile = profile(Family),
        ensure(maps:get(model_id, Request) =:= maps:get(model_id, Profile), model_substitution),
        ensure(maps:get(effort, Request) =:= medium, effort_substitution),
        ensure(maps:get(max_output_tokens, Request) =:= 8192, output_token_ceiling_substitution),
        Prompt = maps:get(prompt, Request),
        ensure(is_binary(Prompt) andalso byte_size(Prompt) > 0, invalid_prompt),
        ensure(byte_size(Prompt) =< ?MAX_PROMPT_BYTES, prompt_too_large),
        ensure(valid_hex_id(maps:get(trial_id, Request)), invalid_trial_id),
        ensure(valid_hex_id(maps:get(operation_id, Request)), invalid_operation_id),
        Deadline = maps:get(deadline_ms, Request),
        ensure(is_integer(Deadline) andalso Deadline > 0 andalso Deadline =< 120000, invalid_deadline),
        ensure(
            lists:member(maps:get(attempt_class, Request), [primary, repair, replacement, retry]),
            invalid_attempt_class
        ),
        {ok, Request}
    catch
        throw:{provider_protocol_error, Reason} -> {error, Reason}
    end.

-spec success(map(), binary(), map(), binary(), non_neg_integer(), map()) ->
    {ok, map()} | {error, term()}.
success(Request, Output, Usage, StopReason, LatencyMs, Prices) ->
    case validate_request(Request) of
        {ok, _} ->
            try
                ensure(is_binary(Output), invalid_output),
                ensure(byte_size(Output) =< ?MAX_OUTPUT_BYTES, output_too_large),
                ensure(is_binary(StopReason) andalso byte_size(StopReason) =< 64, invalid_stop_reason),
                ensure(is_integer(LatencyMs) andalso LatencyMs >= 0, invalid_latency),
                InputTokens = usage_value(input_tokens, Usage),
                OutputTokens = usage_value(output_tokens, Usage),
                Family = maps:get(family, Request),
                Cost = cost_microusd(InputTokens, OutputTokens, maps:get(Family, Prices)),
                Result0 = (base_result(Request))#{
                    status => success,
                    submission => definitive,
                    primary_fidelity_eligible => true,
                    output => Output,
                    output_digest => alang_fidelity_json:hex(crypto:hash(sha256, Output)),
                    usage => #{input_tokens => InputTokens, output_tokens => OutputTokens},
                    stop_reason => StopReason,
                    latency_ms => LatencyMs,
                    cost_microusd => Cost,
                    retry_allowed => false,
                    diagnostic => <<>>
                },
                {ok, Result0#{result_digest => result_digest(Result0)}}
            catch
                throw:{provider_protocol_error, Reason} -> {error, Reason}
            end;
        {error, _} = Error -> Error
    end.

-spec failure(map(), atom(), definitive | not_submitted | uncertain, binary(), non_neg_integer()) ->
    {ok, map()} | {error, term()}.
failure(Request, Status, Submission, Diagnostic, LatencyMs) ->
    case validate_request(Request) of
        {ok, _} ->
            try
                Allowed = [
                    budget_exhausted,
                    definitive_refusal,
                    malformed_provider_response,
                    oversized_provider_response,
                    provider_error,
                    rate_limited,
                    redirect_rejected,
                    sidecar_crash,
                    timeout,
                    tls_rejected,
                    transport_failure,
                    truncated,
                    wrong_model_identity
                ],
                ensure(lists:member(Status, Allowed), invalid_failure_status),
                ensure(lists:member(Submission, [definitive, not_submitted, uncertain]), invalid_submission_class),
                ensure(is_binary(Diagnostic) andalso byte_size(Diagnostic) =< 256, invalid_diagnostic),
                ensure(is_integer(LatencyMs) andalso LatencyMs >= 0, invalid_latency),
                RetryAllowed = Submission =:= not_submitted,
                Result0 = (base_result(Request))#{
                    status => Status,
                    submission => Submission,
                    primary_fidelity_eligible => Submission =:= definitive,
                    output => <<>>,
                    output_digest => <<>>,
                    usage => #{input_tokens => 0, output_tokens => 0},
                    stop_reason => <<>>,
                    latency_ms => LatencyMs,
                    cost_microusd => 0,
                    retry_allowed => RetryAllowed,
                    diagnostic => Diagnostic
                },
                {ok, Result0#{result_digest => result_digest(Result0)}}
            catch
                throw:{provider_protocol_error, Reason} -> {error, Reason}
            end;
        {error, _} = Error -> Error
    end.

-spec cost_microusd(non_neg_integer(), non_neg_integer(), map()) -> non_neg_integer().
cost_microusd(InputTokens, OutputTokens, Price)
  when is_integer(InputTokens), InputTokens >= 0,
       is_integer(OutputTokens), OutputTokens >= 0,
       is_map(Price) ->
    InputRate = maps:get(input_microusd_per_million, Price),
    OutputRate = maps:get(output_microusd_per_million, Price),
    true = is_integer(InputRate) andalso InputRate >= 0,
    true = is_integer(OutputRate) andalso OutputRate >= 0,
    ceil_div((InputTokens * InputRate) + (OutputTokens * OutputRate), 1000000).

-spec redact(term(), [binary()]) -> term().
redact(Value, Secrets) when is_binary(Value) ->
    lists:foldl(
        fun
            (Secret, Acc) when is_binary(Secret), byte_size(Secret) > 0 ->
                binary:replace(Acc, Secret, <<"[redacted]">>, [global]);
            (_, Acc) -> Acc
        end,
        Value,
        Secrets
    );
redact(Value, Secrets) when is_map(Value) ->
    maps:from_list([{redact(Key, Secrets), redact(Item, Secrets)} || {Key, Item} <- maps:to_list(Value)]);
redact(Value, Secrets) when is_list(Value) ->
    [redact(Item, Secrets) || Item <- Value];
redact(Value, Secrets) when is_tuple(Value) ->
    list_to_tuple([redact(Item, Secrets) || Item <- tuple_to_list(Value)]);
redact(Value, _Secrets) -> Value.

-spec result_digest(map()) -> binary().
result_digest(Result) ->
    alang_fidelity_json:digest(maps:remove(result_digest, Result)).

base_result(Request) ->
    #{
        format => alang_fidelity_provider_result_v1,
        trial_id => maps:get(trial_id, Request),
        operation_id => maps:get(operation_id, Request),
        attempt_class => maps:get(attempt_class, Request),
        family => maps:get(family, Request),
        model_id => maps:get(model_id, Request)
    }.

usage_value(Key, Usage) ->
    ensure(is_map(Usage), invalid_usage),
    Value = maps:get(Key, Usage, invalid),
    ensure(is_integer(Value) andalso Value >= 0, {invalid_usage, Key}),
    Value.

valid_hex_id(Value) when is_binary(Value), byte_size(Value) =:= 64 ->
    re:run(Value, <<"^[0-9a-f]{64}$">>, [{capture, none}]) =:= match;
valid_hex_id(_) -> false.

ceil_div(0, _Denominator) -> 0;
ceil_div(Numerator, Denominator) -> (Numerator + Denominator - 1) div Denominator.

ensure(true, _Reason) -> ok;
ensure(false, Reason) -> throw({provider_protocol_error, Reason}).
