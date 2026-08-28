-module(alang_mnemonic_qualification).

-export([build/1, registration_files/1, validate_contract/2, write/2]).

-define(CONTRACT, "assets/token-positive-mnemonic-promotion/phase-02/contracts/qualification-contract-v1.json").
-define(PROFILES, [<<"tiktoken-0.12.0-cl100k-base">>,
    <<"tiktoken-0.12.0-o200k-base">>]).
-define(PROTOCOLS, [<<"action-completion">>, <<"comprehension">>,
    <<"diagnostic-repair">>, <<"generation">>]).
-define(CATEGORIES, [<<"layout">>, <<"vocabulary">>, <<"identifiers">>,
    <<"facts">>, <<"paths">>, <<"budgets">>, <<"authority">>,
    <<"completion">>, <<"legends">>, <<"instructions">>,
    <<"output-scaffolding">>]).

-spec build(file:filename()) -> {ok, map()} | {error, term()}.
build(RepoRoot) ->
    try
        Contract = decode(filename:join(RepoRoot, ?CONTRACT)),
        ok = validate_contract(Contract, RepoRoot),
        CaseRecords = case_records(RepoRoot),
        Directory = filename:join(RepoRoot,
            binary_to_list(maps:get(<<"tokenizer_directory">>, Contract))),
        Rows = [audit_case(Profile, Record, Directory) ||
            Profile <- ?PROFILES, Record <- CaseRecords],
        Summaries = [profile_summary(Profile, Rows) || Profile <- ?PROFILES],
        Gate = gate(Summaries, Rows),
        exact(maps:get(<<"pass">>, Gate), true, offline_token_gate),
        Files = [file_entry(Path, RepoRoot) || Path <- registration_files(RepoRoot)],
        {ok, Schedule} = checked(alang_mnemonic_schedule:materialize(filename:join([
            RepoRoot, "assets", "token-positive-mnemonic-promotion", "campaign"]))),
        Body = #{
            <<"format">> => <<"alang-token-positive-phase-2-qualification-v1">>,
            <<"registration_file_count">> => length(Files),
            <<"registration_digest">> => alang_fidelity_json:digest(Files),
            <<"registration_files">> => Files,
            <<"phase1_registration_digest">> =>
                <<"e7804254acc846c8e5ec83ac959c3f3d7fc8ea321209a26bd0b7cfcc4ded4c5b">>,
            <<"semantic_cases">> => 48,
            <<"document_pairs">> => 96,
            <<"full_request_pairs">> => 384,
            <<"candidate_conformance_digest">> => conformance_digest(CaseRecords),
            <<"protocol_oracle_digest">> => protocol_digest(CaseRecords),
            <<"token_report_digest">> => alang_fidelity_json:digest(Rows),
            <<"schedule_digest">> => alang_fidelity_json:digest(Schedule),
            <<"profiles">> => Summaries,
            <<"gate">> => Gate,
            <<"attribution_categories">> => ?CATEGORIES,
            <<"hosted_calls_observed">> => 0,
            <<"efficacy_observations">> => 0,
            <<"network_authorized">> => false,
            <<"model_fidelity_claim">> => false
        },
        {ok, Body#{<<"qualification_digest">> => alang_fidelity_json:digest(Body)}}
    catch
        error:{badkey, Key} -> {error, {mnemonic_qualification_error, {missing_field, Key}}};
        error:{badmatch, Reason} -> {error, {mnemonic_qualification_error, {badmatch, Reason}}};
        throw:{mnemonic_qualification_error, Reason} ->
            {error, {mnemonic_qualification_error, Reason}}
    end.

-spec validate_contract(term(), file:filename()) -> ok | no_return().
validate_contract(Contract, RepoRoot) ->
    exact(maps:keys(Contract), [<<"attribution_categories">>, <<"cases">>,
        <<"conditions">>, <<"format">>, <<"live_authorization">>,
        <<"protocols">>, <<"registration">>, <<"thresholds">>,
        <<"tokenizer_directory">>, <<"tokenizers">>], contract_fields),
    exact(maps:get(<<"format">>, Contract),
        <<"alang-token-positive-qualification-contract-v1">>, format),
    exact(maps:get(<<"cases">>, Contract), 48, cases),
    exact(maps:get(<<"protocols">>, Contract), 4, protocols),
    exact(maps:get(<<"conditions">>, Contract), 2, conditions),
    exact(maps:get(<<"attribution_categories">>, Contract), ?CATEGORIES, categories),
    exact(maps:get(<<"thresholds">>, Contract), expected_thresholds(), thresholds),
    exact(maps:get(<<"live_authorization">>, Contract), #{
        <<"network_default">> => <<"disabled">>,
        <<"environment_variable">> => <<"ALANG_ALLOW_MNEMONIC_MODEL_CALLS">>,
        <<"required_value">> => <<"1">>,
        <<"qualification_digest_required">> => true,
        <<"any_drift">> => <<"reject">>}, live_authorization),
    Tokenizers = maps:get(<<"tokenizers">>, Contract),
    exact([maps:get(<<"profile_id">>, T) || T <- Tokenizers], ?PROFILES, profiles),
    lists:foreach(fun(T) -> verify_sha(filename:join(RepoRoot,
        binary_to_list(maps:get(<<"vocabulary_path">>, T))),
        maps:get(<<"vocabulary_sha256">>, T)) end, Tokenizers),
    RuntimePath = filename:join([RepoRoot,
        binary_to_list(maps:get(<<"tokenizer_directory">>, Contract)),
        "tokenizer-runtime-v1.json"]),
    {ok, _} = checked(alang_compact_tokenizer:load_runtime(RuntimePath)),
    ok.

