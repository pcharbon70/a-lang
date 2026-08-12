-module(alang_compact_preregister).

-export([
    build/1,
    main/0,
    prior_boundary/2,
    registration_files/1,
    validate/1,
    validate_protocols/2,
    validate_traceability/3,
    validate_vocabulary/2,
    write/2
]).

-define(DEFAULT_BASE, "assets/compact-projection-fidelity").
-define(DEFAULT_OUTPUT, "build/compact-projection-fidelity/phase-01/evidence/pre-registration-evidence.json").
-define(PRIOR_DIGEST, <<"dcf8187fa20eb440784901b25d453ba729abb134c865abf29b5b868da2afb3dd">>).
-define(PRIOR_ARCHIVE_DIGEST, <<"3dc60f80fa2bc0730af9d4b42f145b0663704a8a75f1fece3a76638d73c56f78">>).
-define(REGISTRATION_DIGEST, <<"b63beacc39ae35e76002acac4a2e7c0a53741db9af0d5928b16c7481cebb1839">>).
-define(EVIDENCE_DIGEST, <<"764798a90f6ea465123b36a1aea386737b8250271656d7ac14814c11f9f86734">>).

-spec main() -> no_return().
main() ->
    {Base, Output} = case init:get_plain_arguments() of
        [] -> {?DEFAULT_BASE, ?DEFAULT_OUTPUT};
        [OutputArgument] -> {?DEFAULT_BASE, OutputArgument};
        [BaseArgument, OutputArgument] -> {BaseArgument, OutputArgument};
        Arguments -> fail_main({invalid_arguments, Arguments})
    end,
    case write(Base, Output) of
        {ok, Evidence} ->
            io:format("compact_preregistration_ok digest=~s files=~B cases=48 cells=2304 hosted_calls=0 output=~s~n",
                [maps:get(<<"registration_digest">>, Evidence),
                    maps:get(<<"registration_file_count">>, Evidence), Output]),
            halt(0);
        {error, Reason} -> fail_main(Reason)
    end.

-spec build(file:filename()) -> {ok, map()} | {error, term()}.
build(Base) ->
    case validate(Base) of
        {ok, Validation} ->
            Entries = [file_entry(Path) || Path <- registration_files(Base)],
            RegistrationDigest = digest_entries(Entries),
            exact(RegistrationDigest, ?REGISTRATION_DIGEST, registration_digest_drift),
            Schedule = maps:get(<<"schedule">>, Validation),
            Power = maps:get(<<"power">>, Validation),
            Registration = maps:get(<<"registration">>, Validation),
            Corpus = maps:get(<<"corpus">>, Registration),
            Derived = #{
                <<"power_audit_digest">> => alang_fidelity_json:digest(Power),
                <<"schedule_digest">> => maps:get(<<"schedule_digest">>, Schedule),
                <<"schedule_record_digest">> => alang_fidelity_json:digest(Schedule),
                <<"oracle_bundle_digest">> => alang_fidelity_json:digest(maps:get(<<"semantic_digests">>, Corpus)),
                <<"validation_digest">> => alang_fidelity_json:digest(maps:without([<<"schedule">>, <<"power">>], Validation))
            },
            exact(Derived, expected_derived_digests(), derived_digest_drift),
            Prior = maps:get(<<"prior_campaign">>, Validation),
            Evidence0 = #{
                <<"format">> => <<"alang-compact-preregistration-evidence-v1">>,
                <<"digest_algorithm">> => <<"sha-256-canonical-etf-v1">>,
                <<"registration_digest">> => RegistrationDigest,
                <<"registration_file_count">> => length(Entries),
                <<"registration_files">> => Entries,
                <<"derived">> => Derived,
                <<"semantic_case_count">> => 48,
                <<"primary_cell_count">> => 2304,
                <<"hard_request_ceiling">> => 4608,
                <<"model_profile_count">> => 2,
                <<"screening_tokenizer_count">> => 2,
                <<"schema_count">> => 12,
                <<"prior_campaign_digest">> => maps:get(<<"registration_digest">>, Prior),
                <<"prior_campaign_file_count">> => maps:get(<<"registration_file_count">>, Prior),
                <<"prior_archive_digest">> => maps:get(<<"archive_digest">>, Prior),
                <<"prior_archive_file_count">> => maps:get(<<"archive_file_count">>, Prior),
                <<"scope_audit">> => maps:get(<<"scope_audit">>, Validation),
                <<"hosted_calls_observed">> => 0,
                <<"efficacy_observations">> => 0,
                <<"network_authorized">> => false,
                <<"commands">> => [<<"make test-compact-section-1-4">>,
                    <<"make build-compact-phase-1-evidence">>, <<"make test-compact-phase-1">>]
            },
            Evidence = Evidence0#{<<"evidence_digest">> => alang_fidelity_json:digest(Evidence0)},
            exact(maps:get(<<"evidence_digest">>, Evidence), ?EVIDENCE_DIGEST, evidence_digest_drift),
            {ok, Evidence};
        {error, _} = Error -> Error
    end.

