-module(alang_fidelity_contract).

-export([
    decode_answer_key/1,
    decode_comprehension/1,
    normalize/1,
    semantic_digest/1,
    validate_answer_key/1,
    validate_comprehension/1
]).

-define(COMPREHENSION_FORMAT, <<"alang_task_comprehension_v1">>).
-define(ANSWER_KEY_FORMAT, <<"alang-answer-key-v1">>).

-spec decode_comprehension(binary()) -> {ok, map()} | {error, term()}.
decode_comprehension(Binary) ->
    decode_and_validate(Binary, fun validate_comprehension/1).

-spec decode_answer_key(binary()) -> {ok, map()} | {error, term()}.
decode_answer_key(Binary) ->
    decode_and_validate(Binary, fun validate_answer_key/1).

-spec validate_comprehension(term()) -> {ok, map()} | {error, term()}.
validate_comprehension(Value) ->
    try
        check_comprehension(Value),
        {ok, Value}
    catch
        throw:{contract_error, Path, Reason} ->
            {error, {contract_error, Path, Reason}}
    end.

-spec validate_answer_key(term()) -> {ok, map()} | {error, term()}.
validate_answer_key(Value) ->
    try
        closed_object(
            Value,
            [<<"format">>, <<"case_id">>, <<"semantic_digest">>, <<"expected">>],
            [<<"format">>, <<"case_id">>, <<"semantic_digest">>, <<"expected">>],
            []
        ),
        exact(maps:get(<<"format">>, Value), ?ANSWER_KEY_FORMAT, [<<"format">>]),
        CaseId = maps:get(<<"case_id">>, Value),
        identifier(CaseId, [<<"case_id">>]),
        Expected = maps:get(<<"expected">>, Value),
        check_comprehension(Expected),
        exact(maps:get(<<"case_id">>, Expected), CaseId, [<<"expected">>, <<"case_id">>]),
        Digest = maps:get(<<"semantic_digest">>, Value),
        sha256(Digest, [<<"semantic_digest">>]),
        exact(Digest, semantic_digest(Expected), [<<"semantic_digest">>]),
        {ok, Value}
    catch
        throw:{contract_error, Path, Reason} ->
            {error, {contract_error, Path, Reason}}
    end.

-spec semantic_digest(map()) -> binary().
semantic_digest(Comprehension) ->
    alang_fidelity_json:digest(normalize(Comprehension)).

-spec normalize(map()) -> map().
normalize(Comprehension) ->
    WithoutPresentation = maps:without([<<"format">>, <<"case_id">>], Comprehension),
    Child = maps:get(<<"child_attenuation">>, Comprehension),
    WithoutPresentation#{
        <<"goal_facts">> => lists:sort(maps:get(<<"goal_facts">>, Comprehension)),
        <<"inputs">> => sort_maps(maps:get(<<"inputs">>, Comprehension)),
        <<"actions">> => [normalize_action(Action) || Action <- maps:get(<<"actions">>, Comprehension)],
        <<"effects">> => lists:sort(maps:get(<<"effects">>, Comprehension)),
        <<"requirements">> => sort_maps(maps:get(<<"requirements">>, Comprehension)),
        <<"scopes">> => normalize_scopes(maps:get(<<"scopes">>, Comprehension)),
        <<"error_branches">> => sort_maps(maps:get(<<"error_branches">>, Comprehension)),
        <<"child_attenuation">> => normalize_child(Child),
        <<"completion_predicates">> => sort_maps(maps:get(<<"completion_predicates">>, Comprehension)),
        <<"clarification_needs">> => lists:sort(maps:get(<<"clarification_needs">>, Comprehension))
    }.

decode_and_validate(Binary, Validator) ->
    case alang_fidelity_json:decode(Binary) of
        {ok, Value} -> Validator(Value);
        {error, _} = Error -> Error
    end.

