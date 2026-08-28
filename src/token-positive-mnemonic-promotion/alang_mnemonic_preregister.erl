-module(alang_mnemonic_preregister).

-export([build/1, registration_files/1, validate/1,
    validate_traceability/2, write/2]).

-spec build(file:filename()) -> {ok, map()} | {error, term()}.
build(Base) ->
    case validate(Base) of
        {ok, V} ->
            Entries = [file_entry(Path, Base) || Path <- registration_files(Base)],
            Trace = maps:get(<<"traceability">>, V),
            Evidence = #{
                <<"format">> => <<"alang-token-positive-phase-1-evidence-v1">>,
                <<"registration_file_count">> => length(Entries),
                <<"registration_digest">> => alang_fidelity_json:digest(Entries),
                <<"files">> => Entries,
                <<"derived_digests">> => derived_digests(V),
                <<"selected_cases">> => 48,
                <<"primary_cells">> => 1536,
                <<"hard_request_ceiling">> => 3072,
                <<"model_families">> => 2,
                <<"protocols">> => 4,
                <<"conditions">> => 2,
                <<"design_evidence">> => maps:get(<<"design_evidence">>, Trace),
                <<"scope">> => maps:get(<<"scope">>, V),
                <<"schema_count">> => 11,
                <<"mutations">> => maps:get(<<"mutations">>, V),
                <<"hosted_calls_observed">> => 0,
                <<"efficacy_observations">> => 0,
                <<"network_authorized">> => false
            },
            {ok, Evidence};
        {error, _} = Error -> Error
    end.

-spec write(file:filename(), file:filename()) -> {ok, map()} | {error, term()}.
write(Base, Output) ->
    try
        SafeOutput = safe_output(Output),
        case build(Base) of
            {ok, Evidence} ->
                {ok, Bytes} = alang_fidelity_json:encode_canonical(Evidence),
                ok = filelib:ensure_dir(SafeOutput),
                ok = file:write_file(SafeOutput, [Bytes, <<"\n">>]),
                {ok, Evidence};
            {error, _} = Error -> Error
        end
    catch Class:Reason -> {error, {mnemonic_evidence_write_failed, Class, Reason}} end.

-spec validate(file:filename()) -> {ok, map()} | {error, term()}.
validate(Base) ->
    try
        Campaign = filename:join(Base, "campaign"),
        Contracts = filename:join(Base, "contracts"),
        RepoRoot = filename:dirname(filename:dirname(Base)),
        {ok, Contract} = checked(alang_mnemonic_contract:load(
            filename:join(Contracts, "campaign-contract-v1.json"))),
        {ok, Reference} = checked(alang_mnemonic_contract:validate_reference(Contract, RepoRoot)),
        {ok, Power} = checked(alang_mnemonic_power:load(
            filename:join(Campaign, "power-design-v1.json"))),
        {ok, Schedule} = checked(alang_mnemonic_schedule:materialize(Campaign)),
        {ok, Corpus} = checked(alang_mnemonic_corpus:load(Base)),
        {ok, Registration} = checked(alang_mnemonic_registration:load(Base)),
        Trace = decode(filename:join(Campaign, "traceability-v1.json")),
        ok = validate_traceability(Trace, RepoRoot),
        Schemas = validate_schemas(Contracts),
        ok = reconcile(Contract, Power, Schedule, Corpus, Registration),
        {ok, Mutations} = checked(alang_mnemonic_mutation:run(Base)),
        {ok, #{
            <<"format">> => <<"alang-token-positive-phase-1-validation-v1">>,
            <<"contract">> => Contract,
            <<"reference">> => Reference,
            <<"power">> => Power,
            <<"schedule">> => Schedule,
            <<"corpus">> => Corpus,
            <<"registration">> => Registration,
            <<"traceability">> => Trace,
            <<"schemas">> => Schemas,
            <<"scope">> => scope_audit(Trace, RepoRoot),
            <<"mutations">> => Mutations,
            <<"hosted_calls_observed">> => 0,
            <<"efficacy_observations">> => 0
        }}
    catch
        throw:{mnemonic_preregistration_error, Reason} ->
            {error, {mnemonic_preregistration_error, Reason}};
        error:{badmatch, Reason} ->
            {error, {mnemonic_preregistration_error, {badmatch, Reason}}};
        error:{badkey, Key} ->
            {error, {mnemonic_preregistration_error, {missing_field, Key}}}
    end.

