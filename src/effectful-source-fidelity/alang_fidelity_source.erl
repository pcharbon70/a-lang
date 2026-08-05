-module(alang_fidelity_source).

-export([decode/1]).

-spec decode(binary()) -> {ok, map()} | {error, [map()]}.
decode(Binary) when is_binary(Binary) ->
    case alang_fidelity_parser:parse(Binary) of
        {ok, #{format := alang_source_ast_v2, task := Task}} ->
            Semantic = semantic_task(Task),
            CaseId = maps:get(name, Task),
            Comprehension = Semantic#{
                <<"format">> => <<"alang_task_comprehension_v1">>,
                <<"case_id">> => CaseId
            },
            case alang_fidelity_contract:validate_comprehension(Comprehension) of
                {ok, _} ->
                    {ok, #{
                        format => alang_semantic_input_v2,
                        frontend => alang_source,
                        case_id => CaseId,
                        semantic => Semantic,
                        semantic_digest => alang_fidelity_contract:semantic_digest(Comprehension),
                        source_digest => alang_fidelity_json:hex(crypto:hash(sha256, Binary)),
                        origins => source_origins(Task)
                    }};
                {error, {contract_error, Path, Reason}} ->
                    {error, [contract_diagnostic(Path, Reason, Task)]}
            end;
        {ok, _LegacyAst} ->
            {error, [diagnostic(
                control_boundary,
                unsupported_source_version,
                default_origin(),
                <<"the effectful fidelity checker requires alang-source-v2">>
            )]};
        {error, Diagnostics} ->
            {error, [parser_diagnostic(Diagnostic) || Diagnostic <- Diagnostics]}
    end;
decode(_) ->
    {error, [diagnostic(
        control_boundary,
        expected_source_binary,
        default_origin(),
        <<"A-Lang source must be a binary">>
    )]}.

semantic_task(Task) ->
    #{
        <<"goal_facts">> => [maps:get(value, Item) || Item <-
            maps:get(values, maps:get(facts, Task))],
        <<"inputs">> => [semantic_input(Item) || Item <- maps:get(inputs, Task)],
        <<"actions">> => [semantic_action(Item) || Item <- maps:get(steps, Task)],
        <<"effects">> => [maps:get(name, Item) || Item <-
            maps:get(values, maps:get(effects, Task))],
        <<"requirements">> => [semantic_requirement(Item) || Item <-
            maps:get(values, maps:get(requirements, Task))],
        <<"scopes">> => semantic_scopes(maps:get(scopes, Task)),
        <<"budgets">> => semantic_limits(maps:get(limits, Task)),
        <<"error_branches">> => [semantic_error_branch(Item) || Item <-
            maps:get(values, maps:get(on_error, Task))],
        <<"child_attenuation">> => semantic_child(maps:get(child, Task)),
        <<"completion_predicates">> => [semantic_predicate(Item) || Item <-
            maps:get(predicates, maps:get(completion, Task))],
        <<"clarification_needs">> => [maps:get(value, Item) || Item <-
            maps:get(values, maps:get(clarify, Task))],
        <<"terminal_class">> => maps:get(class, maps:get(terminal, Task))
    }.

semantic_input(Input) ->
    #{
        <<"name">> => maps:get(name, Input),
        <<"type">> => maps:get(type, Input),
        <<"required">> => maps:get(required, Input)
    }.

semantic_action(Action) ->
    #{
        <<"id">> => maps:get(name, Action),
        <<"operation">> => maps:get(operation, Action),
        <<"depends_on">> => [maps:get(value, Item) || Item <- maps:get(depends_on, Action)]
    }.

semantic_requirement(Requirement) ->
    #{
        <<"kind">> => maps:get(resource_kind, Requirement),
        <<"resource">> => maps:get(resource, Requirement)
    }.

semantic_scopes(Scopes) ->
    #{
        <<"models">> => scope_values(models, Scopes),
        <<"workspaces">> => scope_values(workspaces, Scopes),
        <<"paths">> => scope_values(paths, Scopes)
    }.

scope_values(Key, Scopes) ->
    [maps:get(value, Item) || Item <- maps:get(values, maps:get(Key, Scopes))].

semantic_limits(Limits) ->
    maps:from_list([
        {limit_key(maps:get(name, Item)), maps:get(value, Item)}
     || Item <- maps:get(values, Limits)
    ]).

