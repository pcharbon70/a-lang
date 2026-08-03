-module(alang_phase4_effect_registry).

-export([
    adapter_view/0,
    bind_to_manifest/2,
    broker_view/0,
    compiler_view/0,
    decode/1,
    decode_abi/2,
    manifest_view/0,
    new/2,
    operations/0,
    trace_view/0,
    validate_manifest/1,
    views/0
]).

-define(MAX_REQUEST_BYTES, 98304).
-define(MAX_ID_BYTES, 128).
-define(MAX_PATH_BYTES, 4096).
-define(MAX_PROMPT_BYTES, 32768).
-define(MAX_CONTENT_BYTES, 65536).
-define(MAX_MODEL_OUTPUT_BYTES, 65536).

-type request() :: {alang_effect_request_v1, binary(), term()}.
-type decoded_request() :: map().

-spec operations() -> [binary()].
operations() -> [maps:get(id, Definition) || Definition <- registry()].

-spec views() -> map().
views() -> #{
    compiler => compiler_view(),
    manifest => manifest_view(),
    broker => broker_view(),
    adapter => adapter_view(),
    trace => trace_view()
}.

-spec compiler_view() -> [map()].
compiler_view() ->
    [
        maps:with([id, request_type, success_type, failure_type], Definition)
     || Definition <- registry()
    ].

-spec manifest_view() -> [map()].
manifest_view() ->
    [
        #{effect => maps:get(id, Definition), requirement => maps:get(requirement, Definition)}
     || Definition <- registry()
    ].

-spec broker_view() -> [map()].
broker_view() ->
    [
        maps:with([id, operation_tag, request_schema, requirement], Definition)
     || Definition <- registry()
    ].

-spec adapter_view() -> [map()].
adapter_view() ->
    [
        #{operation_tag => maps:get(operation_tag, Definition), adapter => maps:get(adapter, Definition)}
     || Definition <- registry()
    ].

-spec trace_view() -> [map()].
trace_view() ->
    [
        #{operation_tag => maps:get(operation_tag, Definition), trace_name => maps:get(trace_name, Definition)}
     || Definition <- registry()
    ].

-spec new(binary(), term()) -> {ok, request()} | {error, atom()}.
new(Operation, Arguments) ->
    Request = {alang_effect_request_v1, Operation, Arguments},
    case decode(Request) of
        {ok, _Decoded} -> {ok, Request};
        {error, _} = Error -> Error
    end.

-spec decode_abi(binary(), term()) -> {ok, decoded_request()} | {error, atom()}.
decode_abi(Operation, Arguments) ->
    decode({alang_effect_request_v1, Operation, Arguments}).

-spec decode(term()) -> {ok, decoded_request()} | {error, atom()}.
decode(Request) ->
    case bounded_term(Request) of
        false -> {error, request_too_large};
        true -> decode_bounded(Request)
    end.

decode_bounded({alang_effect_request_v1, Operation, Arguments}) when is_binary(Operation) ->
    case definition(Operation) of
        {ok, Definition} -> decode_arguments(Definition, Arguments);
        error -> {error, unknown_operation}
    end;
decode_bounded({Version, _, _}) when Version =/= alang_effect_request_v1 ->
    {error, unsupported_request_version};
