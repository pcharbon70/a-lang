-module(alang_phase6_integration_fixture).

-export([model_ir/4, repairing_model_ir/6]).

-spec model_ir(binary(), binary(), binary(), binary()) -> map().
model_ir(TaskId, ModelId, Prompt, OperationId) ->
    Origin = origin(100),
    Nodes = [
        node(<<"m0">>, literal, binary, #{value => ModelId}, Origin),
        node(<<"m1">>, literal, binary, #{value => Prompt}, Origin),
        node(<<"m2">>, literal, int, #{value => 4096}, Origin),
        node(<<"m3">>, literal, binary, #{value => OperationId}, Origin),
        node(<<"m4">>, effect_request, {result, binary, binary}, #{
            operation => <<"model.complete">>, arguments => [<<"m0">>, <<"m1">>, <<"m2">>, <<"m3">>],
            deadline => 3000
        }, Origin),
        node(<<"m5">>, input, binary, #{name => <<"model-output">>}, Origin),
        node(<<"m6">>, input, binary, #{name => <<"model-error">>}, Origin),
        node(<<"m7">>, match_result, binary, #{value => <<"m4">>, ok_branch => <<"m5">>,
            error_branch => <<"m6">>, ok_binding => <<"model-output">>,
            error_binding => <<"model-error">>}, Origin),
        node(<<"m8">>, literal, bool, #{value => true}, Origin),
        node(<<"m9">>, verify, bool, #{condition => <<"m8">>}, Origin)
    ],
    ir(TaskId, <<"ModelFixture">>, <<"m7">>, <<"m9">>, Nodes).

-spec repairing_model_ir(binary(), binary(), binary(), binary(), binary(), binary()) -> map().
repairing_model_ir(TaskId, ModelId, OriginalPrompt, OriginalOperationId,
    RepairPrompt, RepairOperationId) ->
    Origin = origin(200),
    Nodes = [
        node(<<"o0">>, literal, binary, #{value => ModelId}, Origin),
        node(<<"o1">>, literal, binary, #{value => OriginalPrompt}, Origin),
        node(<<"o2">>, literal, int, #{value => 4096}, Origin),
        node(<<"o3">>, literal, binary, #{value => OriginalOperationId}, Origin),
        node(<<"o4">>, effect_request, {result, binary, binary}, #{
            operation => <<"model.complete">>, arguments => [<<"o0">>, <<"o1">>, <<"o2">>, <<"o3">>],
            deadline => 3000
        }, Origin),
        node(<<"o5">>, input, binary, #{name => <<"original-output">>}, Origin),
        node(<<"o6">>, input, binary, #{name => <<"original-error">>}, Origin),

        node(<<"r0">>, literal, binary, #{value => ModelId}, Origin),
        node(<<"r1">>, literal, binary, #{value => RepairPrompt}, Origin),
        node(<<"r2">>, literal, int, #{value => 4096}, Origin),
        node(<<"r3">>, literal, binary, #{value => RepairOperationId}, Origin),
        node(<<"r4">>, effect_request, {result, binary, binary}, #{
            operation => <<"model.complete">>, arguments => [<<"r0">>, <<"r1">>, <<"r2">>, <<"r3">>],
            deadline => 3000
        }, Origin),
        node(<<"r5">>, input, binary, #{name => <<"repair-output">>}, Origin),
        node(<<"r6">>, input, binary, #{name => <<"repair-error">>}, Origin),
        node(<<"r7">>, match_result, binary, #{value => <<"r4">>, ok_branch => <<"r5">>,
            error_branch => <<"r6">>, ok_binding => <<"repair-output">>,
            error_binding => <<"repair-error">>}, Origin),

        node(<<"p0">>, match_result, binary, #{value => <<"o4">>, ok_branch => <<"o5">>,
            error_branch => <<"r7">>, ok_binding => <<"original-output">>,
            error_binding => <<"original-error">>}, Origin),
        node(<<"p1">>, literal, bool, #{value => true}, Origin),
        node(<<"p2">>, verify, bool, #{condition => <<"p1">>}, Origin)
    ],
    ir(TaskId, <<"RepairingModelFixture">>, <<"p0">>, <<"p2">>, Nodes).

ir(TaskId, Module, BodyRoot, CompletionRoot, Nodes) -> #{
    format => alang_typed_task_ir_v1,
    module => Module,
    tasks => [#{
        id => TaskId,
        name => TaskId,
        parameters => [],
        result_type => binary,
        effects => [<<"model.complete">>],
        requirements => [<<"model:complete">>],
        body_root => BodyRoot,
        completion_root => CompletionRoot,
        origin => origin(1)
    }],
    nodes => Nodes
}.

node(Id, Kind, Type, Fields, Origin) ->
    maps:merge(#{id => Id, kind => Kind, type => Type, origin => Origin}, Fields).
origin(Byte) -> #{byte => Byte, line => 1, column => 1}.
