-module(alang_fidelity_provider_tests).

-include_lib("eunit/include/eunit.hrl").

provider_neutral_request_rejects_substitution_test() ->
    Request = request(ornith),
    ?assertMatch({ok, _}, alang_fidelity_provider_protocol:validate_request(Request)),
    ?assertEqual(
        {error, model_substitution},
        alang_fidelity_provider_protocol:validate_request(Request#{model_id := <<"newer-alias">>})
    ),
    ?assertEqual(
        {error, effort_substitution},
        alang_fidelity_provider_protocol:validate_request(Request#{effort := high})
    ).

ornith_body_uses_ollama_format_and_response_is_normalized_test() ->
    Request = request(ornith),
    {ok, Body} = alang_fidelity_ornith_adapter:request_body(Request),
    {ok, Decoded} = alang_fidelity_json:decode(Body),
    ?assertEqual(<<"ornith-1.0">>, maps:get(<<"model">>, Decoded)),
    ?assertEqual(false, maps:get(<<"stream">>, Decoded)),
    Envelope = json:format(#{
        <<"model">> => <<"ornith-1.0">>,
        <<"done">> => true,
        <<"message">> => #{<<"content">> => <<"{}">>},
        <<"usage">> => #{<<"prompt_tokens">> => 10, <<"completion_tokens">> => 2}
    }),
    {ok, Result} = alang_fidelity_ornith_adapter:decode_response(
        Request, iolist_to_binary(Envelope), 7, prices()
    ),
    ?assertEqual(success, maps:get(status, Result)),
    ?assertEqual(<<"{}">>, maps:get(output, Result)),
    ?assertEqual(false, maps:get(retry_allowed, Result)).

mixtral_body_uses_ollama_format_and_rejects_wrong_identity_test() ->
    Request = request(mixtral),
    {ok, Body} = alang_fidelity_mixtral_adapter:request_body(Request),
    {ok, Decoded} = alang_fidelity_json:decode(Body),
    ?assertEqual(<<"mixtral-8x7b">>, maps:get(<<"model">>, Decoded)),
    Envelope = iolist_to_binary(json:format(#{
        <<"model">> => <<"mixtral-other">>,
        <<"done">> => true,
        <<"message">> => #{<<"content">> => <<"{}">>},
        <<"usage">> => #{<<"prompt_tokens">> => 10, <<"completion_tokens">> => 2}
    })),
    {ok, Result} = alang_fidelity_mixtral_adapter:decode_response(Request, Envelope, 3, prices()),
    ?assertEqual(wrong_model_identity, maps:get(status, Result)).

transport_certainty_controls_retry_test() ->
    Request = request(ornith),
    {ok, Retryable} = alang_fidelity_provider_protocol:failure(
        Request, transport_failure, not_submitted, <<"connect-failed">>, 1
    ),
    {ok, Uncertain} = alang_fidelity_provider_protocol:failure(
        Request, timeout, uncertain, <<"deadline">>, 2
    ),
    ?assertEqual(true, maps:get(retry_allowed, Retryable)),
    ?assertEqual(false, maps:get(retry_allowed, Uncertain)),
    ?assertEqual(false, maps:get(primary_fidelity_eligible, Uncertain)).

secrets_are_not_retained_by_adapter_test() ->
    Secret = <<"fixture-ollama-secret">>,
    Transport = fun(_Method, _Url, _Headers, _Body, _Deadline) ->
        {error, timeout, uncertain}
    end,
    Options = #{
        transport => Transport,
        prices => prices()
    },
    {ok, Result} = alang_fidelity_ornith_adapter:send(request(ornith), Options),
    Bytes = term_to_binary(Result, [deterministic]),
    ?assertEqual(nomatch, binary:match(Bytes, Secret)),
    ?assertEqual(timeout, maps:get(status, Result)).

live_gate_requires_profiles_and_confirmation_test() ->
    {ok, Projection} = alang_fidelity_live_gate:project(prices()),
    Digest = maps:get(projection_digest, Projection),
    Context = #{
        allow_live => true,
        credential_status => #{mixtral => present, ornith => present},
        profile_ids => #{mixtral => <<"mixtral-8x7b">>, ornith => <<"ornith-1.0">>},
        confirmed_projection_digest => Digest
    },
    {ok, Token} = alang_fidelity_live_gate:authorize(Context, prices()),
    ?assertMatch({ok, _}, alang_fidelity_live_gate:validate_token(Token)),
    ?assertMatch(
        {error, {live_calls_disabled, _}},
        alang_fidelity_live_gate:authorize(Context#{allow_live := false}, prices())
    ),
    ?assertMatch(
        {error, {confirmation_required, _}},
        alang_fidelity_live_gate:authorize(Context#{confirmed_projection_digest := <<"wrong">>}, prices())
    ).

profile_probes_reject_aliases_test() ->
    ?assertMatch(
        {ok, <<"ornith-1.0">>},
        alang_fidelity_ornith_adapter:decode_model_probe(<<"{\"models\":[{\"name\":\"ornith-1.0\"}]}">>)
    ),
    ?assertMatch(
        {error, {model_substitution, _}},
        alang_fidelity_mixtral_adapter:decode_model_probe(<<"{\"models\":[{\"name\":\"mixtral-other\"}]}">>)
    ).

request(Family) ->
    Profile = alang_fidelity_provider_protocol:profile(Family),
    #{
        format => alang_fidelity_provider_request_v1,
        trial_id => hex_id($a),
        operation_id => hex_id($b),
        family => Family,
        model_id => maps:get(model_id, Profile),
        prompt => <<"Return one JSON object.">>,
        effort => medium,
        max_output_tokens => 8192,
        deadline_ms => 30000,
        attempt_class => primary
    }.

prices() ->
    #{
        ornith => #{
            input_microusd_per_million => 0,
            output_microusd_per_million => 0,
            source_url => <<"http://localhost:11434">>,
            observed_at => <<"2026-08-06T00:00:00Z">>
        },
        mixtral => #{
            input_microusd_per_million => 0,
            output_microusd_per_million => 0,
            source_url => <<"http://localhost:11434">>,
            observed_at => <<"2026-08-06T00:00:00Z">>
        }
    }.

hex_id(Character) -> list_to_binary(lists:duplicate(64, Character)).
