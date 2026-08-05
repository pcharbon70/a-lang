-module(alang_fidelity_representation).

-export([
    decode_control/1,
    load_pairing_contract/1,
    load_source_contract/1,
    normalize_control/1,
    origin_index/1,
    validate_control/1,
    validate_pairing_contract/1,
    validate_source_contract/1
]).

-define(CONTROL_FORMAT, <<"alang-task-json-v1">>).
-define(DECODED_FORMAT, <<"alang-task-json-decoded-v1">>).

-spec decode_control(binary()) -> {ok, map()} | {error, term()}.
decode_control(Binary) ->
    case alang_fidelity_json:decode(Binary) of
        {ok, Value} -> validate_control(Value);
        {error, _} = Error -> Error
    end.

-spec validate_control(term()) -> {ok, map()} | {error, term()}.
validate_control(Value) ->
    try
        closed(Value, [<<"format">>, <<"case_id">>, <<"task">>], [<<"format">>, <<"case_id">>, <<"task">>], []),
        ensure(maps:get(<<"format">>, Value) =:= ?CONTROL_FORMAT, [<<"format">>], wrong_control_format),
        Task = maps:get(<<"task">>, Value),
        ensure(is_map(Task), [<<"task">>], expected_object),
        Comprehension = Task#{
            <<"format">> => <<"alang_task_comprehension_v1">>,
            <<"case_id">> => maps:get(<<"case_id">>, Value)
        },
        case alang_fidelity_contract:validate_comprehension(Comprehension) of
            {ok, _} ->
                Normalized = alang_fidelity_contract:normalize(Comprehension),
                {ok, #{
                    <<"format">> => ?DECODED_FORMAT,
                    <<"source_format">> => ?CONTROL_FORMAT,
                    <<"semantic">> => Normalized,
                    <<"semantic_digest">> => alang_fidelity_json:digest(Normalized),
                    <<"origins">> => origin_index(Value)
                }};
            {error, Reason} ->
                {error, {invalid_control_semantics, Reason}}
        end
    catch
        throw:{representation_error, Path, CaughtReason} ->
            {error, {representation_error, Path, CaughtReason}}
    end.

-spec normalize_control(map()) -> map().
normalize_control(Value) ->
    {ok, Decoded} = validate_control(Value),
    maps:get(<<"semantic">>, Decoded).

-spec origin_index(term()) -> [map()].
origin_index(Value) ->
    lists:sort(
        fun(Left, Right) -> maps:get(<<"pointer">>, Left) =< maps:get(<<"pointer">>, Right) end,
        collect_origins(Value, <<>>)
    ).

-spec load_source_contract(file:filename()) -> {ok, map()} | {error, term()}.
load_source_contract(Path) ->
    load_frozen(Path, fun validate_source_contract/1).

-spec load_pairing_contract(file:filename()) -> {ok, map()} | {error, term()}.
load_pairing_contract(Path) ->
    load_frozen(Path, fun validate_pairing_contract/1).

-spec validate_source_contract(term()) -> {ok, map()} | {error, term()}.
validate_source_contract(Value) ->
    validate_frozen(Value, expected_source_contract(), source_contract).

-spec validate_pairing_contract(term()) -> {ok, map()} | {error, term()}.
validate_pairing_contract(Value) ->
    validate_frozen(Value, expected_pairing_contract(), pairing_contract).

load_frozen(Path, Validator) ->
    case alang_fidelity_json:decode_file(Path) of
        {ok, Value} -> Validator(Value);
        {error, _} = Error -> Error
    end.

validate_frozen(Value, Expected, _Name) when Value =:= Expected ->
    {ok, Value};
validate_frozen(Value, Expected, Name) ->
    {error, {
        frozen_contract_mismatch,
        Name,
        alang_fidelity_json:digest(Expected),
        alang_fidelity_json:digest(Value)
    }}.