-spec write(file:filename(), file:filename()) -> {ok, map()} | {error, term()}.
write(Base, Output0) ->
    try
        Output = safe_output(Output0),
        case build(Base) of
            {ok, Evidence} ->
                {ok, Bytes} = alang_fidelity_json:encode_canonical(Evidence),
                ok = filelib:ensure_dir(Output),
                ok = file:write_file(Output, [Bytes, <<"\n">>]),
                {ok, Evidence};
            {error, _} = Error -> Error
        end
    catch Class:Reason -> {error, {evidence_write_failed, Class, Reason}} end.

-spec validate(file:filename()) -> {ok, map()} | {error, term()}.
validate(Base) ->
    try
        Campaign = filename:join(Base, "campaign"),
        Contracts = filename:join(Base, "contracts"),
        {ok, Contract} = checked(alang_compact_contract:load(filename:join(Contracts, "campaign-contract-v1.json"))),
        {ok, Registration} = checked(alang_compact_registration:load(Base)),
        {ok, PowerDesign} = checked(alang_compact_power:load(filename:join(Campaign, "power-design-v1.json"))),
        {ok, Power} = checked(alang_compact_power:audit(PowerDesign)),
        {ok, Schedule} = checked(alang_compact_schedule:materialize(Campaign)),
        Vocabulary = decode(filename:join(Campaign, "projection-vocabulary-v1.json")),
        Protocols = decode(filename:join(Campaign, "protocol-registry-v1.json")),
        Traceability = decode(filename:join(Campaign, "traceability-v1.json")),
        ok = validate_vocabulary(Vocabulary, Contract),
        ok = validate_protocols(Protocols, Contract),
        RepoRoot = filename:dirname(filename:dirname(Base)),
        ok = validate_traceability(Traceability, Contract, RepoRoot),
        SchemaEvidence = validate_schemas(Contracts),
        reconcile(Contract, Registration, Power, Schedule),
        PriorExpected = maps:get(<<"prior_campaign_boundary">>, Traceability),
        {ok, Prior} = checked(prior_boundary(maps:get(<<"base">>, PriorExpected),
            maps:get(<<"registration_digest">>, PriorExpected))),
        exact(maps:get(<<"registration_file_count">>, Prior),
            maps:get(<<"registration_file_count">>, PriorExpected), prior_file_count),
        Scope = scope_audit(Traceability, RepoRoot),
        {ok, #{
            <<"format">> => <<"alang-compact-phase1-validation-v1">>,
            <<"registration">> => Registration,
            <<"power">> => Power,
            <<"schedule">> => Schedule,
            <<"schemas">> => SchemaEvidence,
            <<"vocabulary_digest">> => alang_fidelity_json:digest(Vocabulary),
            <<"protocol_digest">> => alang_fidelity_json:digest(Protocols),
            <<"traceability_digest">> => alang_fidelity_json:digest(Traceability),
            <<"prior_campaign">> => Prior,
            <<"scope_audit">> => Scope,
            <<"hosted_calls_observed">> => 0,
            <<"efficacy_observations">> => 0
        }}
    catch
        throw:{compact_preregistration_error, Reason} -> {error, {compact_preregistration_error, Reason}};
        error:{badmatch, Reason} -> {error, {compact_preregistration_error, {badmatch, Reason}}}
    end.

