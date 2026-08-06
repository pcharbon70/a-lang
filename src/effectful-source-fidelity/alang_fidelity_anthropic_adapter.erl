-module(alang_fidelity_anthropic_adapter).

-export([
    credential_status/0,
    decode_model_probe/1,
    decode_response/4,
    request_body/1,
    send/2
]).

-define(MAX_ENVELOPE_BYTES, 65536).

-spec credential_status() -> present | absent.
credential_status() ->
    case os:getenv("ALANG_ANTHROPIC_API_KEY") of
        false -> absent;
        [] -> absent;
        _ -> present
    end.

-spec request_body(map()) -> {ok, binary()} | {error, term()}.
request_body(Request) ->
    case alang_fidelity_provider_protocol:validate_request(Request) of
        {ok, #{family := anthropic}} ->
            Body = #{
                <<"max_tokens">> => 8192,
                <<"messages">> => [#{
                    <<"content">> => maps:get(prompt, Request),
                    <<"role">> => <<"user">>
                }],
                <<"model">> => <<"claude-sonnet-5">>,
                <<"output_config">> => #{<<"effort">> => <<"medium">>}
            },
            {ok, iolist_to_binary(json:format(Body))};
        {ok, _} -> {error, wrong_adapter_family};
        {error, _} = Error -> Error
    end.

-spec send(map(), map()) -> {ok, map()} | {error, term()}.
send(Request, Options) when is_map(Options) ->
    case credential(Options) of
        {ok, Key} ->
            case request_body(Request) of
                {ok, Body} ->
                    Profile = alang_fidelity_provider_protocol:profile(anthropic),
                    Headers = [
                        {<<"accept">>, <<"application/json">>},
                        {<<"anthropic-version">>, <<"2023-06-01">>},
                        {<<"content-type">>, <<"application/json">>},
                        {<<"x-api-key">>, Key}
                    ],
                    Result = alang_fidelity_https:post(
                        maps:get(endpoint, Profile),
                        Headers,
                        Body,
                        maps:get(deadline_ms, Request),
                        Options
                    ),
                    handle_transport(Result, Request, Options);
                {error, _} = Error -> Error
            end;
        {error, _} = Error -> Error
    end.

-spec decode_response(map(), binary(), non_neg_integer(), map()) ->
    {ok, map()} | {error, term()}.
decode_response(Request, Body, LatencyMs, Prices)
  when is_binary(Body), byte_size(Body) =< ?MAX_ENVELOPE_BYTES ->
    case alang_fidelity_json:decode(Body) of
        {ok, Envelope} when is_map(Envelope) -> decode_envelope(Request, Envelope, LatencyMs, Prices);
        _ -> alang_fidelity_provider_protocol:failure(
            Request, malformed_provider_response, definitive, <<"invalid-provider-json">>, LatencyMs
        )
    end;
decode_response(Request, _Body, LatencyMs, _Prices) ->
    alang_fidelity_provider_protocol:failure(
        Request, oversized_provider_response, definitive, <<"provider-envelope-too-large">>, LatencyMs
    ).

