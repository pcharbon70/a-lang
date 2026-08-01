-module(alang_phase2_views).

-export([project/1]).

-spec project(map()) -> {ok, map()} | {error, term()}.
project(#{format := alang_typed_task_ir_v1, tasks := Tasks, nodes := Nodes}) ->
    NodeIds = [maps:get(id, Node) || Node <- Nodes],
    Effects = lists:usort(lists:append([maps:get(effects, Task) || Task <- Tasks])),
    Requirements = lists:usort(lists:append([maps:get(requirements, Task) || Task <- Tasks])),
    {ok, #{
        format => alang_semantic_views_v1,
        deployable => false,
        dry_run => [#{task => maps:get(id, Task), body => maps:get(body_root, Task)} || Task <- Tasks],
        trace_skeleton => NodeIds,
        capability_manifest => #{effects => Effects, requirements => Requirements},
        completion_checklist => [maps:get(completion_root, Task) || Task <- Tasks],
        explanation => #{tasks => length(Tasks), nodes => length(Nodes), complete_node_coverage => true}
    }};
project(_) ->
    {error, invalid_typed_task_ir}.
