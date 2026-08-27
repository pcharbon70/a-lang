-module(alang_compact_model).

-export([decode/1, encode/1, load_contract/1, validate_contract/1]).

-define(HEADER, <<"#!alang-model-v1\n">>).
-define(MAX_BYTES, 32768).
-define(MAX_ALIASES, 64).

-spec load_contract(file:filename()) -> {ok, map()} | {error, term()}.
load_contract(Path) ->
    case alang_fidelity_json:decode_file(Path) of
        {ok, Value} -> validate_contract(Value);
        {error, Reason} -> {error, {model_contract_read_failed, Reason}}
    end.

-spec validate_contract(term()) -> {ok, map()} | {error, term()}.
validate_contract(Value) when is_map(Value) ->
    Expected = expected_contract(),
    case Value =:= Expected of
        true -> {ok, Value};
        false -> {error, {model_contract_mismatch,
            alang_fidelity_json:digest(Expected), alang_fidelity_json:digest(Value)}}
    end;
validate_contract(Value) -> {error, {invalid_model_contract, Value}}.

-spec encode(map()) -> {ok, map()} | {error, term()}.
encode(Oracle) ->
    case alang_fidelity_contract:validate_comprehension(Oracle) of
        {ok, _} ->
            try
                Canonical = canonical_oracle(Oracle),
                Plan = derivation_plan(Canonical),
                {AliasForward, AliasReverse} = build_aliases(Canonical, Plan),
                Compact = compact_task(Canonical, Plan, AliasForward, AliasReverse),
                {ok, Json} = alang_fidelity_json:encode_canonical(Compact),
                Binary = <<?HEADER/binary, Json/binary>>,
                ensure(byte_size(Binary) =< ?MAX_BYTES, [],
                    {representation_too_large, byte_size(Binary), ?MAX_BYTES}),
                {ok, #{bytes => Binary, aliases => AliasReverse,
                    derived => maps:get(top, Plan), semantic_digest =>
                        alang_fidelity_contract:semantic_digest(Canonical)}}
            catch
                throw:{compact_model_error, Path, Reason} ->
                    {error, {compact_model_error, Path, Reason}};
                error:{badmatch, {error, Reason}} ->
                    {error, {compact_model_error, [], Reason}}
            end;
        {error, Reason} -> {error, {invalid_checked_semantics, Reason}}
    end.

-spec decode(binary()) -> {ok, map()} | {error, term()}.
decode(<<"#!alang-model-v1\n", Json/binary>> = Binary) when byte_size(Binary) =< ?MAX_BYTES ->
    case alang_fidelity_json:decode(Json) of
        {ok, Value} -> decode_value(Value);
        {error, Reason} -> {error, {compact_model_error, [], Reason}}
    end;
decode(<<"#!alang-model-", _/binary>>) ->
    {error, {compact_model_error, [<<"version">>], unsupported_model_version}};
decode(Binary) when is_binary(Binary), byte_size(Binary) > ?MAX_BYTES ->
    {error, {compact_model_error, [], {representation_too_large, byte_size(Binary), ?MAX_BYTES}}};
decode(Binary) when is_binary(Binary) ->
    {error, {compact_model_error, [<<"version">>], missing_model_version}};
decode(_) -> {error, {compact_model_error, [], expected_binary}}.

