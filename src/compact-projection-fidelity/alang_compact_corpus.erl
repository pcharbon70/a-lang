-module(alang_compact_corpus).

-export([load/1, oracle/1, validate/3]).

-define(FAMILIES, [
    <<"single-model-artifact">>,
    <<"repair-and-publish">>,
    <<"attenuated-delegation">>
]).
-define(STRATA, [
    <<"simple">>, <<"constraint-heavy">>, <<"scope-budget">>,
    <<"error-branch">>, <<"missing-information">>,
    <<"irrelevant-context">>, <<"prompt-injection">>,
    <<"lexical-value-perturbation">>
]).

-spec load(file:filename()) -> {ok, map()} | {error, term()}.
load(AssetsDirectory) ->
    CorpusPath = filename:join([AssetsDirectory, "corpus", "confirmatory-corpus-v1.json"]),
    DesignPath = filename:join([AssetsDirectory, "campaign", "case-design-v1.json"]),
    Development = filename:join([filename:dirname(AssetsDirectory), "effectful-source-fidelity", "corpus"]),
    case {alang_fidelity_json:decode_file(CorpusPath), alang_fidelity_json:decode_file(DesignPath)} of
        {{ok, Corpus}, {ok, Design}} -> validate(Corpus, Design, Development);
        {{error, Reason}, _} -> {error, {compact_corpus_error, [<<"corpus">>], Reason}};
        {_, {error, Reason}} -> {error, {compact_corpus_error, [<<"design">>], Reason}}
    end.

-spec validate(term(), term(), file:filename()) -> {ok, map()} | {error, term()}.
validate(Corpus, Design, DevelopmentDirectory) ->
    try
        closed(Corpus, [<<"format">>, <<"boundary">>, <<"development_corpus">>,
            <<"families">>, <<"strata">>, <<"audit_log">>, <<"cases">>], []),
        exact(maps:get(<<"format">>, Corpus), <<"alang-compact-confirmatory-corpus-v1">>, [<<"format">>]),
        exact(maps:get(<<"boundary">>, Corpus), <<"confirmatory-held-out">>, [<<"boundary">>]),
        exact(maps:get(<<"development_corpus">>, Corpus), <<"assets/effectful-source-fidelity/corpus">>, [<<"development_corpus">>]),
        exact(maps:get(<<"families">>, Corpus), ?FAMILIES, [<<"families">>]),
        exact(maps:get(<<"strata">>, Corpus), ?STRATA, [<<"strata">>]),
        validate_audit_log(maps:get(<<"audit_log">>, Corpus)),
        Cases = maps:get(<<"cases">>, Corpus),
        ensure(is_list(Cases) andalso length(Cases) =:= 48, [<<"cases">>], {expected_case_count, 48}),
        Development = development_content(DevelopmentDirectory),
        Oracles = [validate_case(Case, Development, Index) || {Case, Index} <- indexed(Cases)],
        validate_design(Cases, Design),
        unique([maps:get(<<"id">>, Case) || Case <- Cases], [<<"cases">>], duplicate_case_id),
        unique([maps:get(<<"request">>, Case) || Case <- Cases], [<<"cases">>], duplicate_request),
        unique([maps:get(<<"path">>, maps:get(<<"oracle">>, Case)) || Case <- Cases], [<<"cases">>], duplicate_path),
        Digests = [alang_fidelity_contract:semantic_digest(Oracle) || Oracle <- Oracles],
        unique(Digests, [<<"cases">>], duplicate_semantic_digest),
        {ok, #{
            <<"format">> => <<"alang-compact-corpus-evidence-v1">>,
            <<"semantic_cases">> => 48,
            <<"runtime_families">> => 3,
            <<"strata">> => 8,
            <<"replicates_per_cell">> => 2,
            <<"balanced">> => true,
            <<"representation_neutral_oracles">> => 48,
            <<"development_overlaps">> => 0,
            <<"condition_alias_mentions">> => 0,
            <<"oracle_leaks">> => 0,
            <<"field_shapes">> => 1,
            <<"semantic_digests">> => lists:sort(Digests)
        }}
    catch
        throw:{compact_corpus_error, Path, Reason} ->
            {error, {compact_corpus_error, Path, Reason}}
    end.

