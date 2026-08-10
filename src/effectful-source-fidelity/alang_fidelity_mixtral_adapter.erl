-module(alang_fidelity_mixtral_adapter).

-export([
    credential_status/0,
    decode_model_probe/1,
    decode_response/4,
    request_body/1,
    send/2
]).

-define(MAX_ENVELOPE_BYTES, 65536).

-spec credential_status() -> present.
credential_status() ->
    present.

-spec request_body(map()) -> {ok, binary()} | {error, term()}.
request_body(Request) ->
    case alang_fidelity_provider_protocol:validate_request(Request) of
        {ok, #{family := mixtral}} ->
            Body = #{
                <<"model">> => <<"mixtral-8x7b">>,
                <<"messages">> => [#{
                    <<"content">> => maps:get(prompt, Request),
                    <<"role">> => <<"user">>
                }],
                <<"stream">> => false,
                <<"options">> => #{
                    <<"num_predict">> => 8192
                }
            },
            {ok, iolist_to_binary(json:format(Body))};
        {ok, _} -> {error, wrong_adapter_family};
        {error, _} = Error -> Error
    end.

-spec send(map(), map()) -> {ok, map()} | {error, term()}.
send(Request, Options) when is_map(Options) ->
    case request_body(Request) of
        {ok, Body} ->
            Profile = alang_fidelity_provider_protocol:profile(mixtral),
            Headers = [
                {<<"accept">>, <<"application/json">>},
                {<<"content-type">>, <<"application/json">>}
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
    end.

-spec decode_response(map(), binary(), non_neg_integer(), map()) ->
    {ok, map()} | {error, term()}.
decode_response(Request, Body, LatencyMs, Prices)
  when is_binary(Body), byte_size(Body) =< ?MAX_ENVELOPE_BYTES ->
    case alang_fidelity_json:decode(Body) of
        {ok, Envelope} when is_map(Envelope) -> decode_envelope(Request, Envelope, LatencyMs, Prices);
        {ok, _} -> alang_fidelity_provider_protocol:failure(
            Request, malformed_provider_response, definitive, <<"non-object-response">>, LatencyMs
        );
        {error, _} -> alang_fidelity_provider_protocol:failure(
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
        {ok, #{<<"models">> := Models}) when is_list(Models) ->
            case lists:any(fun(#{<<"name">> := <<"mixtral-8x7b">>}) -> true;
                              (_) -> false
                           end, Models) of
                true -> {ok, <<"mixtral-8x7b">>};
                false -> {error, {model_substitution, <<"mixtral-8x7b-not-found">>}}
            end;
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
        <<"mixtral-8x7b">> -> decode_done(Request, Envelope, LatencyMs, Prices);
        _ -> alang_fidelity_provider_protocol:failure(
            Request, wrong_model_identity, definitive, <<"model-substitution">>, LatencyMs
        )
    end.

decode_done(Request, #{<<"done">> := false}, LatencyMs, _Prices) ->
    alang_fidelity_provider_protocol:failure(
        Request, truncated, definitive, <<"streaming-not-supported">>, LatencyMs
    );
decode_done(Request, #{<<"done">> := true} = Envelope, LatencyMs, Prices) ->
    case {message_text(maps:get(<<"message">>, Envelope, undefined)),
          usage(maps:get(<<"usage">>, Envelope, undefined))} of
        {{ok, Output}, {ok, Usage}} -> alang_fidelity_provider_protocol:success(
            Request,
            Output,
            Usage,
            <<"done">>,
            LatencyMs,
            Prices
        );
        _ -> alang_fidelity_provider_protocol:failure(
            Request, malformed_provider_response, definitive, <<"invalid-output-shape">>, LatencyMs
        )
    end;
decode_done(Request, _Envelope, LatencyMs, _Prices) ->
    alang_fidelity_provider_protocol:failure(
        Request, malformed_provider_response, definitive, <<"invalid-response-shape">>, LatencyMs
    ).

message_text(#{<<"content">> := Text}) when is_binary(Text) -> {ok, Text};
message_text(_) -> {error, invalid_message}.

usage(#{<<"prompt_tokens">> := Input, <<"completion_tokens">> := Output})
  when is_integer(Input), Input >= 0, is_integer(Output), Output >= 0 ->
    {ok, #{input_tokens => Input, output_tokens => Output}};
usage(_) -> {error, invalid_usage}.

credential(_Options) ->
    {ok, <<>>}.

normalize_transport_class(timeout) -> timeout;
normalize_transport_class(tls_rejected) -> tls_rejected;
normalize_transport_class(oversized_provider_response) -> oversized_provider_response;
normalize_transport_class(sidecar_crash) -> sidecar_crash;
normalize_transport_class(_) -> transport_failure.
