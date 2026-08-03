-module(alang_phase3_contract_tests).

-include_lib("eunit/include/eunit.hrl").

counter_ir_satisfies_backend_contract_test() ->
    {ok, Product} = counter_product(),
    ?assertEqual(ok, alang_phase3_contract:validate_ir(maps:get(ir, Product))).

closed_value_encodings_do_not_collide_test() ->
    {ok, Product} = alang_phase3_contract:wrap_value({product, [int, bool]}, [42, true]),
    ?assertEqual({alang_data_v1, product, {42, true}}, Product),
    ?assertEqual(ok, alang_phase3_contract:validate_value({product, [int, bool]}, Product)),
    {ok, Result} = alang_phase3_contract:wrap_value({result, int, binary}, {error, <<"denied">>}),
    ?assertEqual({alang_data_v1, error, <<"denied">>}, Result),
    ?assertEqual(ok, alang_phase3_contract:validate_value({result, int, binary}, Result)),
    ?assertMatch(
        {error, {invalid_encoded_value, _, _}},
        alang_phase3_contract:validate_value({result, int, binary}, {ok, 42})
    ).

opaque_values_require_runtime_references_test() ->
    Reference = make_ref(),
    Type = {opaque, <<"capability-ref/v1">>},
    {ok, Encoded} = alang_phase3_contract:wrap_value(Type, {opaque, <<"capability-ref/v1">>, Reference}),
    ?assertEqual(ok, alang_phase3_contract:validate_value(Type, Encoded)),
    ?assertMatch(
        {error, _},
        alang_phase3_contract:wrap_value(Type, {opaque, <<"capability-ref/v1">>, <<"forge">>})
    ).

unsupported_node_reports_identity_and_origin_test() ->
    {ok, Product} = counter_product(),
    Ir = maps:get(ir, Product),
    Origin = #{byte => 77, line => 5, column => 9},
    Unknown = #{
        id => <<"node:unknown">>,
        kind => spawn_unbounded,
        type => int,
        origin => Origin
    },
    {error, Errors} = alang_phase3_contract:validate_ir(Ir#{nodes := maps:get(nodes, Ir) ++ [Unknown]}),
    ?assert(lists:member(
        {alang_compile_error_v1, unsupported_ir_node, <<"node:unknown">>, {source, 77, 5, 9}},
        Errors
    )).

dangling_reference_fails_closed_test() ->
    {ok, Product} = counter_product(),
    Ir = maps:get(ir, Product),
    [First | Rest] = maps:get(nodes, Ir),
    Broken = First#{right := <<"node:missing">>},
    {error, Errors} = alang_phase3_contract:validate_ir(Ir#{nodes := [Broken | Rest]}),
    ?assert(lists:any(
        fun({alang_compile_error_v1, dangling_node_reference, _, _}) -> true;
           (_) -> false
        end,
        Errors
    )).

source_controlled_module_atom_is_rejected_test() ->
    {ok, Product} = counter_product(),
    Ir = maps:get(ir, Product),
    ?assertMatch(
        {error, [{alang_compile_error_v1, invalid_ir_shape, _, _}]},
        alang_phase3_contract:validate_ir(Ir#{module := user_created_atom})
    ).

abstract_format_and_runtime_surfaces_are_closed_test() ->
    Forms = alang_phase3_contract:allowed_abstract_forms(),
    ?assertNot(lists:member(core_erlang, Forms)),
    ?assertNot(lists:member(beam_assembly, Forms)),
    Calls = alang_phase3_contract:allowed_runtime_calls(),
    ?assertEqual([{alang_phase3_abi, request_effect, 5}], [Call || {alang_phase3_abi, _, _} = Call <- Calls]),
    ?assertNot(lists:any(fun({erlang, apply, _}) -> true; (_) -> false end, Calls)).

evaluation_and_failure_order_is_explicit_test() ->
    ?assertEqual(
        [
            evaluate_arguments_left_to_right,
            propagate_tagged_error_before_next_step,
            suspend_only_at_effect_request,
            observe_deadline_before_and_after_effect,
            evaluate_verifier_after_result,
            contain_exception_as_runtime_failure
        ],
        alang_phase3_contract:evaluation_order()
    ),
    ?assertEqual(
        {alang_runtime_error_v1, deadline_exceeded, {source, 3, 2, 4}},
        alang_phase3_contract:runtime_error(deadline_exceeded, #{byte => 3, line => 2, column => 4})
    ).

counter_product() ->
    {ok, Source} = file:read_file("src/phase-02/fixtures/counter.alang"),
    alang_phase2_compiler:compile_source(Source).