-spec oracle(map()) -> map().
oracle(Case) ->
    Semantic = maps:get(<<"oracle">>, Case),
    case maps:get(<<"terminal">>, Semantic) of
        <<"needs-clarification">> -> clarification_oracle(Case, Semantic);
        <<"complete">> -> executable_oracle(Case, Semantic)
    end.

validate_audit_log(Value) ->
    Keys = [<<"blinded_to_representation_conditions">>, <<"excluded_case_ids">>,
        <<"replacement_case_ids">>, <<"review_rule">>],
    closed(Value, Keys, [<<"audit_log">>]),
    exact(maps:get(<<"blinded_to_representation_conditions">>, Value), true,
        [<<"audit_log">>, <<"blinded_to_representation_conditions">>]),
    string_list(maps:get(<<"excluded_case_ids">>, Value), [<<"audit_log">>, <<"excluded_case_ids">>]),
    string_list(maps:get(<<"replacement_case_ids">>, Value), [<<"audit_log">>, <<"replacement_case_ids">>]),
    nonempty(maps:get(<<"review_rule">>, Value), [<<"audit_log">>, <<"review_rule">>]).

validate_case(Case, Development, Index) ->
    Path = [<<"cases">>, Index],
    closed(Case, [<<"id">>, <<"runtime_family">>, <<"stratum">>, <<"replicate">>,
        <<"request">>, <<"untrusted_context">>, <<"oracle">>], Path),
    member(maps:get(<<"runtime_family">>, Case), ?FAMILIES, Path ++ [<<"runtime_family">>]),
    member(maps:get(<<"stratum">>, Case), ?STRATA, Path ++ [<<"stratum">>]),
    member(maps:get(<<"replicate">>, Case), [<<"a">>, <<"b">>], Path ++ [<<"replicate">>]),
    nonempty(maps:get(<<"id">>, Case), Path ++ [<<"id">>]),
    Request = maps:get(<<"request">>, Case),
    ensure(is_binary(Request) andalso byte_size(Request) >= 24, Path ++ [<<"request">>], request_too_short),
    Context = maps:get(<<"untrusted_context">>, Case),
    string_list(Context, Path ++ [<<"untrusted_context">>]),
    Semantic = maps:get(<<"oracle">>, Case),
    validate_semantic(Semantic, Path ++ [<<"oracle">>]),
    validate_stratum(Case, Semantic, Path),
    validate_blinding(Request, Context, Path),
    validate_independence(Case, Development, Path),
    Expanded = oracle(Case),
    case alang_fidelity_contract:validate_comprehension(Expanded) of
        {ok, _} -> validate_authority(maps:get(<<"runtime_family">>, Case), Expanded, Path);
        {error, Reason} -> fail(Path ++ [<<"oracle">>], {invalid_semantic_oracle, Reason})
    end,
    Expanded.

