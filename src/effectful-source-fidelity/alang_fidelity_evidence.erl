-module(alang_fidelity_evidence).

-export([build/6, read/1, write/2]).

-define(MAX_EVIDENCE_BYTES, 33554432).

-spec build(file:filename(), map(), [map()], [map()], map(), map()) ->
    {ok, map()} | {error, term()}.
build(Base, Schedule, Observations, Scores, Statistics, Options)
  when is_list(Observations), is_list(Scores), is_map(Statistics), is_map(Options) ->
    try
        validate_options(Options),
        {ok, Registration} = checked_registration(Base),
        {ok, _} = checked_schedule(Schedule),
        CampaignJournal = maps:get(campaign_journal, Options, none),
        validate_campaign_journal(CampaignJournal, maps:get(schedule_digest, Schedule)),
        Cells = maps:get(cells, Schedule),
        validate_records(Cells, Observations, Scores),
        Corpus = load_corpus_snapshot(Base),
        Prompt = load_named_asset(Base, ["campaign", "prompt-template-v1.txt"]),
        ResultSchema = load_named_asset(
            Base, ["contracts", "alang-task-comprehension-v1.schema.json"]
        ),
        OrderedObservations = order_by_schedule(Cells, Observations),
        OrderedScores = order_by_schedule(Cells, Scores),
        Present = ordsets:from_list([maps:get(trial_id, Item) || Item <- OrderedObservations]),
        Missing = [maps:get(trial_id, Cell) || Cell <- Cells,
            not ordsets:is_element(maps:get(trial_id, Cell), Present)],
        Provenance = provenance(Options),
        Evidence0 = #{
            format => alang_fidelity_redacted_evidence_v1,
            campaign_status => maps:get(campaign_status, Options, partial),
            registration => Registration,
            corpus => Corpus,
            prompt_template => Prompt,
            result_schema => ResultSchema,
            schedule => Schedule,
            observations => OrderedObservations,
            scores => OrderedScores,
            statistics => Statistics,
            campaign_journal => CampaignJournal,
            missing_trial_ids => Missing,
            completeness => #{
                scheduled => length(Cells),
                observed => length(OrderedObservations),
                scored => length(OrderedScores),
                missing => length(Missing)
            },
            provenance => Provenance,
            implementation_digests => #{
                anthropic_adapter_beam_sha256 => module_digest(alang_fidelity_anthropic_adapter),
                observation_beam_sha256 => module_digest(alang_fidelity_observation),
                scorer_beam_sha256 => module_digest(alang_fidelity_score),
                bootstrap_beam_sha256 => module_digest(alang_fidelity_bootstrap),
                campaign_beam_sha256 => module_digest(alang_fidelity_campaign),
                campaign_journal_beam_sha256 => module_digest(alang_fidelity_campaign_journal),
                campaign_runner_beam_sha256 => module_digest(alang_fidelity_campaign_runner),
                evidence_beam_sha256 => module_digest(alang_fidelity_evidence),
                offline_campaign_beam_sha256 => module_digest(alang_fidelity_offline_campaign),
                openai_adapter_beam_sha256 => module_digest(alang_fidelity_openai_adapter)
            }
        },
        validate_safe(Evidence0, maps:get(secrets, Options, [])),
        Evidence = Evidence0#{evidence_digest => alang_fidelity_json:digest(Evidence0)},
        ensure(byte_size(term_to_binary(Evidence, [deterministic])) =< ?MAX_EVIDENCE_BYTES,
            evidence_too_large),
        {ok, Evidence}
    catch
        throw:{evidence_error, Reason} -> {error, Reason};
        error:{badkey, Key} -> {error, {missing_evidence_field, Key}};
        error:{badmatch, {error, Reason}} -> {error, Reason}
    end;
build(_, _, _, _, _, _) -> {error, invalid_evidence_input}.

