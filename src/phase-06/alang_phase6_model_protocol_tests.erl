-module(alang_phase6_model_protocol_tests).

-include_lib("eunit/include/eunit.hrl").

canonical_request_is_deterministic_and_closed_test() ->
    Request = request(<<"model-call-1">>, <<"Draft the result">>),
    ?assertEqual(ok, alang_phase6_model_protocol:validate_request(Request)),
    {ok, First} = alang_phase6_model_protocol:canonical_request(Request),
    {ok, Second} = alang_phase6_model_protocol:canonical_request(Request),
    ?assertEqual(First, Second),
    ?assertMatch({ok, <<_:64/binary>>}, alang_phase6_model_protocol:request_digest(Request)),
    Profile = maps:get(profile, Request),
    ?assertEqual(
        {error, invalid_model_profile},
        alang_phase6_model_protocol:validate_request(
            Request#{profile := Profile#{provider_url => <<"https://arbitrary.invalid">>}})
    ).

request_bounds_and_context_order_are_enforced_test() ->
    Request = request(<<"model-call-2">>, <<"Draft">>),
    [First, Second] = maps:get(context, Request),
    {ok, Digest} = alang_phase6_model_protocol:request_digest(Request),
    {ok, ReorderedDigest} = alang_phase6_model_protocol:request_digest(
        Request#{context := [Second, First]}),
    ?assertNotEqual(Digest, ReorderedDigest),
    Profile = maps:get(profile, Request),
    ?assertEqual(
        {error, model_request_too_large},
        alang_phase6_model_protocol:validate_request(Request#{instruction := binary:copy(<<"x">>,
            maps:get(max_input_bytes, Profile))})
    ),
    ?assertEqual(
        {error, invalid_model_context},
        alang_phase6_model_protocol:validate_request(Request#{context := [First, First]})
    ).

success_and_failure_variants_are_typed_test() ->
    Request = request(<<"model-call-3">>, <<"Draft">>),
    Output = <<"# Result\n\nAccepted.\n">>,
    Usage = usage(Request, Output),
    Metadata = metadata(),
    {ok, Success} = alang_phase6_model_protocol:success(
        Request, Output, #{format => markdown_draft_v1, markdown => Output}, Usage, Metadata),
    ?assertEqual(ok, alang_phase6_model_protocol:validate_result(Success, Request)),
    ?assertEqual(
        {error, invalid_model_result},
        alang_phase6_model_protocol:validate_result(
            Success#{provider_metadata := (maps:get(provider_metadata, Success))#{
                provider := <<"must-be-redacted">>
            }},
            Request
        )
    ),
    Statuses = [invalid_syntax, schema_failure, content_policy_denial, timeout,
        provider_error, budget_exhausted, outcome_unknown],
    lists:foreach(fun(Status) ->
        {ok, Failure} = alang_phase6_model_protocol:failure(Request, Status,
            #{code => atom_to_binary(Status), fragment => <<"bounded">>, offset => none},
            usage(Request, <<>>), Metadata),
        ?assertEqual(ok, alang_phase6_model_protocol:validate_result(Failure, Request))
    end, Statuses),
    ?assertEqual(
        {error, invalid_model_result},
        alang_phase6_model_protocol:validate_result(Success#{secret => <<"not-allowed">>}, Request)
    ).

mock_provider_selects_all_offline_fixture_classes_test() ->
    Requests = [
        {success, request(<<"fixture-success">>, <<"success">>)},
        {invalid_syntax, request(<<"fixture-syntax">>, <<"syntax">>)},
        {schema_failure, request(<<"fixture-schema">>, <<"schema">>)},
        {content_policy_denial, request(<<"fixture-policy">>, <<"policy">>)},
        {timeout, request(<<"fixture-timeout">>, <<"timeout">>)},
        {transient, request(<<"fixture-transient">>, <<"transient">>)},
        {permanent, request(<<"fixture-permanent">>, <<"permanent">>)},
        {outcome_unknown, request(<<"fixture-unknown">>, <<"unknown">>)}
    ],
    Fixtures = maps:from_list([begin
        {ok, Digest} = alang_phase6_model_protocol:request_digest(Request),
        Fixture = case Status of
            success -> #{status => success, output => <<"# Result\n\nDeterministic.\n">>};
            invalid_syntax -> #{status => invalid_syntax, fragment => <<"{">>};
            schema_failure -> #{status => schema_failure, fragment => <<"missing-field">>};
            _ -> #{status => Status}
        end,
        {Digest, Fixture}
    end || {Status, Request} <- Requests]),
    {ok, Adapter} = alang_phase6_mock_model:start_link(#{
        profiles => [profile()], fixtures => Fixtures, max_calls => 32}),
    try
        Results = [begin
            {ok, Result} = alang_phase6_mock_model:complete(Adapter, Request, deadline()),
            {Status, maps:get(status, Result), maps:get(retryable, Result, false)}
        end || {Status, Request} <- Requests],
        ?assertEqual([
            {success, success, false},
            {invalid_syntax, invalid_syntax, true},
            {schema_failure, schema_failure, true},
            {content_policy_denial, content_policy_denial, false},
            {timeout, timeout, false},
            {transient, provider_error, true},
            {permanent, provider_error, false},
            {outcome_unknown, outcome_unknown, false}
        ], Results),
        Status = alang_phase6_mock_model:status(Adapter),
        ?assertEqual(disabled, maps:get(network, Status)),
        ?assertEqual(none, maps:get(secrets, Status)),
        ?assertEqual(8, maps:get(calls, Status))
    after
        alang_phase6_mock_model:stop(Adapter)
    end,
    ?assertEqual(
        {error, live_provider_disabled},
        alang_phase6_mock_model:live_complete(#{}, hd([Request || {_Status, Request} <- Requests]),
            deadline())
    ).