-spec validate_traceability(term(), file:filename()) -> ok | no_return().
validate_traceability(Value, RepoRoot) ->
    closed(Value, [<<"format">>, <<"sources">>, <<"design_evidence">>,
        <<"included_scope">>, <<"excluded_scope">>, <<"observation_boundary">>], traceability),
    exact(maps:get(<<"format">>, Value), <<"alang-token-positive-traceability-v1">>, traceability_format),
    Sources = maps:get(<<"sources">>, Value),
    exact(length(Sources), 5, source_count),
    lists:foreach(fun(Source) ->
        closed(Source, [<<"role">>, <<"path">>], traceability_source),
        Path = binary_to_list(maps:get(<<"path">>, Source)),
        ensure(filelib:is_regular(filename:join(RepoRoot, Path)), {missing_source, Path})
    end, Sources),
    exact(maps:get(<<"design_evidence">>, Value), expected_design_evidence(), design_evidence),
    exact(maps:get(<<"included_scope">>, Value), expected_included_scope(), included_scope),
    exact(maps:get(<<"excluded_scope">>, Value), expected_excluded_scope(), excluded_scope),
    exact(maps:get(<<"observation_boundary">>, Value), #{
        <<"fresh_cases">> => 48, <<"prior_design_cases">> => 72,
        <<"hosted_calls_observed">> => 0, <<"efficacy_observations">> => 0,
        <<"network_authorized">> => false}, observation_boundary),
    ok.

reconcile(Contract, Power, Schedule, Corpus, Registration) ->
    exact(maps:get(<<"candidate_condition">>, Contract), <<"P1">>, candidate),
    exact(maps:get(<<"selected_cases">>, Power), 48, selected_cases),
    exact(maps:get(<<"semantic_cases">>, Corpus), 48, corpus_cases),
    exact(length(maps:get(<<"cells">>, Schedule)), 1536, primary_cells),
    Policy = maps:get(<<"policy">>, Registration),
    exact(maps:get(<<"primary_requests">>, Policy), 1536, primary_requests),
    exact(maps:get(<<"hard_request_ceiling">>, Policy), 3072, hard_ceiling),
    exact(maps:get(<<"exact_profiles">>, maps:get(<<"profiles">>, Registration)), 2, profiles),
    exact(maps:get(<<"protocols">>, maps:get(<<"prompts">>, Registration)), 4, protocols),
    exact(maps:get(<<"hosted_calls_observed">>, Registration), 0, hosted_calls),
    exact(maps:get(<<"network_authorized">>, Registration), false, network),
    ok.

derived_digests(V) -> #{
    <<"contract">> => alang_fidelity_json:digest(maps:get(<<"contract">>, V)),
    <<"r2_reference">> => alang_fidelity_json:digest(maps:get(<<"reference">>, V)),
    <<"power_audit">> => alang_fidelity_json:digest(maps:get(<<"power">>, V)),
    <<"schedule">> => alang_fidelity_json:digest(maps:get(<<"schedule">>, V)),
    <<"corpus">> => alang_fidelity_json:digest(maps:get(<<"corpus">>, V)),
    <<"registration">> => alang_fidelity_json:digest(maps:get(<<"registration">>, V)),
    <<"traceability">> => alang_fidelity_json:digest(maps:get(<<"traceability">>, V))
}.

validate_schemas(Contracts) ->
    Paths = lists:sort(filelib:wildcard(filename:join(Contracts, "*.schema.json"))),
    exact(length(Paths), 11, schema_count),
    Schemas = [decode(Path) || Path <- Paths],
    lists:foreach(fun(Schema) ->
        exact(maps:get(<<"$schema">>, Schema),
            <<"https://json-schema.org/draft/2020-12/schema">>, schema_dialect),
        ensure(maps:is_key(<<"$id">>, Schema), missing_schema_id),
        exact(maps:get(<<"type">>, Schema), <<"object">>, schema_root_type),
        validate_closed_schema_objects(Schema)
    end, Schemas),
    Ids = [maps:get(<<"$id">>, Schema) || Schema <- Schemas],
    unique(Ids, duplicate_schema_id),
    #{<<"format">> => <<"alang-token-positive-schema-evidence-v1">>,
        <<"schema_count">> => 11, <<"schema_ids">> => lists:sort(Ids)}.

validate_closed_schema_objects(Value) when is_map(Value) ->
    case maps:get(<<"type">>, Value, undefined) of
        <<"object">> -> exact(maps:get(<<"additionalProperties">>, Value, undefined),
            false, open_object_schema);
        _ -> ok
    end,
    lists:foreach(fun validate_closed_schema_objects/1, maps:values(Value));