decode_value(Value) ->
    try
        RootKeys = [<<"task">>, <<"f">>, <<"i">>, <<"step">>, <<"effects">>,
            <<"use">>, <<"at">>, <<"cap">>, <<"err">>, <<"kid">>, <<"ok">>,
            <<"ask">>, <<"end">>, <<"derived">>, <<"aliases">>],
        Required = [<<"task">>, <<"f">>, <<"i">>, <<"step">>, <<"at">>,
            <<"cap">>, <<"kid">>, <<"ok">>, <<"end">>, <<"derived">>, <<"aliases">>],
        closed(Value, RootKeys, Required, []),
        Aliases = validate_aliases(maps:get(<<"aliases">>, Value)),
        validate_alias_usage(Value, Aliases),
        Derived = validate_derived(maps:get(<<"derived">>, Value),
            [<<"effects">>, <<"requirements">>], [<<"derived">>]),
        Inputs = decode_inputs(maps:get(<<"i">>, Value), Aliases),
        Actions = decode_actions(maps:get(<<"step">>, Value), Aliases),
        Scopes = decode_scopes(maps:get(<<"at">>, Value), Aliases, [<<"at">>]),
        Effects = decode_or_derive_effects(Value, Derived, Actions),
        Requirements = decode_or_derive_requirements(Value, Derived, Scopes, Aliases),
        Budgets = decode_budgets(maps:get(<<"cap">>, Value), [<<"cap">>]),
        Errors = decode_errors(maps:get(<<"err">>, Value, []), Aliases),
        Child = decode_child(maps:get(<<"kid">>, Value), Aliases),
        Predicates = decode_predicates(maps:get(<<"ok">>, Value), Aliases),
        Clarifications = binary_list(maps:get(<<"ask">>, Value, []), [<<"ask">>]),
        Comprehension = #{
            <<"format">> => <<"alang_task_comprehension_v1">>,
            <<"case_id">> => binary_value(maps:get(<<"task">>, Value), [<<"task">>]),
            <<"goal_facts">> => binary_list(maps:get(<<"f">>, Value), [<<"f">>]),
            <<"inputs">> => Inputs,
            <<"actions">> => Actions,
            <<"effects">> => Effects,
            <<"requirements">> => Requirements,
            <<"scopes">> => Scopes,
            <<"budgets">> => Budgets,
            <<"error_branches">> => Errors,
            <<"child_attenuation">> => Child,
            <<"completion_predicates">> => Predicates,
            <<"clarification_needs">> => Clarifications,
            <<"terminal_class">> => binary_value(maps:get(<<"end">>, Value), [<<"end">>])
        },
        case alang_fidelity_contract:validate_comprehension(Comprehension) of
            {ok, _} ->
                Normalized = alang_fidelity_contract:normalize(Comprehension),
                {ok, #{source_format => <<"alang-model-v1">>, semantic => Normalized,
                    semantic_digest => alang_fidelity_contract:semantic_digest(Comprehension),
                    aliases => Aliases, derived => Derived, origins => #{}}};
            {error, SemanticReason} -> fail([], {invalid_reconstructed_semantics, SemanticReason})
        end
    catch
        throw:{compact_model_error, ErrorPath, CaughtReason} ->
            {error, {compact_model_error, ErrorPath, CaughtReason}};
        error:ShapeReason ->
            {error, {compact_model_error, [], {invalid_model_shape, ShapeReason}}}
    end.

canonical_oracle(Oracle) ->
    (alang_fidelity_contract:normalize(Oracle))#{
        <<"format">> => <<"alang_task_comprehension_v1">>,
        <<"case_id">> => maps:get(<<"case_id">>, Oracle)
    }.

derivation_plan(Oracle) ->
    EffectsDerived = derive_effects(maps:get(<<"actions">>, Oracle)) =:= maps:get(<<"effects">>, Oracle),
    RequirementsDerived = derive_requirements(maps:get(<<"scopes">>, Oracle)) =:=
        maps:get(<<"requirements">>, Oracle),
    Top = derivation_names(EffectsDerived, RequirementsDerived),
    ChildPlan = case maps:get(<<"child_attenuation">>, Oracle) of
        null -> [];
        Child ->
            case derive_requirements(maps:get(<<"scopes">>, Child)) =:= maps:get(<<"requirements">>, Child) of
                true -> [<<"requirements">>];
                false -> []
            end
    end,
    #{top => Top, child => ChildPlan}.

derivation_names(Effects, Requirements) ->
    [Name || {Name, true} <- [{<<"effects">>, Effects}, {<<"requirements">>, Requirements}]].