case_records(RepoRoot) ->
    CorpusPath = filename:join([RepoRoot, "assets", "token-positive-mnemonic-promotion",
        "corpus", "confirmatory-corpus-v1.json"]),
    Corpus = decode(CorpusPath),
    [begin
        Oracle = alang_mnemonic_corpus:oracle(Case),
        {ok, P0} = checked(alang_mnemonic_candidate:render(<<"P0">>, Oracle, RepoRoot)),
        {ok, P1} = checked(alang_mnemonic_candidate:render(<<"P1">>, Oracle, RepoRoot)),
        Prompts = maps:from_list([{{Protocol, Condition}, Prompt} ||
            Protocol <- ?PROTOCOLS, Condition <- [<<"P0">>, <<"P1">>],
            {ok, Prompt} <- [checked(alang_mnemonic_protocol:materialize(
                Case, Oracle, Condition, Protocol, RepoRoot))]]),
        #{'case' => Case, oracle => Oracle, p0 => P0, p1 => P1, prompts => Prompts}
    end || Case <- maps:get(<<"cases">>, Corpus)].

audit_case(Profile, Record, Directory) ->
    P0 = maps:get(p0, Record), P1 = maps:get(p1, Record),
    D0 = count(Profile, maps:get(bytes, P0), Directory),
    D1 = count(Profile, maps:get(bytes, P1), Directory),
    Requests = [begin
        Prompt0 = maps:get({Protocol, <<"P0">>}, maps:get(prompts, Record)),
        Prompt1 = maps:get({Protocol, <<"P1">>}, maps:get(prompts, Record)),
        R0 = count(Profile, maps:get(<<"bytes">>, Prompt0), Directory),
        R1 = count(Profile, maps:get(<<"bytes">>, Prompt1), Directory),
        #{<<"protocol">> => Protocol, <<"p0">> => R0, <<"p1">> => R1,
            <<"savings_basis_points">> => basis_points(R0, R1),
            <<"attribution">> => #{
                <<"P0">> => attribution(Profile, P0, Prompt0, Directory),
                <<"P1">> => attribution(Profile, P1, Prompt1, Directory)}}
    end || Protocol <- ?PROTOCOLS],
    #{<<"case_id">> => maps:get(<<"id">>, maps:get('case', Record)),
        <<"profile_id">> => Profile,
        <<"document">> => #{<<"p0">> => D0, <<"p1">> => D1,
            <<"savings_basis_points">> => basis_points(D0, D1)},
        <<"requests">> => Requests}.