-spec validate_vocabulary(term(), map()) -> ok | no_return().
validate_vocabulary(Value, Contract) ->
    Keys = [<<"format">>, <<"canonical_source">>, <<"conditions">>, <<"alias_groups">>,
        <<"derivations">>, <<"identifier_policy">>, <<"security_policy">>, <<"selection_policy">>],
    closed(Value, Keys, vocabulary),
    exact(maps:get(<<"format">>, Value), <<"alang-compact-projection-vocabulary-v1">>, vocabulary_format),
    exact(maps:get(<<"canonical_source">>, Value), maps:get(<<"canonical_source">>, Contract), canonical_source),
    Conditions = maps:get(<<"conditions">>, Value),
    ExpectedConditions = [{maps:get(<<"id">>, C), maps:get(<<"representation">>, C)} || C <- maps:get(<<"conditions">>, Contract)],
    exact([{maps:get(<<"id">>, C), maps:get(<<"representation">>, C)} || C <- Conditions], ExpectedConditions, vocabulary_conditions),
    lists:foreach(fun(C) -> closed(C, [<<"id">>, <<"representation">>, <<"strategy">>, <<"version">>], vocabulary_condition) end, Conditions),
    Groups = maps:get(<<"alias_groups">>, Value),
    exact([maps:get(<<"group">>, G) || G <- Groups], [<<"declaration">>, <<"scope-key">>,
        <<"budget-key">>, <<"operation">>, <<"predicate">>, <<"relation">>], alias_groups),
    lists:foreach(fun validate_alias_group/1, Groups),
    exact(alias_pairs(Groups), expected_alias_pairs(), alias_pairs),
    Derivations = maps:get(<<"derivations">>, Value),
    exact([maps:get(<<"field">>, D) || D <- Derivations], [<<"effects">>, <<"requirements">>, <<"empty-collections">>], derivation_fields),
    lists:foreach(fun(D) ->
        closed(D, [<<"field">>, <<"rule">>, <<"allowed_only_after_check">>, <<"ambiguity">>], derivation),
        exact(maps:get(<<"allowed_only_after_check">>, D), true, derivation_after_check),
        exact(maps:get(<<"ambiguity">>, D), <<"reject">>, derivation_ambiguity)
    end, Derivations),
    Identifier = maps:get(<<"identifier_policy">>, Value),
    closed(Identifier, [<<"r3">>, <<"r4">>, <<"protected">>, <<"reverse_map_required">>, <<"opaque_control_promotable">>], identifier_policy),
    exact(maps:get(<<"reverse_map_required">>, Identifier), true, reverse_map),
    exact(maps:get(<<"opaque_control_promotable">>, Identifier), false, opaque_promotion),
    Security = maps:get(<<"security_policy">>, Value),
    closed(Security, [<<"keyed_authority_fields_required">>, <<"positional_security_fields">>,
        <<"nonempty_authority_elision">>, <<"unknown_alias">>, <<"unknown_version">>], security_policy),
    exact(maps:get(<<"keyed_authority_fields_required">>, Security), true, keyed_authority),
    exact(maps:get(<<"positional_security_fields">>, Security), false, positional_security),
    exact(maps:get(<<"nonempty_authority_elision">>, Security), <<"only-with-exact-derivation-witness">>, authority_elision),
    exact(maps:get(<<"unknown_alias">>, Security), <<"reject">>, unknown_alias),
    exact(maps:get(<<"unknown_version">>, Security), <<"reject">>, unknown_version),
    nonempty(maps:get(<<"selection_policy">>, Value), selection_policy),
    ok.

validate_alias_group(Group) ->
    closed(Group, [<<"group">>, <<"aliases">>], alias_group),
    Aliases = maps:get(<<"aliases">>, Group),
    ensure(is_list(Aliases) andalso Aliases =/= [], empty_alias_group),
    lists:foreach(fun(Alias) ->
        closed(Alias, [<<"readable">>, <<"compact">>], alias),
        nonempty(maps:get(<<"readable">>, Alias), alias_readable),
        nonempty(maps:get(<<"compact">>, Alias), alias_compact)
    end, Aliases),
    unique([maps:get(<<"readable">>, A) || A <- Aliases], duplicate_readable_alias),
    unique([maps:get(<<"compact">>, A) || A <- Aliases], duplicate_compact_alias).

