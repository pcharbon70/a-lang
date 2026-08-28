-module(alang_mnemonic_corpus).

-export([load/1, oracle/1, validate/3]).

-define(FAMILIES, [<<"single-model-artifact">>, <<"repair-and-publish">>,
    <<"attenuated-delegation">>]).
-define(STRATA, [<<"simple">>, <<"constraint-heavy">>, <<"scope-budget">>,
    <<"error-branch">>, <<"missing-information">>, <<"irrelevant-context">>,
    <<"prompt-injection">>, <<"lexical-value-perturbation">>]).

-spec load(file:filename()) -> {ok, map()} | {error, term()}.
load(AssetsDirectory) ->
    CorpusPath = filename:join([AssetsDirectory, "corpus", "confirmatory-corpus-v1.json"]),
    DesignPath = filename:join([AssetsDirectory, "campaign", "case-design-v1.json"]),
    case {alang_fidelity_json:decode_file(CorpusPath), alang_fidelity_json:decode_file(DesignPath)} of
        {{ok, Corpus}, {ok, Design}} -> validate(Corpus, Design, repo_root(AssetsDirectory));
        {{error, Reason}, _} -> {error, {mnemonic_corpus_error, corpus, Reason}};
        {_, {error, Reason}} -> {error, {mnemonic_corpus_error, design, Reason}}
    end.

-spec validate(term(), term(), file:filename()) -> {ok, map()} | {error, term()}.
validate(Corpus, Design, RepoRoot) ->
    try
        validate_header(Corpus),
        OldCorpus = (maps:without([<<"prior_confirmatory_corpus">>, <<"coverage_required">>], Corpus))#{
            <<"format">> := <<"alang-compact-confirmatory-corpus-v1">>,
            <<"boundary">> := <<"confirmatory-held-out">>},
        OldDesign = Design#{<<"format">> := <<"alang-compact-case-design-v1">>,
            <<"boundary">> := <<"confirmatory-held-out">>},
        Development = filename:join([RepoRoot, "assets", "effectful-source-fidelity", "corpus"]),
        BaseEvidence = case alang_compact_corpus:validate(OldCorpus, OldDesign, Development) of
            {ok, Evidence} -> Evidence;
            {error, BaseReason} -> fail({base_semantic_validation_failed, BaseReason})
        end,
        Cases = maps:get(<<"cases">>, Corpus),
        validate_design_source_separation(Cases, Corpus, RepoRoot),
        Coverage = validate_coverage(Cases),
        validate_new_condition_blinding(Cases),
        {ok, BaseEvidence#{
            <<"format">> := <<"alang-token-positive-corpus-evidence-v1">>,
            <<"previous_design_cases">> => 72,
            <<"design_input_overlaps">> => 0,
            <<"coverage">> => Coverage,
            <<"prospective_boundary">> => true
        }}
    catch
        error:{badmap, _} -> {error, {mnemonic_corpus_error, expected_object}};
        error:{badkey, Key} -> {error, {mnemonic_corpus_error, {missing_field, Key}}};
        throw:{mnemonic_corpus_error, Reason} -> {error, {mnemonic_corpus_error, Reason}}
    end.

-spec oracle(map()) -> map().
oracle(Case) -> alang_compact_corpus:oracle(Case).

validate_header(Corpus) ->
    Keys = [<<"format">>, <<"boundary">>, <<"development_corpus">>,
        <<"prior_confirmatory_corpus">>, <<"families">>, <<"strata">>,
        <<"coverage_required">>, <<"audit_log">>, <<"cases">>],
    closed(Corpus, Keys, corpus),
    exact(maps:get(<<"format">>, Corpus), <<"alang-token-positive-confirmatory-corpus-v1">>, format),
    exact(maps:get(<<"boundary">>, Corpus), <<"prospective-confirmatory-held-out">>, boundary),
    exact(maps:get(<<"development_corpus">>, Corpus), <<"assets/effectful-source-fidelity/corpus">>, development),
    exact(maps:get(<<"prior_confirmatory_corpus">>, Corpus),
        <<"assets/compact-projection-fidelity/corpus/confirmatory-corpus-v1.json">>, prior),
    exact(maps:get(<<"families">>, Corpus), ?FAMILIES, families),
    exact(maps:get(<<"strata">>, Corpus), ?STRATA, strata),
    exact(maps:get(<<"coverage_required">>, Corpus),
        [<<"same-prefix">>, <<"negation">>, <<"numeric-value">>, <<"prompt-injection">>], coverage),
    ensure(length(maps:get(<<"cases">>, Corpus)) =:= 48, case_count).