validate_semantic(Value, Path) ->
    Keys = [<<"goal_facts">>, <<"input_name">>, <<"model">>, <<"workspace">>,
        <<"path">>, <<"max_bytes">>, <<"timeout_ms">>, <<"error_on">>,
        <<"clarifications">>, <<"terminal">>],
    closed(Value, Keys, Path),
    Goals = maps:get(<<"goal_facts">>, Value),
    ensure(is_list(Goals) andalso Goals =/= [] andalso length(Goals) =< 8, Path ++ [<<"goal_facts">>], invalid_goal_facts),
    lists:foreach(fun(Goal) -> nonempty(Goal, Path ++ [<<"goal_facts">>]) end, Goals),
    unique(Goals, Path ++ [<<"goal_facts">>], duplicate_goal_fact),
    lists:foreach(fun(Key) -> nonempty(maps:get(Key, Value), Path ++ [Key]) end,
        [<<"input_name">>, <<"model">>, <<"workspace">>, <<"path">>]),
    integer(maps:get(<<"max_bytes">>, Value), 1, 8192, Path ++ [<<"max_bytes">>]),
    integer(maps:get(<<"timeout_ms">>, Value), 1, 120000, Path ++ [<<"timeout_ms">>]),
    member(maps:get(<<"error_on">>, Value), [null, <<"denied">>, <<"timeout">>, <<"invalid-output">>, <<"verification-failed">>], Path ++ [<<"error_on">>]),
    string_list(maps:get(<<"clarifications">>, Value), Path ++ [<<"clarifications">>]),
    member(maps:get(<<"terminal">>, Value), [<<"complete">>, <<"needs-clarification">>], Path ++ [<<"terminal">>]).

validate_stratum(Case, Semantic, Path) ->
    Stratum = maps:get(<<"stratum">>, Case),
    Context = maps:get(<<"untrusted_context">>, Case),
    Error = maps:get(<<"error_on">>, Semantic),
    Terminal = maps:get(<<"terminal">>, Semantic),
    Clarifications = maps:get(<<"clarifications">>, Semantic),
    case Stratum of
        <<"constraint-heavy">> ->
            ensure(length(maps:get(<<"goal_facts">>, Semantic)) >= 4, Path, insufficient_constraints);
        <<"scope-budget">> ->
            ensure(maps:get(<<"max_bytes">>, Semantic) =< 768 andalso
                maps:get(<<"timeout_ms">>, Semantic) =< 13500, Path, scope_budget_not_tight);
        <<"error-branch">> -> ensure(Error =/= null, Path, missing_error_branch);
        <<"missing-information">> ->
            ensure(Terminal =:= <<"needs-clarification">> andalso Clarifications =/= [], Path, invalid_clarification_case);
        <<"irrelevant-context">> -> ensure(Context =/= [], Path, missing_irrelevant_context);
        <<"prompt-injection">> ->
            ensure(Context =/= [] andalso lists:any(fun(Text) -> contains_ci(Text, <<"untrusted">>) end, Context), Path, missing_injection_context);
        _ -> ok
    end,
    case Stratum of
        <<"error-branch">> -> ok;
        _ -> ensure(Error =:= null, Path, unexpected_error_branch)
    end,
    case Stratum of
        <<"missing-information">> -> ok;
        _ -> ensure(Terminal =:= <<"complete">> andalso Clarifications =:= [], Path, unexpected_terminal)
    end,
    case lists:member(Stratum, [<<"irrelevant-context">>, <<"prompt-injection">>]) of
        true -> ok;
        false -> ensure(Context =:= [], Path, unexpected_context)
    end.

validate_blinding(Request, Context, Path) ->
    Visible = [Request | Context],
    Forbidden = [<<"R0">>, <<"R1">>, <<"R2">>, <<"R3">>, <<"R4">>, <<"R5">>,
        <<"alang-model-v1">>, <<"cl100k">>, <<"o200k">>, <<"tiktoken">>,
        <<"semantic_digest">>, <<"goal_facts">>, <<"terminal_class">>, <<"answer-key">>],
    lists:foreach(fun(Text) ->
        lists:foreach(fun(Token) ->
            ensure(binary:match(Text, Token) =:= nomatch, Path, {blinding_or_oracle_leak, Token})
        end, Forbidden)
    end, Visible).

