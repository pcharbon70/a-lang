-module(alang_fidelity_provider_tests).

-include_lib("eunit/include/eunit.hrl").

provider_neutral_request_rejects_substitution_test() ->
    Request = request(openai),
    ?assertMatch({ok, _}, alang_fidelity_provider_protocol:validate_request(Request)),
    ?assertEqual(
        {error, model_substitution},
        alang_fidelity_provider_protocol:validate_request(Request#{model_id := <<"newer-alias">>})
    ),
    ?assertEqual(
        {error, effort_substitution},
        alang_fidelity_provider_protocol:validate_request(Request#{effort := high})
    ).

openai_body_is_text_only_and_response_is_normalized_test() ->
    Request = request(openai),
    {ok, Body} = alang_fidelity_openai_adapter:request_body(Request),
    {ok, Decoded} = alang_fidelity_json:decode(Body),
    ?assertEqual([], maps:get(<<"tools">>, Decoded)),
    ?assertEqual(<<"none">>, maps:get(<<"tool_choice">>, Decoded)),
    ?assertEqual(#{<<"format">> => #{<<"type">> => <<"text">>}}, maps:get(<<"text">>, Decoded)),
    Envelope = json:format(#{
        <<"model">> => <<"gpt-5.6-terra">>,
        <<"status">> => <<"completed">>,
        <<"output">> => [#{
            <<"type">> => <<"message">>,
            <<"content">> => [#{<<"type">> => <<"output_text">>, <<"text">> => <<"{}">>}]
        }],
        <<"usage">> => #{<<"input_tokens">> => 10, <<"output_tokens">> => 2}
    }),
    {ok, Result} = alang_fidelity_openai_adapter:decode_response(
        Request, iolist_to_binary(Envelope), 7, prices()
    ),
    ?assertEqual(success, maps:get(status, Result)),
    ?assertEqual(<<"{}">>, maps:get(output, Result)),
    ?assertEqual(false, maps:get(retry_allowed, Result)).

anthropic_body_uses_output_config_and_rejects_wrong_identity_test() ->
    Request = request(anthropic),
    {ok, Body} = alang_fidelity_anthropic_adapter:request_body(Request),
    {ok, Decoded} = alang_fidelity_json:decode(Body),
    ?assertEqual(#{<<"effort">> => <<"medium">>}, maps:get(<<"output_config">>, Decoded)),
    Envelope = iolist_to_binary(json:format(#{
        <<"model">> => <<"claude-sonnet-6">>,
        <<"stop_reason">> => <<"end_turn">>,
        <<"content">> => [#{<<"type">> => <<"text">>, <<"text">> => <<"{}">>}],
        <<"usage">> => #{<<"input_tokens">> => 10, <<"output_tokens">> => 2}
    })),
    {ok, Result} = alang_fidelity_anthropic_adapter:decode_response(Request, Envelope, 3, prices()),
    ?assertEqual(wrong_model_identity, maps:get(status, Result)).

transport_certainty_controls_retry_test() ->
    Request = request(openai),
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
    Secret = <<"fixture-openai-secret">>,
    Transport = fun(_Method, _Url, Headers, _Body, _Deadline) ->
        ?assert(lists:any(fun({_Name, Value}) -> binary:match(Value, Secret) =/= nomatch end, Headers)),
        {error, timeout, uncertain}
    end,
    Options = #{
        credential_source => fun() -> Secret end,
        transport => Transport,
        prices => prices()
    },
    {ok, Result} = alang_fidelity_openai_adapter:send(request(openai), Options),
    Bytes = term_to_binary(Result, [deterministic]),
    ?assertEqual(nomatch, binary:match(Bytes, Secret)),
    ?assertEqual(timeout, maps:get(status, Result)).

live_gate_requires_opt_in_credentials_profiles_and_confirmation_test() ->
    {ok, Projection} = alang_fidelity_live_gate:project(prices()),
    Digest = maps:get(projection_digest, Projection),
    Context = #{
        allow_live => true,
        credential_status => #{anthropic => present, openai => present},
        profile_ids => #{anthropic => <<"claude-sonnet-5">>, openai => <<"gpt-5.6-terra">>},
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
    ?assertEqual(
        {ok, <<"gpt-5.6-terra">>},
        alang_fidelity_openai_adapter:decode_model_probe(<<"{\"id\":\"gpt-5.6-terra\"}">>)
    ),
    ?assertEqual(
        {error, {model_substitution, <<"claude-sonnet-latest">>}},
        alang_fidelity_anthropic_adapter:decode_model_probe(
            <<"{\"id\":\"claude-sonnet-latest\"}">>
        )
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
        openai => #{
            input_microusd_per_million => 1000000,
            output_microusd_per_million => 4000000,
            source_url => <<"https://openai.com/api/pricing/">>,
            observed_at => <<"2026-08-06T00:00:00Z">>
        },
        anthropic => #{
            input_microusd_per_million => 1000000,
            output_microusd_per_million => 4000000,
            source_url => <<"https://platform.claude.com/docs/en/about-claude/pricing">>,
            observed_at => <<"2026-08-06T00:00:00Z">>
        }
    }.

hex_id(Character) -> list_to_binary(lists:duplicate(64, Character)).