-spec write(file:filename(), map()) -> {ok, map()} | {error, term()}.
write(Path, Evidence) when is_map(Evidence) ->
    try
        validate_evidence(Evidence),
        SafePath = safe_evidence_path(Path),
        Binary = term_to_binary(Evidence, [deterministic]),
        ensure(byte_size(Binary) =< ?MAX_EVIDENCE_BYTES, evidence_too_large),
        ok = filelib:ensure_dir(SafePath),
        Temporary = SafePath ++ ".tmp." ++ integer_to_list(erlang:unique_integer([positive])),
        case file:write_file(Temporary, Binary, [binary, exclusive]) of
            ok ->
                case file:rename(Temporary, SafePath) of
                    ok -> {ok, #{path => SafePath, bytes => byte_size(Binary),
                        sha256 => binary_digest(Binary)}};
                    {error, RenameReason} ->
                        _ = file:delete(Temporary),
                        {error, {evidence_rename_failed, RenameReason}}
                end;
            {error, WriteReason} -> {error, {evidence_write_failed, WriteReason}}
        end
    catch
        throw:{evidence_error, EvidenceReason} -> {error, EvidenceReason};
        error:{badmatch, {error, MatchReason}} -> {error, MatchReason}
    end;
write(_, _) -> {error, invalid_evidence_write}.

-spec read(file:filename()) -> {ok, map()} | {error, term()}.
read(Path) ->
    try
        SafePath = safe_evidence_path(Path),
        case file:read_file(SafePath) of
            {ok, Binary} when byte_size(Binary) =< ?MAX_EVIDENCE_BYTES ->
                ensure_reader_modules(),
                try binary_to_term(Binary, [safe]) of
                    Evidence when is_map(Evidence) ->
                        ensure(term_to_binary(Evidence, [deterministic]) =:= Binary,
                            noncanonical_evidence),
                        validate_evidence(Evidence),
                        {ok, Evidence};
                    _ -> {error, invalid_evidence_term}
                catch
                    error:DecodeReason -> {error, {unsafe_evidence_term, DecodeReason}}
                end;
            {ok, _} -> {error, evidence_too_large};
            {error, ReadReason} -> {error, {evidence_read_failed, ReadReason}}
        end
    catch
        throw:{evidence_error, EvidenceReason} -> {error, EvidenceReason}
    end.

checked_registration(Base) ->
    case alang_fidelity_corpus:validate(Base) of
        {ok, _} = Ok -> Ok;
        {error, Reason} -> throw({evidence_error, {invalid_registration, Reason}})
    end.

checked_schedule(Schedule) ->
    case alang_fidelity_campaign:validate_schedule(Schedule) of
        {ok, _} = Ok -> Ok;
        {error, Reason} -> throw({evidence_error, {invalid_schedule, Reason}})
    end.