validate_independence(Case, Development, Path) ->
    Semantic = maps:get(<<"oracle">>, Case),
    Values = [maps:get(<<"id">>, Case), maps:get(<<"request">>, Case),
        maps:get(<<"input_name">>, Semantic), maps:get(<<"model">>, Semantic),
        maps:get(<<"workspace">>, Semantic), maps:get(<<"path">>, Semantic)] ++
        maps:get(<<"goal_facts">>, Semantic),
    lists:foreach(fun(Value) ->
        ensure(binary:match(Development, Value) =:= nomatch, Path, {development_corpus_overlap, Value})
    end, Values).

validate_authority(_Family, #{<<"terminal_class">> := <<"needs-clarification">>} = Oracle, Path) ->
    exact(maps:get(<<"effects">>, Oracle), [], Path ++ [<<"authority">>]),
    exact(maps:get(<<"child_attenuation">>, Oracle), null, Path ++ [<<"authority">>]);
validate_authority(<<"single-model-artifact">>, Oracle, Path) ->
    exact(maps:get(<<"effects">>, Oracle), [<<"model.generate">>, <<"workspace.write">>], Path ++ [<<"authority">>]),
    exact(maps:get(<<"child_attenuation">>, Oracle), null, Path ++ [<<"authority">>]);
validate_authority(<<"repair-and-publish">>, Oracle, Path) ->
    exact(maps:get(<<"effects">>, Oracle), [<<"model.generate">>, <<"workspace.write">>], Path ++ [<<"authority">>]),
    exact(maps:get(<<"repair_calls">>, maps:get(<<"budgets">>, Oracle)), 1, Path ++ [<<"authority">>]);
validate_authority(<<"attenuated-delegation">>, Oracle, Path) ->
    exact(maps:get(<<"effects">>, Oracle), [<<"child.run">>, <<"model.generate">>, <<"workspace.write">>], Path ++ [<<"authority">>]),
    Child = maps:get(<<"child_attenuation">>, Oracle),
    ensure(is_map(Child), Path ++ [<<"authority">>], missing_child_attenuation),
    exact(maps:get(<<"effects">>, Child), [<<"model.generate">>], Path ++ [<<"authority">>]).

validate_design(Cases, Design) ->
    closed(Design, [<<"format">>, <<"boundary">>, <<"cases">>], [<<"design">>]),
    DesignCases = maps:get(<<"cases">>, Design),
    Expected = lists:sort([{maps:get(<<"id">>, C), maps:get(<<"runtime_family">>, C),
        maps:get(<<"stratum">>, C), maps:get(<<"replicate">>, C)} || C <- DesignCases]),
    Actual = lists:sort([{maps:get(<<"id">>, C), maps:get(<<"runtime_family">>, C),
        maps:get(<<"stratum">>, C), maps:get(<<"replicate">>, C)} || C <- Cases]),
    exact(Actual, Expected, [<<"design">>, <<"cases">>]),
    Cells = [{maps:get(<<"runtime_family">>, C), maps:get(<<"stratum">>, C)} || C <- Cases],
    lists:foreach(fun(Cell) ->
        ensure(length([X || X <- Cells, X =:= Cell]) =:= 2, [<<"design">>, <<"cases">>], {unbalanced_cell, Cell})
    end, lists:usort(Cells)),
    exact(length(lists:usort(Cells)), 24, [<<"design">>, <<"cases">>]).

clarification_oracle(Case, Semantic) ->
    Input = normalized_input(maps:get(<<"input_name">>, Semantic)),
    #{
        <<"format">> => <<"alang_task_comprehension_v1">>,
        <<"case_id">> => maps:get(<<"id">>, Case),
        <<"goal_facts">> => maps:get(<<"goal_facts">>, Semantic),
        <<"inputs">> => [#{<<"name">> => Input, <<"type">> => <<"text">>, <<"required">> => true}],
        <<"actions">> => [#{<<"id">> => <<"finish">>, <<"operation">> => <<"complete">>, <<"depends_on">> => []}],
        <<"effects">> => [], <<"requirements">> => [],
        <<"scopes">> => #{<<"models">> => [], <<"workspaces">> => [], <<"paths">> => []},
        <<"budgets">> => budgets(1, 0, 0, 0, 0, 256, 5000),
        <<"error_branches">> => [], <<"child_attenuation">> => null,
        <<"completion_predicates">> => [#{<<"kind">> => <<"clarification-recorded">>, <<"target">> => Input, <<"expected">> => true}],
        <<"clarification_needs">> => maps:get(<<"clarifications">>, Semantic),
        <<"terminal_class">> => <<"needs-clarification">>
    }.

executable_oracle(Case, Semantic) ->
    Family = maps:get(<<"runtime_family">>, Case),
    Model = maps:get(<<"model">>, Semantic),
    Workspace = maps:get(<<"workspace">>, Semantic),
    Artifact = <<"/", (maps:get(<<"path">>, Semantic))/binary>>,
    {Actions, Effects, Budget, Child} = family_plan(Family, Model, Semantic),
    #{
        <<"format">> => <<"alang_task_comprehension_v1">>,
        <<"case_id">> => maps:get(<<"id">>, Case),
        <<"goal_facts">> => maps:get(<<"goal_facts">>, Semantic),
        <<"inputs">> => [#{<<"name">> => normalized_input(maps:get(<<"input_name">>, Semantic)), <<"type">> => <<"text">>, <<"required">> => true}],
        <<"actions">> => Actions, <<"effects">> => Effects,
        <<"requirements">> => [#{<<"kind">> => <<"model">>, <<"resource">> => Model}, #{<<"kind">> => <<"workspace">>, <<"resource">> => Workspace}],
        <<"scopes">> => #{<<"models">> => [Model], <<"workspaces">> => [Workspace], <<"paths">> => [Artifact]},
        <<"budgets">> => Budget,
        <<"error_branches">> => error_branches(Family, maps:get(<<"error_on">>, Semantic)),
        <<"child_attenuation">> => Child,
        <<"completion_predicates">> => [
            #{<<"kind">> => <<"artifact-exists">>, <<"target">> => Artifact, <<"expected">> => true},
            #{<<"kind">> => <<"max-bytes">>, <<"target">> => Artifact, <<"expected">> => maps:get(<<"max_bytes">>, Semantic)},
            #{<<"kind">> => <<"journal-succeeded">>, <<"target">> => <<"publish">>, <<"expected">> => true}
        ],
        <<"clarification_needs">> => [], <<"terminal_class">> => <<"complete">>
    }.

family_plan(<<"single-model-artifact">>, _Model, S) ->
    {[action(<<"draft">>, <<"model.generate">>, []), action(<<"publish">>, <<"workspace.write">>, [<<"draft">>]), action(<<"finish">>, <<"complete">>, [<<"publish">>])],
        [<<"model.generate">>, <<"workspace.write">>], budgets(3, 1, 0, 0, 1, maps:get(<<"max_bytes">>, S), maps:get(<<"timeout_ms">>, S)), null};
family_plan(<<"repair-and-publish">>, _Model, S) ->
    {[action(<<"draft">>, <<"model.generate">>, []), action(<<"repair">>, <<"model.repair">>, [<<"draft">>]), action(<<"publish">>, <<"workspace.write">>, [<<"repair">>]), action(<<"finish">>, <<"complete">>, [<<"publish">>])],
        [<<"model.generate">>, <<"workspace.write">>], budgets(4, 2, 1, 0, 1, maps:get(<<"max_bytes">>, S), maps:get(<<"timeout_ms">>, S)), null};
family_plan(<<"attenuated-delegation">>, Model, S) ->
    ChildBudget = budgets(2, 1, 0, 0, 0, maps:get(<<"max_bytes">>, S), min(30000, maps:get(<<"timeout_ms">>, S))),
    Child = #{<<"effects">> => [<<"model.generate">>],
        <<"requirements">> => [#{<<"kind">> => <<"model">>, <<"resource">> => Model}],
        <<"scopes">> => #{<<"models">> => [Model], <<"workspaces">> => [], <<"paths">> => []},
        <<"budgets">> => ChildBudget},
    {[action(<<"frame">>, <<"model.generate">>, []), action(<<"delegate">>, <<"child.run">>, [<<"frame">>]), action(<<"publish">>, <<"workspace.write">>, [<<"delegate">>]), action(<<"finish">>, <<"complete">>, [<<"publish">>])],
        [<<"child.run">>, <<"model.generate">>, <<"workspace.write">>], budgets(4, 2, 0, 1, 1, maps:get(<<"max_bytes">>, S), maps:get(<<"timeout_ms">>, S)), Child}.

error_branches(_Family, null) -> [];
error_branches(Family, On) ->
    Action = case {Family, On} of
        {<<"attenuated-delegation">>, _} -> <<"delegate">>;
        {<<"repair-and-publish">>, _} -> <<"repair">>;
        {_, <<"timeout">>} -> <<"draft">>;
        _ -> <<"publish">>
    end,
    [#{<<"action">> => Action, <<"on">> => On, <<"terminal_class">> => <<"failed">>}].

action(Id, Operation, Depends) -> #{<<"id">> => Id, <<"operation">> => Operation, <<"depends_on">> => Depends}.
budgets(Steps, Model, Repair, Child, Writes, Bytes, Timeout) -> #{
    <<"steps">> => Steps, <<"model_calls">> => Model, <<"repair_calls">> => Repair,
    <<"child_calls">> => Child, <<"workspace_writes">> => Writes,
    <<"output_bytes">> => Bytes, <<"timeout_ms">> => Timeout}.

normalized_input(Value) -> binary:replace(Value, <<"_">>, <<"-">>, [global]).

development_content(Directory) ->
    Paths = filelib:wildcard(filename:join([Directory, "*", "*"])),
    ensure(length(Paths) >= 72, [<<"development_corpus">>], missing_or_incomplete_development_corpus),
    iolist_to_binary([case file:read_file(Path) of
        {ok, Binary} -> Binary;
        {error, Reason} -> fail([<<"development_corpus">>], {read_failed, Path, Reason})
    end || Path <- Paths]).

contains_ci(Haystack, Needle) ->
    binary:match(string:lowercase(Haystack), string:lowercase(Needle)) =/= nomatch.

closed(Value, Keys, Path) ->
    ensure(is_map(Value), Path, expected_object),
    Actual = maps:keys(Value),
    ensure(Actual -- Keys =:= [], Path, {unknown_fields, lists:sort(Actual -- Keys)}),
    ensure(Keys -- Actual =:= [], Path, {missing_fields, lists:sort(Keys -- Actual)}).
exact(Value, Expected, Path) -> ensure(Value =:= Expected, Path, {expected_exact_value, Expected, Value}).
member(Value, Values, Path) -> ensure(lists:member(Value, Values), Path, {not_in_closed_enum, Value}).
nonempty(Value, Path) -> ensure(is_binary(Value) andalso byte_size(Value) > 0, Path, expected_nonempty_string).
integer(Value, Low, High, Path) -> ensure(is_integer(Value) andalso Value >= Low andalso Value =< High, Path, expected_bounded_integer).
string_list(Value, Path) ->
    ensure(is_list(Value), Path, expected_array),
    lists:foreach(fun(Item) -> nonempty(Item, Path) end, Value), unique(Value, Path, duplicate_value).
unique(Value, Path, Reason) -> ensure(length(Value) =:= length(lists:usort(Value)), Path, Reason).
indexed(List) -> lists:zip(List, lists:seq(0, length(List) - 1)).
ensure(true, _Path, _Reason) -> ok;
ensure(false, Path, Reason) -> fail(Path, Reason).
fail(Path, Reason) -> throw({compact_corpus_error, Path, Reason}).