decode_bounded(#{module := _}) -> {error, dynamic_dispatch_forbidden};
decode_bounded(#{function := _}) -> {error, dynamic_dispatch_forbidden};
decode_bounded(#{adapter := _}) -> {error, dynamic_dispatch_forbidden};
decode_bounded(Request) when is_map(Request) -> {error, unknown_request_fields};
decode_bounded({alang_effect_request_v1, _DynamicOperation, _Arguments}) ->
    {error, dynamic_dispatch_forbidden};
decode_bounded(_) -> {error, invalid_request_shape}.

-spec validate_manifest(term()) -> ok | {error, atom()}.
validate_manifest(#{effects := Effects, requirements := Requirements} = Manifest) when
    map_size(Manifest) =:= 2,
    is_list(Effects),
    is_list(Requirements)
->
    case {
        valid_manifest_values(Effects),
        valid_manifest_values(Requirements),
        length(Effects) =:= length(lists:usort(Effects)),
        lists:all(fun registered_operation/1, Effects)
    } of
        {true, true, true, true} -> ok;
        {false, _, _, _} -> {error, invalid_manifest_effects};
        {_, false, _, _} -> {error, invalid_manifest_requirements};
        {_, _, false, _} -> {error, duplicate_manifest_effect};
        {_, _, _, false} -> {error, unknown_manifest_effect}
    end;
validate_manifest(_) -> {error, invalid_manifest_shape}.

-spec bind_to_manifest(term(), term()) -> {ok, decoded_request()} | {error, atom()}.
bind_to_manifest(Request, Manifest) ->
    case decode(Request) of
        {ok, Decoded} -> bind_decoded(Decoded, Manifest);
        {error, _} = Error -> Error
    end.

bind_decoded(Decoded, Manifest) ->
    case validate_manifest(Manifest) of
        ok ->
            Operation = maps:get(operation, Decoded),
            case lists:member(Operation, maps:get(effects, Manifest)) of
                true -> {ok, Decoded};
                false -> {error, undeclared_effect}
            end;
        {error, _} = Error -> Error
    end.

decode_arguments(
    #{operation_tag := workspace_write} = Definition,
    {alang_data_v1, product, {WorkspaceId, RelativePath, Content, OperationId}}
) ->
    case {
        valid_id(WorkspaceId),
        normalize_path(RelativePath),
        valid_binary(Content, 0, ?MAX_CONTENT_BYTES),
        valid_id(OperationId)
    } of
        {true, {ok, Segments}, true, true} ->
            decoded(Definition, #{
                workspace_id => WorkspaceId,
                path_segments => Segments,
                content => Content,
                operation_id => OperationId
            }, #{workspace_id => WorkspaceId, path_segments => Segments}, OperationId);
        {false, _, _, _} -> {error, invalid_resource};
        {_, {error, Reason}, _, _} -> {error, Reason};
        {_, _, false, _} -> {error, invalid_arguments};
        {_, _, _, false} -> {error, invalid_operation_id}
    end;
decode_arguments(
    #{operation_tag := model_complete} = Definition,
    {alang_data_v1, product, {ModelId, Prompt, MaxOutputBytes, OperationId}}
) ->
    case {
        valid_id(ModelId),
        valid_binary(Prompt, 1, ?MAX_PROMPT_BYTES),
        is_integer(MaxOutputBytes) andalso MaxOutputBytes > 0 andalso
            MaxOutputBytes =< ?MAX_MODEL_OUTPUT_BYTES,
        valid_id(OperationId)
    } of
        {true, true, true, true} ->
            decoded(Definition, #{
                model_id => ModelId,
                prompt => Prompt,
                max_output_bytes => MaxOutputBytes,
                operation_id => OperationId
            }, #{model_id => ModelId}, OperationId);
        {false, _, _, _} -> {error, invalid_resource};
        {_, false, _, _} -> {error, invalid_arguments};
        {_, _, false, _} -> {error, invalid_arguments};
        {_, _, _, false} -> {error, invalid_operation_id}
    end;
decode_arguments(_Definition, _Arguments) -> {error, invalid_arguments}.

decoded(Definition, Arguments, Resource, OperationId) ->
    {ok, #{
        format => alang_decoded_effect_v1,
        registry_version => 1,
        operation => maps:get(id, Definition),
        operation_tag => maps:get(operation_tag, Definition),
        request_schema => maps:get(request_schema, Definition),
        adapter => maps:get(adapter, Definition),
        trace_name => maps:get(trace_name, Definition),
        requirement => maps:get(requirement, Definition),
        resource => Resource,
        arguments => Arguments,
        operation_id => OperationId
    }}.

normalize_path(Path) when is_binary(Path), byte_size(Path) > 0, byte_size(Path) =< ?MAX_PATH_BYTES ->
    case {
        binary:at(Path, 0) =:= $/,
        binary:match(Path, <<"\\">>) =/= nomatch,
        binary:match(Path, <<0>>) =/= nomatch
    } of
        {false, false, false} -> validate_segments(binary:split(Path, <<"/">>, [global]), []);
        _ -> {error, invalid_relative_path}
    end;
normalize_path(_) -> {error, invalid_relative_path}.

validate_segments([], Acc) -> {ok, lists:reverse(Acc)};
validate_segments([<<>> | _], _Acc) -> {error, invalid_relative_path};
validate_segments([<<".">> | _], _Acc) -> {error, invalid_relative_path};
validate_segments([<<"..">> | _], _Acc) -> {error, path_traversal};
validate_segments([Segment | Rest], Acc) when byte_size(Segment) =< ?MAX_ID_BYTES ->
    validate_segments(Rest, [Segment | Acc]);
validate_segments(_, _Acc) -> {error, invalid_relative_path}.

definition(Operation) ->
    case [Definition || Definition <- registry(), maps:get(id, Definition) =:= Operation] of
        [Definition] -> {ok, Definition};
        [] -> error
    end.

registered_operation(Operation) ->
    is_binary(Operation) andalso definition(Operation) =/= error.

valid_manifest_values(Values) ->
    length(Values) =< 32 andalso lists:all(fun valid_id/1, Values).

valid_id(Value) -> valid_binary(Value, 1, ?MAX_ID_BYTES).

valid_binary(Value, Minimum, Maximum) ->
    is_binary(Value) andalso byte_size(Value) >= Minimum andalso byte_size(Value) =< Maximum.

bounded_term(Term) ->
    try erlang:external_size(Term) =< ?MAX_REQUEST_BYTES
    catch
        error:badarg -> false
    end.

registry() ->
    [
        #{
            id => <<"model.complete">>,
            operation_tag => model_complete,
            request_schema => alang_model_complete_v1,
            request_type => {product, [binary, binary, int, binary]},
            success_type => binary,
            failure_type => {sum, [denied, timeout, cancelled, failed]},
            requirement => <<"model:complete">>,
            adapter => model_adapter,
            trace_name => <<"effect.model.complete">>
        },
        #{
            id => <<"workspace.write">>,
            operation_tag => workspace_write,
            request_schema => alang_workspace_write_v1,
            request_type => {product, [binary, binary, binary, binary]},
            success_type => binary,
            failure_type => {sum, [denied, timeout, cancelled, failed]},
            requirement => <<"workspace:write">>,
            adapter => workspace_adapter,
            trace_name => <<"effect.workspace.write">>
        }
    ].