expected_source_contract() ->
    #{
        <<"format">> => <<"alang-source-v2-contract-v1">>,
        <<"candidate_format">> => <<"alang-source-v2">>,
        <<"preserves">> => #{
            <<"format">> => <<"alang-source-v1">>,
            <<"accepted_unchanged">> => true
        },
        <<"types">> => [<<"bool">>, <<"json">>, <<"model-profile">>, <<"nat">>, <<"path">>, <<"text">>],
        <<"effects">> => [<<"child.run">>, <<"model.generate">>, <<"workspace.write">>],
        <<"constructs">> => [
            <<"attenuated-child">>,
            <<"bounded-limit">>,
            <<"completion-predicate">>,
            <<"effect-declaration">>,
            <<"error-branch">>,
            <<"ordered-step">>,
            <<"requirement-declaration">>,
            <<"result-match">>,
            <<"task-declaration">>,
            <<"terminal-class">>,
            <<"typed-input">>
        ],
        <<"forbidden">> => [
            <<"arbitrary-calls">>,
            <<"categorical-surface-syntax">>,
            <<"distribution">>,
            <<"dynamic-operations">>,
            <<"parallelism">>,
            <<"polymorphism">>,
            <<"recursion">>
        ],
        <<"bounds">> => #{
            <<"max_actions">> => 16,
            <<"max_child_depth">> => 1,
            <<"max_document_bytes">> => 8192,
            <<"max_output_bytes">> => 8192
        },
        <<"compiler_path">> => #{
            <<"backend">> => <<"otp-abstract-format-to-beam">>,
            <<"executes_on">> => <<"erts">>,
            <<"source_to_erlang">> => false,
            <<"uses_erlang_ast_as_language_ir">> => false
        }
    }.

expected_pairing_contract() ->
    #{
        <<"format">> => <<"alang-fidelity-pairing-v1">>,
        <<"candidate_format">> => <<"alang-source-v2">>,
        <<"control_format">> => <<"alang-task-json-v1">>,
        <<"semantic_digest">> => <<"sha-256-canonical-etf-v1">>,
        <<"normalization">> => #{
            <<"remove">> => [
                <<"comments">>,
                <<"json-key-order">>,
                <<"opaque-trial-identifiers">>,
                <<"presentation-order-for-sets">>,
                <<"source-origins">>
            ],
            <<"retain">> => [
                <<"action-order">>,
                <<"authority">>,
                <<"budgets">>,
                <<"child-attenuation">>,
                <<"completion-semantics">>,
                <<"dependencies">>,
                <<"error-branches">>
            ]
        },
        <<"trial_materialization">> => #{
            <<"schedule_seed">> => 2026080501,
            <<"assign_identifiers_after">> => <<"complete-corpus-validation">>,
            <<"case_identifiers">> => <<"opaque">>,
            <<"condition_identifiers">> => <<"opaque">>,
            <<"presentation_order">> => <<"balanced-randomized-within-model-family-and-repetition">>,
            <<"same_prompt_template">> => true,
            <<"representation_visible_treatment">> => true,
            <<"model_visible_exclusions">> => [
                <<"answer-key">>,
                <<"condition-label">>,
                <<"filename">>,
                <<"semantic-digest">>,
                <<"source-format-label">>
            ]
        }
    }.

collect_origins(Value, Pointer) when is_map(Value) ->
    Current = [origin(Pointer, <<"object">>)],
    Current ++ lists:append([
        collect_origins(Child, join_pointer(Pointer, escape_pointer(Key)))
        || {Key, Child} <- lists:sort(maps:to_list(Value))
    ]);
collect_origins(Value, Pointer) when is_list(Value) ->
    Current = [origin(Pointer, <<"array">>)],
    Current ++ lists:append([
        collect_origins(Child, join_pointer(Pointer, integer_to_binary(Index)))
        || {Child, Index} <- lists:zip(Value, lists:seq(0, length(Value) - 1))
    ]);
collect_origins(_Value, Pointer) ->
    [origin(Pointer, <<"value">>)].

origin(Pointer, Kind) ->
    #{<<"source">> => <<"control-json">>, <<"pointer">> => Pointer, <<"kind">> => Kind}.

join_pointer(<<>>, Segment) -> <<"/", Segment/binary>>;
join_pointer(Pointer, Segment) -> <<Pointer/binary, "/", Segment/binary>>.

escape_pointer(Key) ->
    binary:replace(binary:replace(Key, <<"~">>, <<"~0">>, [global]), <<"/">>, <<"~1">>, [global]).

closed(Value, Allowed, Required, Path) ->
    ensure(is_map(Value), Path, expected_object),
    Keys = maps:keys(Value),
    Unknown = Keys -- Allowed,
    Missing = Required -- Keys,
    ensure(Unknown =:= [], Path, {unknown_fields, lists:sort(Unknown)}),
    ensure(Missing =:= [], Path, {missing_fields, lists:sort(Missing)}).

ensure(true, _Path, _Reason) -> ok;
ensure(false, Path, Reason) -> throw({representation_error, Path, Reason}).
