-module(alang_fidelity_https_fixture).

-export([
    crashing_transport/1,
    provider_response/3,
    transport/2
]).

-spec transport(ornith | mixtral, term()) -> fun((atom(), binary(), list(), binary(), integer()) -> term()).
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

-spec provider_response(ornith | mixtral, success | partial_usage | wrong_model, binary()) -> binary().
provider_response(ornith, Mode, Output) ->
    Model = case Mode of wrong_model -> <<"ornith-substituted">>; _ -> <<"ornith-1.0">> end,
    Usage = case Mode of
        partial_usage -> #{<<"prompt_tokens">> => 100};
        _ -> #{<<"prompt_tokens">> => 100, <<"completion_tokens">> => 50}
    end,
    iolist_to_binary(json:encode(#{
        <<"model">> => Model,
        <<"done">> => true,
        <<"message">> => #{<<"content">> => Output},
        <<"usage">> => Usage
    }));
provider_response(mixtral, Mode, Output) ->
    Model = case Mode of wrong_model -> <<"mixtral-substituted">>; _ -> <<"mixtral-8x7b">> end,
    Usage = case Mode of
        partial_usage -> #{<<"prompt_tokens">> => 100};
        _ -> #{<<"prompt_tokens">> => 100, <<"completion_tokens">> => 50}
    end,
    iolist_to_binary(json:encode(#{
        <<"model">> => Model,
        <<"done">> => true,
        <<"message">> => #{<<"content">> => Output},
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

has_authentication(_Family, _Headers) -> true.

request_model(_Family, Body) -> maps:get(<<"model">>, Body).
