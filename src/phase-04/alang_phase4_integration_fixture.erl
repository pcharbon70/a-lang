-module(alang_phase4_integration_fixture).

-export([workspace_ir/4]).

-spec workspace_ir(binary(), binary(), binary(), binary()) -> map().
workspace_ir(WorkspaceId, RelativePath, Content, OperationId) ->
    Origin = #{byte => 100, line => 10, column => 1},
    Nodes = [
        node(<<"w0">>, literal, binary, #{value => WorkspaceId}, Origin),
        node(<<"w1">>, literal, binary, #{value => RelativePath}, Origin),
        node(<<"w2">>, literal, binary, #{value => Content}, Origin),
        node(<<"w3">>, literal, binary, #{value => OperationId}, Origin),
        node(<<"w4">>, effect_request, {result, binary, binary}, #{
            operation => <<"workspace.write">>,
            arguments => [<<"w0">>, <<"w1">>, <<"w2">>, <<"w3">>],
            deadline => 3000
        }, Origin),
        node(<<"w5">>, literal, bool, #{value => true}, Origin),
        node(<<"w6">>, verify, bool, #{condition => <<"w5">>}, Origin)
    ],
    #{
        format => alang_typed_task_ir_v1,
        module => <<"WorkspaceEffectFixture">>,
        tasks => [#{
            id => <<"task:Workspace.write/0">>,
            name => <<"task:Workspace.write/0">>,
            parameters => [],
            result_type => {result, binary, binary},
            effects => [<<"workspace.write">>],
            requirements => [<<"workspace:write">>],
            body_root => <<"w4">>,
            completion_root => <<"w6">>,
            origin => Origin
        }],
        nodes => Nodes
    }.

node(Id, Kind, Type, Fields, Origin) ->
    maps:merge(#{id => Id, kind => Kind, type => Type, origin => Origin}, Fields).