check_comprehension(Value) ->
    Keys = [
        <<"format">>,
        <<"case_id">>,
        <<"goal_facts">>,
        <<"inputs">>,
        <<"actions">>,
        <<"effects">>,
        <<"requirements">>,
        <<"scopes">>,
        <<"budgets">>,
        <<"error_branches">>,
        <<"child_attenuation">>,
        <<"completion_predicates">>,
        <<"clarification_needs">>,
        <<"terminal_class">>
    ],
    closed_object(Value, Keys, Keys, []),
    exact(maps:get(<<"format">>, Value), ?COMPREHENSION_FORMAT, [<<"format">>]),
    identifier(maps:get(<<"case_id">>, Value), [<<"case_id">>]),
    GoalFacts = maps:get(<<"goal_facts">>, Value),
    text_list(GoalFacts, 1, 32, [<<"goal_facts">>]),
    Inputs = maps:get(<<"inputs">>, Value),
    input_list(Inputs, [<<"inputs">>]),
    Actions = maps:get(<<"actions">>, Value),
    ActionIds = action_list(Actions, [<<"actions">>]),
    Effects = maps:get(<<"effects">>, Value),
    enum_list(
        Effects,
        [<<"model.generate">>, <<"workspace.write">>, <<"child.run">>],
        0,
        3,
        [<<"effects">>]
    ),
    Requirements = maps:get(<<"requirements">>, Value),
    requirement_list(Requirements, [<<"requirements">>]),
    Scopes = maps:get(<<"scopes">>, Value),
    check_scopes(Scopes, [<<"scopes">>]),
    check_requirement_scopes(Requirements, Scopes),
    Budgets = maps:get(<<"budgets">>, Value),
    check_budgets(Budgets, [<<"budgets">>]),
    check_error_branches(maps:get(<<"error_branches">>, Value), ActionIds, [<<"error_branches">>]),
    check_child(
        maps:get(<<"child_attenuation">>, Value),
        Effects,
        Requirements,
        Scopes,
        Budgets,
        [<<"child_attenuation">>]
    ),
    check_completion_predicates(
        maps:get(<<"completion_predicates">>, Value),
        [<<"completion_predicates">>]
    ),
    Clarifications = maps:get(<<"clarification_needs">>, Value),
    text_list(Clarifications, 0, 16, [<<"clarification_needs">>]),
    Terminal = maps:get(<<"terminal_class">>, Value),
    enum(Terminal, [<<"complete">>, <<"needs-clarification">>, <<"failed">>], [<<"terminal_class">>]),
    case Terminal of
        <<"needs-clarification">> ->
            ensure(Clarifications =/= [], [<<"clarification_needs">>], required_for_terminal_class);
        _ ->
            ok
    end.

input_list(Value, Path) ->
    list(Value, 0, 16, Path),
    Names = lists:map(
        fun({Input, Index}) ->
            InputPath = Path ++ [Index],
            closed_object(Input, [<<"name">>, <<"type">>, <<"required">>], [<<"name">>, <<"type">>, <<"required">>], InputPath),
            identifier(maps:get(<<"name">>, Input), InputPath ++ [<<"name">>]),
            enum(
                maps:get(<<"type">>, Input),
                [<<"text">>, <<"json">>, <<"path">>, <<"model-profile">>],
                InputPath ++ [<<"type">>]
            ),
            boolean(maps:get(<<"required">>, Input), InputPath ++ [<<"required">>]),
            maps:get(<<"name">>, Input)
        end,
        indexed(Value)
    ),
    unique(Names, Path, duplicate_input_name).

action_list(Value, Path) ->
    list(Value, 1, 16, Path),
    {Ids, _Seen} = lists:mapfoldl(
        fun({Action, Index}, Seen) ->
            ActionPath = Path ++ [Index],
            closed_object(Action, [<<"id">>, <<"operation">>, <<"depends_on">>], [<<"id">>, <<"operation">>, <<"depends_on">>], ActionPath),
            Id = maps:get(<<"id">>, Action),
            identifier(Id, ActionPath ++ [<<"id">>]),
            ensure(not lists:member(Id, Seen), ActionPath ++ [<<"id">>], duplicate_action_id),
            enum(
                maps:get(<<"operation">>, Action),
                [<<"model.generate">>, <<"model.repair">>, <<"workspace.write">>, <<"child.run">>, <<"complete">>],
                ActionPath ++ [<<"operation">>]
            ),
            Dependencies = maps:get(<<"depends_on">>, Action),
            identifier_list(Dependencies, 0, 15, ActionPath ++ [<<"depends_on">>]),
            lists:foreach(
                fun(Dependency) ->
                    ensure(lists:member(Dependency, Seen), ActionPath ++ [<<"depends_on">>], {dependency_not_prior, Dependency})
                end,
                Dependencies
            ),
            {Id, Seen ++ [Id]}
        end,
        [],
        indexed(Value)
    ),
    Ids.

