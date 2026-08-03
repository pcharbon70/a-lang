-module(alang_phase2_bridge).

-export([phase1_fixture/2]).

-spec phase1_fixture(map(), file:filename()) -> {ok, binary()} | {error, term()}.
phase1_fixture(
    #{
        format := alang_typed_task_ir_v1,
        module := <<"Counter">>,
        tasks := [#{
            id := <<"task:Counter.successor/1">>,
            result_type := int,
            effects := [],
            requirements := []
        }]
    } = Ir,
    GoldenFixturePath
) ->
    case matches_successor_profile(Ir) of
        true -> file:read_file(GoldenFixturePath);
        false -> {error, unsupported_phase1_bridge_profile}
    end;
phase1_fixture(_, _) ->
    {error, unsupported_phase1_bridge_profile}.

matches_successor_profile(#{tasks := [Task], nodes := Nodes}) ->
    NodeMap = maps:from_list([{maps:get(id, Node), Node} || Node <- Nodes]),
    BodyId = maps:get(body_root, Task),
    CompletionId = maps:get(completion_root, Task),
    case {maps:find(BodyId, NodeMap), maps:find(CompletionId, NodeMap)} of
        {
            {ok, #{kind := add, left := InputId, right := OneId}},
            {ok, #{kind := verify, condition := EqualityId}}
        } ->
            matches_successor_nodes(NodeMap, InputId, OneId, EqualityId);
        _ ->
            false
    end.

matches_successor_nodes(NodeMap, InputId, OneId, EqualityId) ->
    case {maps:find(InputId, NodeMap), maps:find(OneId, NodeMap), maps:find(EqualityId, NodeMap)} of
        {
            {ok, #{kind := input, name := <<"value">>, type := int}},
            {ok, #{kind := literal, value := 1, type := int}},
            {ok, #{kind := equal, left := ResultId, right := EnsureAddId}}
        } ->
            matches_completion_nodes(NodeMap, ResultId, EnsureAddId);
        _ ->
            false
    end.

matches_completion_nodes(NodeMap, ResultId, EnsureAddId) ->
    case {maps:find(ResultId, NodeMap), maps:find(EnsureAddId, NodeMap)} of
        {
            {ok, #{kind := result, type := int}},
            {ok, #{kind := add, left := EnsureInputId, right := EnsureOneId}}
        } ->
            case {maps:find(EnsureInputId, NodeMap), maps:find(EnsureOneId, NodeMap)} of
                {
                    {ok, #{kind := input, name := <<"value">>, type := int}},
                    {ok, #{kind := literal, value := 1, type := int}}
                } -> true;
                _ -> false
            end;
        _ ->
            false
    end.