compact_task(Oracle, Plan, Forward, Reverse) ->
    Base0 = #{
        <<"task">> => maps:get(<<"case_id">>, Oracle),
        <<"f">> => maps:get(<<"goal_facts">>, Oracle),
        <<"i">> => [compact_input(Input, Forward) || Input <- maps:get(<<"inputs">>, Oracle)],
        <<"step">> => [compact_action(Action, Forward) || Action <- maps:get(<<"actions">>, Oracle)],
        <<"at">> => compact_scopes(maps:get(<<"scopes">>, Oracle), Forward),
        <<"cap">> => compact_budgets(maps:get(<<"budgets">>, Oracle)),
        <<"kid">> => compact_child(maps:get(<<"child_attenuation">>, Oracle),
            maps:get(child, Plan), Forward),
        <<"ok">> => [compact_predicate(Predicate, Forward) || Predicate <-
            maps:get(<<"completion_predicates">>, Oracle)],
        <<"end">> => maps:get(<<"terminal_class">>, Oracle),
        <<"derived">> => maps:get(top, Plan),
        <<"aliases">> => Reverse
    },
    Base1 = optional_list(<<"err">>, [compact_error(Error, Forward) || Error <-
        maps:get(<<"error_branches">>, Oracle)], Base0),
    Base2 = optional_list(<<"ask">>, maps:get(<<"clarification_needs">>, Oracle), Base1),
    Base3 = case lists:member(<<"effects">>, maps:get(top, Plan)) of
        true -> Base2;
        false -> Base2#{<<"effects">> => [effect_alias(Effect) || Effect <- maps:get(<<"effects">>, Oracle)]}
    end,
    case lists:member(<<"requirements">>, maps:get(top, Plan)) of
        true -> Base3;
        false -> Base3#{<<"use">> => [compact_requirement(Requirement, Forward) ||
            Requirement <- maps:get(<<"requirements">>, Oracle)]}
    end.

compact_input(Input, Forward) ->
    Input#{<<"name">> := reference(maps:get(<<"name">>, Input), Forward)}.

compact_action(Action, Forward) ->
    #{<<"id">> => reference(maps:get(<<"id">>, Action), Forward),
        <<"operation">> => operation_alias(maps:get(<<"operation">>, Action)),
        <<"<-">> => [reference(Value, Forward) || Value <- maps:get(<<"depends_on">>, Action)]}.

compact_requirement(Requirement, Forward) ->
    Requirement#{<<"resource">> := reference(maps:get(<<"resource">>, Requirement), Forward)}.

compact_scopes(Scopes, Forward) ->
    optional_list(<<"p">>, maps:get(<<"paths">>, Scopes),
        optional_list(<<"w">>, [reference(Value, Forward) || Value <- maps:get(<<"workspaces">>, Scopes)],
            optional_list(<<"m">>, [reference(Value, Forward) || Value <- maps:get(<<"models">>, Scopes)], #{}))).

compact_budgets(Budgets) ->
    #{<<"s">> => maps:get(<<"steps">>, Budgets),
        <<"m">> => maps:get(<<"model_calls">>, Budgets),
        <<"r">> => maps:get(<<"repair_calls">>, Budgets),
        <<"c">> => maps:get(<<"child_calls">>, Budgets),
        <<"w">> => maps:get(<<"workspace_writes">>, Budgets),
        <<"b">> => maps:get(<<"output_bytes">>, Budgets),
        <<"t">> => maps:get(<<"timeout_ms">>, Budgets)}.

compact_error(Error, Forward) ->
    #{<<"action">> => reference(maps:get(<<"action">>, Error), Forward),
        <<"on">> => maps:get(<<"on">>, Error), <<"end">> => maps:get(<<"terminal_class">>, Error)}.

compact_child(null, _Derived, _Forward) -> null;
compact_child(Child, Derived, Forward) ->
    Base = #{<<"effects">> => [effect_alias(Effect) || Effect <- maps:get(<<"effects">>, Child)],
        <<"at">> => compact_scopes(maps:get(<<"scopes">>, Child), Forward),
        <<"cap">> => compact_budgets(maps:get(<<"budgets">>, Child)),
        <<"derived">> => Derived},
    case lists:member(<<"requirements">>, Derived) of
        true -> Base;
        false -> Base#{<<"use">> => [compact_requirement(Requirement, Forward) ||
            Requirement <- maps:get(<<"requirements">>, Child)]}
    end.

compact_predicate(Predicate, Forward) ->
    Kind = maps:get(<<"kind">>, Predicate),
    Target0 = maps:get(<<"target">>, Predicate),
    Target = case Kind of
        <<"journal-succeeded">> -> reference(Target0, Forward);
        <<"clarification-recorded">> -> reference(Target0, Forward);
        _ -> Target0
    end,
    #{<<"kind">> => predicate_alias(Kind), <<"target">> => Target,
        <<"expected">> => maps:get(<<"expected">>, Predicate)}.

optional_list(_Key, [], Map) -> Map;
optional_list(Key, Value, Map) -> Map#{Key => Value}.

