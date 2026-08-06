-module(alang_fidelity_phase4_worker).

-export([build/0, decode/1, main/0, validate/1, write/1]).

-define(OWNED_ROOT, "build/effectful-source-fidelity/phase-04").

-spec build() -> {ok, map()} | {error, term()}.
build() ->
    Base = filename:join(filename:absname(?OWNED_ROOT), "reproduction-worker"),
    try
        Pairs = [alang_fidelity_offline:run_pair(Path, Base) || Path <- representatives()],
        Cases = [case_record(Pair) || Pair <- Pairs],
        Body = #{
            format => alang_fidelity_phase4_reproduction_body_v1,
            engine => beam,
            otp_release => list_to_binary(erlang:system_info(otp_release)),
            case_count => length(Cases),
            representation_count => length(Cases) * 2,
            cases => Cases
        },
        Bundle = #{
            format => alang_fidelity_phase4_reproduction_v1,
            bundle_sha256 => digest(Body),
            evidence => Body
        },
        ok = validate(Bundle),
        {ok, Bundle}
    catch
        Class:Reason:Stack -> {error, {Class, Reason, lists:sublist(Stack, 3)}}
    after
        cleanup(Base)
    end.

-spec write(file:filename_all()) -> {ok, map()} | {error, term()}.
write(Path) ->
    case owned_path(Path) of
        true ->
            case build() of
                {ok, Bundle} ->
                    ok = filelib:ensure_dir(Path),
                    Binary = term_to_binary(Bundle, [deterministic]),
                    case file:write_file(Path, Binary, [binary]) of
                        ok -> {ok, Bundle#{artifact_sha256 => digest_binary(Binary)}};
                        {error, Reason} -> {error, {reproduction_write_failed, Reason}}
                    end;
                {error, _} = Error -> Error
            end;
        false -> {error, reproduction_path_outside_owned_root}
    end.

main() ->
    case init:get_plain_arguments() of
        [Output] ->
            case write(Output) of
                {ok, Bundle} ->
                    Body = maps:get(evidence, Bundle),
                    io:format(
                        "fidelity_phase4_reproduction_ok digest=~s artifact=~s cases=~B representations=~B otp=~s output=~s~n",
                        [maps:get(bundle_sha256, Bundle),
                            maps:get(artifact_sha256, Bundle),
                            maps:get(case_count, Body),
                            maps:get(representation_count, Body),
                            maps:get(otp_release, Body), Output]),
                    halt(0);
                {error, Reason} ->
                    io:format(standard_error,
                        "fidelity_phase4_reproduction_error ~tp~n", [Reason]),
                    halt(1)
            end;
        _ ->
            io:format(standard_error,
                "usage: alang_fidelity_phase4_worker <output.etf>~n", []),
            halt(2)
    end.

-spec validate(term()) -> ok | {error, atom()}.
validate(#{
    format := alang_fidelity_phase4_reproduction_v1,
    bundle_sha256 := Digest,
    evidence := #{
        format := alang_fidelity_phase4_reproduction_body_v1,
        engine := beam,
        otp_release := Otp,
        case_count := 3,
        representation_count := 6,
        cases := Cases
    } = Body
} = Bundle) when map_size(Bundle) =:= 3, is_binary(Otp), length(Cases) =:= 3 ->
    Valid = valid_digest(Digest) andalso digest(Body) =:= Digest andalso
        lists:sort([maps:get(family, Case) || Case <- Cases]) =:=
            lists:sort([<<"attenuated-delegation">>, <<"repair-and-publish">>,
                <<"single-model-artifact">>]) andalso
        lists:all(fun valid_case/1, Cases),
    case Valid of
        true -> ok;
        false -> {error, invalid_phase4_reproduction}
    end;
validate(_) -> {error, invalid_phase4_reproduction}.

-spec decode(binary()) -> {ok, map()} | {error, atom()}.
decode(Binary) when is_binary(Binary) ->
    ensure_validation_modules(),
    try binary_to_term(Binary, [safe]) of
        Bundle ->
            case validate(Bundle) of
                ok -> {ok, Bundle};
                {error, _} = Error -> Error
            end
    catch
        error:badarg -> {error, unsafe_phase4_reproduction_etf}
    end;
decode(_) -> {error, unsafe_phase4_reproduction_etf}.

case_record(Pair) ->
    Source = representation_record(maps:get(source, Pair)),
    Json = representation_record(maps:get(json, Pair)),
    true = maps:get(normalized_etf, Source) =:= maps:get(normalized_etf, Json),
    true = maps:get(beam_sha256, Source) =/= maps:get(beam_sha256, Json),
    true = maps:get(semantic_artifact_sha256, Source) =:=
        maps:get(semantic_artifact_sha256, Json),
    #{
        case_id => maps:get(case_id, Pair),
        family => maps:get(family, Pair),
        semantic_artifact_sha256 => maps:get(semantic_artifact_sha256, Source),
        source => Source,
        json => Json
    }.

representation_record(Observation) ->
    {ok, Witness} = maps:get(outcome, Observation),
    Normalized = alang_fidelity_offline:normalize_observation(Observation),
    MetadataEtf = alang_fidelity_forms_v2:encode_metadata(
        maps:get(metadata, Observation)),
    NormalizedEtf = term_to_binary(Normalized, [deterministic]),
    TraceEtf = term_to_binary(maps:get(trace, Normalized), [deterministic]),
    WitnessEtf = term_to_binary(Witness, [deterministic]),
    Artifact = maps:get(artifact, Observation),
    Content = maps:get(content, Artifact),
    #{
        frontend => maps:get(frontend, Observation),
        beam => maps:get(raw_beam, Observation),
        beam_sha256 => maps:get(raw_beam_sha256, Observation),
        metadata_etf => MetadataEtf,
        metadata_sha256 => maps:get(metadata_sha256, Observation),
        semantic_artifact_sha256 => maps:get(semantic_artifact_sha256, Observation),
        normalized_etf => NormalizedEtf,
        normalized_sha256 => digest_binary(NormalizedEtf),
        trace_etf => TraceEtf,
        trace_sha256 => digest_binary(TraceEtf),
        artifact_content => Content,
        artifact_sha256 => maps:get(sha256, Artifact),
        completion_witness_etf => WitnessEtf,
        completion_witness_sha256 => maps:get(witness_digest, Witness)
    }.

