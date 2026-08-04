-module(alang_phase3_backend_tests).

-include_lib("eunit/include/eunit.hrl").

-define(TOOLCHAIN, "src/phase-01/toolchain.config").
-define(GENERATED_BEAM, "alang_phase3_program_v1.beam").

counter_lowering_is_bounded_and_source_mapped_test() ->
    {Ir, Context} = counter_input(),
    {ok, Lowered} = alang_phase3_lowering:lower(Ir, Context),
    ?assertEqual(alang_phase3_program_v1, maps:get(module, Lowered)),
    ?assertEqual(ok, alang_phase3_forms:validate(maps:get(forms, Lowered))),
    ?assertEqual(
        '$alang_callable_0',
        maps:get(<<"task:Counter.successor/1">>, maps:get(callable_map, Lowered))
    ),
    ?assertEqual(length(maps:get(nodes, Ir)), length(maps:get(source_map, Lowered))).

pure_data_and_control_vocabulary_lowers_test() ->
    {ok, Lowered} = alang_phase3_lowering:lower(extended_ir(), default_context()),
    Forms = maps:get(forms, Lowered),
    ?assertEqual(ok, alang_phase3_forms:validate(Forms)),
    lists:foreach(
        fun(Tag) -> ?assert(term_contains(Forms, Tag)) end,
        [product, ok, error, '$alang_callable_0']
    ),
    ?assert(term_contains(Forms, {atom, 10, alang_data_v1})),
    ?assert(term_contains(Forms, {remote, 10, {atom, 10, erlang}, {atom, 10, element}})).

effect_requests_lower_only_through_runtime_abi_test() ->
    Context = (default_context())#{
        capability_manifest := #{effects => [<<"fixture.increment">>], requirements => []}
    },
    {ok, Lowered} = alang_phase3_lowering:lower(effect_ir(), Context),
    Forms = maps:get(forms, Lowered),
    ?assertEqual(ok, alang_phase3_forms:validate(Forms)),
    ?assert(term_contains(
        Forms,
        {remote, 10, {atom, 10, alang_phase3_abi}, {atom, 10, request_effect}}
    )),
    ?assertNot(term_contains(Forms, {atom, 10, spawn})),
    ?assertNot(term_contains(Forms, {atom, 10, send})).

pinned_compilation_is_in_memory_and_deterministic_test() ->
    ?assertNot(filelib:is_file(?GENERATED_BEAM)),
    {Ir, Context} = counter_input(),
    {ok, First} = alang_phase3_backend:compile_ir(Ir, Context, ?TOOLCHAIN),
    {ok, Second} = alang_phase3_backend:compile_ir(Ir, Context, ?TOOLCHAIN),
    ?assertEqual(maps:get(beam, First), maps:get(beam, Second)),
    ?assertEqual(maps:get(beam_sha256, First), maps:get(beam_sha256, Second)),
    ?assertEqual(maps:get(forms_sha256, First), maps:get(forms_sha256, Second)),
    ?assertEqual(passed, maps:get(strong_validation, First)),
    ?assertEqual(beam, maps:get(compiler_engine, First)),
    ?assertEqual(<<"29">>, maps:get(otp_release, First)),
    ?assertNot(filelib:is_file(?GENERATED_BEAM)).

metadata_attribute_uses_versioned_deterministic_etf_test() ->
    {Ir, Context} = counter_input(),
    {ok, Lowered} = alang_phase3_lowering:lower(Ir, Context),
    [{attribute, _, alang_backend, Encoded}] = [Form ||
        {attribute, _, alang_backend, _} = Form <- maps:get(forms, Lowered)],
    ?assertMatch({alang_backend_metadata_etf_v1, _}, Encoded),
    ?assertEqual({ok, maps:get(metadata, Lowered)},
        alang_phase3_forms:decode_metadata(Encoded)),
    ?assertEqual(Encoded, alang_phase3_forms:encode_metadata(
        maps:get(metadata, Lowered))).

