-module(alang_phase3_runtime_fixture).

-export([execute/3]).

execute(<<"task:Fixture.pure/0">>, _Inputs, _Context) ->
    {alang_runtime_v1, complete, 42};
execute(<<"task:Fixture.effect/0">>, _Inputs, Context) ->
    Result = alang_phase3_abi:request_effect(
        Context,
        <<"fixture.increment">>,
        {alang_data_v1, product, {41}},
        {source, 10, 2, 3},
        1000
    ),
    {alang_runtime_v1, complete, Result};
execute(<<"task:Fixture.slow/0">>, _Inputs, Context) ->
    Result = alang_phase3_abi:request_effect(
        Context,
        <<"fixture.slow">>,
        {alang_data_v1, product, {}},
        {source, 20, 3, 4},
        1000
    ),
    {alang_runtime_v1, complete, Result};
execute(_TaskId, _Inputs, _Context) ->
    {alang_runtime_v1, error, <<"unknown-fixture-task">>}.