request(OperationId, Instruction) ->
    {ok, Request} = alang_phase6_model_protocol:new_request(#{
        operation_id => OperationId,
        profile => profile(),
        context => [
            fragment(<<"goal">>, public, instruction, <<"Write a concise report.">>),
            fragment(<<"source">>, task_local, data_only, <<"Untrusted source material.">>)
        ],
        instruction => Instruction,
        output_schema => #{format => alang_output_schema_v1, id => markdown_draft_v1,
            max_bytes => 4096, required_sections => [<<"Result">>]},
        deadline => deadline(),
        retry_class => repair_only,
        redaction_policy => #{format => alang_redaction_policy_v1, trace_content => digest_only,
            retain_provider_fields => [<<"model">>, <<"request_id">>]},
        provenance => #{format => alang_model_provenance_v1, task_id => <<"task:model/0">>,
            goal_digest => digest(<<"goal">>), parent_call_id => none}
    }),
    Request.

profile() -> #{
    format => alang_model_profile_v1,
    id => <<"mock-deterministic-v1">>,
    provider_class => mock,
    model => <<"fixture-model-v1">>,
    sampling => #{temperature_milli => 0, top_p_milli => 1000},
    max_input_bytes => 16384,
    max_output_bytes => 8192,
    max_tokens => 8192,
    timeout_ms => 2000
}.

fragment(Id, Visibility, Trust, Content) -> #{
    format => alang_context_fragment_v1,
    id => Id,
    visibility => Visibility,
    provenance => digest({Id, Content}),
    trust => Trust,
    content => Content
}.

usage(Request, Output) -> #{
    input_tokens => 10,
    output_tokens => 5,
    input_bytes => byte_size(maps:get(instruction, Request)),
    output_bytes => byte_size(Output)
}.

metadata() -> #{
    provider => <<>>,
    model => <<"fixture-model-v1">>,
    request_id => <<"request-1">>,
    finish_reason => <<>>
}.

deadline() -> erlang:monotonic_time(millisecond) + 5000.

digest(Term) ->
    Binary = crypto:hash(sha256, term_to_binary(Term, [deterministic])),
    << <<(hex_digit(Nibble))>> || <<Nibble:4>> <= Binary >>.

hex_digit(Nibble) when Nibble < 10 -> $0 + Nibble;
hex_digit(Nibble) -> $a + Nibble - 10.