alias_pairs(Groups) -> [[{maps:get(<<"readable">>, A), maps:get(<<"compact">>, A)} || A <- maps:get(<<"aliases">>, G)] || G <- Groups].
expected_alias_pairs() -> [
    [{<<"facts">>,<<"f">>},{<<"inputs">>,<<"i">>},{<<"requirements">>,<<"use">>},{<<"scopes">>,<<"at">>},{<<"limits">>,<<"cap">>},{<<"on-error">>,<<"err">>},{<<"child">>,<<"kid">>},{<<"completion">>,<<"ok">>},{<<"clarify">>,<<"ask">>},{<<"terminal">>,<<"end">>}],
    [{<<"models">>,<<"m">>},{<<"workspaces">>,<<"w">>},{<<"paths">>,<<"p">>}],
    [{<<"steps">>,<<"s">>},{<<"model-calls">>,<<"m">>},{<<"repair-calls">>,<<"r">>},{<<"child-calls">>,<<"c">>},{<<"workspace-writes">>,<<"w">>},{<<"output-bytes">>,<<"b">>},{<<"timeout-ms">>,<<"t">>}],
    [{<<"model.generate">>,<<"gen">>},{<<"model.repair">>,<<"fix">>},{<<"workspace.write">>,<<"put">>},{<<"child.run">>,<<"sub">>},{<<"complete">>,<<"done">>}],
    [{<<"artifact-exists">>,<<"exists">>},{<<"journal-succeeded">>,<<"journal">>},{<<"max-bytes">>,<<"maxb">>},{<<"utf8">>,<<"u8">>},{<<"clarification-recorded">>,<<"asked">>}],
    [{<<"depends">>,<<"<-">>}]
].

-spec validate_protocols(term(), map()) -> ok | no_return().
validate_protocols(Value, Contract) ->
    Keys = [<<"format">>, <<"single_turn">>, <<"conversation_memory">>, <<"examples">>,
        <<"common_instruction">>, <<"request_order">>, <<"protocols">>, <<"legends">>,
        <<"leakage_forbidden">>, <<"definitive_response">>],
    closed(Value, Keys, protocols),
    exact(maps:get(<<"format">>, Value), <<"alang-compact-protocol-registry-v1">>, protocol_format),
    exact(maps:get(<<"single_turn">>, Value), true, single_turn),
    exact(maps:get(<<"conversation_memory">>, Value), false, conversation_memory),
    exact(maps:get(<<"examples">>, Value), false, examples),
    nonempty(maps:get(<<"common_instruction">>, Value), common_instruction),
    exact(maps:get(<<"request_order">>, Value), [<<"opaque-trial-id">>, <<"common-instruction">>,
        <<"protocol-instruction">>, <<"condition-legend">>, <<"case-material">>, <<"output-contract">>], request_order),
    Protocols = maps:get(<<"protocols">>, Value),
    exact(lists:sort([maps:get(<<"id">>, P) || P <- Protocols]), lists:sort(maps:get(<<"task_protocols">>, Contract)), protocol_ids),
    lists:foreach(fun(P) ->
        closed(P, [<<"id">>, <<"conditions">>, <<"instruction">>, <<"output_contract">>], protocol),
        Id = maps:get(<<"id">>, P),
        Eligible = [maps:get(<<"id">>, C) || C <- maps:get(<<"conditions">>, Contract), lists:member(Id, maps:get(<<"task_protocols">>, C))],
        exact(lists:sort(maps:get(<<"conditions">>, P)), lists:sort(Eligible), {protocol_eligibility, Id}),
        nonempty(maps:get(<<"instruction">>, P), protocol_instruction),
        nonempty(maps:get(<<"output_contract">>, P), output_contract)
    end, Protocols),
    Legends = maps:get(<<"legends">>, Value),
    lists:foreach(fun(L) -> closed(L, [<<"condition">>, <<"title">>, <<"content">>], legend) end, Legends),
    exact(lists:sort([maps:get(<<"condition">>, L) || L <- Legends]), [<<"R0">>,<<"R1">>,<<"R2">>,<<"R3">>,<<"R4">>,<<"R5">>], legend_conditions),
    unique([maps:get(<<"content">>, L) || L <- Legends], duplicate_legend),
    exact(maps:get(<<"definitive_response">>, Value), <<"first-provider-response-only">>, definitive_response),
    ensure(lists:member(<<"answer-key">>, maps:get(<<"leakage_forbidden">>, Value)), missing_answer_key_leakage_rule),
    ok.