requirement_list(Value, Path) ->
    list(Value, 0, 8, Path),
    lists:foreach(
        fun({Requirement, Index}) ->
            RequirementPath = Path ++ [Index],
            closed_object(Requirement, [<<"kind">>, <<"resource">>], [<<"kind">>, <<"resource">>], RequirementPath),
            enum(maps:get(<<"kind">>, Requirement), [<<"model">>, <<"workspace">>], RequirementPath ++ [<<"kind">>]),
            short_text(maps:get(<<"resource">>, Requirement), 1, 128, RequirementPath ++ [<<"resource">>])
        end,
        indexed(Value)
    ),
    unique(Value, Path, duplicate_requirement).

check_scopes(Value, Path) ->
    Keys = [<<"models">>, <<"workspaces">>, <<"paths">>],
    closed_object(Value, Keys, Keys, Path),
    text_list(maps:get(<<"models">>, Value), 0, 8, Path ++ [<<"models">>]),
    text_list(maps:get(<<"workspaces">>, Value), 0, 8, Path ++ [<<"workspaces">>]),
    text_list(maps:get(<<"paths">>, Value), 0, 16, Path ++ [<<"paths">>]).

check_requirement_scopes(Requirements, Scopes) ->
    lists:foreach(
        fun(Requirement) ->
            Kind = maps:get(<<"kind">>, Requirement),
            Resource = maps:get(<<"resource">>, Requirement),
            ScopeKey = case Kind of
                <<"model">> -> <<"models">>;
                <<"workspace">> -> <<"workspaces">>
            end,
            ensure(
                lists:member(Resource, maps:get(ScopeKey, Scopes)),
                [<<"requirements">>],
                {resource_outside_scope, Kind, Resource}
            )
        end,
        Requirements
    ).

check_budgets(Value, Path) ->
    Keys = [
        <<"steps">>,
        <<"model_calls">>,
        <<"repair_calls">>,
        <<"child_calls">>,
        <<"workspace_writes">>,
        <<"output_bytes">>,
        <<"timeout_ms">>
    ],
    closed_object(Value, Keys, Keys, Path),
    integer_range(maps:get(<<"steps">>, Value), 1, 64, Path ++ [<<"steps">>]),
    integer_range(maps:get(<<"model_calls">>, Value), 0, 8, Path ++ [<<"model_calls">>]),
    integer_range(maps:get(<<"repair_calls">>, Value), 0, 4, Path ++ [<<"repair_calls">>]),
    integer_range(maps:get(<<"child_calls">>, Value), 0, 8, Path ++ [<<"child_calls">>]),
    integer_range(maps:get(<<"workspace_writes">>, Value), 0, 8, Path ++ [<<"workspace_writes">>]),
    integer_range(maps:get(<<"output_bytes">>, Value), 1, 8192, Path ++ [<<"output_bytes">>]),
    integer_range(maps:get(<<"timeout_ms">>, Value), 1, 120000, Path ++ [<<"timeout_ms">>]).

check_error_branches(Value, ActionIds, Path) ->
    list(Value, 0, 16, Path),
    lists:foreach(
        fun({Branch, Index}) ->
            BranchPath = Path ++ [Index],
            Keys = [<<"action">>, <<"on">>, <<"terminal_class">>],
            closed_object(Branch, Keys, Keys, BranchPath),
            Action = maps:get(<<"action">>, Branch),
            identifier(Action, BranchPath ++ [<<"action">>]),
            ensure(lists:member(Action, ActionIds), BranchPath ++ [<<"action">>], unknown_action),
            enum(
                maps:get(<<"on">>, Branch),
                [<<"denied">>, <<"timeout">>, <<"invalid-output">>, <<"verification-failed">>],
                BranchPath ++ [<<"on">>]
            ),
            enum(
                maps:get(<<"terminal_class">>, Branch),
                [<<"needs-clarification">>, <<"failed">>],
                BranchPath ++ [<<"terminal_class">>]
            )
        end,
        indexed(Value)
    ),
    unique(Value, Path, duplicate_error_branch).

