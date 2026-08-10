-module(alang_fidelity_adapter_fault_tests).

-include_lib("eunit/include/eunit.hrl").

-define(BASE, "assets/effectful-source-fidelity").
-define(SECRET, <<"ALANG_SECTION_5_4_SECRET">>).

both_adapters_use_the_scripted_https_boundary_without_retaining_secrets_test() ->
    lists:foreach(fun(Family) ->
        Cell = cell(Family),
        Request = request(Cell),
        Body = alang_fidelity_https_fixture:provider_response(
            Family, success, <<"{\"fixture\":true}">>
        ),
        {ok, Result} = send(Family, Request, {ok, 200, Body}),
        ?assertEqual(success, maps:get(status, Result)),
        ?assertEqual(maps:get(model_id, Cell), maps:get(model_id, Result)),
        ?assertEqual(nomatch, binary:match(
            term_to_binary(Result, [deterministic]), ?SECRET
        ))
    end, [mixtral, ornith]).

transport_identity_and_bound_failures_are_closed_test() ->
    OrnithCell = cell(ornith),
    MixtralCell = cell(mixtral),
    Cases = [
        {ornith, OrnithCell, {error, tls_rejected, not_submitted}, tls_rejected, not_submitted},
        {mixtral, MixtralCell, {ok, 302, <<"redirect">>}, redirect_rejected, definitive},
        {ornith, OrnithCell, {error, timeout, not_submitted}, timeout, not_submitted},
        {mixtral, MixtralCell, {error, timeout, uncertain}, timeout, uncertain},
        {ornith, OrnithCell, {ok, 429, <<"rate">>}, rate_limited, definitive},
        {mixtral, MixtralCell, {ok, 200, <<"not-json">>}, malformed_provider_response, definitive},
        {ornith, OrnithCell, {ok, 200, binary:copy(<<"x">>, 65537)},
            oversized_provider_response, uncertain}
    ],
    lists:foreach(fun({Family, Cell, FixtureResult, Status, Submission}) ->
        {ok, Result} = send(Family, request(Cell), FixtureResult),
        ?assertEqual(Status, maps:get(status, Result)),
        ?assertEqual(Submission, maps:get(submission, Result))
    end, Cases),
    {ok, WrongOrnith} = send(ornith, request(OrnithCell), {ok, 200,
        alang_fidelity_https_fixture:provider_response(ornith, wrong_model, <<"{}">>)}),
    {ok, WrongMixtral} = send(mixtral, request(MixtralCell), {ok, 200,
        alang_fidelity_https_fixture:provider_response(mixtral, wrong_model, <<"{}">>)}),
    ?assertEqual(wrong_model_identity, maps:get(status, WrongOrnith)),
    ?assertEqual(wrong_model_identity, maps:get(status, WrongMixtral)),
    {ok, PartialUsage} = send(mixtral, request(MixtralCell), {ok, 200,
        alang_fidelity_https_fixture:provider_response(mixtral, partial_usage, <<"{}">>)}),
    ?assertEqual(malformed_provider_response, maps:get(status, PartialUsage)).

scripted_sidecar_crash_and_secret_bearing_error_fail_closed_test() ->
    Cell = cell(ornith),
    Options = (options(ornith))#{
        transport => alang_fidelity_https_fixture:crashing_transport(?SECRET)
    },
    {ok, Result} = alang_fidelity_ornith_adapter:send(request(Cell), Options),
    ?assertEqual(sidecar_crash, maps:get(status, Result)),
    ?assertEqual(uncertain, maps:get(submission, Result)),
    ?assertEqual(nomatch, binary:match(term_to_binary(Result, [deterministic]), ?SECRET)),
    {ok, WeirdResult} = send(ornith, request(Cell), {secret_bearing_error, ?SECRET}),
    ?assertEqual(sidecar_crash, maps:get(status, WeirdResult)),
    ?assertEqual(nomatch, binary:match(
        term_to_binary(WeirdResult, [deterministic]), ?SECRET
    )).

call_cost_and_projection_ceilings_fail_closed_test() ->
    {ok, Schedule} = alang_fidelity_campaign:materialize(?BASE),
    {ok, Runner0} = alang_fidelity_campaign_runner:new(Schedule),
    ?assertEqual(
        {error, call_ceiling_exhausted},
        alang_fidelity_campaign_runner:intent(Runner0#{calls := 576}, primary)
    ),
    {ok, Intent, Runner1} = alang_fidelity_campaign_runner:intent(Runner0, primary),
    CostResult = #{
        trial_id => maps:get(trial_id, Intent),
        operation_id => maps:get(operation_id, Intent),
        status => valid,
        submission => definitive,
        cost_microusd => 200000001,
        usage => #{input_tokens => 1, output_tokens => 1}
    },
    ?assertEqual(
        {error, cost_ceiling_exhausted},
        alang_fidelity_campaign_runner:record_result(Runner1, CostResult)
    ),
    Expensive = #{
        mixtral => price(30000000, 30000000),
        ornith => price(30000000, 30000000)
    },
    ?assertEqual(
        {error, projected_cost_exceeds_ceiling},
        alang_fidelity_live_gate:project(Expensive)
    ).

send(Family, Request, FixtureResult) ->
    Options = (options(Family))#{
        transport => alang_fidelity_https_fixture:transport(Family, FixtureResult)
    },
    case Family of
        ornith -> alang_fidelity_ornith_adapter:send(Request, Options);
        mixtral -> alang_fidelity_mixtral_adapter:send(Request, Options)
    end.

options(_Family) -> #{
    prices => #{
        mixtral => #{input_microusd_per_million => 0,
            output_microusd_per_million => 0},
        ornith => #{input_microusd_per_million => 0,
            output_microusd_per_million => 0}
    }
}.

request(Cell) -> #{
    format => alang_fidelity_provider_request_v1,
    trial_id => maps:get(trial_id, Cell),
    operation_id => alang_fidelity_json:digest({fixture, maps:get(trial_id, Cell)}),
    attempt_class => primary,
    family => maps:get(model_family, Cell),
    model_id => maps:get(model_id, Cell),
    effort => medium,
    max_output_tokens => 8192,
    prompt => maps:get(request, Cell),
    deadline_ms => 120000
}.

cell(Family) ->
    {ok, Schedule} = alang_fidelity_campaign:materialize(?BASE),
    hd([Cell || Cell <- maps:get(cells, Schedule), maps:get(model_family, Cell) =:= Family]).

price(Input, Output) -> #{
    input_microusd_per_million => Input,
    output_microusd_per_million => Output,
    observed_at => <<"2026-08-06">>,
    source_url => <<"https://example.invalid/offline-fixture">>
}.