emitted_beam_has_fixed_module_and_export_test() ->
    {Ir, Context} = counter_input(),
    {ok, Compiled} = alang_phase3_backend:compile_ir(Ir, Context, ?TOOLCHAIN),
    {ok, {alang_phase3_program_v1, Chunks}} = beam_lib:chunks(
        maps:get(beam, Compiled),
        [exports, imports]
    ),
    Exports = proplists:get_value(exports, Chunks),
    ?assert(lists:member({execute, 3}, Exports)),
    ?assertNot(lists:member({start, 1}, Exports)).

forbidden_abstract_call_is_rejected_with_source_identity_test() ->
    Forms = forbidden_forms(),
    {error, Diagnostic} = alang_phase3_backend:compile_forms(Forms, ?TOOLCHAIN),
    ?assertEqual({unsupported_remote_call, {os, cmd, 1}}, maps:get(detail, Diagnostic)),
    ?assertEqual(
        [{alang_compile_error_v1, abstract_format_rejected, <<"node:bad">>, {source, 7, 9, 2}}],
        maps:get(errors, Diagnostic)
    ).

otp_failure_is_translated_to_nearest_source_identity_test() ->
    {Ir, Context} = counter_input(),
    {ok, Lowered} = alang_phase3_lowering:lower(Ir, Context),
    Forms = make_execute_unbound(maps:get(forms, Lowered)),
    ?assertEqual(ok, alang_phase3_forms:validate(Forms)),
    {error, Diagnostic} = alang_phase3_backend:compile_forms(Forms, ?TOOLCHAIN),
    [{alang_compile_error_v1, otp_validation_failed, NodeId, {source, _, _, _}}] =
        maps:get(errors, Diagnostic),
    ?assertMatch(<<"node:", _/binary>>, NodeId).

counter_input() ->
    {ok, Source} = file:read_file("src/phase-02/fixtures/counter.alang"),
    {ok, Product} = alang_phase2_compiler:compile_source(Source),
    Views = maps:get(views, Product),
    Context = #{
        source_sha256 => hex(crypto:hash(sha256, Source)),
        capability_manifest => maps:get(capability_manifest, Views)
    },
    {maps:get(ir, Product), Context}.

default_context() ->
    #{
        source_sha256 => <<"fixture-source-sha256">>,
        capability_manifest => #{effects => [], requirements => []}
    }.

