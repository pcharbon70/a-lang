-module(alang_fidelity_control).

-export([decode/1, normalize/1]).

-define(MAX_CONTROL_BYTES, 8192).

-spec decode(binary()) -> {ok, map()} | {error, [map()]}.
decode(Binary) when is_binary(Binary), byte_size(Binary) =< ?MAX_CONTROL_BYTES ->
    case alang_fidelity_json_pointer:scan(Binary) of
        {ok, PointerOrigins} ->
            decode_scanned(Binary, PointerOrigins);
        {error, {duplicate_key, Key, Pointer, Byte}} ->
            {error, [diagnostic(
                control_boundary,
                duplicate_key,
                #{source => typed_json, pointer => Pointer, byte => Byte, kind => member},
                <<"duplicate JSON object member: ", Key/binary>>
            )]};
        {error, Reason} ->
            json_error(Reason)
    end;
decode(Binary) when is_binary(Binary) ->
    {error, [diagnostic(
        control_boundary,
        control_document_too_large,
        default_origin(),
        iolist_to_binary(io_lib:format(
            "typed JSON control is ~B bytes; maximum is ~B",
            [byte_size(Binary), ?MAX_CONTROL_BYTES]
        ))
    )]};
decode(_) ->
    {error, [diagnostic(
        control_boundary,
        expected_json_binary,
        default_origin(),
        <<"typed JSON control must be a binary">>
    )]}.

-spec normalize(binary()) -> {ok, map()} | {error, [map()]}.
normalize(Binary) ->
    decode(Binary).

decode_scanned(Binary, PointerOrigins) ->
    case alang_fidelity_json:decode(Binary) of
        {ok, Value} ->
            case alang_fidelity_representation:validate_control(Value) of
                {ok, Decoded} ->
                    Semantic = maps:get(<<"task">>, Value),
                    {ok, #{
                        format => alang_semantic_input_v2,
                        frontend => typed_json,
                        case_id => maps:get(<<"case_id">>, Value),
                        semantic => Semantic,
                        semantic_digest => maps:get(<<"semantic_digest">>, Decoded),
                        source_digest => alang_fidelity_json:hex(crypto:hash(sha256, Binary)),
                        origins => semantic_origins(PointerOrigins)
                    }};
                {error, Reason} ->
                    control_error(Reason, PointerOrigins)
            end;
        {error, {duplicate_key, Key}} ->
            {error, [diagnostic(
                control_boundary,
                duplicate_key,
                alang_fidelity_json_pointer:lookup(PointerOrigins, <<>>),
                <<"duplicate JSON object member: ", Key/binary>>
            )]};
        {error, Reason} ->
            json_error(Reason)
    end.

control_error({invalid_control_semantics, {contract_error, Path, Reason}}, Origins) ->
    Pointer = contract_pointer(Path, Reason),
    {Class, Code} = classify(Path, Reason),
    {error, [diagnostic(
        Class,
        Code,
        alang_fidelity_json_pointer:lookup(Origins, Pointer),
        reason_message(Reason)
    )]};
control_error({representation_error, Path, Reason}, Origins) ->
    Pointer = representation_pointer(Path, Reason),
    {error, [diagnostic(
        control_boundary,
        schema_violation,
        alang_fidelity_json_pointer:lookup(Origins, Pointer),
        reason_message(Reason)
    )]};
control_error(Reason, _Origins) ->
    {error, [diagnostic(
        control_boundary,
        invalid_control,
        default_origin(),
        reason_message(Reason)
    )]}.

json_error(Reason) ->
    {error, [diagnostic(
        control_boundary,
        invalid_json,
        default_origin(),
        reason_message(Reason)
    )]}.

semantic_origins(Origins) ->
    maps:from_list(lists:filtermap(fun(Origin) ->
        Pointer = maps:get(pointer, Origin),
        case semantic_pointer(Pointer) of
            skip -> false;
            SemanticPointer -> {true, {SemanticPointer, Origin}}
        end
    end, Origins)).

semantic_pointer(<<"/task", Rest/binary>>) ->
    case Rest of
        <<>> -> <<>>;
        _ -> Rest
    end;
semantic_pointer(<<"/case_id">>) -> <<"/@case-id">>;
semantic_pointer(<<>>) -> <<"/@document">>;
semantic_pointer(_Pointer) -> skip.

contract_pointer([<<"format">> | Rest], _Reason) ->
    pointer([<<"format">> | Rest]);
contract_pointer([<<"case_id">> | Rest], _Reason) ->
    pointer([<<"case_id">> | Rest]);
contract_pointer(Path, {unknown_fields, [Field | _]}) ->
    pointer([<<"task">> | Path ++ [Field]]);
contract_pointer(Path, {missing_fields, [Field | _]}) ->
    pointer([<<"task">> | Path ++ [Field]]);
contract_pointer(Path, _Reason) ->
    pointer([<<"task">> | Path]).

representation_pointer(Path, {unknown_fields, [Field | _]}) ->
    pointer(Path ++ [Field]);
representation_pointer(Path, {missing_fields, [Field | _]}) ->
    pointer(Path ++ [Field]);
representation_pointer(Path, _Reason) ->
    pointer(Path).

pointer([]) -> <<>>;
pointer(Segments) ->
    iolist_to_binary([[<<"/">>, escape_segment(Segment)] || Segment <- Segments]).

escape_segment(Segment) when is_integer(Segment) -> integer_to_binary(Segment);
escape_segment(Segment) when is_binary(Segment) ->
    binary:replace(binary:replace(Segment, <<"~">>, <<"~0">>, [global]),
        <<"/">>, <<"~1">>, [global]).

classify(Path, {not_in_closed_enum, _Value}) ->
    case lists:last(Path) of
        <<"operation">> -> {name, unknown_operation};
        <<"type">> -> {type, unknown_type};
        _ -> {control_boundary, value_outside_closed_set}
    end;
classify(_Path, {dependency_not_prior, _Name}) -> {control, dependency_not_prior};
classify(_Path, child_effect_widens_authority) -> {attenuation, child_effect_widens_authority};
classify(_Path, child_requirement_widens_authority) -> {attenuation, child_requirement_widens_authority};
classify(_Path, child_scope_widens_authority) -> {attenuation, child_scope_widens_authority};
classify(_Path, child_budget_exceeds_parent) -> {attenuation, child_budget_exceeds_parent};
classify(_Path, {resource_outside_scope, _, _}) -> {authority, resource_outside_scope};
classify(_Path, {unknown_fields, _}) -> {control_boundary, unknown_field};
classify(_Path, {missing_fields, _}) -> {control_boundary, missing_field};
classify(_Path, duplicate_action_id) -> {name, duplicate_action};
classify(_Path, duplicate_input_name) -> {name, duplicate_input};
classify(_Path, duplicate_requirement) -> {authority, duplicate_requirement};
classify(_Path, duplicate_error_branch) -> {control, duplicate_error_branch};
classify(_Path, duplicate_completion_predicate) -> {completion, duplicate_completion_predicate};
classify(_Path, required_for_terminal_class) -> {completion, missing_clarification};
classify(_Path, Reason) when is_tuple(Reason) -> {control_boundary, schema_violation};
classify(_Path, _Reason) -> {control_boundary, schema_violation}.

reason_message(Reason) ->
    iolist_to_binary(io_lib:format("~tp", [Reason])).

diagnostic(Class, Code, Origin, Message) ->
    #{class => Class, code => Code, severity => error, origin => Origin, message => Message}.

default_origin() ->
    #{source => typed_json, pointer => <<>>, byte => 0, kind => document}.