validate_closed_schema_objects(Value) when is_list(Value) ->
    lists:foreach(fun validate_closed_schema_objects/1, Value);
validate_closed_schema_objects(_) -> ok.

scope_audit(Trace, RepoRoot) ->
    SourceDirectory = filename:join([RepoRoot, "src", "token-positive-mnemonic-promotion"]),
    SourceFiles = [Path || Path <- filelib:wildcard(filename:join(SourceDirectory, "*")),
        filelib:is_regular(Path)],
    Foreign = [Path || Path <- SourceFiles,
        not lists:member(filename:extension(Path), [".erl", ".md"])],
    exact(Foreign, [], foreign_trusted_sources),
    #{<<"included">> => length(maps:get(<<"included_scope">>, Trace)),
        <<"excluded">> => length(maps:get(<<"excluded_scope">>, Trace)),
        <<"source_links">> => 5, <<"foreign_trusted_sources">> => 0}.

-spec registration_files(file:filename()) -> [file:filename()].
registration_files(Base) -> lists:sort(
    filelib:wildcard(filename:join([Base, "contracts", "*.json"])) ++
    filelib:wildcard(filename:join([Base, "campaign", "*.json"])) ++
    filelib:wildcard(filename:join([Base, "corpus", "*.json"]))).

file_entry(Path, Base) ->
    {ok, Bytes} = file:read_file(Path),
    #{<<"path">> => list_to_binary(relative_path(Path, Base)),
        <<"sha256">> => alang_fidelity_json:hex(crypto:hash(sha256, Bytes))}.

relative_path(Path, Base) ->
    Absolute = filename:absname(Path),
    Prefix = filename:absname(Base) ++ "/",
    ensure(lists:prefix(Prefix, Absolute), {registration_path_outside_base, Path}),
    lists:nthtail(length(Prefix), Absolute).

safe_output(Output) ->
    Absolute = filename:absname(Output),
    OwnedRoot = filename:absname(filename:join(["build",
        "token-positive-mnemonic-promotion", "phase-01"])),
    ensure(lists:prefix(OwnedRoot ++ "/", Absolute),
        {evidence_path_outside_owned_root, Output}),
    Absolute.

expected_design_evidence() -> #{
    <<"role">> => <<"candidate-selection-and-threshold-design-only">>,
    <<"previous_semantic_cases">> => 72,
    <<"model_calls_observed">> => 0,
    <<"r0_document_tokens">> => #{<<"cl100k_base">> => 17204, <<"o200k_base">> => 17118},
    <<"r2_document_tokens">> => #{<<"cl100k_base">> => 15703, <<"o200k_base">> => 15755},
    <<"r2_document_savings">> => #{<<"cl100k_base">> => 0.0872, <<"o200k_base">> => 0.0796},
    <<"every_measured_document_and_request_cheaper">> => true,
    <<"model_fidelity_claim">> => false
}.

expected_included_scope() -> [<<"exact-r2-re-registration">>, <<"readable-p0-baseline">>,
    <<"four-single-turn-protocols">>, <<"two-exact-model-families">>,
    <<"paired-case-cluster-inference">>, <<"token-positive-promotion-gate">>].

expected_excluded_scope() -> [<<"historical-r2-role-rewrite">>, <<"r3-live-campaign">>,
    <<"authored-mnemonic-source">>, <<"opaque-identifiers">>, <<"learned-tokens">>,
    <<"runtime-semantic-change">>, <<"model-effect-execution">>].

decode(Path) ->
    case alang_fidelity_json:decode_file(Path) of
        {ok, Value} -> Value;
        {error, Reason} -> fail({decode_failed, Path, Reason})
    end.

checked({ok, _} = Result) -> Result;
checked({error, Reason}) -> fail(Reason).
closed(Value, Keys, Reason) ->
    ensure(is_map(Value), {Reason, expected_object}),
    Actual = maps:keys(Value),
    exact(lists:sort(Actual), lists:sort(Keys), {Reason, fields}).
unique(Values, Reason) -> ensure(length(Values) =:= length(lists:usort(Values)), Reason).
exact(Value, Expected, Reason) -> ensure(Value =:= Expected, {expected, Reason, Expected, Value}).
ensure(true, _Reason) -> ok;
ensure(false, Reason) -> fail(Reason).
fail(Reason) -> throw({mnemonic_preregistration_error, Reason}).