-spec validate_traceability(term(), map(), file:filename()) -> ok | no_return().
validate_traceability(Value, Contract, RepoRoot) ->
    Keys = [<<"format">>, <<"sources">>, <<"condition_hypotheses">>, <<"primary_metric_ids">>,
        <<"secondary_metric_ids">>, <<"metric_rationales">>, <<"included_scope">>,
        <<"excluded_scope">>, <<"prior_campaign_boundary">>],
    closed(Value, Keys, traceability),
    exact(maps:get(<<"format">>, Value), <<"alang-compact-traceability-v1">>, traceability_format),
    Sources = maps:get(<<"sources">>, Value),
    exact(length(Sources), 5, source_link_count),
    lists:foreach(fun(Source) ->
        closed(Source, [<<"role">>, <<"path">>], traceability_source),
        Path = binary_to_list(maps:get(<<"path">>, Source)),
        ensure(filelib:is_regular(filename:join(RepoRoot, Path)), {missing_traceability_source, Path})
    end, Sources),
    Hypotheses = maps:get(<<"condition_hypotheses">>, Value),
    lists:foreach(fun(H) -> closed(H, [<<"id">>, <<"hypothesis">>], condition_hypothesis) end, Hypotheses),
    exact(lists:sort([maps:get(<<"id">>, H) || H <- Hypotheses]), [<<"R0">>,<<"R1">>,<<"R2">>,<<"R3">>,<<"R4">>,<<"R5">>], hypothesis_conditions),
    exact(maps:get(<<"primary_metric_ids">>, Value), maps:get(<<"primary_metrics">>, Contract), primary_metric_traceability),
    exact(maps:get(<<"secondary_metric_ids">>, Value), maps:get(<<"secondary_metrics">>, Contract), secondary_metric_traceability),
    Rationales = maps:get(<<"metric_rationales">>, Value),
    exact(lists:sort([maps:get(<<"group">>, R) || R <- Rationales]), [<<"fidelity">>, <<"operations">>, <<"safety">>, <<"token">>], metric_rationale_groups),
    lists:foreach(fun(R) -> closed(R, [<<"group">>, <<"source_role">>, <<"reason">>], metric_rationale) end, Rationales),
    exact(maps:get(<<"included_scope">>, Value), [<<"compiler-produced-reversible-projections">>,
        <<"fixed-closed-vocabulary-aliases">>, <<"layout-minification">>,
        <<"opaque-identifier-negative-control">>, <<"typed-json-external-control">>,
        <<"single-turn-offline-scoring">>], included_scope),
    exact(maps:get(<<"excluded_scope">>, Value), [<<"compact-authored-surface">>, <<"learned-macros">>,
        <<"human-usability-claim">>, <<"production-readiness">>, <<"unrelated-language-feature">>,
        <<"model-effect-execution">>, <<"training-or-fine-tuning">>], excluded_scope),
    Boundary = maps:get(<<"prior_campaign_boundary">>, Value),
    closed(Boundary, [<<"base">>, <<"registration_file_count">>, <<"registration_digest">>,
        <<"archive_file_count">>, <<"archive_digest">>, <<"digest_algorithm">>, <<"mutation">>], prior_boundary),
    exact(maps:get(<<"base">>, Boundary), <<"assets/effectful-source-fidelity">>, prior_base),
    exact(maps:get(<<"registration_file_count">>, Boundary), 86, prior_count),
    exact(maps:get(<<"registration_digest">>, Boundary), ?PRIOR_DIGEST, prior_digest),
    exact(maps:get(<<"archive_file_count">>, Boundary), 182, prior_archive_count),
    exact(maps:get(<<"archive_digest">>, Boundary), ?PRIOR_ARCHIVE_DIGEST, prior_archive_digest),
    exact(maps:get(<<"mutation">>, Boundary), <<"forbidden">>, prior_mutation),
    ok.

