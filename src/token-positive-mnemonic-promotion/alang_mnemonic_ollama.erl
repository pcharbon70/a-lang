-module(alang_mnemonic_ollama).

-export([decode_response/2, probe/2, request_body/1, submit/2]).

-define(ENDPOINT, <<"http://127.0.0.1:11434">>).

-spec probe(map(), binary()) -> {ok, [map()]} | {error, term()}.
probe(Preauthorization, Endpoint) ->
    case preliminary_token(Preauthorization) andalso Endpoint =:= ?ENDPOINT of
        true ->
            ok = ensure_http_started(),
            Url = binary_to_list(<<Endpoint/binary, "/api/tags">>),
            case httpc:request(get, {Url, []}, [{timeout, 120000}],
                    [{body_format, binary}]) of
                {ok, {{_, 200, _}, _, Body}} -> alang_mnemonic_live_gate:decode_inventory(Body);
                {ok, {{_, Status, _}, _, _}} -> {error, {probe_http_status, Status}};
                {error, Reason} -> {error, {probe_transport, Reason}}
            end;
        false -> {error, probe_not_authorized}
    end.

-spec request_body(map()) -> {ok, binary()} | {error, term()}.
request_body(Request) ->
    try
        Parameters = maps:get(<<"parameters">>, Request),
        Options = Parameters#{<<"seed">> => maps:get(<<"seed">>, Request)},
        Body = #{<<"model">> => maps:get(<<"model_id">>, Request),
            <<"messages">> => [#{<<"role">> => <<"user">>,
                <<"content">> => maps:get(<<"prompt">>, Request)}],
            <<"stream">> => false, <<"options">> => Options},
        alang_fidelity_json:encode_canonical(Body)
    catch error:{badkey, Key} -> {error, {missing_request_field, Key}} end.

-spec submit(map(), map()) -> {ok, map()} | {error, term()}.
submit(Token, Request) ->
    case full_token(Token, Request) of
        false -> {error, submission_not_authorized};
        true ->
            {ok, Body} = request_body(Request), ok = ensure_http_started(),
            Url = binary_to_list(<<?ENDPOINT/binary, "/api/chat">>),
            Headers = [{"accept", "application/json"},
                {"content-type", "application/json"}],
            Timeout = maps:get(<<"timeout_ms">>, maps:get(<<"request_ceilings">>, Token)),
            Started = erlang:monotonic_time(millisecond),
            Reply = httpc:request(post, {Url, Headers, "application/json", Body},
                [{timeout, Timeout}], [{body_format, binary}]),
            Latency = erlang:monotonic_time(millisecond) - Started,
            case Reply of
                {ok, {{_, 200, _}, _, Response}} ->
                    with_latency(decode_response(Request, Response), Latency);
                {ok, {{_, Status, _}, _, _}} -> definitive_failure(Request,
                    <<"http-", (integer_to_binary(Status))/binary>>, Latency);
                {error, {failed_connect, _} = Reason} -> not_submitted(Request,
                    unicode:characters_to_binary(io_lib:format("~tp", [Reason])), Latency);
                {error, Reason} -> uncertain(Request,
                    unicode:characters_to_binary(io_lib:format("~tp", [Reason])), Latency)
            end
    end.

-spec decode_response(map(), binary()) -> {ok, map()} | {error, term()}.
decode_response(Request, Bytes) ->
    try
        {ok, Value} = alang_fidelity_json:decode(Bytes),
        Model = maps:get(<<"model">>, Value),
        true = Model =:= maps:get(<<"model_id">>, Request),
        true = maps:get(<<"done">>, Value),
        Response = maps:get(<<"content">>, maps:get(<<"message">>, Value)),
        Input = maps:get(<<"prompt_eval_count">>, Value),
        Output = maps:get(<<"eval_count">>, Value),
        true = is_binary(Response), true = is_integer(Input) andalso Input >= 0,
        true = is_integer(Output) andalso Output >= 0,
        {ok, result(Request, <<"definitive">>, Response,
            #{<<"estimated">> => false, <<"prompt_tokens">> => Input,
              <<"output_tokens">> => Output, <<"total_tokens">> => Input + Output}, <<>>, 0)}
    catch _:_ -> definitive_failure(Request, <<"malformed-provider-response">>, 0) end.

result(Request, State, Response, Usage, Diagnostic, Latency) ->
    #{<<"format">> => <<"alang-token-positive-provider-result-v1">>,
      <<"operation_id">> => maps:get(<<"operation_id">>, Request),
      <<"trial_id">> => maps:get(<<"trial_id">>, Request),
      <<"model_id">> => maps:get(<<"model_id">>, Request),
      <<"provider_state">> => State, <<"response">> => Response,
      <<"response_sha256">> => hex(crypto:hash(sha256, Response)),
      <<"usage">> => Usage, <<"diagnostic">> => Diagnostic,
      <<"latency_ms">> => Latency}.
definitive_failure(Request, Diagnostic, Latency) ->
    {ok, result(Request, <<"definitive">>, <<>>, missing, Diagnostic, Latency)}.
not_submitted(Request, Diagnostic, Latency) ->
    {ok, result(Request, <<"not_submitted">>, <<>>, missing, Diagnostic, Latency)}.
uncertain(Request, Diagnostic, Latency) ->
    {ok, result(Request, <<"uncertain">>, <<>>, missing, Diagnostic, Latency)}.
with_latency({ok, Result}, Latency) -> {ok, Result#{<<"latency_ms">> := Latency}};
with_latency({error, _} = Error, _Latency) -> Error.

preliminary_token(Token) -> maps:get(<<"authorized">>, Token, false) =:= true andalso
    maps:get(<<"scope">>, Token, undefined) =:= <<"phase-3-registered-runner-only">>.
full_token(Token, Request) -> maps:get(<<"authorized">>, Token, false) =:= true andalso
    maps:get(<<"scope">>, Token, undefined) =:=
        <<"phase-3-exact-profile-submissions-only">> andalso
    maps:get(<<"endpoint">>, Token, undefined) =:= ?ENDPOINT andalso
    lists:any(fun(P) -> maps:get(<<"model_id">>, P) =:= maps:get(<<"model_id">>, Request)
        andalso maps:get(<<"manifest_sha256">>, P) =:=
            maps:get(<<"manifest_sha256">>, Request) end, maps:get(<<"profiles">>, Token, [])).
ensure_http_started() -> case inets:start() of ok -> ok; {error, {already_started, inets}} -> ok end.
hex(Bytes) -> alang_fidelity_json:hex(Bytes).