limit_key(<<"steps">>) -> <<"steps">>;
limit_key(<<"model-calls">>) -> <<"model_calls">>;
limit_key(<<"repair-calls">>) -> <<"repair_calls">>;
limit_key(<<"child-calls">>) -> <<"child_calls">>;
limit_key(<<"workspace-writes">>) -> <<"workspace_writes">>;
limit_key(<<"output-bytes">>) -> <<"output_bytes">>;
limit_key(<<"timeout-ms">>) -> <<"timeout_ms">>.

semantic_error_branch(Branch) ->
    #{
        <<"action">> => maps:get(action, Branch),
        <<"on">> => maps:get(reason, Branch),
        <<"terminal_class">> => maps:get(terminal_class, Branch)
    }.

semantic_child(#{value := none}) -> null;
semantic_child(#{value := attenuation} = Child) ->
    #{
        <<"effects">> => [maps:get(name, Item) || Item <-
            maps:get(values, maps:get(effects, Child))],
        <<"requirements">> => [semantic_requirement(Item) || Item <-
            maps:get(values, maps:get(requirements, Child))],
        <<"scopes">> => semantic_scopes(maps:get(scopes, Child)),
        <<"budgets">> => semantic_limits(maps:get(limits, Child))
    }.

semantic_predicate(Predicate) ->
    #{
        <<"kind">> => maps:get(predicate, Predicate),
        <<"target">> => maps:get(target, Predicate),
        <<"expected">> => maps:get(expected, Predicate)
    }.

source_origins(Task) ->
    Pairs = [
        {<<>>, maps:get(origin, Task)},
        {<<"/@document">>, maps:get(origin, Task)},
        {<<"/@case-id">>, maps:get(name_origin, Task)},
        {<<"/goal_facts">>, maps:get(origin, maps:get(facts, Task))},
        {<<"/inputs">>, maps:get(origin, Task)},
        {<<"/actions">>, maps:get(origin, Task)},
        {<<"/effects">>, maps:get(origin, maps:get(effects, Task))},
        {<<"/requirements">>, maps:get(origin, maps:get(requirements, Task))},
        {<<"/scopes">>, maps:get(origin, maps:get(scopes, Task))},
        {<<"/budgets">>, maps:get(origin, maps:get(limits, Task))},
        {<<"/error_branches">>, maps:get(origin, maps:get(on_error, Task))},
        {<<"/child_attenuation">>, maps:get(origin, maps:get(child, Task))},
        {<<"/completion_predicates">>, maps:get(origin, maps:get(completion, Task))},
        {<<"/clarification_needs">>, maps:get(origin, maps:get(clarify, Task))},
        {<<"/terminal_class">>, maps:get(class_origin, maps:get(terminal, Task))}
    ] ++ fact_origins(Task) ++ input_origins(Task) ++ action_origins(Task) ++
        effect_origins(Task) ++ requirement_origins(Task) ++ scope_origins(Task) ++
        limit_origins(Task, <<>>) ++ error_origins(Task) ++ child_origins(Task) ++
        completion_origins(Task) ++ clarification_origins(Task),
    maps:from_list([{Pointer, source_origin(Pointer, Origin)} || {Pointer, Origin} <- Pairs]).

fact_origins(Task) ->
    indexed_pairs(<<"/goal_facts">>, maps:get(values, maps:get(facts, Task)),
        fun(Item) -> maps:get(origin, Item) end).

input_origins(Task) ->
    lists:append([begin
        Base = indexed_pointer(<<"/inputs">>, Index),
        [
            {Base, maps:get(origin, Input)},
            {<<Base/binary, "/name">>, maps:get(name_origin, Input)},
            {<<Base/binary, "/type">>, maps:get(type_origin, Input)},
            {<<Base/binary, "/required">>, maps:get(required_origin, Input)}
        ]
    end || {Input, Index} <- indexed(maps:get(inputs, Task))]).

action_origins(Task) ->
    lists:append([begin
        Base = indexed_pointer(<<"/actions">>, Index),
        DependencyOrigins = indexed_pairs(<<Base/binary, "/depends_on">>,
            maps:get(depends_on, Action), fun(Item) -> maps:get(origin, Item) end),
        [
            {Base, maps:get(origin, Action)},
            {<<Base/binary, "/id">>, maps:get(name_origin, Action)},
            {<<Base/binary, "/operation">>, maps:get(operation_origin, Action)},
            {<<Base/binary, "/depends_on">>, maps:get(origin, Action)}
        ] ++ DependencyOrigins
    end || {Action, Index} <- indexed(maps:get(steps, Task))]).