build_aliases(Oracle, Plan) ->
    Pairs = eligible_pairs(Oracle, Plan),
    lists:foreach(fun({_Category, Value}) ->
        ensure(not alias_reference(Value), [<<"aliases">>], {literal_alias_collision, Value})
    end, Pairs),
    Counts = count_values(Pairs, #{}),
    Categories = value_categories(Pairs, #{}),
    Repeated = unique_order([Value || {_Category, Value} <- Pairs,
        maps:get(Value, Counts) >= 2]),
    ensure(length(Repeated) =< ?MAX_ALIASES, [<<"aliases">>], too_many_aliases),
    lists:foreach(fun(Value) ->
        ensure(length(maps:get(Value, Categories)) =:= 1, [<<"aliases">>],
            {cross_namespace_shadowing, Value})
    end, Repeated),
    Indexed = lists:zip(Repeated, lists:seq(0, length(Repeated) - 1)),
    Forward = maps:from_list([{Value, <<"@n", (integer_to_binary(Index))/binary>>}
        || {Value, Index} <- Indexed]),
    Reverse = maps:from_list([{<<"n", (integer_to_binary(Index))/binary>>, Value}
        || {Value, Index} <- Indexed]),
    {Forward, Reverse}.

eligible_pairs(Oracle, Plan) ->
    Inputs = [{input, maps:get(<<"name">>, Input)} || Input <- maps:get(<<"inputs">>, Oracle)],
    Actions = [{action, maps:get(<<"id">>, Action)} || Action <- maps:get(<<"actions">>, Oracle)],
    TopResources = resource_pairs(Oracle, maps:get(top, Plan)),
    ChildResources = case maps:get(<<"child_attenuation">>, Oracle) of
        null -> [];
        Child -> resource_pairs(Child, maps:get(child, Plan))
    end,
    ActionReferences = lists:append([[{action, Value} || Value <- maps:get(<<"depends_on">>, Action)]
        || Action <- maps:get(<<"actions">>, Oracle)]) ++
        [{action, maps:get(<<"action">>, Error)} || Error <- maps:get(<<"error_branches">>, Oracle)],
    PredicateReferences = lists:append([predicate_reference(Predicate) || Predicate <-
        maps:get(<<"completion_predicates">>, Oracle)]),
    Inputs ++ Actions ++ TopResources ++ ChildResources ++ ActionReferences ++ PredicateReferences.

resource_pairs(Value, Derived) ->
    Explicit = case lists:member(<<"requirements">>, Derived) of
        true -> [];
        false -> [{resource_category(maps:get(<<"kind">>, Requirement)), maps:get(<<"resource">>, Requirement)}
            || Requirement <- maps:get(<<"requirements">>, Value)]
    end,
    Scopes = maps:get(<<"scopes">>, Value),
    Explicit ++ [{model_resource, Resource} || Resource <- maps:get(<<"models">>, Scopes)] ++
        [{workspace_resource, Resource} || Resource <- maps:get(<<"workspaces">>, Scopes)].

predicate_reference(#{<<"kind">> := <<"journal-succeeded">>, <<"target">> := Value}) -> [{action, Value}];
predicate_reference(#{<<"kind">> := <<"clarification-recorded">>, <<"target">> := Value}) -> [{input, Value}];
predicate_reference(_) -> [].

resource_category(<<"model">>) -> model_resource;
resource_category(<<"workspace">>) -> workspace_resource.

count_values([], Acc) -> Acc;
count_values([{_Category, Value} | Rest], Acc) ->
    count_values(Rest, Acc#{Value => maps:get(Value, Acc, 0) + 1}).

value_categories([], Acc) -> Acc;
value_categories([{Category, Value} | Rest], Acc) ->
    Existing = maps:get(Value, Acc, []),
    value_categories(Rest, Acc#{Value => lists:usort([Category | Existing])}).

unique_order(Values) -> unique_order(Values, #{}, []).
unique_order([], _Seen, Acc) -> lists:reverse(Acc);
unique_order([Value | Rest], Seen, Acc) ->
    case maps:is_key(Value, Seen) of
        true -> unique_order(Rest, Seen, Acc);
        false -> unique_order(Rest, Seen#{Value => true}, [Value | Acc])
    end.

reference(Value, Forward) -> maps:get(Value, Forward, Value).

validate_aliases(Value) ->
    ensure(is_map(Value), [<<"aliases">>], expected_object),
    ensure(maps:size(Value) =< ?MAX_ALIASES, [<<"aliases">>], too_many_aliases),
    Keys = maps:keys(Value),
    Expected = [<<"n", (integer_to_binary(Index))/binary>> || Index <-
        lists:seq(0, length(Keys) - 1)],
    ensure(lists:sort(Keys) =:= lists:sort(Expected), [<<"aliases">>], noncontiguous_alias_keys),
    Values = maps:values(Value),
    lists:foreach(fun(Item) ->
        ensure(is_binary(Item) andalso not alias_reference(Item), [<<"aliases">>], invalid_alias_value)
    end, Values),
    ensure(length(Values) =:= length(lists:usort(Values)), [<<"aliases">>], duplicate_alias_value),
    Value.

validate_alias_usage(Root, Aliases) ->
    Pairs = compact_eligible_pairs(Root),
    Usage = lists:foldl(fun({Category, Value}, Acc) ->
        case alias_key(Value) of
            none -> Acc;
            Key ->
                ensure(maps:is_key(Key, Aliases), [<<"aliases">>, Key], unknown_alias),
                {Count, Categories} = maps:get(Key, Acc, {0, []}),
                Acc#{Key => {Count + 1, lists:usort([Category | Categories])}}
        end
    end, #{}, Pairs),
    lists:foreach(fun(Key) ->
        case maps:get(Key, Usage, {0, []}) of
            {Count, [Category]} when Count >= 2, is_atom(Category) -> ok;
            {Count, Categories} -> fail([<<"aliases">>, Key],
                {invalid_alias_usage, Count, Categories})
        end
    end, maps:keys(Aliases)).

compact_eligible_pairs(Root) ->
    Inputs = [{input, maps:get(<<"name">>, Input)} || Input <- map_list(maps:get(<<"i">>, Root), [<<"i">>])],
    Steps = map_list(maps:get(<<"step">>, Root), [<<"step">>]),
    Actions = lists:append([[{action, maps:get(<<"id">>, Step)} |
        [{action, Value} || Value <- list_value(maps:get(<<"<-">>, Step), [<<"step">>, <<"<-">>])]]
        || Step <- Steps]),
    TopResources = compact_resource_pairs(Root),
    Errors = [{action, maps:get(<<"action">>, Error)} || Error <-
        map_list(maps:get(<<"err">>, Root, []), [<<"err">>])],
    ChildResources = case maps:get(<<"kid">>, Root) of
        null -> [];
        Child when is_map(Child) -> compact_resource_pairs(Child);
        _ -> fail([<<"kid">>], expected_object_or_null)
    end,
    Predicates = lists:append([compact_predicate_reference(Predicate) || Predicate <-
        map_list(maps:get(<<"ok">>, Root), [<<"ok">>])]),
    Inputs ++ Actions ++ TopResources ++ ChildResources ++ Errors ++ Predicates.

compact_resource_pairs(Value) ->
    Explicit = [{resource_category(maps:get(<<"kind">>, Requirement)),
        maps:get(<<"resource">>, Requirement)} || Requirement <-
        map_list(maps:get(<<"use">>, Value, []), [<<"use">>])],
    Scopes = maps:get(<<"at">>, Value),
    ensure(is_map(Scopes), [<<"at">>], expected_object),
    Explicit ++ [{model_resource, Item} || Item <- list_value(maps:get(<<"m">>, Scopes, []), [<<"at">>, <<"m">>])] ++
        [{workspace_resource, Item} || Item <- list_value(maps:get(<<"w">>, Scopes, []), [<<"at">>, <<"w">>])].

compact_predicate_reference(Predicate) ->
    case maps:get(<<"kind">>, Predicate) of
        <<"journal">> -> [{action, maps:get(<<"target">>, Predicate)}];
        <<"asked">> -> [{input, maps:get(<<"target">>, Predicate)}];
        _ -> []
    end.

decode_inputs(Value, Aliases) ->
    [begin
        Path = [<<"i">>, Index],
        closed(Input, [<<"name">>, <<"type">>, <<"required">>],
            [<<"name">>, <<"type">>, <<"required">>], Path),
        #{<<"name">> => expand_reference(maps:get(<<"name">>, Input), Aliases, Path ++ [<<"name">>]),
            <<"type">> => maps:get(<<"type">>, Input), <<"required">> => maps:get(<<"required">>, Input)}
    end || {Input, Index} <- indexed(map_list(Value, [<<"i">>]))].

decode_actions(Value, Aliases) ->
    [begin
        Path = [<<"step">>, Index],
        closed(Action, [<<"id">>, <<"operation">>, <<"<-">>],
            [<<"id">>, <<"operation">>, <<"<-">>], Path),
        #{<<"id">> => expand_reference(maps:get(<<"id">>, Action), Aliases, Path ++ [<<"id">>]),
            <<"operation">> => decode_operation(maps:get(<<"operation">>, Action), Path ++ [<<"operation">>]),
            <<"depends_on">> => [expand_reference(Item, Aliases, Path ++ [<<"<-">>]) ||
                Item <- binary_list(maps:get(<<"<-">>, Action), Path ++ [<<"<-">>])]}
    end || {Action, Index} <- indexed(map_list(Value, [<<"step">>]))].

decode_scopes(Value, Aliases, Path) ->
    closed(Value, [<<"m">>, <<"w">>, <<"p">>], [], Path),
    #{<<"models">> => [expand_reference(Item, Aliases, Path ++ [<<"m">>]) ||
            Item <- binary_list(maps:get(<<"m">>, Value, []), Path ++ [<<"m">>])],
        <<"workspaces">> => [expand_reference(Item, Aliases, Path ++ [<<"w">>]) ||
            Item <- binary_list(maps:get(<<"w">>, Value, []), Path ++ [<<"w">>])],
        <<"paths">> => binary_list(maps:get(<<"p">>, Value, []), Path ++ [<<"p">>])}.

decode_budgets(Value, Path) ->
    Keys = [<<"s">>, <<"m">>, <<"r">>, <<"c">>, <<"w">>, <<"b">>, <<"t">>],
    closed(Value, Keys, Keys, Path),
    #{<<"steps">> => integer_value(maps:get(<<"s">>, Value), Path ++ [<<"s">>]),
        <<"model_calls">> => integer_value(maps:get(<<"m">>, Value), Path ++ [<<"m">>]),
        <<"repair_calls">> => integer_value(maps:get(<<"r">>, Value), Path ++ [<<"r">>]),
        <<"child_calls">> => integer_value(maps:get(<<"c">>, Value), Path ++ [<<"c">>]),
        <<"workspace_writes">> => integer_value(maps:get(<<"w">>, Value), Path ++ [<<"w">>]),
        <<"output_bytes">> => integer_value(maps:get(<<"b">>, Value), Path ++ [<<"b">>]),
        <<"timeout_ms">> => integer_value(maps:get(<<"t">>, Value), Path ++ [<<"t">>])}.

decode_or_derive_effects(Value, Derived, Actions) ->
    case lists:member(<<"effects">>, Derived) of
        true ->
            ensure(not maps:is_key(<<"effects">>, Value), [<<"effects">>], present_with_derivation),
            derive_effects(Actions);
        false ->
            ensure(maps:is_key(<<"effects">>, Value), [<<"effects">>], missing_without_derivation),
            [decode_effect(Item, [<<"effects">>]) || Item <- binary_list(maps:get(<<"effects">>, Value), [<<"effects">>])]
    end.

decode_or_derive_requirements(Value, Derived, Scopes, Aliases) ->
    case lists:member(<<"requirements">>, Derived) of
        true ->
            ensure(not maps:is_key(<<"use">>, Value), [<<"use">>], present_with_derivation),
            derive_requirements(Scopes);
        false ->
            ensure(maps:is_key(<<"use">>, Value), [<<"use">>], missing_without_derivation),
            decode_requirements(maps:get(<<"use">>, Value), Aliases, [<<"use">>])
    end.

decode_requirements(Value, Aliases, Path) ->
    [begin
        ItemPath = Path ++ [Index],
        closed(Requirement, [<<"kind">>, <<"resource">>], [<<"kind">>, <<"resource">>], ItemPath),
        #{<<"kind">> => maps:get(<<"kind">>, Requirement),
            <<"resource">> => expand_reference(maps:get(<<"resource">>, Requirement), Aliases,
                ItemPath ++ [<<"resource">>])}
    end || {Requirement, Index} <- indexed(map_list(Value, Path))].

decode_errors(Value, Aliases) ->
    [begin
        Path = [<<"err">>, Index],
        closed(Error, [<<"action">>, <<"on">>, <<"end">>],
            [<<"action">>, <<"on">>, <<"end">>], Path),
        #{<<"action">> => expand_reference(maps:get(<<"action">>, Error), Aliases, Path ++ [<<"action">>]),
            <<"on">> => maps:get(<<"on">>, Error),
            <<"terminal_class">> => maps:get(<<"end">>, Error)}
    end || {Error, Index} <- indexed(map_list(Value, [<<"err">>]))].

decode_child(null, _Aliases) -> null;
decode_child(Value, Aliases) ->
    Path = [<<"kid">>],
    closed(Value, [<<"effects">>, <<"use">>, <<"at">>, <<"cap">>, <<"derived">>],
        [<<"effects">>, <<"at">>, <<"cap">>, <<"derived">>], Path),
    Derived = validate_derived(maps:get(<<"derived">>, Value), [<<"requirements">>],
        Path ++ [<<"derived">>]),
    Scopes = decode_scopes(maps:get(<<"at">>, Value), Aliases, Path ++ [<<"at">>]),
    Requirements = decode_or_derive_requirements(Value, Derived, Scopes, Aliases),
    #{<<"effects">> => [decode_effect(Item, Path ++ [<<"effects">>]) ||
            Item <- binary_list(maps:get(<<"effects">>, Value), Path ++ [<<"effects">>])],
        <<"requirements">> => Requirements,
        <<"scopes">> => Scopes,
        <<"budgets">> => decode_budgets(maps:get(<<"cap">>, Value), Path ++ [<<"cap">>])}.