attribution(Profile, Surface, Prompt, Directory) ->
    SurfaceSections = maps:get(sections, Surface),
    PromptSections = maps:get(<<"sections">>, Prompt),
    Components = #{
        <<"layout">> => maps:get(layout, SurfaceSections),
        <<"vocabulary">> => maps:get(keywords, SurfaceSections),
        <<"identifiers">> => maps:get(identifiers, SurfaceSections),
        <<"facts">> => iolist_to_binary([maps:get(facts, SurfaceSections),
            maps:get(<<"case_material">>, PromptSections)]),
        <<"paths">> => maps:get(paths, SurfaceSections),
        <<"budgets">> => maps:get(budgets, SurfaceSections),
        <<"authority">> => maps:get(authority, SurfaceSections),
        <<"completion">> => maps:get(completion, SurfaceSections),
        <<"legends">> => maps:get(<<"condition_legend">>, PromptSections),
        <<"instructions">> => iolist_to_binary([
            maps:get(<<"opaque_trial_id">>, PromptSections), <<"\n">>,
            maps:get(<<"common_instruction">>, PromptSections), <<"\n">>,
            maps:get(<<"protocol_instruction">>, PromptSections)]),
        <<"output-scaffolding">> => maps:get(<<"output_contract">>, PromptSections)
    },
    maps:from_list([{Name, count(Profile, maps:get(Name, Components), Directory)}
        || Name <- ?CATEGORIES]).

profile_summary(Profile, Rows) ->
    Selected = [R || R <- Rows, maps:get(<<"profile_id">>, R) =:= Profile],
    Docs = [maps:get(<<"document">>, R) || R <- Selected],
    Requests = lists:append([maps:get(<<"requests">>, R) || R <- Selected]),
    summary(Profile, Docs, Requests).

summary(Profile, Docs, Requests) ->
    D0 = lists:sum([maps:get(<<"p0">>, D) || D <- Docs]),
    D1 = lists:sum([maps:get(<<"p1">>, D) || D <- Docs]),
    R0 = lists:sum([maps:get(<<"p0">>, R) || R <- Requests]),
    R1 = lists:sum([maps:get(<<"p1">>, R) || R <- Requests]),
    #{<<"profile_id">> => Profile,
        <<"documents_all_strictly_cheaper">> => all_cheaper(Docs),
        <<"requests_all_strictly_cheaper">> => all_cheaper(Requests),
        <<"document_aggregate_savings_basis_points">> => basis_points(D0, D1),
        <<"document_median_savings_basis_points">> => median([
            maps:get(<<"savings_basis_points">>, D) || D <- Docs]),
        <<"request_aggregate_savings_basis_points">> => basis_points(R0, R1),
        <<"request_median_savings_basis_points">> => median([
            maps:get(<<"savings_basis_points">>, R) || R <- Requests]),
        <<"p0_document_tokens">> => D0, <<"p1_document_tokens">> => D1,
        <<"p0_request_tokens">> => R0, <<"p1_request_tokens">> => R1}.

gate(Summaries, Rows) ->
    Min = 500,
    CategoriesComplete = lists:all(fun(Row) -> lists:all(fun(Request) ->
        A = maps:get(<<"attribution">>, Request),
        lists:all(fun(Condition) -> maps:keys(maps:get(Condition, A)) =:=
            lists:sort(?CATEGORIES) end,
            [<<"P0">>, <<"P1">>])
    end, maps:get(<<"requests">>, Row)) end, Rows),
    Predicates = [
        lists:all(fun(S) -> maps:get(<<"documents_all_strictly_cheaper">>, S) end, Summaries),
        lists:all(fun(S) -> maps:get(<<"requests_all_strictly_cheaper">>, S) end, Summaries),
        lists:all(fun(S) -> maps:get(<<"document_aggregate_savings_basis_points">>, S) >= Min end, Summaries),
        lists:all(fun(S) -> maps:get(<<"document_median_savings_basis_points">>, S) >= Min end, Summaries),
        lists:all(fun(S) -> maps:get(<<"request_aggregate_savings_basis_points">>, S) >= Min end, Summaries),
        lists:all(fun(S) -> maps:get(<<"request_median_savings_basis_points">>, S) >= Min end, Summaries),
        CategoriesComplete],
    #{<<"pass">> => lists:all(fun(X) -> X end, Predicates),
        <<"every_document_strictly_cheaper">> => lists:nth(1, Predicates),
        <<"every_full_request_strictly_cheaper">> => lists:nth(2, Predicates),
        <<"aggregate_document_savings_at_least_five_percent">> => lists:nth(3, Predicates),
        <<"median_document_savings_at_least_five_percent">> => lists:nth(4, Predicates),
        <<"aggregate_request_savings_at_least_five_percent">> => lists:nth(5, Predicates),
        <<"median_request_savings_at_least_five_percent">> => lists:nth(6, Predicates),
        <<"attribution_complete">> => CategoriesComplete}.

