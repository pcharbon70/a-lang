-module(alang_fidelity_https_fixture).

-export([
    crashing_transport/1,
    provider_response/3,
    transport/2
]).

-spec transport(openai | anthropic, term()) -> fun((atom(), binary(), list(), binary(), integer()) -> term()).
transport(Family, Result) ->
    fun(Method, Url, Headers, Body, DeadlineMs) ->
        validate_request(Family, Method, Url, Headers, Body, DeadlineMs),
        Result
    end.

-spec crashing_transport(binary()) -> fun((atom(), binary(), list(), binary(), integer()) -> no_return()).
crashing_transport(Secret) ->
    fun(_Method, _Url, _Headers, _Body, _DeadlineMs) ->
        error({scripted_sidecar_crash, Secret})
    end.

-spec provider_response(openai | anthropic, success | partial_usage | wrong_model, binary()) -> binary().
provider_response(openai, Mode, Output) ->
    Model = case Mode of wrong_model -> <<"gpt-substituted">>; _ -> <<"gpt-5.6-terra">> end,
    Usage = case Mode of
        partial_usage -> #{<<"input_tokens">> => 100};
        _ -> #{<<"input_tokens">> => 100, <<"output_tokens">> => 50}
    end,
    iolist_to_binary(json:encode(#{
        <<"model">> => Model,
        <<"status">> => <<"completed">>,
        <<"output">> => [#{
            <<"type">> => <<"message">>,
            <<"content">> => [#{<<"type">> => <<"output_text">>, <<"text">> => Output}]
        }],
        <<"usage">> => Usage
    }));
provider_response(anthropic, Mode, Output) ->
    Model = case Mode of wrong_model -> <<"claude-substituted">>; _ -> <<"claude-sonnet-5">> end,
    Usage = case Mode of
        partial_usage -> #{<<"input_tokens">> => 100};
        _ -> #{<<"input_tokens">> => 100, <<"output_tokens">> => 50}
    end,
    iolist_to_binary(json:encode(#{
        <<"model">> => Model,
        <<"stop_reason">> => <<"end_turn">>,
        <<"content">> => [#{<<"type">> => <<"text">>, <<"text">> => Output}],
        <<"usage">> => Usage
    })).

validate_request(Family, post, Url, Headers, Body, DeadlineMs) ->
    Profile = alang_fidelity_provider_protocol:profile(Family),
    true = Url =:= maps:get(endpoint, Profile),
    true = is_integer(DeadlineMs) andalso DeadlineMs > 0 andalso DeadlineMs =< 120000,
    true = has_header(<<"content-type">>, Headers),
    true = has_authentication(Family, Headers),
    {ok, RequestBody} = alang_fidelity_json:decode(Body),
    true = request_model(Family, RequestBody) =:= maps:get(model_id, Profile),
    ok;
validate_request(_Family, _Method, _Url, _Headers, _Body, _DeadlineMs) ->
    error(fixture_request_mismatch).

has_header(Name, Headers) -> lists:any(fun({Header, _Value}) -> Header =:= Name end, Headers).

has_authentication(openai, Headers) ->
    lists:any(fun
        ({<<"authorization">>, <<"Bearer ", Key/binary>>}) -> byte_size(Key) > 0;
        (_) -> false
    end, Headers);
has_authentication(anthropic, Headers) ->
    lists:any(fun
        ({<<"x-api-key">>, Key}) -> is_binary(Key) andalso byte_size(Key) > 0;
        (_) -> false
    end, Headers).

request_model(openai, Body) -> maps:get(<<"model">>, Body);
request_model(anthropic, Body) -> maps:get(<<"model">>, Body).