decode_predicates(Value, Aliases) ->
    [begin
        Path = [<<"ok">>, Index],
        closed(Predicate, [<<"kind">>, <<"target">>, <<"expected">>],
            [<<"kind">>, <<"target">>, <<"expected">>], Path),
        Kind = decode_predicate(maps:get(<<"kind">>, Predicate), Path ++ [<<"kind">>]),
        Target0 = maps:get(<<"target">>, Predicate),
        Target = case Kind of
            <<"journal-succeeded">> -> expand_reference(Target0, Aliases, Path ++ [<<"target">>]);
            <<"clarification-recorded">> -> expand_reference(Target0, Aliases, Path ++ [<<"target">>]);
            _ -> binary_value(Target0, Path ++ [<<"target">>])
        end,
        #{<<"kind">> => Kind, <<"target">> => Target,
            <<"expected">> => maps:get(<<"expected">>, Predicate)}
    end || {Predicate, Index} <- indexed(map_list(Value, [<<"ok">>]))].

validate_derived(Value, Allowed, Path) ->
    Values = binary_list(Value, Path),
    ensure(length(Values) =:= length(lists:usort(Values)), Path, duplicate_derivation),
    ensure(Values =:= [Item || Item <- Allowed, lists:member(Item, Values)], Path,
        unknown_or_noncanonical_derivation),
    Values.

