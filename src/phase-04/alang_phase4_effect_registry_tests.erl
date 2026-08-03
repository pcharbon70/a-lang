-module(alang_phase4_effect_registry_tests).

-include_lib("eunit/include/eunit.hrl").

closed_views_are_derived_from_one_registry_test() ->
    Operations = alang_phase4_effect_registry:operations(),
    Views = alang_phase4_effect_registry:views(),
    ?assertEqual([<<"model.complete">>, <<"workspace.write">>], Operations),
    ?assertEqual(Operations, [maps:get(id, Entry) || Entry <- maps:get(compiler, Views)]),
    ?assertEqual(Operations, [maps:get(effect, Entry) || Entry <- maps:get(manifest, Views)]),
    ?assertEqual(Operations, [maps:get(id, Entry) || Entry <- maps:get(broker, Views)]),
    ?assertEqual([model_complete, workspace_write], [
        maps:get(operation_tag, Entry) || Entry <- maps:get(adapter, Views)
    ]),
    ?assertEqual([model_complete, workspace_write], [
        maps:get(operation_tag, Entry) || Entry <- maps:get(trace, Views)
    ]).

workspace_request_is_versioned_typed_and_normalized_test() ->
    Arguments = product({<<"workspace-a">>, <<"notes/result.md">>, <<"body">>, <<"write-1">>}),
    {ok, Request} = alang_phase4_effect_registry:new(<<"workspace.write">>, Arguments),
    ?assertMatch({alang_effect_request_v1, <<"workspace.write">>, _}, Request),
    {ok, Decoded} = alang_phase4_effect_registry:decode(Request),
    ?assertEqual(workspace_write, maps:get(operation_tag, Decoded)),
    ?assertEqual(workspace_adapter, maps:get(adapter, Decoded)),
    ?assertEqual(
        #{workspace_id => <<"workspace-a">>, path_segments => [<<"notes">>, <<"result.md">>]},
        maps:get(resource, Decoded)
    ),
    ?assertEqual(<<"write-1">>, maps:get(operation_id, Decoded)).

model_request_decodes_without_dynamic_dispatch_test() ->
    Arguments = product({<<"model-a">>, <<"complete this">>, 4096, <<"completion-1">>}),
    {ok, Decoded} = alang_phase4_effect_registry:decode_abi(<<"model.complete">>, Arguments),
    ?assertEqual(model_complete, maps:get(operation_tag, Decoded)),
    ?assertEqual(model_adapter, maps:get(adapter, Decoded)),
    ?assertEqual(#{model_id => <<"model-a">>}, maps:get(resource, Decoded)).

malformed_and_dynamic_dispatch_inputs_fail_closed_test() ->
    ?assertEqual(
        {error, unsupported_request_version},
        alang_phase4_effect_registry:decode({alang_effect_request_v2, <<"workspace.write">>, product({})})
    ),
    ?assertEqual(
        {error, dynamic_dispatch_forbidden},
        alang_phase4_effect_registry:decode(#{module => <<"file">>, function => <<"write_file">>})
    ),
    ?assertEqual(
        {error, dynamic_dispatch_forbidden},
        alang_phase4_effect_registry:decode({alang_effect_request_v1, file, product({})})
    ),
    ?assertEqual(
        {error, unknown_request_fields},
        alang_phase4_effect_registry:decode(#{operation => <<"workspace.write">>, extra => true})
    ),
    ?assertEqual(
        {error, unknown_operation},
        alang_phase4_effect_registry:decode_abi(<<"erlang.apply">>, product({}))
    ),
    ?assertEqual(
        {error, invalid_arguments},
        alang_phase4_effect_registry:decode_abi(
            <<"workspace.write">>,
            product({<<"workspace-a">>, <<"result.md">>, <<"body">>, <<"op">>, <<"extra">>})
        )
    ).

request_bounds_and_paths_fail_closed_test() ->
    Oversized = binary:copy(<<"x">>, 100000),
    ?assertEqual(
        {error, request_too_large},
        alang_phase4_effect_registry:decode_abi(
            <<"workspace.write">>,
            product({<<"workspace-a">>, <<"result.md">>, Oversized, <<"op">>})
        )
    ),
    lists:foreach(
        fun(Path) ->
            ?assertMatch(
                {error, _},
                alang_phase4_effect_registry:decode_abi(
                    <<"workspace.write">>,
                    product({<<"workspace-a">>, Path, <<"body">>, <<"op">>})
                )
            )
        end,
        [<<"/absolute">>, <<"../escape">>, <<"a/../escape">>, <<"a//b">>, <<"a\\b">>]
    ).

artifact_manifest_is_an_independent_upper_bound_test() ->
    Request = {alang_effect_request_v1, <<"workspace.write">>,
        product({<<"workspace-a">>, <<"result.md">>, <<"body">>, <<"op">>})},
    Declared = #{effects => [<<"workspace.write">>], requirements => [<<"workspace:write">>]},
    BroaderButUndeclared = #{effects => [<<"model.complete">>], requirements => []},
    {ok, Decoded} = alang_phase4_effect_registry:bind_to_manifest(Request, Declared),
    ?assertEqual(<<"workspace.write">>, maps:get(operation, Decoded)),
    ?assertEqual(
        {error, undeclared_effect},
        alang_phase4_effect_registry:bind_to_manifest(Request, BroaderButUndeclared)
    ),
    ?assertEqual(
        {error, unknown_manifest_effect},
        alang_phase4_effect_registry:validate_manifest(#{effects => [<<"dynamic.effect">>], requirements => []})
    ),
    ?assertEqual(
        {error, invalid_manifest_shape},
        alang_phase4_effect_registry:validate_manifest(Declared#{adapter => <<"workspace_adapter">>})
    ).

unknown_binary_operations_do_not_create_atoms_test() ->
    _ = alang_phase4_effect_registry:operations(),
    Before = erlang:system_info(atom_count),
    lists:foreach(
        fun(Index) ->
            Operation = <<"unknown.", (integer_to_binary(Index))/binary>>,
            ?assertEqual(
                {error, unknown_operation},
                alang_phase4_effect_registry:decode_abi(Operation, product({}))
            )
        end,
        lists:seq(1, 1000)
    ),
    ?assertEqual(Before, erlang:system_info(atom_count)).

product(Elements) -> {alang_data_v1, product, Elements}.
