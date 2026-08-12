-module(alang_compact_opaque).

-export([decode/2, encode/1, load_contract/1, promotable/0, validate_contract/1]).

-define(HEADER, <<"#!alang-model-v1-opaque-control\n">>).
-define(MODEL_HEADER, <<"#!alang-model-v1\n">>).
-define(MAX_ALIASES, 128).
-define(PROTECTED_MODEL_PROFILES, [
    <<"hf.co/unsloth/Ornith-1.0-35B-GGUF:UD-Q5_K_M">>,
    <<"mixtral:8x7b">>
]).

-spec promotable() -> false.
promotable() -> false.

-spec load_contract(file:filename()) -> {ok, map()} | {error, term()}.
load_contract(Path) ->
    case alang_fidelity_json:decode_file(Path) of
        {ok, Value} -> validate_contract(Value);
        {error, Reason} -> {error, {opaque_contract_read_failed, Reason}}
    end.

-spec validate_contract(term()) -> {ok, map()} | {error, term()}.
validate_contract(Value) when is_map(Value) ->
    Expected = expected_contract(),
    case Value =:= Expected of
        true -> {ok, Value};
        false -> {error, {opaque_contract_mismatch,
            alang_fidelity_json:digest(Expected), alang_fidelity_json:digest(Value)}}
    end;
validate_contract(Value) -> {error, {invalid_opaque_contract, Value}}.

-spec encode(map()) -> {ok, map()} | {error, term()}.
encode(Oracle) ->
    case alang_fidelity_contract:validate_comprehension(Oracle) of
        {ok, _} ->
            try
                Canonical = canonical_oracle(Oracle),
                {Forward, Reverse} = opaque_aliases(Canonical),
                OpaqueOracle = transform(Canonical, Forward),
                case alang_compact_model:encode(OpaqueOracle) of
                    {ok, Model} ->
                        ModelBytes = maps:get(bytes, Model),
                        <<"#!alang-model-v1\n", Body/binary>> = ModelBytes,
                        {ok, #{
                            bytes => <<?HEADER/binary, Body/binary>>,
                            reverse_map => Reverse,
                            promotable => false,
                            role => identifier_negative_control,
                            semantic_digest => alang_fidelity_contract:semantic_digest(Canonical),
                            protected => protected_names()
                        }};
                    {error, ProjectionReason} -> fail([], {model_projection_failed, ProjectionReason})
                end
            catch
                throw:{compact_opaque_error, ErrorPath, CaughtReason} ->
                    {error, {compact_opaque_error, ErrorPath, CaughtReason}}
            end;
        {error, Reason} -> {error, {invalid_checked_semantics, Reason}}
    end.

-spec decode(binary(), map()) -> {ok, map()} | {error, term()}.
decode(<<"#!alang-model-v1-opaque-control\n", Body/binary>>, ReverseMap) ->
    try
        Reverse = validate_reverse_map(ReverseMap),
        ModelBinary = <<?MODEL_HEADER/binary, Body/binary>>,
        case alang_compact_model:decode(ModelBinary) of
            {ok, ModelDecoded} ->
                {ok, Compact} = alang_fidelity_json:decode(Body),
                OpaqueTask = maps:get(<<"task">>, Compact),
                OpaqueSemantic = maps:get(semantic, ModelDecoded),
                {Task, Semantic, Used} = restore(OpaqueTask, OpaqueSemantic, Reverse),
                ensure(lists:sort(maps:keys(Reverse)) =:= lists:sort(maps:keys(Used)),
                    [<<"reverse_map">>], unused_opaque_alias),
                Comprehension = Semantic#{<<"format">> => <<"alang_task_comprehension_v1">>,
                    <<"case_id">> => Task},
                case alang_fidelity_contract:validate_comprehension(Comprehension) of
                    {ok, _} -> {ok, #{
                        source_format => <<"alang-model-v1-opaque-control">>,
                        semantic => alang_fidelity_contract:normalize(Comprehension),
                        semantic_digest => alang_fidelity_contract:semantic_digest(Comprehension),
                        reverse_map => Reverse,
                        promotable => false,
                        origins => #{}
                    }};
                    {error, SemanticReason} -> fail([], {invalid_restored_semantics, SemanticReason})
                end;
            {error, ModelReason} -> fail([], {model_decode_failed, ModelReason})
        end
    catch
        throw:{compact_opaque_error, ErrorPath, CaughtReason} ->
            {error, {compact_opaque_error, ErrorPath, CaughtReason}};
        error:ShapeReason ->
            {error, {compact_opaque_error, [], {invalid_opaque_shape, ShapeReason}}}
    end;