-spec prior_boundary(file:filename() | binary(), binary()) -> {ok, map()} | {error, term()}.
prior_boundary(Base0, ExpectedDigest) ->
    try
        Base = path_list(Base0),
        Files = prior_registration_files(Base),
        exact(length(Files), 86, prior_registration_file_count),
        Digest = digest_entries([file_entry(Path) || Path <- Files]),
        exact(Digest, ExpectedDigest, prior_registration_digest),
        RepoRoot = filename:dirname(filename:dirname(Base)),
        ArchiveFiles = prior_archive_files(RepoRoot),
        exact(length(ArchiveFiles), 182, prior_archive_file_count),
        ArchiveDigest = digest_entries([file_entry(Path) || Path <- ArchiveFiles]),
        exact(ArchiveDigest, ?PRIOR_ARCHIVE_DIGEST, prior_archive_digest),
        {ok, #{<<"format">> => <<"alang-compact-prior-boundary-v1">>,
            <<"registration_file_count">> => 86, <<"registration_digest">> => Digest,
            <<"archive_file_count">> => 182, <<"archive_digest">> => ArchiveDigest,
            <<"unchanged">> => true}}
    catch throw:{compact_preregistration_error, Reason} -> {error, {compact_preregistration_error, Reason}} end.

reconcile(Contract, Registration, Power, Schedule) ->
    exact(maps:get(<<"selected_cases">>, Power), 48, selected_cases),
    Corpus = maps:get(<<"corpus">>, Registration),
    exact(maps:get(<<"semantic_cases">>, Corpus), 48, corpus_cases),
    exact(length(maps:get(<<"cells">>, Schedule)), 2304, primary_cells),
    Policy = maps:get(<<"policy">>, Registration),
    exact(maps:get(<<"primary_requests">>, Policy), 2304, primary_requests),
    exact(maps:get(<<"hard_request_ceiling">>, Policy), 4608, hard_request_ceiling),
    exact(maps:get(<<"candidate_condition">>, Contract), <<"R3">>, candidate_condition),
    exact(maps:get(<<"aliases_allowed">>, maps:get(<<"profiles">>, Registration)), false, model_aliases),
    ok.

expected_derived_digests() -> #{
    <<"power_audit_digest">> => <<"3d2858f974b98293ccaffd7c2928858e1545d900f4af005f0f7c695ec68dee16">>,
    <<"schedule_digest">> => <<"72aca835d079fceab15c6ec87861f0b6afd52751a2cf4d49a7883ff77d440ac6">>,
    <<"schedule_record_digest">> => <<"32cdef4b898e9bdb04d2a9d3034d075ff30803c1761072b622cc777527fdb549">>,
    <<"oracle_bundle_digest">> => <<"896117d38eb07b4da0044fd01c5f1eb39842bfb82909b8ec397f1bc8eb2abcd6">>,
    <<"validation_digest">> => <<"27d21411889845c952ddd20428bc654210f35fea397606edad5691a8c852c79f">>
}.

scope_audit(Traceability, RepoRoot) ->
    SourceDirectory = filename:join([RepoRoot, "src", "compact-projection-fidelity"]),
    SourceFiles = [P || P <- filelib:wildcard(filename:join(SourceDirectory, "*")), filelib:is_regular(P)],
    Foreign = [P || P <- SourceFiles, not lists:member(filename:extension(P), [".erl", ".md"])],
    exact(Foreign, [], foreign_trusted_source),
    #{<<"condition_hypotheses">> => 6, <<"metric_ids">> => 14,
        <<"source_links">> => 5,
        <<"included_scope">> => length(maps:get(<<"included_scope">>, Traceability)),
        <<"excluded_scope">> => length(maps:get(<<"excluded_scope">>, Traceability)),
        <<"foreign_trusted_sources">> => 0, <<"passed">> => true}.

validate_schemas(Contracts) ->
    Paths = lists:sort(filelib:wildcard(filename:join(Contracts, "*.schema.json"))),
    exact(length(Paths), 12, schema_count),
    Schemas = [decode(Path) || Path <- Paths],
    lists:foreach(fun(Schema) ->
        exact(maps:get(<<"$schema">>, Schema), <<"https://json-schema.org/draft/2020-12/schema">>, schema_dialect),
        ensure(maps:is_key(<<"$id">>, Schema), missing_schema_id),
        exact(maps:get(<<"type">>, Schema), <<"object">>, schema_root_type),
        exact(maps:get(<<"additionalProperties">>, Schema), false, schema_root_closed),
        validate_closed_schema_objects(Schema)
    end, Schemas),
    Ids = [maps:get(<<"$id">>, S) || S <- Schemas],
    unique(Ids, duplicate_schema_id),
    #{<<"format">> => <<"alang-compact-schema-evidence-v1">>, <<"schema_count">> => 12,
        <<"schema_ids">> => lists:sort(Ids)}.