validate_design_source_separation(Cases, Corpus, RepoRoot) ->
    Relative = maps:get(<<"prior_confirmatory_corpus">>, Corpus),
    Path = filename:join(RepoRoot, binary_to_list(Relative)),
    Prior = case file:read_file(Path) of
        {ok, Bytes} -> Bytes;
        {error, Reason} -> fail({prior_corpus_read_failed, Reason})
    end,
    lists:foreach(fun(Case) ->
        Values = case_values(Case),
        lists:foreach(fun(Value) ->
            ensure(binary:match(Prior, Value) =:= nomatch,
                {prior_confirmatory_overlap, maps:get(<<"id">>, Case), Value})
        end, Values)
    end, Cases).

case_values(Case) ->
    Semantic = maps:get(<<"oracle">>, Case),
    [maps:get(<<"id">>, Case), maps:get(<<"request">>, Case),
        maps:get(<<"input_name">>, Semantic), maps:get(<<"model">>, Semantic),
        maps:get(<<"workspace">>, Semantic), maps:get(<<"path">>, Semantic)] ++
        maps:get(<<"goal_facts">>, Semantic).

validate_new_condition_blinding(Cases) ->
    Forbidden = [<<"P0">>, <<"P1">>, <<"R2">>, <<"alang-source-v2-alias-v1">>,
        <<"semantic_digest">>, <<"answer-key">>],
    lists:foreach(fun(Case) ->
        Visible = [maps:get(<<"request">>, Case) | maps:get(<<"untrusted_context">>, Case)],
        lists:foreach(fun(Text) -> lists:foreach(fun(Token) ->
            ensure(binary:match(Text, Token) =:= nomatch,
                {condition_or_answer_leak, maps:get(<<"id">>, Case), Token})
        end, Forbidden) end, Visible)
    end, Cases).

validate_coverage(Cases) ->
    ConstraintGoals = goals_for(<<"constraint-heavy">>, Cases),
    LexicalGoals = goals_for(<<"lexical-value-perturbation">>, Cases),
    InjectionContext = lists:append([maps:get(<<"untrusted_context">>, C) || C <- Cases,
        maps:get(<<"stratum">>, C) =:= <<"prompt-injection">>]),
    SamePrefix = contains_any(ConstraintGoals, <<".extra">>),
    Negation = contains_any(ConstraintGoals, <<"not authorized">>),
    Numeric = lists:any(fun contains_digit/1, LexicalGoals),
    Injection = contains_any(InjectionContext, <<"Untrusted">>),
    lists:foreach(fun({Name, Pass}) -> ensure(Pass, {missing_coverage, Name}) end,
        [{same_prefix, SamePrefix}, {negation, Negation}, {numeric_value, Numeric}, {prompt_injection, Injection}]),
    #{<<"same_prefix">> => SamePrefix, <<"negation">> => Negation,
        <<"numeric_value">> => Numeric, <<"prompt_injection">> => Injection}.

goals_for(Stratum, Cases) -> lists:append([maps:get(<<"goal_facts">>, maps:get(<<"oracle">>, C))
    || C <- Cases, maps:get(<<"stratum">>, C) =:= Stratum]).
contains_any(Values, Needle) -> lists:any(fun(V) -> binary:match(V, Needle) =/= nomatch end, Values).
contains_digit(Binary) -> lists:any(fun(C) -> C >= $0 andalso C =< $9 end, binary_to_list(Binary)).

repo_root(AssetsDirectory) -> filename:dirname(filename:dirname(AssetsDirectory)).
closed(Value, Keys, Reason) ->
    ensure(is_map(Value), {Reason, expected_object}), Actual = maps:keys(Value),
    ensure(Actual -- Keys =:= [], {Reason, unknown_fields, lists:sort(Actual -- Keys)}),
    ensure(Keys -- Actual =:= [], {Reason, missing_fields, lists:sort(Keys -- Actual)}).
exact(Value, Expected, Reason) -> ensure(Value =:= Expected, {expected, Reason, Expected, Value}).
ensure(true, _Reason) -> ok;
ensure(false, Reason) -> fail(Reason).
fail(Reason) -> throw({mnemonic_corpus_error, Reason}).