effect_origins(Task) ->
    indexed_pairs(<<"/effects">>, maps:get(values, maps:get(effects, Task)),
        fun(Item) -> maps:get(origin, Item) end).

requirement_origins(Task) ->
    requirement_origin_pairs(<<"/requirements">>,
        maps:get(values, maps:get(requirements, Task))).

requirement_origin_pairs(BasePointer, Requirements) ->
    lists:append([begin
        Base = indexed_pointer(BasePointer, Index),
        [
            {Base, maps:get(origin, Requirement)},
            {<<Base/binary, "/kind">>, maps:get(origin, Requirement)},
            {<<Base/binary, "/resource">>, maps:get(resource_origin, Requirement)}
        ]
    end || {Requirement, Index} <- indexed(Requirements)]).

scope_origins(Task) ->
    scope_origin_pairs(<<"/scopes">>, maps:get(scopes, Task)).

scope_origin_pairs(BasePointer, Scopes) ->
    lists:append([begin
        Field = maps:get(Key, Scopes),
        FieldPointer = <<BasePointer/binary, "/", (atom_to_binary(Key))/binary>>,
        [{FieldPointer, maps:get(origin, Field)} |
            indexed_pairs(FieldPointer, maps:get(values, Field),
                fun(Item) -> maps:get(origin, Item) end)]
    end || Key <- [models, workspaces, paths]]).

limit_origins(Task, Prefix) ->
    Limits = case Prefix of
        <<>> -> maps:get(limits, Task);
        _ -> maps:get(limits, maps:get(child, Task))
    end,
    Base = <<Prefix/binary, "/budgets">>,
    [begin
        Key = limit_key(maps:get(name, Item)),
        {<<Base/binary, "/", Key/binary>>, maps:get(value_origin, Item)}
    end || Item <- maps:get(values, Limits)].

error_origins(Task) ->
    lists:append([begin
        Base = indexed_pointer(<<"/error_branches">>, Index),
        [
            {Base, maps:get(origin, Branch)},
            {<<Base/binary, "/action">>, maps:get(origin, Branch)},
            {<<Base/binary, "/on">>, maps:get(reason_origin, Branch)},
            {<<Base/binary, "/terminal_class">>, maps:get(terminal_origin, Branch)}
        ]
    end || {Branch, Index} <- indexed(maps:get(values, maps:get(on_error, Task)))]).