conformance_digest(Records) -> alang_fidelity_json:digest([#{
    <<"case_id">> => maps:get(<<"id">>, maps:get('case', R)),
    <<"semantic_digest">> => alang_fidelity_contract:semantic_digest(maps:get(oracle, R)),
    <<"p0_sha256">> => maps:get(representation_sha256, maps:get(p0, R)),
    <<"p1_sha256">> => maps:get(representation_sha256, maps:get(p1, R)),
    <<"p1_r2_byte_equal">> => maps:get(byte_equal_to_r2, maps:get(p1, R)),
    <<"p0_source_map">> => alang_fidelity_json:digest(maps:get(source_map, maps:get(p0, R))),
    <<"p1_source_map">> => alang_fidelity_json:digest(maps:get(source_map, maps:get(p1, R)))
} || R <- Records]).

protocol_digest(Records) -> alang_fidelity_json:digest(lists:append([[
    #{<<"case_id">> => maps:get(<<"id">>, maps:get('case', R)),
        <<"protocol">> => Protocol, <<"condition">> => Condition,
        <<"prompt_sha256">> => maps:get(<<"sha256">>,
            maps:get({Protocol, Condition}, maps:get(prompts, R))),
        <<"oracle">> => maps:get(<<"oracle">>,
            maps:get({Protocol, Condition}, maps:get(prompts, R)))}
    || Protocol <- ?PROTOCOLS, Condition <- [<<"P0">>, <<"P1">>]]
    || R <- Records])).

-spec registration_files(file:filename()) -> [file:filename()].
registration_files(RepoRoot) ->
    Phase1Base = filename:join([RepoRoot, "assets", "token-positive-mnemonic-promotion"]),
    Phase1 = alang_mnemonic_preregister:registration_files(Phase1Base),
    Relative = [
        "assets/token-positive-mnemonic-promotion/phase-02/contracts/candidate-contract-v1.json",
        "assets/token-positive-mnemonic-promotion/phase-02/contracts/candidate-contract-v1.schema.json",
        "assets/token-positive-mnemonic-promotion/phase-02/contracts/protocol-contract-v1.json",
        "assets/token-positive-mnemonic-promotion/phase-02/contracts/protocol-contract-v1.schema.json",
        "assets/token-positive-mnemonic-promotion/phase-02/contracts/qualification-contract-v1.json",
        "assets/token-positive-mnemonic-promotion/phase-02/contracts/qualification-contract-v1.schema.json",
        "assets/token-positive-mnemonic-promotion/phase-02/contracts/qualification-evidence-v1.schema.json",
        "assets/compact-projection-fidelity/campaign/projection-vocabulary-v1.json",
        "assets/compact-projection-fidelity/phase-02/contracts/surface-registry-v1.json",
        "assets/compact-projection-fidelity/phase-02/contracts/source-map-v1.json",
        "assets/compact-projection-fidelity/phase-02/tokenizers/tokenizer-runtime-v1.json",
        "assets/compact-projection-fidelity/phase-02/tokenizers/cl100k_base.tiktoken",
        "assets/compact-projection-fidelity/phase-02/tokenizers/o200k_base.tiktoken",
        "src/effectful-source-fidelity/alang_fidelity_json.erl",
        "src/effectful-source-fidelity/alang_fidelity_contract.erl",
        "src/effectful-source-fidelity/alang_fidelity_representation.erl",
        "src/effectful-source-fidelity/alang_fidelity_lexer.erl",
        "src/effectful-source-fidelity/alang_fidelity_parser.erl",
        "src/effectful-source-fidelity/alang_fidelity_ast.erl",
        "src/effectful-source-fidelity/alang_fidelity_source.erl",
        "src/compact-projection-fidelity/alang_compact_source_normalizer.erl",
        "src/compact-projection-fidelity/alang_compact_surface.erl",
        "src/compact-projection-fidelity/alang_compact_source_map.erl",
        "src/compact-projection-fidelity/alang_compact_tokenizer.erl",
        "src/token-positive-mnemonic-promotion/alang_mnemonic_contract.erl",
        "src/token-positive-mnemonic-promotion/alang_mnemonic_candidate.erl",
        "src/token-positive-mnemonic-promotion/alang_mnemonic_protocol.erl",
        "src/token-positive-mnemonic-promotion/alang_mnemonic_qualification.erl",
        "src/token-positive-mnemonic-promotion/alang_mnemonic_authorization.erl"
    ],
    lists:sort(lists:usort(Phase1 ++ [filename:join(RepoRoot, P) || P <- Relative])).