check_child(null, _Effects, _Requirements, _Scopes, _Budgets, _Path) ->
    ok;
check_child(Value, Effects, Requirements, Scopes, Budgets, Path) ->
    Keys = [<<"effects">>, <<"requirements">>, <<"scopes">>, <<"budgets">>],
    closed_object(Value, Keys, Keys, Path),
    ChildEffects = maps:get(<<"effects">>, Value),
    enum_list(
        ChildEffects,
        [<<"model.generate">>, <<"workspace.write">>, <<"child.run">>],
        0,
        3,
        Path ++ [<<"effects">>]
    ),
    subset(ChildEffects, Effects, Path ++ [<<"effects">>], child_effect_widens_authority),
    ChildRequirements = maps:get(<<"requirements">>, Value),
    requirement_list(ChildRequirements, Path ++ [<<"requirements">>]),
    subset(ChildRequirements, Requirements, Path ++ [<<"requirements">>], child_requirement_widens_authority),
    ChildScopes = maps:get(<<"scopes">>, Value),
    check_scopes(ChildScopes, Path ++ [<<"scopes">>]),
    lists:foreach(
        fun(Key) ->
            subset(
                maps:get(Key, ChildScopes),
                maps:get(Key, Scopes),
                Path ++ [<<"scopes">>, Key],
                child_scope_widens_authority
            )
        end,
        [<<"models">>, <<"workspaces">>, <<"paths">>]
    ),
    check_requirement_scopes(ChildRequirements, ChildScopes),
    ChildBudgets = maps:get(<<"budgets">>, Value),
    check_budgets(ChildBudgets, Path ++ [<<"budgets">>]),
    lists:foreach(
        fun(Key) ->
            ensure(
                maps:get(Key, ChildBudgets) =< maps:get(Key, Budgets),
                Path ++ [<<"budgets">>, Key],
                child_budget_exceeds_parent
            )
        end,
        maps:keys(Budgets)
    ).

check_completion_predicates(Value, Path) ->
    list(Value, 1, 16, Path),
    lists:foreach(
        fun({Predicate, Index}) ->
            PredicatePath = Path ++ [Index],
            Keys = [<<"kind">>, <<"target">>, <<"expected">>],
            closed_object(Predicate, Keys, Keys, PredicatePath),
            Kind = maps:get(<<"kind">>, Predicate),
            enum(
                Kind,
                [<<"artifact-exists">>, <<"sha256">>, <<"max-bytes">>, <<"utf8">>, <<"markdown-h1">>, <<"journal-succeeded">>, <<"clarification-recorded">>],
                PredicatePath ++ [<<"kind">>]
            ),
            short_text(maps:get(<<"target">>, Predicate), 1, 256, PredicatePath ++ [<<"target">>]),
            check_predicate_expected(Kind, maps:get(<<"expected">>, Predicate), PredicatePath ++ [<<"expected">>])
        end,
        indexed(Value)
    ),
    unique(Value, Path, duplicate_completion_predicate).

check_predicate_expected(<<"sha256">>, Value, Path) -> sha256(Value, Path);
check_predicate_expected(<<"max-bytes">>, Value, Path) -> integer_range(Value, 1, 8192, Path);
check_predicate_expected(<<"markdown-h1">>, Value, Path) -> short_text(Value, 1, 256, Path);
check_predicate_expected(_BooleanKind, Value, Path) -> boolean(Value, Path).

normalize_action(Action) ->
    Action#{<<"depends_on">> => lists:sort(maps:get(<<"depends_on">>, Action))}.

normalize_scopes(Scopes) ->
    maps:map(fun(_Key, Values) -> lists:sort(Values) end, Scopes).

normalize_child(null) ->
    null;
normalize_child(Child) ->
    Child#{
        <<"effects">> => lists:sort(maps:get(<<"effects">>, Child)),
        <<"requirements">> => sort_maps(maps:get(<<"requirements">>, Child)),
        <<"scopes">> => normalize_scopes(maps:get(<<"scopes">>, Child))
    }.