child_origins(#{child := #{value := none}}) -> [];
child_origins(Task) ->
    Child = maps:get(child, Task),
    Prefix = <<"/child_attenuation">>,
    [
        {<<Prefix/binary, "/effects">>, maps:get(origin, maps:get(effects, Child))},
        {<<Prefix/binary, "/requirements">>, maps:get(origin, maps:get(requirements, Child))},
        {<<Prefix/binary, "/scopes">>, maps:get(origin, maps:get(scopes, Child))},
        {<<Prefix/binary, "/budgets">>, maps:get(origin, maps:get(limits, Child))}
    ] ++
        indexed_pairs(<<Prefix/binary, "/effects">>,
            maps:get(values, maps:get(effects, Child)), fun(Item) -> maps:get(origin, Item) end) ++
        requirement_origin_pairs(<<Prefix/binary, "/requirements">>,
            maps:get(values, maps:get(requirements, Child))) ++
        scope_origin_pairs(<<Prefix/binary, "/scopes">>, maps:get(scopes, Child)) ++
        limit_origins(Task, Prefix).

completion_origins(Task) ->
    lists:append([begin
        Base = indexed_pointer(<<"/completion_predicates">>, Index),
        [
            {Base, maps:get(origin, Predicate)},
            {<<Base/binary, "/kind">>, maps:get(origin, Predicate)},
            {<<Base/binary, "/target">>, maps:get(target_origin, Predicate)},
            {<<Base/binary, "/expected">>, maps:get(expected_origin, Predicate)}
        ]
    end || {Predicate, Index} <- indexed(
        maps:get(predicates, maps:get(completion, Task))) ]).

clarification_origins(Task) ->
    indexed_pairs(<<"/clarification_needs">>,
        maps:get(values, maps:get(clarify, Task)), fun(Item) -> maps:get(origin, Item) end).

indexed_pairs(Base, Values, OriginFun) ->
    [{indexed_pointer(Base, Index), OriginFun(Value)} || {Value, Index} <- indexed(Values)].

indexed_pointer(Base, Index) ->
    <<Base/binary, "/", (integer_to_binary(Index))/binary>>.

indexed(List) ->
    lists:zip(List, lists:seq(0, length(List) - 1)).

source_origin(Pointer, Origin) ->
    Origin#{source => alang_source, semantic_pointer => Pointer}.

contract_diagnostic(Path, Reason, Task) ->
    Pointer = pointer(Path),
    Origin = nearest_origin(source_origins(Task), Pointer),
    {Class, Code} = classify_contract(Path, Reason),
    diagnostic(Class, Code, Origin, reason_message(Reason)).

parser_diagnostic(#{code := Code, origin := Origin, message := Message}) ->
    {Class, StableCode} = classify_parser(Code),
    diagnostic(Class, StableCode, Origin#{source => alang_source}, Message).

classify_parser(Code) when Code =:= duplicate_input; Code =:= duplicate_step;
    Code =:= duplicate_dependency; Code =:= unresolved_name -> {name, Code};
classify_parser(Code) when Code =:= unknown_operation; Code =:= unknown_effect -> {name, Code};
classify_parser(Code) when Code =:= unknown_type; Code =:= invalid_input_type -> {type, Code};
classify_parser(Code) when Code =:= unsafe_completion_path; Code =:= unknown_completion_predicate;
    Code =:= invalid_completion_expected; Code =:= invalid_completion_expected_type ->
    {completion, Code};
classify_parser(Code) when Code =:= invalid_child_shape; Code =:= unknown_child_field ->
    {attenuation, Code};
classify_parser(Code) when Code =:= unknown_limit; Code =:= missing_limit;
    Code =:= limit_out_of_range; Code =:= limit_value_too_large -> {limit, Code};
classify_parser(Code) -> {syntax, Code}.

classify_contract(Path, {not_in_closed_enum, _}) ->
    case Path of
        [] -> {control_boundary, value_outside_closed_set};
        _ -> case lists:last(Path) of
            <<"type">> -> {type, unknown_type};
            <<"operation">> -> {name, unknown_operation};
            _ -> {control_boundary, value_outside_closed_set}
        end
    end;
classify_contract(_Path, {dependency_not_prior, _}) -> {control, dependency_not_prior};
classify_contract(_Path, Reason) when Reason =:= child_effect_widens_authority;
    Reason =:= child_requirement_widens_authority;
    Reason =:= child_scope_widens_authority;
    Reason =:= child_budget_exceeds_parent -> {attenuation, Reason};
classify_contract(_Path, {resource_outside_scope, _, _}) -> {authority, resource_outside_scope};
classify_contract(_Path, Reason) -> {control_boundary, contract_violation_code(Reason)}.

contract_violation_code({unknown_fields, _}) -> unknown_field;
contract_violation_code({missing_fields, _}) -> missing_field;
contract_violation_code(Reason) when is_atom(Reason) -> Reason;
contract_violation_code(_Reason) -> schema_violation.

pointer([]) -> <<>>;
pointer(Segments) ->
    iolist_to_binary([[<<"/">>, segment(Segment)] || Segment <- Segments]).

segment(Segment) when is_integer(Segment) -> integer_to_binary(Segment);
segment(Segment) -> Segment.

nearest_origin(Origins, Pointer) ->
    case maps:find(Pointer, Origins) of
        {ok, Origin} -> Origin;
        error when Pointer =:= <<>> -> default_origin();
        error -> nearest_origin(Origins, parent_pointer(Pointer))
    end.

parent_pointer(Pointer) ->
    Segments = binary:split(Pointer, <<"/">>, [global]),
    ParentSegments = lists:sublist(Segments, length(Segments) - 1),
    iolist_to_binary(lists:join(<<"/">>, ParentSegments)).

reason_message(Reason) ->
    iolist_to_binary(io_lib:format("~tp", [Reason])).

diagnostic(Class, Code, Origin, Message) ->
    #{class => Class, code => Code, severity => error, origin => Origin, message => Message}.

default_origin() ->
    #{byte => 0, line => 1, column => 1, source => alang_source}.
