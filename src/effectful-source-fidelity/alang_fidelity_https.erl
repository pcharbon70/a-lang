-module(alang_fidelity_https).

-export([get/4, post/5]).

-define(MAX_RESPONSE_BYTES, 65536).

-spec get(binary(), [{binary(), binary()}], pos_integer(), map()) ->
    {ok, non_neg_integer(), binary(), non_neg_integer()} |
    {error, atom(), not_submitted | uncertain, non_neg_integer()}.
get(Url, Headers, DeadlineMs, Options) ->
    request(get, Url, Headers, <<>>, DeadlineMs, Options).

-spec post(binary(), [{binary(), binary()}], binary(), pos_integer(), map()) ->
    {ok, non_neg_integer(), binary(), non_neg_integer()} |
    {error, atom(), not_submitted | uncertain, non_neg_integer()}.
post(Url, Headers, Body, DeadlineMs, Options) ->
    request(post, Url, Headers, Body, DeadlineMs, Options).

request(Method, Url, Headers, Body, DeadlineMs, Options)
  when is_binary(Url), is_list(Headers), is_binary(Body),
       is_integer(DeadlineMs), DeadlineMs > 0, is_map(Options) ->
    Started = erlang:monotonic_time(millisecond),
    case maps:get(transport, Options, otp_https) of
        otp_https -> otp_request(Method, Url, Headers, Body, DeadlineMs, Started);
        Transport when is_function(Transport, 5) ->
            normalize_fixture_result(Transport(Method, Url, Headers, Body, DeadlineMs), Started)
    end.

otp_request(Method, Url, Headers, Body, DeadlineMs, Started) ->
    try
        {ok, _} = application:ensure_all_started(crypto),
        {ok, _} = application:ensure_all_started(public_key),
        {ok, _} = application:ensure_all_started(ssl),
        {ok, _} = application:ensure_all_started(inets),
        Host = host(Url),
        SslOptions = [
            {verify, verify_peer},
            {cacerts, public_key:cacerts_get()},
            {server_name_indication, Host},
            {customize_hostname_check, [
                {match_fun, public_key:pkix_verify_hostname_match_fun(https)}
            ]}
        ],
        HttpOptions = [
            {timeout, DeadlineMs},
            {connect_timeout, min(DeadlineMs, 10000)},
            {autoredirect, false},
            {ssl, SslOptions}
        ],
        RequestOptions = [{body_format, binary}],
        Request = request_tuple(Method, Url, Headers, Body),
        case httpc:request(Method, Request, HttpOptions, RequestOptions) of
            {ok, {{_Version, Status, _Phrase}, _ResponseHeaders, ResponseBody}}
              when is_binary(ResponseBody), byte_size(ResponseBody) =< ?MAX_RESPONSE_BYTES ->
                {ok, Status, ResponseBody, elapsed(Started)};
            {ok, {{_Version, _Status, _Phrase}, _ResponseHeaders, ResponseBody}}
              when is_binary(ResponseBody) ->
                {error, oversized_provider_response, uncertain, elapsed(Started)};
            {error, Reason} ->
                {Class, Submission} = classify_error(Reason),
                {error, Class, Submission, elapsed(Started)}
        end
    catch
        _Class:_Reason -> {error, sidecar_crash, uncertain, elapsed(Started)}
    end.

normalize_fixture_result({ok, Status, Body}, Started)
  when is_integer(Status), is_binary(Body), byte_size(Body) =< ?MAX_RESPONSE_BYTES ->
    {ok, Status, Body, elapsed(Started)};
normalize_fixture_result({ok, _Status, Body}, Started) when is_binary(Body) ->
    {error, oversized_provider_response, uncertain, elapsed(Started)};
normalize_fixture_result({error, Class, Submission}, Started)
  when is_atom(Class), (Submission =:= not_submitted orelse Submission =:= uncertain) ->
    {error, Class, Submission, elapsed(Started)};
normalize_fixture_result(_Other, Started) ->
    {error, sidecar_crash, uncertain, elapsed(Started)}.

request_tuple(get, Url, Headers, _Body) ->
    {binary_to_list(Url), header_lists(Headers)};
request_tuple(post, Url, Headers, Body) ->
    {binary_to_list(Url), header_lists(Headers), "application/json", Body}.

header_lists(Headers) ->
    [{binary_to_list(Name), binary_to_list(Value)} || {Name, Value} <- Headers].

host(Url) ->
    Parsed = uri_string:parse(binary_to_list(Url)),
    maps:get(host, Parsed).

classify_error({failed_connect, _}) -> {transport_failure, not_submitted};
classify_error({tls_alert, _}) -> {tls_rejected, not_submitted};
classify_error(timeout) -> {timeout, uncertain};
classify_error({timeout, _}) -> {timeout, uncertain};
classify_error(_) -> {transport_failure, uncertain}.

elapsed(Started) ->
    max(0, erlang:monotonic_time(millisecond) - Started).
