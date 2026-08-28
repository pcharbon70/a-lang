-module(alang_mnemonic_limits).

-export([admit/3, validate_registered_bounds/1]).

-spec validate_registered_bounds(map()) -> ok | {error, term()}.
validate_registered_bounds(Policy) ->
    try
        Request = maps:get(<<"per_request_ceilings">>, Policy),
        Campaign = maps:get(<<"campaign_ceilings">>, Policy),
        All = maps:get(<<"all_requests">>, Campaign),
        Timeout = maps:get(<<"timeout_ms">>, Request),
        Minutes = maps:get(<<"local_compute_minutes">>, Campaign),
        ensure(All * Timeout =< Minutes * 60000, registered_compute_bound),
        ensure(maps:get(<<"monetary_cost_usd">>, Campaign) =:= 0, monetary_bound), ok
    catch
        error:{badkey, Key} -> {error, {mnemonic_limits_error, {missing_field, Key}}};
        throw:{mnemonic_limits_error, Reason} -> {error, {mnemonic_limits_error, Reason}}
    end.

-spec admit(map(), map(), map()) -> ok | {error, term()}.
admit(Policy, State, Projection) ->
    try
        ok = checked(validate_registered_bounds(Policy)),
        Request = maps:get(<<"per_request_ceilings">>, Policy),
        Campaign = maps:get(<<"campaign_ceilings">>, Policy),
        ensure(maps:get(calls, State) + 1 =< maps:get(<<"all_requests">>, Campaign),
            request_ceiling),
        ensure(maps:get(compute_ms, State) + maps:get(timeout_ms, Projection) =<
            maps:get(<<"local_compute_minutes">>, Campaign) * 60000, compute_ceiling),
        ensure(maps:get(input_bytes, Projection) =<
            maps:get(<<"accepted_input_bytes">>, Request), input_byte_ceiling),
        ensure(maps:get(response_bytes, Projection) =<
            maps:get(<<"accepted_response_bytes">>, Request), response_byte_ceiling),
        ensure(maps:get(output_tokens, Projection) =<
            maps:get(<<"max_output_tokens">>, Request), output_token_ceiling),
        ensure(maps:get(timeout_ms, Projection) =< maps:get(<<"timeout_ms">>, Request),
            time_ceiling), ok
    catch
        error:{badkey, Key} -> {error, {mnemonic_limits_error, {missing_field, Key}}};
        throw:{mnemonic_limits_error, Reason} -> {error, {mnemonic_limits_error, Reason}}
    end.

checked(ok) -> ok;
checked({error, Reason}) -> fail(Reason).
ensure(true, _Reason) -> ok;
ensure(false, Reason) -> fail(Reason).
fail(Reason) -> throw({mnemonic_limits_error, Reason}).
