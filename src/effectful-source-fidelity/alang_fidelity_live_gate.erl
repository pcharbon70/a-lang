-module(alang_fidelity_live_gate).

-export([authorize/2, from_environment/2, project/1, validate_token/1]).

-define(PRIMARY_CALLS, 288).
-define(ALL_CALLS, 576).
-define(COST_CEILING_MICROUSD, 200000000).
-define(TOKENS_PER_CALL_BOUND, 8192).

-spec project(map()) -> {ok, map()} | {error, term()}.
project(Prices) ->
    try
        validate_prices(Prices),
        Costs = maps:from_list([
            {Family, max_family_cost(Family, Prices)} || Family <- [anthropic, openai]
        ]),
        Maximum = lists:max(maps:values(Costs)),
        Projection0 = #{
            format => alang_fidelity_live_projection_v1,
            primary_calls => ?PRIMARY_CALLS,
            all_calls_ceiling => ?ALL_CALLS,
            input_tokens_per_call_bound => ?TOKENS_PER_CALL_BOUND,
            output_tokens_per_call_bound => ?TOKENS_PER_CALL_BOUND,
            maximum_cost_by_single_family_microusd => Costs,
            maximum_campaign_cost_microusd => Maximum,
            cost_ceiling_microusd => ?COST_CEILING_MICROUSD,
            price_provenance => maps:map(fun(_Family, Price) ->
                maps:with([observed_at, source_url], Price)
            end, Prices)
        },
        ensure(Maximum =< ?COST_CEILING_MICROUSD, projected_cost_exceeds_ceiling),
        {ok, Projection0#{projection_digest => alang_fidelity_json:digest(Projection0)}}
    catch
        throw:{live_gate_error, Reason} -> {error, Reason}
    end.

-spec authorize(map(), map()) -> {ok, map()} | {error, term()}.
authorize(Context, Prices) when is_map(Context) ->
    case project(Prices) of
        {ok, Projection} ->
            try
                ensure(maps:get(allow_live, Context, false) =:= true, live_calls_disabled),
                Credentials = maps:get(credential_status, Context, #{}),
                ensure(maps:get(openai, Credentials, absent) =:= present, missing_openai_credential),
                ensure(maps:get(anthropic, Credentials, absent) =:= present, missing_anthropic_credential),
                Profiles = maps:get(profile_ids, Context, #{}),
                ensure(maps:get(openai, Profiles, undefined) =:= <<"gpt-5.6-terra">>, openai_profile_unavailable),
                ensure(maps:get(anthropic, Profiles, undefined) =:= <<"claude-sonnet-5">>, anthropic_profile_unavailable),
                Expected = maps:get(projection_digest, Projection),
                ensure(maps:get(confirmed_projection_digest, Context, undefined) =:= Expected, confirmation_required),
                Token0 = #{
                    format => alang_fidelity_live_authorization_v1,
                    projection_digest => Expected,
                    model_ids => Profiles,
                    primary_call_ceiling => ?PRIMARY_CALLS,
                    all_call_ceiling => ?ALL_CALLS,
                    cost_ceiling_microusd => ?COST_CEILING_MICROUSD,
                    prices => Prices,
                    authorized => true
                },
                {ok, Token0#{authorization_digest => alang_fidelity_json:digest(Token0)}}
            catch
                throw:{live_gate_error, Reason} -> {error, {Reason, Projection}}
            end;
        {error, _} = Error -> Error
    end.

-spec from_environment(map(), binary()) -> {ok, map()} | {error, term()}.
from_environment(Prices, ConfirmationDigest) ->
    Context = #{
        allow_live => os:getenv("ALANG_ALLOW_LIVE_MODEL_CALLS") =:= "1",
        confirmed_projection_digest => ConfirmationDigest,
        credential_status => #{
            anthropic => alang_fidelity_anthropic_adapter:credential_status(),
            openai => alang_fidelity_openai_adapter:credential_status()
        },
        profile_ids => #{
            anthropic => <<"claude-sonnet-5">>,
            openai => <<"gpt-5.6-terra">>
        }
    },
    authorize(Context, Prices).

-spec validate_token(term()) -> {ok, map()} | {error, term()}.
validate_token(Token) when is_map(Token) ->
    Digest = maps:get(authorization_digest, Token, undefined),
    Unsigned = maps:remove(authorization_digest, Token),
    case maps:get(format, Token, undefined) =:= alang_fidelity_live_authorization_v1
        andalso maps:get(authorized, Token, false) =:= true
        andalso Digest =:= alang_fidelity_json:digest(Unsigned) of
        true -> {ok, Token};
        false -> {error, invalid_live_authorization}
    end;
validate_token(_) -> {error, invalid_live_authorization}.

max_family_cost(Family, Prices) ->
    Price = maps:get(Family, Prices),
    alang_fidelity_provider_protocol:cost_microusd(
        ?ALL_CALLS * ?TOKENS_PER_CALL_BOUND,
        ?ALL_CALLS * ?TOKENS_PER_CALL_BOUND,
        Price
    ).

validate_prices(Prices) ->
    ensure(is_map(Prices), invalid_prices),
    ensure(lists:sort(maps:keys(Prices)) =:= [anthropic, openai], invalid_price_families),
    lists:foreach(fun(Family) -> validate_price(maps:get(Family, Prices)) end, [anthropic, openai]).

validate_price(Price) ->
    Keys = [input_microusd_per_million, observed_at, output_microusd_per_million, source_url],
    ensure(is_map(Price) andalso lists:sort(maps:keys(Price)) =:= Keys, invalid_price_fields),
    lists:foreach(fun(Key) ->
        Value = maps:get(Key, Price),
        ensure(is_integer(Value) andalso Value >= 0, {invalid_price, Key})
    end, [input_microusd_per_million, output_microusd_per_million]),
    ensure(is_binary(maps:get(source_url, Price)), invalid_price_source),
    ensure(is_binary(maps:get(observed_at, Price)), invalid_price_time).

ensure(true, _Reason) -> ok;
ensure(false, Reason) -> throw({live_gate_error, Reason}).