validate_options(Options) ->
    Allowed = [campaign_journal, campaign_status, provenance, secrets],
    ensure(lists:sort(maps:keys(Options)) -- Allowed =:= [], invalid_evidence_options),
    Status = maps:get(campaign_status, Options, partial),
    ensure(lists:member(Status, [offline_fixture, live_complete, partial, invalid]),
        invalid_campaign_status),
    Secrets = maps:get(secrets, Options, []),
    ensure(is_list(Secrets) andalso lists:all(fun is_binary/1, Secrets), invalid_secret_list),
    validate_provenance(maps:get(provenance, Options, #{})).

validate_campaign_journal(none, _ScheduleDigest) -> ok;
validate_campaign_journal(Journal, ScheduleDigest) when is_map(Journal) ->
    ensure(maps:get(campaign_digest, Journal, invalid) =:= ScheduleDigest,
        campaign_journal_digest_mismatch),
    case alang_fidelity_campaign_journal:validate(maps:get(records, Journal, []), ScheduleDigest) of
        {ok, Validated} ->
            ensure(Validated =:= Journal, campaign_journal_state_mismatch);
        {error, Reason} -> throw({evidence_error, {invalid_campaign_journal, Reason}})
    end;
validate_campaign_journal(_, _ScheduleDigest) ->
    throw({evidence_error, invalid_campaign_journal}).

validate_provenance(Provenance) when is_map(Provenance) ->
    Allowed = [campaign_mode, otp_release, price_record_digest, provider_profiles_verified],
    ensure(maps:keys(Provenance) -- Allowed =:= [], invalid_provenance_fields);
validate_provenance(_) -> throw({evidence_error, invalid_provenance}).

provenance(Options) ->
    Defaults = #{
        campaign_mode => maps:get(campaign_status, Options, partial),
        otp_release => list_to_binary(erlang:system_info(otp_release)),
        provider_profiles_verified => false
    },
    maps:merge(Defaults, maps:get(provenance, Options, #{})).

validate_records(Cells, Observations, Scores) ->
    Scheduled = ordsets:from_list([maps:get(trial_id, Cell) || Cell <- Cells]),
    validate_record_set(Observations, alang_fidelity_observation_v1,
        observation_digest, Scheduled),
    validate_record_set(Scores, alang_fidelity_score_v1, score_digest, Scheduled),
    ObservationIds = lists:sort([maps:get(trial_id, Item) || Item <- Observations]),
    ScoreIds = lists:sort([maps:get(trial_id, Item) || Item <- Scores]),
    ensure(ObservationIds =:= ScoreIds, observation_score_join_mismatch).

validate_record_set(Records, Format, DigestKey, Scheduled) ->
    Ids = [maps:get(trial_id, Record) || Record <- Records],
    ensure(length(Ids) =:= length(lists:usort(Ids)), duplicate_evidence_trial),
    ensure(lists:all(fun(Id) -> ordsets:is_element(Id, Scheduled) end, Ids),
        unknown_evidence_trial),
    lists:foreach(fun(Record) ->
        ensure(maps:get(format, Record) =:= Format, invalid_evidence_record_format),
        Expected = alang_fidelity_json:digest(maps:remove(DigestKey, Record)),
        ensure(maps:get(DigestKey, Record) =:= Expected, invalid_evidence_record_digest)
    end, Records).

order_by_schedule(Cells, Records) ->
    Index = maps:from_list([{maps:get(trial_id, Cell), maps:get(index, Cell)} || Cell <- Cells]),
    lists:sort(fun(Left, Right) ->
        maps:get(maps:get(trial_id, Left), Index) < maps:get(maps:get(trial_id, Right), Index)
    end, Records).

load_corpus_snapshot(Base) ->
    CorpusDirectory = filename:join(Base, "corpus"),
    ManifestPath = filename:join(CorpusDirectory, "corpus-manifest-v1.json"),
    {ok, ManifestBytes} = read_bounded(ManifestPath),
    {ok, Manifest} = alang_fidelity_json:decode(ManifestBytes),
    Cases = [snapshot_case(CorpusDirectory, Case) || Case <- maps:get(<<"cases">>, Manifest)],
    #{
        manifest => #{content => ManifestBytes, sha256 => binary_digest(ManifestBytes)},
        cases => Cases,
        snapshot_digest => alang_fidelity_json:digest(Cases)
    }.

snapshot_case(CorpusDirectory, Case) ->
    #{
        case_id => maps:get(<<"case_id">>, Case),
        task_family => maps:get(<<"family">>, Case),
        variant => maps:get(<<"variant">>, Case),
        semantic_digest => maps:get(<<"semantic_digest">>, Case),
        candidate => snapshot_ref(CorpusDirectory, maps:get(<<"candidate">>, Case)),
        control => snapshot_ref(CorpusDirectory, maps:get(<<"control">>, Case)),
        answer_key => snapshot_ref(CorpusDirectory, maps:get(<<"answer_key">>, Case))
    }.

snapshot_ref(CorpusDirectory, Ref) ->
    Relative = maps:get(<<"path">>, Ref),
    Path = safe_child_path(CorpusDirectory, Relative),
    {ok, Content} = read_bounded(Path),
    Digest = binary_digest(Content),
    ensure(Digest =:= maps:get(<<"content_sha256">>, Ref), {asset_digest_mismatch, Relative}),
    #{path => Relative, content => Content, sha256 => Digest}.

load_named_asset(Base, Segments) ->
    Path = filename:join([Base | Segments]),
    {ok, Content} = read_bounded(Path),
    #{path => list_to_binary(filename:join(Segments)), content => Content,
        sha256 => binary_digest(Content)}.