derive_effects(Actions) ->
    lists:usort(lists:append([operation_effect(maps:get(<<"operation">>, Action)) || Action <- Actions])).

operation_effect(<<"model.generate">>) -> [<<"model.generate">>];
operation_effect(<<"model.repair">>) -> [<<"model.generate">>];
operation_effect(<<"workspace.write">>) -> [<<"workspace.write">>];
operation_effect(<<"child.run">>) -> [<<"child.run">>];
operation_effect(<<"complete">>) -> [].

derive_requirements(Scopes) ->
    [#{<<"kind">> => <<"model">>, <<"resource">> => Resource} || Resource <- maps:get(<<"models">>, Scopes)] ++
    [#{<<"kind">> => <<"workspace">>, <<"resource">> => Resource} || Resource <- maps:get(<<"workspaces">>, Scopes)].

expand_reference(Value, Aliases, Path) ->
    Binary = binary_value(Value, Path),
    case alias_key(Binary) of
        none -> Binary;
        Key ->
            case maps:find(Key, Aliases) of
                {ok, Original} -> Original;
                error -> fail(Path, {unknown_alias, Key})
            end
    end.

alias_reference(Value) when is_binary(Value) -> alias_key(Value) =/= none;
alias_reference(_) -> false.

alias_key(<<"@", Key/binary>>) ->
    case re:run(Key, <<"^n[0-9]+$">>, [{capture, none}]) of match -> Key; nomatch -> none end;
alias_key(_) -> none.

operation_alias(<<"model.generate">>) -> <<"gen">>;
operation_alias(<<"model.repair">>) -> <<"fix">>;
operation_alias(<<"workspace.write">>) -> <<"put">>;
operation_alias(<<"child.run">>) -> <<"sub">>;
operation_alias(<<"complete">>) -> <<"done">>.

decode_operation(<<"gen">>, _Path) -> <<"model.generate">>;
decode_operation(<<"fix">>, _Path) -> <<"model.repair">>;
decode_operation(<<"put">>, _Path) -> <<"workspace.write">>;
decode_operation(<<"sub">>, _Path) -> <<"child.run">>;
decode_operation(<<"done">>, _Path) -> <<"complete">>;
decode_operation(Value, Path) -> fail(Path, {unknown_operation_alias, Value}).

effect_alias(<<"model.generate">>) -> <<"gen">>;
effect_alias(<<"workspace.write">>) -> <<"put">>;
effect_alias(<<"child.run">>) -> <<"sub">>.

decode_effect(<<"gen">>, _Path) -> <<"model.generate">>;
decode_effect(<<"put">>, _Path) -> <<"workspace.write">>;
decode_effect(<<"sub">>, _Path) -> <<"child.run">>;
decode_effect(Value, Path) -> fail(Path, {unknown_effect_alias, Value}).

predicate_alias(<<"artifact-exists">>) -> <<"exists">>;
predicate_alias(<<"journal-succeeded">>) -> <<"journal">>;
predicate_alias(<<"max-bytes">>) -> <<"maxb">>;
predicate_alias(<<"utf8">>) -> <<"u8">>;
predicate_alias(<<"clarification-recorded">>) -> <<"asked">>;
predicate_alias(Value) -> Value.

decode_predicate(<<"exists">>, _Path) -> <<"artifact-exists">>;
decode_predicate(<<"journal">>, _Path) -> <<"journal-succeeded">>;
decode_predicate(<<"maxb">>, _Path) -> <<"max-bytes">>;
decode_predicate(<<"u8">>, _Path) -> <<"utf8">>;
decode_predicate(<<"asked">>, _Path) -> <<"clarification-recorded">>;
decode_predicate(Value, _Path) -> Value.

binary_value(Value, _Path) when is_binary(Value) -> Value;
binary_value(_Value, Path) -> fail(Path, expected_string).

integer_value(Value, _Path) when is_integer(Value) -> Value;
integer_value(_Value, Path) -> fail(Path, expected_integer).

binary_list(Value, Path) ->
    Items = list_value(Value, Path),
    [binary_value(Item, Path) || Item <- Items].

map_list(Value, Path) ->
    Items = list_value(Value, Path),
    lists:foreach(fun(Item) -> ensure(is_map(Item), Path, expected_object_item) end, Items),
    Items.

list_value(Value, _Path) when is_list(Value) -> Value;
list_value(_Value, Path) -> fail(Path, expected_array).

closed(Value, Allowed, Required, Path) ->
    ensure(is_map(Value), Path, expected_object),
    Keys = maps:keys(Value),
    ensure(Keys -- Allowed =:= [], Path, {unknown_fields, lists:sort(Keys -- Allowed)}),
    ensure(Required -- Keys =:= [], Path, {missing_fields, lists:sort(Required -- Keys)}).

indexed(Items) -> lists:zip(Items, lists:seq(0, length(Items) - 1)).

ensure(true, _Path, _Reason) -> ok;
ensure(false, Path, Reason) -> fail(Path, Reason).

fail(Path, Reason) -> throw({compact_model_error, Path, Reason}).

expected_contract() ->
    #{
        <<"format">> => <<"alang-compact-model-format-contract-v1">>,
        <<"surface_id">> => <<"R3">>,
        <<"version">> => <<"alang-model-v1">>,
        <<"header">> => <<"#!alang-model-v1">>,
        <<"max_representation_bytes">> => 32768,
        <<"keyed_authority">> => true,
        <<"positional_security_fields">> => false,
        <<"derivations">> => #{
            <<"effects">> => <<"exact-from-checked-actions-or-retain">>,
            <<"requirements">> => <<"exact-from-keyed-scopes-or-retain">>,
            <<"empty_collections">> => <<"restore-only-versioned-optional-fields">>
        },
        <<"aliases">> => #{
            <<"prefix">> => <<"@n">>, <<"maximum">> => 64,
            <<"minimum_references">> => 2,
            <<"assignment">> => <<"first-eligible-declaration-order">>,
            <<"reverse_map">> => <<"required">>, <<"collisions">> => <<"reject">>,
            <<"cross_namespace_shadowing">> => <<"reject">>
        },
        <<"unknown_fields">> => <<"reject">>,
        <<"semantic_acceptance">> => <<"validate-and-match-sha-256-canonical-etf-v1">>
    }.