sort_maps(List) ->
    lists:sort(fun(Left, Right) -> term_to_binary(Left, [deterministic]) =< term_to_binary(Right, [deterministic]) end, List).

closed_object(Value, Allowed, Required, Path) ->
    ensure(is_map(Value), Path, expected_object),
    Keys = maps:keys(Value),
    Unknown = Keys -- Allowed,
    Missing = Required -- Keys,
    ensure(Unknown =:= [], Path, {unknown_fields, lists:sort(Unknown)}),
    ensure(Missing =:= [], Path, {missing_fields, lists:sort(Missing)}).

text_list(Value, Minimum, Maximum, Path) ->
    list(Value, Minimum, Maximum, Path),
    lists:foreach(
        fun({Text, Index}) -> short_text(Text, 1, 4096, Path ++ [Index]) end,
        indexed(Value)
    ),
    unique(Value, Path, duplicate_value).

identifier_list(Value, Minimum, Maximum, Path) ->
    list(Value, Minimum, Maximum, Path),
    lists:foreach(fun({Id, Index}) -> identifier(Id, Path ++ [Index]) end, indexed(Value)),
    unique(Value, Path, duplicate_identifier).

enum_list(Value, Allowed, Minimum, Maximum, Path) ->
    list(Value, Minimum, Maximum, Path),
    lists:foreach(fun({Item, Index}) -> enum(Item, Allowed, Path ++ [Index]) end, indexed(Value)),
    unique(Value, Path, duplicate_enum_value).

list(Value, Minimum, Maximum, Path) ->
    ensure(is_list(Value), Path, expected_array),
    Length = length(Value),
    ensure(Length >= Minimum andalso Length =< Maximum, Path, {array_size_out_of_bounds, Length, Minimum, Maximum}).

identifier(Value, Path) ->
    short_text(Value, 1, 64, Path),
    ensure(re:run(Value, <<"^[a-z][a-z0-9-]{0,63}$">>, [{capture, none}]) =:= match, Path, invalid_identifier).

short_text(Value, Minimum, Maximum, Path) ->
    ensure(is_binary(Value), Path, expected_string),
    Size = byte_size(Value),
    ensure(Size >= Minimum andalso Size =< Maximum, Path, {string_size_out_of_bounds, Size, Minimum, Maximum}),
    ensure(valid_utf8(Value), Path, invalid_utf8),
    ensure(binary:match(Value, <<0>>) =:= nomatch, Path, nul_not_allowed).

sha256(Value, Path) ->
    ensure(is_binary(Value), Path, expected_sha256),
    ensure(re:run(Value, <<"^[0-9a-f]{64}$">>, [{capture, none}]) =:= match, Path, expected_sha256).

integer_range(Value, Minimum, Maximum, Path) ->
    ensure(is_integer(Value), Path, expected_integer),
    ensure(Value >= Minimum andalso Value =< Maximum, Path, {integer_out_of_bounds, Value, Minimum, Maximum}).

boolean(Value, Path) ->
    ensure(is_boolean(Value), Path, expected_boolean).

enum(Value, Allowed, Path) ->
    ensure(lists:member(Value, Allowed), Path, {not_in_closed_enum, Value}).

exact(Value, Expected, Path) ->
    ensure(Value =:= Expected, Path, {expected_exact_value, Expected, Value}).

unique(Value, Path, Reason) ->
    ensure(length(Value) =:= length(lists:usort(Value)), Path, Reason).

subset(Candidate, Parent, Path, Reason) ->
    ensure(lists:all(fun(Item) -> lists:member(Item, Parent) end, Candidate), Path, Reason).

valid_utf8(Value) ->
    case unicode:characters_to_list(Value, utf8) of
        List when is_list(List) -> true;
        _ -> false
    end.

indexed(List) ->
    lists:zip(List, lists:seq(0, length(List) - 1)).

ensure(true, _Path, _Reason) -> ok;
ensure(false, Path, Reason) -> fail(Path, Reason).

fail(Path, Reason) ->
    throw({contract_error, Path, Reason}).