decode(<<"#!alang-model-", _/binary>>, _ReverseMap) ->
    {error, {compact_opaque_error, [<<"version">>], unsupported_opaque_version}};
decode(Binary, _ReverseMap) when is_binary(Binary) ->
    {error, {compact_opaque_error, [<<"version">>], missing_opaque_version}};
decode(_, _) -> {error, {compact_opaque_error, [], expected_binary}}.

canonical_oracle(Oracle) ->
    (alang_fidelity_contract:normalize(Oracle))#{
        <<"format">> => <<"alang_task_comprehension_v1">>,
        <<"case_id">> => maps:get(<<"case_id">>, Oracle)
    }.

opaque_aliases(Oracle) ->
    Pairs = unique_pairs(eligible_pairs(Oracle)),
    ensure(length(Pairs) =< ?MAX_ALIASES, [<<"reverse_map">>], too_many_opaque_aliases),
    Originals = [Value || {_Kind, Value} <- Pairs],
    lists:foreach(fun(Value) ->
        ensure(re:run(Value, <<"^o[0-9]+$">>, [{capture, none}]) =:= nomatch,
            [<<"reverse_map">>], {opaque_alias_collision, Value})
    end, Originals),
    Indexed = lists:zip(Pairs, lists:seq(0, length(Pairs) - 1)),
    Forward = maps:from_list([{{Kind, Value}, <<"o", (integer_to_binary(Index))/binary>>}
        || {{Kind, Value}, Index} <- Indexed]),
    Reverse = maps:from_list([{<<"o", (integer_to_binary(Index))/binary>>,
        #{<<"kind">> => kind_binary(Kind), <<"original">> => Value}}
        || {{Kind, Value}, Index} <- Indexed]),
    {Forward, Reverse}.

eligible_pairs(Oracle) ->
    [{task, maps:get(<<"case_id">>, Oracle)}] ++
    [{input, maps:get(<<"name">>, Input)} || Input <- maps:get(<<"inputs">>, Oracle)] ++
    [{action, maps:get(<<"id">>, Action)} || Action <- maps:get(<<"actions">>, Oracle)] ++
    resource_pairs(Oracle) ++
    case maps:get(<<"child_attenuation">>, Oracle) of
        null -> [];
        Child -> resource_pairs(Child)
    end.

resource_pairs(Value) ->
    Requirements = [{resource_kind(maps:get(<<"kind">>, Requirement)),
        maps:get(<<"resource">>, Requirement)} || Requirement <- maps:get(<<"requirements">>, Value)],
    Scopes = maps:get(<<"scopes">>, Value),
    Requirements ++ [{model_resource, Item} || Item <- maps:get(<<"models">>, Scopes),
        not protected_model_profile(Item)] ++
        [{workspace_resource, Item} || Item <- maps:get(<<"workspaces">>, Scopes)].

unique_pairs(Pairs) -> unique_pairs(Pairs, #{}, []).
unique_pairs([], _Seen, Acc) -> lists:reverse(Acc);
unique_pairs([{model_resource, Value} = Pair | Rest], Seen, Acc) ->
    case protected_model_profile(Value) of
        true -> unique_pairs(Rest, Seen, Acc);
        false -> unique_pair(Pair, Rest, Seen, Acc)
    end;
unique_pairs([Pair | Rest], Seen, Acc) -> unique_pair(Pair, Rest, Seen, Acc).

unique_pair(Pair, Rest, Seen, Acc) ->
    case maps:is_key(Pair, Seen) of
        true -> unique_pairs(Rest, Seen, Acc);
        false -> unique_pairs(Rest, Seen#{Pair => true}, [Pair | Acc])
    end.

transform(Oracle, Forward) ->
    Oracle#{
        <<"case_id">> := opaque(task, maps:get(<<"case_id">>, Oracle), Forward),
        <<"inputs">> := [Input#{<<"name">> := opaque(input, maps:get(<<"name">>, Input), Forward)}
            || Input <- maps:get(<<"inputs">>, Oracle)],
        <<"actions">> := [transform_action(Action, Forward) || Action <- maps:get(<<"actions">>, Oracle)],
        <<"requirements">> := transform_requirements(maps:get(<<"requirements">>, Oracle), Forward),
        <<"scopes">> := transform_scopes(maps:get(<<"scopes">>, Oracle), Forward),
        <<"error_branches">> := [Error#{<<"action">> := opaque(action,
            maps:get(<<"action">>, Error), Forward)} || Error <- maps:get(<<"error_branches">>, Oracle)],
        <<"child_attenuation">> := transform_child(maps:get(<<"child_attenuation">>, Oracle), Forward),
        <<"completion_predicates">> := [transform_predicate(Predicate, Forward) || Predicate <-
            maps:get(<<"completion_predicates">>, Oracle)]
    }.