read_bounded(Path) ->
    case file:read_file(Path) of
        {ok, Binary} when byte_size(Binary) =< 1048576 -> {ok, Binary};
        {ok, _} -> {error, asset_too_large};
        {error, Reason} -> {error, {asset_read_failed, Path, Reason}}
    end.

safe_child_path(Directory0, Relative) when is_binary(Relative) ->
    Directory = filename:absname(Directory0),
    Path = filename:absname(filename:join(Directory, binary_to_list(Relative))),
    ensure(lists:prefix(Directory ++ "/", Path), unsafe_asset_path),
    Path.

module_digest(Module) ->
    case code:ensure_loaded(Module) of
        {module, Module} ->
            case code:get_object_code(Module) of
                {Module, Binary, _Path} -> binary_digest(Binary);
                error -> throw({evidence_error, {missing_beam_object, Module}})
            end;
        {error, Reason} -> throw({evidence_error, {missing_beam_module, Module, Reason}})
    end.

ensure_reader_modules() ->
    Modules = [
        alang_fidelity_anthropic_adapter,
        alang_fidelity_bootstrap,
        alang_fidelity_campaign,
        alang_fidelity_campaign_journal,
        alang_fidelity_campaign_runner,
        alang_fidelity_observation,
        alang_fidelity_offline_campaign,
        alang_fidelity_openai_adapter,
        alang_fidelity_phase5_worker,
        alang_fidelity_score
    ],
    lists:foreach(fun(Module) ->
        case code:ensure_loaded(Module) of
            {module, Module} -> ok;
            {error, Reason} -> throw({evidence_error,
                {missing_evidence_schema_module, Module, Reason}})
        end
    end, Modules).

validate_safe(Value, Secrets) when is_map(Value) ->
    lists:foreach(fun({Key, Item}) ->
        ensure(not forbidden_key(Key), {forbidden_evidence_key, Key}),
        validate_safe(Key, Secrets),
        validate_safe(Item, Secrets)
    end, maps:to_list(Value));
validate_safe(Value, Secrets) when is_list(Value) ->
    lists:foreach(fun(Item) -> validate_safe(Item, Secrets) end, Value);
validate_safe(Value, Secrets) when is_tuple(Value) ->
    validate_safe(tuple_to_list(Value), Secrets);
validate_safe(Value, Secrets) when is_binary(Value) ->
    lists:foreach(fun
        (Secret) when byte_size(Secret) > 0 ->
            ensure(binary:match(Value, Secret) =:= nomatch, secret_retention_detected);
        (_) -> ok
    end, Secrets);
validate_safe(_Value, _Secrets) -> ok.

forbidden_key(Key) -> lists:member(Key, [
    authorization, <<"authorization">>,
    headers, <<"headers">>,
    raw_http_envelope, <<"raw_http_envelope">>,
    raw_envelope, <<"raw_envelope">>,
    hidden_reasoning, <<"hidden_reasoning">>,
    api_key, <<"api_key">>,
    credential, <<"credential">>,
    credential_source, <<"credential_source">>,
    provider_request_id, <<"provider_request_id">>,
    provider_response_id, <<"provider_response_id">>,
    response_id, <<"response_id">>
]).

validate_evidence(Evidence) ->
    ensure(maps:get(format, Evidence, invalid) =:= alang_fidelity_redacted_evidence_v1,
        invalid_evidence_format),
    Digest = maps:get(evidence_digest, Evidence, invalid),
    ensure(Digest =:= alang_fidelity_json:digest(maps:remove(evidence_digest, Evidence)),
        invalid_evidence_digest),
    validate_safe(Evidence, []).

safe_evidence_path(Path0) ->
    Root = filename:absname("build/effectful-source-fidelity/phase-05/evidence"),
    Path = filename:absname(Path0),
    ensure(lists:prefix(Root ++ "/", Path), unsafe_evidence_path),
    Path.

binary_digest(Binary) -> alang_fidelity_json:hex(crypto:hash(sha256, Binary)).

ensure(true, _Reason) -> ok;
ensure(false, Reason) -> throw({evidence_error, Reason}).