-spec decode_model_probe(binary()) -> {ok, binary()} | {error, term()}.
decode_model_probe(Body) ->
    case alang_fidelity_json:decode(Body) of
        {ok, #{<<"id">> := <<"claude-sonnet-5">>}} -> {ok, <<"claude-sonnet-5">>};
        {ok, #{<<"id">> := Other}} -> {error, {model_substitution, Other}};
        _ -> {error, invalid_model_probe}
    end.

handle_transport({ok, 200, Body, LatencyMs}, Request, Options) ->
    decode_response(Request, Body, LatencyMs, maps:get(prices, Options));
handle_transport({ok, Status, _Body, LatencyMs}, Request, _Options)
  when Status >= 300, Status < 400 ->
    alang_fidelity_provider_protocol:failure(
        Request, redirect_rejected, definitive, <<"redirect-rejected">>, LatencyMs
    );
handle_transport({ok, 429, _Body, LatencyMs}, Request, _Options) ->
    alang_fidelity_provider_protocol:failure(
        Request, rate_limited, definitive, <<"provider-rate-limit">>, LatencyMs
    );
handle_transport({ok, _Status, _Body, LatencyMs}, Request, _Options) ->
    alang_fidelity_provider_protocol:failure(
        Request, provider_error, definitive, <<"provider-http-error">>, LatencyMs
    );
handle_transport({error, Class, Submission, LatencyMs}, Request, _Options) ->
    alang_fidelity_provider_protocol:failure(
        Request, normalize_transport_class(Class), Submission, atom_to_binary(Class), LatencyMs
    ).

decode_envelope(Request, Envelope, LatencyMs, Prices) ->
    case maps:get(<<"model">>, Envelope, undefined) of
        <<"claude-sonnet-5">> -> decode_stop(Request, Envelope, LatencyMs, Prices);
        _ -> alang_fidelity_provider_protocol:failure(
            Request, wrong_model_identity, definitive, <<"model-substitution">>, LatencyMs
        )
    end.

decode_stop(Request, #{<<"stop_reason">> := <<"max_tokens">>}, LatencyMs, _Prices) ->
    alang_fidelity_provider_protocol:failure(
        Request, truncated, definitive, <<"max-tokens">>, LatencyMs
    );
decode_stop(Request, #{<<"stop_reason">> := <<"refusal">>}, LatencyMs, _Prices) ->
    alang_fidelity_provider_protocol:failure(
        Request, definitive_refusal, definitive, <<"provider-refusal">>, LatencyMs
    );
decode_stop(Request, Envelope, LatencyMs, Prices) ->
    case {content_text(maps:get(<<"content">>, Envelope, [])), usage(maps:get(<<"usage">>, Envelope, undefined))} of
        {{ok, Output}, {ok, Usage}} -> alang_fidelity_provider_protocol:success(
            Request,
            Output,
            Usage,
            maps:get(<<"stop_reason">>, Envelope, <<"unknown">>),
            LatencyMs,
            Prices
        );
        _ -> alang_fidelity_provider_protocol:failure(
            Request, malformed_provider_response, definitive, <<"invalid-output-shape">>, LatencyMs
        )
    end.

content_text(Content) when is_list(Content), Content =/= [] ->
    Parts = [maps:get(<<"text">>, Part, invalid) || Part <- Content,
        maps:get(<<"type">>, Part, invalid) =:= <<"text">>],
    case Parts =/= [] andalso length(Parts) =:= length(Content)
        andalso lists:all(fun is_binary/1, Parts) of
        true -> {ok, iolist_to_binary(Parts)};
        false -> {error, invalid_content}
    end;
content_text(_) -> {error, invalid_content}.

usage(#{<<"input_tokens">> := Input, <<"output_tokens">> := Output})
  when is_integer(Input), Input >= 0, is_integer(Output), Output >= 0 ->
    {ok, #{input_tokens => Input, output_tokens => Output}};
usage(_) -> {error, invalid_usage}.

credential(Options) ->
    case maps:get(credential_source, Options, environment) of
        environment ->
            case os:getenv("ALANG_ANTHROPIC_API_KEY") of
                false -> {error, missing_anthropic_credential};
                [] -> {error, missing_anthropic_credential};
                Value -> {ok, list_to_binary(Value)}
            end;
        Source when is_function(Source, 0) ->
            case Source() of
                Value when is_binary(Value), byte_size(Value) > 0 -> {ok, Value};
                _ -> {error, missing_anthropic_credential}
            end
    end.

normalize_transport_class(timeout) -> timeout;
normalize_transport_class(tls_rejected) -> tls_rejected;
normalize_transport_class(oversized_provider_response) -> oversized_provider_response;
normalize_transport_class(sidecar_crash) -> sidecar_crash;
normalize_transport_class(_) -> transport_failure.