-spec write(file:filename(), file:filename()) -> {ok, map()} | {error, term()}.
write(RepoRoot, Output) ->
    try
        Absolute = safe_output(Output, RepoRoot),
        {ok, Evidence} = checked(build(RepoRoot)),
        {ok, Bytes} = alang_fidelity_json:encode_canonical(Evidence),
        ok = filelib:ensure_dir(Absolute), ok = file:write_file(Absolute, [Bytes, <<"\n">>]),
        {ok, Evidence}
    catch
        throw:{mnemonic_qualification_error, Reason} ->
            {error, {mnemonic_qualification_error, Reason}};
        Class:Reason -> {error, {mnemonic_qualification_write_error, Class, Reason}}
    end.

safe_output(Output, RepoRoot) ->
    Absolute = filename:absname(Output),
    Owned = filename:join([root_abs(RepoRoot), "build",
        "token-positive-mnemonic-promotion", "phase-02"]),
    ensure(lists:prefix(Owned ++ "/", Absolute), {output_outside_owned_root, Output}), Absolute.

file_entry(Path, RepoRoot) ->
    {ok, Bytes} = file:read_file(Path),
    #{<<"path">> => list_to_binary(relative(Path, RepoRoot)),
        <<"sha256">> => hex(crypto:hash(sha256, Bytes))}.
relative(Path, RepoRoot) ->
    Absolute = filename:absname(Path), Prefix = root_abs(RepoRoot) ++ "/",
    ensure(lists:prefix(Prefix, Absolute), {path_outside_repo, Path}),
    lists:nthtail(length(Prefix), Absolute).

root_abs(RepoRoot) ->
    filename:dirname(filename:absname(filename:join(RepoRoot, ".repo-root-marker"))).

count(Profile, Bytes, Directory) ->
    {ok, Encoded} = checked(alang_compact_tokenizer:encode(Profile, Bytes, Directory)),
    maps:get(token_count, Encoded).
all_cheaper(Values) -> lists:all(fun(V) ->
    maps:get(<<"p1">>, V) < maps:get(<<"p0">>, V) end, Values).
basis_points(Baseline, Candidate) ->
    ((Baseline - Candidate) * 10000 + Baseline div 2) div Baseline.
median(Values) ->
    Sorted = lists:sort(Values), N = length(Sorted),
    case N rem 2 of
        1 -> lists:nth((N + 1) div 2, Sorted);
        0 -> (lists:nth(N div 2, Sorted) + lists:nth(N div 2 + 1, Sorted)) div 2
    end.
expected_thresholds() -> #{
    <<"every_document_strictly_cheaper">> => true,
    <<"every_full_request_strictly_cheaper">> => true,
    <<"minimum_aggregate_document_savings_basis_points">> => 500,
    <<"minimum_median_document_savings_basis_points">> => 500,
    <<"minimum_aggregate_request_savings_basis_points">> => 500,
    <<"minimum_median_request_savings_basis_points">> => 500}.
decode(Path) -> {ok, Value} = checked(alang_fidelity_json:decode_file(Path)), Value.
verify_sha(Path, Expected) ->
    {ok, Bytes} = case file:read_file(Path) of
        {ok, Value} -> {ok, Value};
        {error, Reason} -> fail({read_failed, Path, Reason})
    end,
    exact(hex(crypto:hash(sha256, Bytes)), Expected, {digest, Path}).
checked({ok, _} = Result) -> Result;
checked({error, Reason}) -> fail(Reason).
exact(Value, Expected, _Reason) when Value =:= Expected -> ok;
exact(Value, Expected, Reason) -> fail({expected, Reason, Expected, Value}).
ensure(true, _Reason) -> ok;
ensure(false, Reason) -> fail(Reason).
fail(Reason) -> throw({mnemonic_qualification_error, Reason}).
hex(Binary) -> alang_fidelity_json:hex(Binary).