extended_ir() ->
    Origin = origin(),
    Nodes = [
        node(<<"n0">>, literal, int, #{value => 40}, Origin),
        node(<<"n1">>, literal, int, #{value => 2}, Origin),
        node(<<"n2">>, product, {product, [int, int]}, #{elements => [<<"n0">>, <<"n1">>]}, Origin),
        node(<<"n3">>, project, int, #{product => <<"n2">>, index => 2}, Origin),
        node(<<"n4">>, ok, {result, int, binary}, #{value => <<"n3">>}, Origin),
        node(<<"n5">>, input, int, #{name => <<"ok-value">>}, Origin),
        node(<<"n6">>, input, binary, #{name => <<"error-value">>}, Origin),
        node(<<"n7">>, match_result, int, #{
            value => <<"n4">>,
            ok_branch => <<"n5">>,
            error_branch => <<"n0">>,
            ok_binding => <<"ok-value">>,
            error_binding => <<"error-value">>
        }, Origin),
        node(<<"n8">>, bind, int, #{value => <<"n0">>, body => <<"n10">>, binding => <<"bound">>}, Origin),
        node(<<"n9">>, input, int, #{name => <<"bound">>}, Origin),
        node(<<"n10">>, add, int, #{left => <<"n9">>, right => <<"n7">>}, Origin),
        node(<<"n11">>, sequence, int, #{first => <<"n17">>, then => <<"n8">>}, Origin),
        node(<<"n12">>, result, int, #{}, Origin),
        node(<<"n13">>, literal, int, #{value => 42}, Origin),
        node(<<"n14">>, equal, bool, #{left => <<"n12">>, right => <<"n13">>}, Origin),
        node(<<"n15">>, verify, bool, #{condition => <<"n14">>}, Origin),
        node(<<"n16">>, literal, binary, #{value => <<"stop">>}, Origin),
        node(<<"n17">>, error, {result, int, binary}, #{value => <<"n16">>}, Origin)
    ],
    ir(Nodes, <<"n11">>, <<"n15">>, int, [], []).

effect_ir() ->
    Origin = origin(),
    Nodes = [
        node(<<"n0">>, literal, int, #{value => 41}, Origin),
        node(<<"n1">>, effect_request, {result, int, binary}, #{
            operation => <<"fixture.increment">>,
            arguments => [<<"n0">>],
            deadline => 1000
        }, Origin),
        node(<<"n2">>, literal, bool, #{value => true}, Origin),
        node(<<"n3">>, verify, bool, #{condition => <<"n2">>}, Origin)
    ],
    ir(Nodes, <<"n1">>, <<"n3">>, {result, int, binary}, [<<"fixture.increment">>], []).

ir(Nodes, BodyRoot, CompletionRoot, ResultType, Effects, Requirements) ->
    Origin = origin(),
    #{
        format => alang_typed_task_ir_v1,
        module => <<"Fixture">>,
        tasks => [#{
            id => <<"task:Fixture.run/0">>,
            name => <<"run">>,
            parameters => [],
            result_type => ResultType,
            effects => Effects,
            requirements => Requirements,
            body_root => BodyRoot,
            completion_root => CompletionRoot,
            origin => Origin
        }],
        nodes => Nodes
    }.

node(Id, Kind, Type, Fields, Origin) ->
    maps:merge(#{id => Id, kind => Kind, type => Type, origin => Origin}, Fields).

origin() -> #{byte => 90, line => 10, column => 4}.

forbidden_forms() ->
    Metadata = #{
        format => alang_backend_metadata_v1,
        module => alang_phase3_program_v1,
        abi => alang_runtime_v1,
        ir_format => alang_typed_task_ir_v1,
        compiler => #{
            format => alang_phase3_compiler_v1,
            module => alang_phase3_backend,
            engine => beam
        },
        toolchain => alang_phase1_compiler:current_toolchain(),
        reproducibility => #{
            forms_encoding => deterministic_etf,
            compiler_profile => alang_phase3_otp29_v1
        },
        source_sha256 => <<"source">>,
        ir_sha256 => <<"ir">>,
        capability_manifest => #{effects => [], requirements => []},
        source_map => [{<<"node:bad">>, {source, 7, 9, 2}}]
    },
    [
        {attribute, 1, module, alang_phase3_program_v1},
        {attribute, 1, export, [{execute, 3}]},
        {attribute, 1, alang_backend, Metadata},
        {function, 9, execute, 3, [
            {clause, 9, [{var, 9, '_'}, {var, 9, '_'}, {var, 9, '_'}], [], [
                {call, 9, {remote, 9, {atom, 9, os}, {atom, 9, cmd}}, [{string, 9, "id"}]}
            ]}
        ]}
    ].

make_execute_unbound(Forms) ->
    [
        case Form of
            {function, Line, execute, 3, _Clauses} ->
                {function, Line, execute, 3, [
                    {clause, 5, [
                        {var, 5, 'ALANG_TASK_ID'},
                        {var, 5, 'ALANG_INPUTS'},
                        {var, 5, 'ALANG_CONTEXT'}
                    ], [], [{var, 5, 'ALANG_V0'}]}
                ]};
            _ -> Form
        end
     || Form <- Forms
    ].

term_contains(Term, Needle) when Term =:= Needle -> true;
term_contains(Term, Needle) when is_tuple(Term) ->
    term_contains(tuple_to_list(Term), Needle);
term_contains([Head | Rest], Needle) ->
    term_contains(Head, Needle) orelse term_contains(Rest, Needle);
term_contains([], _Needle) -> false;
term_contains(_Term, _Needle) -> false.

hex(Binary) ->
    iolist_to_binary([io_lib:format("~2.16.0b", [Byte]) || <<Byte>> <= Binary]).
