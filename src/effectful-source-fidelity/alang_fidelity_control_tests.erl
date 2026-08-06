-module(alang_fidelity_control_tests).

-include_lib("eunit/include/eunit.hrl").

all_frozen_controls_decode_with_pointer_and_byte_origins_test() ->
    Files = control_files(),
    ?assertEqual(24, length(Files)),
    lists:foreach(fun(Path) ->
        {ok, Binary} = file:read_file(Path),
        {ok, Input} = alang_fidelity_control:decode(Binary),
        ?assertEqual(alang_semantic_input_v2, maps:get(format, Input)),
        ?assertEqual(typed_json, maps:get(frontend, Input)),
        ?assertEqual(64, byte_size(maps:get(semantic_digest, Input))),
        ?assertEqual(maps:get(case_id, Input),
            list_to_binary(filename:basename(Path, ".json"))),
        Origins = maps:get(origins, Input),
        OperationOrigin = maps:get(<<"/actions/0/operation">>, Origins),
        ?assertMatch(#{source := typed_json, pointer := <<"/task/actions/0/operation">>,
            byte := Byte} when is_integer(Byte), OperationOrigin)
    end, Files).

origin_offsets_point_to_the_original_json_value_test() ->
    Binary = read_control("single-model-artifact/sma-simple.json"),
    {ok, Input} = alang_fidelity_control:decode(Binary),
    Origin = maps:get(<<"/actions/0/operation">>, maps:get(origins, Input)),
    {ExpectedOffset, _Length} = binary:match(Binary, <<"\"model.generate\"">>),
    ?assertEqual(ExpectedOffset, maps:get(byte, Origin)).

duplicate_members_are_rejected_at_the_second_member_test() ->
    Binary = <<"{\"format\":\"alang-task-json-v1\",\"case_id\":\"first\",\"case_id\":\"second\",\"task\":{}}">>,
    {error, [Diagnostic]} = alang_fidelity_control:decode(Binary),
    ?assertEqual(control_boundary, maps:get(class, Diagnostic)),
    ?assertEqual(duplicate_key, maps:get(code, Diagnostic)),
    Origin = maps:get(origin, Diagnostic),
    ?assertEqual(<<"/case_id">>, maps:get(pointer, Origin)),
    ?assert(maps:get(byte, Origin) > 40).

unknown_runtime_and_ir_escape_fields_are_rejected_test() ->
    Binary = read_control("single-model-artifact/sma-simple.json"),
    {ok, Value} = alang_fidelity_json:decode(Binary),
    Task = maps:get(<<"task">>, Value),
    Forbidden = [
        <<"node_id">>, <<"abstract_format">>, <<"module">>, <<"function">>,
        <<"adapter">>, <<"endpoint">>, <<"credential">>, <<"capability_handle">>,
        <<"process_term">>, <<"grant">>, <<"operation_id">>, <<"ir">>
    ],
    lists:foreach(fun(Field) ->
        Mutant = Value#{<<"task">> => Task#{Field => <<"attacker-controlled">>}},
        {error, [Diagnostic]} = alang_fidelity_control:decode(encode(Mutant)),
        ?assertEqual(control_boundary, maps:get(class, Diagnostic)),
        ?assertEqual(unknown_field, maps:get(code, Diagnostic)),
        ExpectedPointer = <<"/task/", Field/binary>>,
        ?assertEqual(ExpectedPointer, maps:get(pointer, maps:get(origin, Diagnostic)))
    end, Forbidden).

schema_diagnostics_are_json_local_and_classified_test() ->
    Binary = read_control("single-model-artifact/sma-simple.json"),
    {ok, Value} = alang_fidelity_json:decode(Binary),
    Task = maps:get(<<"task">>, Value),
    [First | Rest] = maps:get(<<"actions">>, Task),
    MutantTask = Task#{<<"actions">> => [First#{<<"operation">> => <<"erlang.apply">>} | Rest]},
    {error, [Diagnostic]} = alang_fidelity_control:decode(encode(Value#{<<"task">> => MutantTask})),
    ?assertEqual(name, maps:get(class, Diagnostic)),
    ?assertEqual(unknown_operation, maps:get(code, Diagnostic)),
    Origin = maps:get(origin, Diagnostic),
    ?assertEqual(<<"/task/actions/0/operation">>, maps:get(pointer, Origin)),
    ?assert(is_integer(maps:get(byte, Origin))),
    ?assertEqual(nomatch, binary:match(maps:get(message, Diagnostic), <<"A-Lang">>)),
    ?assertEqual(nomatch, binary:match(maps:get(message, Diagnostic), <<"BEAM">>)).

bounded_decoder_rejects_non_json_and_oversized_documents_test() ->
    ?assertMatch({error, [#{code := invalid_json}]},
        alang_fidelity_control:decode(<<131, 104, 2, 100, 0, 3, "bad">>)),
    ?assertMatch({error, [#{code := control_document_too_large}]},
        alang_fidelity_control:decode(binary:copy(<<"x">>, 8193))).

source_controlled_keys_do_not_grow_the_atom_table_test() ->
    Binary = read_control("single-model-artifact/sma-simple.json"),
    {ok, Value} = alang_fidelity_json:decode(Binary),
    Task = maps:get(<<"task">>, Value),
    _ = alang_fidelity_control:decode(encode(Value#{<<"task">> => Task#{<<"warmup">> => true}})),
    Before = erlang:system_info(atom_count),
    lists:foreach(fun(Index) ->
        Field = <<"attacker-field-", (integer_to_binary(Index))/binary>>,
        {error, [_]} = alang_fidelity_control:decode(
            encode(Value#{<<"task">> => Task#{Field => true}})
        )
    end, lists:seq(1, 128)),
    ?assertEqual(Before, erlang:system_info(atom_count)).

control_files() ->
    [Path || Path <- lists:sort(filelib:wildcard(
        "assets/effectful-source-fidelity/corpus/*/*.json")),
        not lists:suffix(".answer.json", Path)].

read_control(Relative) ->
    {ok, Binary} = file:read_file(filename:join(
        "assets/effectful-source-fidelity/corpus", Relative)),
    Binary.

encode(Value) ->
    iolist_to_binary(json:encode(Value)).
