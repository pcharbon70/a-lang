-module(alang_phase7_authority_model).

-export([intersection/2, observe/1, subset/2, universe/0]).

-spec universe() -> [map()].
universe() ->
    Workspace = [workspace_request(Path) || Path <- workspace_paths(3)],
    Models = [model_request(<<"model-a">>), model_request(<<"model-b">>)],
    Workspace ++ Models.

-spec observe([map()] | map()) -> [term()].
observe(#{invocations := Invocations}) -> observe(Invocations);
observe(Invocations) when is_list(Invocations) ->
    Grant = #{invocations => Invocations},
    lists:sort([request_identity(Request) || Request <- universe(),
        alang_phase4_grants:allows(Grant, Request)]).

-spec subset([term()], [term()]) -> boolean().
subset(Child, Parent) -> ordsets:is_subset(ordsets:from_list(Child), ordsets:from_list(Parent)).

-spec intersection([term()], [term()]) -> [term()].
intersection(Left, Right) ->
    ordsets:intersection(ordsets:from_list(Left), ordsets:from_list(Right)).

workspace_paths(Depth) ->
    [[<<"notes">> | Suffix] || Suffix <- suffixes(Depth)] ++
        [[<<"private">>, <<"result.md">>], [<<"public">>, <<"result.md">>]].

suffixes(0) -> [[]];
suffixes(Depth) ->
    [[] | [[Segment | Tail] || Segment <- [<<"a">>, <<"b">>, <<"c">>],
        Tail <- suffixes(Depth - 1)]].

workspace_request(Path) -> #{operation => <<"workspace.write">>,
    resource => #{workspace_id => <<"workspace-a">>, path_segments => Path}}.
model_request(Model) -> #{operation => <<"model.complete">>, resource => #{model_id => Model}}.

request_identity(#{operation := <<"workspace.write">>, resource := Resource}) ->
    {<<"workspace.write">>, maps:get(workspace_id, Resource), maps:get(path_segments, Resource)};
request_identity(#{operation := <<"model.complete">>, resource := Resource}) ->
    {<<"model.complete">>, maps:get(model_id, Resource)}.