transform_action(Action, Forward) ->
    Action#{<<"id">> := opaque(action, maps:get(<<"id">>, Action), Forward),
        <<"depends_on">> := [opaque(action, Value, Forward) || Value <- maps:get(<<"depends_on">>, Action)]}.

transform_requirements(Requirements, Forward) ->
    [Requirement#{<<"resource">> := opaque(resource_kind(maps:get(<<"kind">>, Requirement)),
        maps:get(<<"resource">>, Requirement), Forward)} || Requirement <- Requirements].

transform_scopes(Scopes, Forward) ->
    Scopes#{
        <<"models">> := [opaque(model_resource, Value, Forward) || Value <- maps:get(<<"models">>, Scopes)],
        <<"workspaces">> := [opaque(workspace_resource, Value, Forward) || Value <- maps:get(<<"workspaces">>, Scopes)]
    }.

transform_child(null, _Forward) -> null;
transform_child(Child, Forward) ->
    Child#{<<"requirements">> := transform_requirements(maps:get(<<"requirements">>, Child), Forward),
        <<"scopes">> := transform_scopes(maps:get(<<"scopes">>, Child), Forward)}.

transform_predicate(#{<<"kind">> := <<"journal-succeeded">>} = Predicate, Forward) ->
    Predicate#{<<"target">> := opaque(action, maps:get(<<"target">>, Predicate), Forward)};
transform_predicate(#{<<"kind">> := <<"clarification-recorded">>} = Predicate, Forward) ->
    Predicate#{<<"target">> := opaque(input, maps:get(<<"target">>, Predicate), Forward)};
transform_predicate(Predicate, _Forward) -> Predicate.

opaque(model_resource, Value, _Forward) when Value =:= <<"hf.co/unsloth/Ornith-1.0-35B-GGUF:UD-Q5_K_M">>;
        Value =:= <<"mixtral:8x7b">> -> Value;
opaque(Kind, Value, Forward) ->
    case maps:find({Kind, Value}, Forward) of
        {ok, Alias} -> Alias;
        error -> fail([<<"reverse_map">>], {missing_opaque_alias, Kind, Value})
    end.

validate_reverse_map(Value) ->
    ensure(is_map(Value), [<<"reverse_map">>], expected_object),
    ensure(maps:size(Value) =< ?MAX_ALIASES, [<<"reverse_map">>], too_many_opaque_aliases),
    Keys = maps:keys(Value),
    Expected = [<<"o", (integer_to_binary(Index))/binary>> || Index <- lists:seq(0, length(Keys) - 1)],
    ensure(lists:sort(Keys) =:= lists:sort(Expected), [<<"reverse_map">>], noncontiguous_opaque_aliases),
    Pairs = [begin
        Path = [<<"reverse_map">>, Key],
        ensure(is_map(Entry), Path, expected_object),
        ensure(lists:sort(maps:keys(Entry)) =:= [<<"kind">>, <<"original">>], Path, invalid_reverse_entry),
        Kind = decode_kind(maps:get(<<"kind">>, Entry), Path ++ [<<"kind">>]),
        Original = maps:get(<<"original">>, Entry),
        ensure(is_binary(Original), Path ++ [<<"original">>], expected_string),
        {{Kind, Original}, Key}
    end || {Key, Entry} <- maps:to_list(Value)],
    ensure(length(Pairs) =:= length(lists:usort([Pair || {Pair, _} <- Pairs])),
        [<<"reverse_map">>], duplicate_reverse_identity),
    Value.

restore(OpaqueTask, Semantic, Reverse) ->
    {Task, Used0} = restore_value(task, OpaqueTask, Reverse, #{}),
    {Inputs, Used1} = restore_inputs(maps:get(<<"inputs">>, Semantic), Reverse, Used0),
    {Actions, Used2} = restore_actions(maps:get(<<"actions">>, Semantic), Reverse, Used1),
    {Requirements, Used3} = restore_requirements(maps:get(<<"requirements">>, Semantic), Reverse, Used2),
    {Scopes, Used4} = restore_scopes(maps:get(<<"scopes">>, Semantic), Reverse, Used3),
    {Errors, Used5} = restore_errors(maps:get(<<"error_branches">>, Semantic), Reverse, Used4),
    {Child, Used6} = restore_child(maps:get(<<"child_attenuation">>, Semantic), Reverse, Used5),
    {Predicates, Used7} = restore_predicates(maps:get(<<"completion_predicates">>, Semantic), Reverse, Used6),
    {Task, Semantic#{<<"inputs">> := Inputs, <<"actions">> := Actions,
        <<"requirements">> := Requirements, <<"scopes">> := Scopes,
        <<"error_branches">> := Errors, <<"child_attenuation">> := Child,
        <<"completion_predicates">> := Predicates}, Used7}.

restore_inputs(Inputs, Reverse, Used) ->
    mapfold(fun(Input, Acc) ->
        {Name, Next} = restore_value(input, maps:get(<<"name">>, Input), Reverse, Acc),
        {Input#{<<"name">> := Name}, Next}
    end, Inputs, Used).

restore_actions(Actions, Reverse, Used) ->
    mapfold(fun(Action, Acc0) ->
        {Id, Acc1} = restore_value(action, maps:get(<<"id">>, Action), Reverse, Acc0),
        {Dependencies, Acc2} = restore_values(action, maps:get(<<"depends_on">>, Action), Reverse, Acc1),
        {Action#{<<"id">> := Id, <<"depends_on">> := Dependencies}, Acc2}
    end, Actions, Used).

restore_requirements(Requirements, Reverse, Used) ->
    mapfold(fun(Requirement, Acc) ->
        Kind = resource_kind(maps:get(<<"kind">>, Requirement)),
        {Resource, Next} = restore_value(Kind, maps:get(<<"resource">>, Requirement), Reverse, Acc),
        {Requirement#{<<"resource">> := Resource}, Next}
    end, Requirements, Used).

restore_scopes(Scopes, Reverse, Used0) ->
    {Models, Used1} = restore_values(model_resource, maps:get(<<"models">>, Scopes), Reverse, Used0),
    {Workspaces, Used2} = restore_values(workspace_resource, maps:get(<<"workspaces">>, Scopes), Reverse, Used1),
    {Scopes#{<<"models">> := Models, <<"workspaces">> := Workspaces}, Used2}.

restore_errors(Errors, Reverse, Used) ->
    mapfold(fun(Error, Acc) ->
        {Action, Next} = restore_value(action, maps:get(<<"action">>, Error), Reverse, Acc),
        {Error#{<<"action">> := Action}, Next}
    end, Errors, Used).

restore_child(null, _Reverse, Used) -> {null, Used};
restore_child(Child, Reverse, Used0) ->
    {Requirements, Used1} = restore_requirements(maps:get(<<"requirements">>, Child), Reverse, Used0),
    {Scopes, Used2} = restore_scopes(maps:get(<<"scopes">>, Child), Reverse, Used1),
    {Child#{<<"requirements">> := Requirements, <<"scopes">> := Scopes}, Used2}.

restore_predicates(Predicates, Reverse, Used) ->
    mapfold(fun(Predicate, Acc) ->
        case maps:get(<<"kind">>, Predicate) of
            <<"journal-succeeded">> ->
                {Target, Next} = restore_value(action, maps:get(<<"target">>, Predicate), Reverse, Acc),
                {Predicate#{<<"target">> := Target}, Next};
            <<"clarification-recorded">> ->
                {Target, Next} = restore_value(input, maps:get(<<"target">>, Predicate), Reverse, Acc),
                {Predicate#{<<"target">> := Target}, Next};
            _ -> {Predicate, Acc}
        end
    end, Predicates, Used).

restore_values(Kind, Values, Reverse, Used) ->
    mapfold(fun(Value, Acc) -> restore_value(Kind, Value, Reverse, Acc) end, Values, Used).

restore_value(model_resource, Value, _Reverse, Used) when Value =:= <<"hf.co/unsloth/Ornith-1.0-35B-GGUF:UD-Q5_K_M">>;
        Value =:= <<"mixtral:8x7b">> -> {Value, Used};
restore_value(ExpectedKind, Alias, Reverse, Used) ->
    case maps:find(Alias, Reverse) of
        {ok, #{<<"kind">> := KindBinary, <<"original">> := Original}} ->
            Kind = decode_kind(KindBinary, [<<"reverse_map">>, Alias, <<"kind">>]),
            ensure(Kind =:= ExpectedKind, [<<"reverse_map">>, Alias],
                {opaque_kind_mismatch, ExpectedKind, Kind}),
            {Original, Used#{Alias => true}};
        error -> fail([<<"reverse_map">>], {unknown_opaque_alias, Alias})
    end.

mapfold(Fun, Values, Acc) -> lists:mapfoldl(Fun, Acc, Values).

resource_kind(<<"model">>) -> model_resource;
resource_kind(<<"workspace">>) -> workspace_resource.

protected_model_profile(Value) -> lists:member(Value, ?PROTECTED_MODEL_PROFILES).

kind_binary(task) -> <<"task">>;
kind_binary(input) -> <<"input">>;
kind_binary(action) -> <<"action">>;
kind_binary(model_resource) -> <<"model-resource">>;
kind_binary(workspace_resource) -> <<"workspace-resource">>.

decode_kind(<<"task">>, _Path) -> task;
decode_kind(<<"input">>, _Path) -> input;
decode_kind(<<"action">>, _Path) -> action;
decode_kind(<<"model-resource">>, _Path) -> model_resource;
decode_kind(<<"workspace-resource">>, _Path) -> workspace_resource;
decode_kind(Value, Path) -> fail(Path, {unknown_opaque_kind, Value}).

protected_names() -> [literal_facts, paths, enum_tags, effect_names, scope_keys,
    budget_keys, provider_model_profiles, completion_predicates].

ensure(true, _Path, _Reason) -> ok;
ensure(false, Path, Reason) -> fail(Path, Reason).
fail(Path, Reason) -> throw({compact_opaque_error, Path, Reason}).

expected_contract() ->
    #{
        <<"format">> => <<"alang-compact-opaque-control-contract-v1">>,
        <<"surface_id">> => <<"R4">>,
        <<"version">> => <<"alang-model-v1-opaque-control">>,
        <<"header">> => <<"#!alang-model-v1-opaque-control">>,
        <<"role">> => <<"identifier-negative-control">>,
        <<"promotable">> => false,
        <<"eligible">> => [<<"task-identifiers">>, <<"input-identifiers">>,
            <<"action-identifiers">>, <<"model-resource-references">>,
            <<"workspace-resource-references">>],
        <<"protected">> => [<<"literal-facts">>, <<"paths">>, <<"enum-tags">>,
            <<"effect-names">>, <<"scope-keys">>, <<"budget-keys">>,
            <<"provider-model-profiles">>, <<"completion-predicates">>],
        <<"protected_model_profiles">> => ?PROTECTED_MODEL_PROFILES,
        <<"alias_prefix">> => <<"o">>, <<"maximum_aliases">> => 128,
        <<"collisions">> => <<"reject">>,
        <<"reverse_map">> => <<"required-non-model-visible-decode-context">>,
        <<"unknown_or_unused_alias">> => <<"reject">>,
        <<"selection_as_default">> => <<"forbidden">>
    }.