validate_closed_schema_objects(Value) when is_map(Value) ->
    case maps:get(<<"type">>, Value, undefined) of
        <<"object">> -> exact(maps:get(<<"additionalProperties">>, Value, undefined), false, open_object_schema);
        _ -> ok
    end,
    lists:foreach(fun validate_closed_schema_objects/1, maps:values(Value));
validate_closed_schema_objects(Value) when is_list(Value) -> lists:foreach(fun validate_closed_schema_objects/1, Value);
validate_closed_schema_objects(_) -> ok.

-spec registration_files(file:filename()) -> [file:filename()].
registration_files(Base) -> lists:sort(
    filelib:wildcard(filename:join([Base, "contracts", "*.json"])) ++
    filelib:wildcard(filename:join([Base, "campaign", "*.json"])) ++
    filelib:wildcard(filename:join([Base, "corpus", "*.json"]))).

prior_registration_files(Base) -> lists:sort(
    filelib:wildcard(filename:join([Base, "contracts", "*.json"])) ++
    filelib:wildcard(filename:join([Base, "campaign", "*.json"])) ++
    filelib:wildcard(filename:join([Base, "campaign", "*.txt"])) ++
    filelib:wildcard(filename:join([Base, "corpus", "*.json"])) ++
    filelib:wildcard(filename:join([Base, "corpus", "*", "*.alang"])) ++
    filelib:wildcard(filename:join([Base, "corpus", "*", "*.json"]))).

prior_archive_files(RepoRoot) ->
    Patterns = [filename:join([RepoRoot, "assets", "effectful-source-fidelity", "*"]),
        filename:join([RepoRoot, "assets", "effectful-source-fidelity", "*", "*"]),
        filename:join([RepoRoot, "assets", "effectful-source-fidelity", "corpus", "*", "*"]),
        filename:join([RepoRoot, "src", "effectful-source-fidelity", "*"]),
        filename:join([RepoRoot, "60-planning", "02-effectful-source-fidelity", "*"])],
    lists:sort(lists:usort([Path || Pattern <- Patterns, Path <- filelib:wildcard(Pattern), filelib:is_regular(Path)])).

file_entry(Path) ->
    {ok, Binary} = file:read_file(Path),
    #{<<"path">> => list_to_binary(Path), <<"sha256">> => alang_fidelity_json:hex(crypto:hash(sha256, Binary)),
        <<"bytes">> => byte_size(Binary)}.
digest_entries(Entries) -> alang_fidelity_json:digest([{maps:get(<<"path">>, E), maps:get(<<"sha256">>, E), maps:get(<<"bytes">>, E)} || E <- Entries]).

decode(Path) -> case alang_fidelity_json:decode_file(Path) of {ok, Value} -> Value; {error, Reason} -> fail({decode_failed, Path, Reason}) end.
checked({ok, Value}) -> {ok, Value};
checked({error, Reason}) -> fail(Reason).
closed(Value, Keys, Reason) ->
    ensure(is_map(Value), {expected_object, Reason}),
    Actual = maps:keys(Value),
    ensure(Actual -- Keys =:= [], {unknown_fields, Reason, Actual -- Keys}),
    ensure(Keys -- Actual =:= [], {missing_fields, Reason, Keys -- Actual}).
exact(Value, Expected, Reason) -> ensure(Value =:= Expected, {Reason, expected, Expected, actual, Value}).
nonempty(Value, Reason) -> ensure(is_binary(Value) andalso byte_size(Value) > 0, {expected_nonempty_string, Reason}).
unique(Values, Reason) -> ensure(length(Values) =:= length(lists:usort(Values)), Reason).
ensure(true, _Reason) -> ok;
ensure(false, Reason) -> fail(Reason).
fail(Reason) -> throw({compact_preregistration_error, Reason}).
path_list(Value) when is_binary(Value) -> binary_to_list(Value);
path_list(Value) -> Value.
safe_output(Output0) ->
    Output = filename:absname(Output0),
    Root = filename:absname("build/compact-projection-fidelity"),
    true = lists:prefix(Root ++ "/", Output), Output.
fail_main(Reason) -> io:format(standard_error, "compact_preregistration_error ~tp~n", [Reason]), halt(1).