valid_case(#{case_id := CaseId, family := Family,
        semantic_artifact_sha256 := SemanticArtifact,
        source := Source, json := Json} = Case) when map_size(Case) =:= 5 ->
    is_binary(CaseId) andalso is_binary(Family) andalso
        valid_digest(SemanticArtifact) andalso
        valid_representation(Source, alang_source) andalso
        valid_representation(Json, typed_json) andalso
        maps:get(normalized_etf, Source) =:= maps:get(normalized_etf, Json) andalso
        maps:get(beam, Source) =/= maps:get(beam, Json) andalso
        maps:get(semantic_artifact_sha256, Source) =:= SemanticArtifact andalso
        maps:get(semantic_artifact_sha256, Json) =:= SemanticArtifact;
valid_case(_) -> false.

valid_representation(#{
    frontend := Frontend,
    beam := Beam,
    beam_sha256 := BeamDigest,
    metadata_etf := MetadataEtf,
    metadata_sha256 := MetadataDigest,
    semantic_artifact_sha256 := SemanticArtifact,
    normalized_etf := NormalizedEtf,
    normalized_sha256 := NormalizedDigest,
    trace_etf := TraceEtf,
    trace_sha256 := TraceDigest,
    artifact_content := Content,
    artifact_sha256 := ArtifactDigest,
    completion_witness_etf := WitnessEtf,
    completion_witness_sha256 := WitnessDigest
} = Record, ExpectedFrontend) when map_size(Record) =:= 14 ->
    {ok, Metadata} = alang_fidelity_forms_v2:decode_metadata(MetadataEtf),
    Normalized = binary_to_term(NormalizedEtf, [safe]),
    Trace = binary_to_term(TraceEtf, [safe]),
    Witness = binary_to_term(WitnessEtf, [safe]),
    Frontend =:= ExpectedFrontend andalso is_binary(Beam) andalso
        digest_binary(Beam) =:= BeamDigest andalso
        digest_binary(MetadataEtf) =:= MetadataDigest andalso
        valid_digest(SemanticArtifact) andalso
        digest_binary(NormalizedEtf) =:= NormalizedDigest andalso
        maps:get(trace, Normalized) =:= Trace andalso
        digest_binary(TraceEtf) =:= TraceDigest andalso
        is_binary(Content) andalso
        digest_binary(Content) =:= ArtifactDigest andalso
        alang_fidelity_completion:validate_witness(Witness) =:= ok andalso
        maps:get(status, Witness) =:= complete andalso
        maps:get(witness_digest, Witness) =:= WitnessDigest andalso
        valid_inspection(Beam, Metadata);
valid_representation(_, _) -> false.

valid_inspection(Beam, Metadata) ->
    case alang_fidelity_artifact_v2:inspect(Beam, Metadata) of
        {ok, _Inspection} -> true;
        {error, _Reason} -> false
    end.

ensure_validation_modules() ->
    lists:foreach(fun(Module) ->
        {module, Module} = code:ensure_loaded(Module)
    end, [
        alang_fidelity_json,
        alang_fidelity_json_pointer,
        alang_fidelity_representation,
        alang_fidelity_contract,
        alang_fidelity_canonical,
        alang_fidelity_ast,
        alang_fidelity_lexer,
        alang_fidelity_parser,
        alang_fidelity_control,
        alang_fidelity_source,
        alang_fidelity_semantics,
        alang_fidelity_authority,
        alang_fidelity_ir,
        alang_fidelity_compiler,
        alang_fidelity_forms_v2,
        alang_fidelity_artifact_v2,
        alang_fidelity_backend_v2,
        alang_fidelity_runtime,
        alang_fidelity_completion,
        alang_phase1_compiler,
        alang_phase2_parser,
        alang_phase3_backend,
        alang_phase4_broker,
        alang_phase5_journal,
        alang_phase6_verifier
    ]),
    ok.

representatives() -> [
    "assets/effectful-source-fidelity/corpus/attenuated-delegation/ad-simple.alang",
    "assets/effectful-source-fidelity/corpus/repair-and-publish/rap-simple.alang",
    "assets/effectful-source-fidelity/corpus/single-model-artifact/sma-simple.alang"
].

owned_path(Path) ->
    Root = filename:absname(?OWNED_ROOT),
    Absolute = filename:absname(Path),
    lists:prefix(Root ++ "/", Absolute).

cleanup(Base) ->
    case filelib:is_dir(Base) of
        true -> file:del_dir_r(Base);
        false -> ok
    end.

valid_digest(Digest) when is_binary(Digest), byte_size(Digest) =:= 64 ->
    re:run(Digest, <<"^[0-9a-f]{64}$">>, [{capture, none}]) =:= match;
valid_digest(_) -> false.

digest(Term) -> digest_binary(term_to_binary(Term, [deterministic])).
digest_binary(Binary) -> hex(crypto:hash(sha256, Binary)).
hex(Binary) -> << <<(hex_digit(Nibble))>> || <<Nibble:4>> <= Binary >>.
hex_digit(Nibble) when Nibble < 10 -> $0 + Nibble;
hex_digit(Nibble) -> $a + Nibble - 10.
