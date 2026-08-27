-module(alang_compact_phase2_worker).

-export([evidence/0, main/0]).

-define(PROFILES, [
    <<"tiktoken-0.12.0-cl100k-base">>,
    <<"tiktoken-0.12.0-o200k-base">>
]).

-spec evidence() -> {ok, map()} | {error, term()}.
evidence() ->
    try
        {ok, _CorpusAudit} = alang_compact_corpus:load(compact_assets_dir()),
        {ok, Corpus} = alang_fidelity_json:decode_file(corpus_path()),
        Confirmatory = [alang_compact_corpus:oracle(Case) ||
            Case <- maps:get(<<"cases">>, Corpus)],
        Development = development_oracles(),
        {ok, Registry} = alang_compact_surface:load_registry(registry_path()),
        Surfaces = maps:get(<<"surfaces">>, Registry),
        {ok, ProtocolRegistry} = alang_fidelity_json:decode_file(protocol_registry_path()),
        Rows = [render_cell(CorpusName, Oracle, Surface, ProtocolRegistry) ||
            {CorpusName, Oracles} <- [{<<"confirmatory">>, Confirmatory},
                {<<"development">>, Development}],
            Oracle <- Oracles, Surface <- Surfaces],
        true = length(Rows) =:= 432,
        {ok, Mutation} = alang_compact_phase2_mutation:run(),
        {ok, Residency} = alang_compact_phase2_residency:audit("."),
        Aggregates = aggregates(Rows, Surfaces),
        {ok, #{
            <<"format">> => <<"alang-compact-phase-2-integration-evidence-v1">>,
            <<"execution">> => <<"clean-erts-offline">>,
            <<"confirmatory_cases">> => length(Confirmatory),
            <<"development_cases">> => length(Development),
            <<"semantic_cases">> => length(Confirmatory) + length(Development),
            <<"registered_surfaces">> => length(Surfaces),
            <<"surface_case_cells">> => length(Rows),
            <<"canonical_round_trips">> => length(Rows),
            <<"source_mapped_surfaces">> => length(Rows),
            <<"rows">> => Rows,
            <<"aggregates">> => Aggregates,
            <<"r3_savings_vs_r0">> => savings(Rows),
            <<"token_accounting">> => #{
                <<"offline_counts">> => <<"exact-registered-tokenizer">>,
                <<"profiles">> => ?PROFILES,
                <<"provider_usage">> => <<"unavailable">>,
                <<"proxy_counts">> => 0,
                <<"token_reports">> => length(Rows) * length(?PROFILES)
            },
            <<"mutation">> => Mutation,
            <<"residency">> => Residency,
            <<"network_access">> => <<"disabled-by-construction">>,
            <<"model_calls">> => 0,
            <<"provider_calls">> => 0,
            <<"model_fidelity_claimed">> => false
        }}
    catch
        Class:Reason:Stack -> {error, {phase2_evidence_failed, Class, Reason, Stack}}
    end.

-spec main() -> no_return().
main() ->
    case {init:get_plain_arguments(), evidence()} of
        {[Output], {ok, Evidence}} ->
            {ok, Bytes} = alang_fidelity_json:encode_canonical(Evidence),
            ok = filelib:ensure_dir(Output),
            ok = file:write_file(Output, <<Bytes/binary, "\n">>),
            io:format("compact_phase2_evidence_ok digest=~s cells=432 token_reports=864 output=~s~n",
                [alang_fidelity_json:digest(Evidence), Output]),
            halt(0);
        {Arguments, {ok, _Evidence}} ->
            io:format(standard_error, "expected one evidence output path, got ~p~n", [Arguments]),
            halt(2);
        {_Arguments, {error, Reason}} ->
            io:format(standard_error, "compact phase 2 evidence failed: ~p~n", [Reason]),
            halt(1)
    end.

render_cell(CorpusName, Oracle, SurfaceSpec, ProtocolRegistry) ->
    SurfaceId = maps:get(<<"id">>, SurfaceSpec),
    Version = maps:get(<<"version">>, SurfaceSpec),
    {ok, First} = alang_compact_surface:render(SurfaceId, Version, Oracle, registry_path()),
    {ok, Shuffled} = alang_compact_surface:render(
        SurfaceId, Version, shuffle(Oracle), registry_path()),
    true = maps:get(bytes, First) =:= maps:get(bytes, Shuffled),
    true = maps:get(semantic_digest, First) =:= maps:get(semantic_digest, Shuffled),
    {ok, FirstMap} = alang_compact_source_map:build(First, Oracle),
    {ok, ShuffledMap} = alang_compact_source_map:build(Shuffled, shuffle(Oracle)),
    true = FirstMap =:= ShuffledMap,
    Decoded = case decode(SurfaceId, Version, First) of
        {ok, Value} -> Value;
        {error, DecodeReason} -> erlang:error({surface_decode_failed, CorpusName,
            maps:get(<<"case_id">>, Oracle), SurfaceId, DecodeReason})
    end,
    Digest = alang_fidelity_contract:semantic_digest(Oracle),
    true = maps:get(semantic_digest, First) =:= Digest,
    true = maps:get(semantic_digest, Decoded) =:= Digest,
    RequestParts = request_parts(SurfaceId, ProtocolRegistry),
    Audits = [audit(Profile, First, RequestParts) || Profile <- ?PROFILES],
    #{
        <<"corpus">> => CorpusName,
        <<"case_id">> => maps:get(<<"case_id">>, Oracle),
        <<"surface_id">> => SurfaceId,
        <<"version">> => Version,
        <<"semantic_digest">> => Digest,
        <<"representation_sha256">> => maps:get(representation_sha256, First),
        <<"representation_bytes">> => maps:get(byte_count, First),
        <<"source_map_sha256">> => alang_fidelity_json:digest(FirstMap),
        <<"source_map_tokens">> => length(maps:get(<<"tokens">>, FirstMap)),
        <<"security_fields">> => length(maps:get(<<"fields">>, FirstMap)),
        <<"source_map_coverage">> => maps:get(<<"coverage">>, FirstMap),
        <<"token_reports">> => Audits
    }.

decode(<<"R4">>, Version, Surface) ->
    Provenance = maps:get(provenance, Surface),
    alang_compact_surface:decode(<<"R4">>, Version, maps:get(bytes, Surface),
        #{opaque_reverse_map => maps:get(opaque_reverse_map, Provenance)});
decode(SurfaceId, Version, Surface) ->
    alang_compact_surface:decode(SurfaceId, Version, maps:get(bytes, Surface)).

audit(Profile, Surface, RequestParts) ->
    {ok, Report} = alang_compact_token_audit:audit(Profile, Surface, RequestParts,
        unavailable, tokenizer_dir(), audit_contract_path()),
    Counts = maps:get(<<"counts">>, Report),
    #{
        <<"profile_id">> => Profile,
        <<"provenance">> => maps:get(<<"provenance">>, maps:get(<<"tokenizer">>, Report)),
        <<"document_tokens">> => maps:get(<<"document">>, Counts),
        <<"full_request_tokens">> => maps:get(<<"full_request">>, Counts),
        <<"report_sha256">> => alang_fidelity_json:digest(Report)
    }.

request_parts(SurfaceId, Registry) ->
    [Protocol] = [Value || Value <- maps:get(<<"protocols">>, Registry),
        maps:get(<<"id">>, Value) =:= <<"comprehension">>],
    [Legend] = [Value || Value <- maps:get(<<"legends">>, Registry),
        maps:get(<<"condition">>, Value) =:= SurfaceId],
    Common = maps:get(<<"common_instruction">>, Registry),
    Instruction = maps:get(<<"instruction">>, Protocol),
    #{
        common_instructions => <<Common/binary, "\n", Instruction/binary>>,
        legend => maps:get(<<"content">>, Legend),
        output_scaffolding => maps:get(<<"output_contract">>, Protocol)
    }.

aggregates(Rows, Surfaces) ->
    [aggregate(maps:get(<<"id">>, Surface), Profile, Rows) ||
        Surface <- Surfaces, Profile <- ?PROFILES].

aggregate(SurfaceId, Profile, Rows) ->
    Selected = [Row || Row <- Rows, maps:get(<<"surface_id">>, Row) =:= SurfaceId],
    Reports = [report(Profile, Row) || Row <- Selected],
    #{
        <<"surface_id">> => SurfaceId,
        <<"profile_id">> => Profile,
        <<"cases">> => length(Selected),
        <<"representation_bytes">> => lists:sum(
            [maps:get(<<"representation_bytes">>, Row) || Row <- Selected]),
        <<"document_tokens">> => lists:sum(
            [maps:get(<<"document_tokens">>, Value) || Value <- Reports]),
        <<"full_request_tokens">> => lists:sum(
            [maps:get(<<"full_request_tokens">>, Value) || Value <- Reports])
    }.

savings(Rows) ->
    R0Bytes = surface_bytes(<<"R0">>, Rows),
    R3Bytes = surface_bytes(<<"R3">>, Rows),
    TokenSavings = [begin
        R0 = surface_tokens(<<"R0">>, Profile, Rows),
        R3 = surface_tokens(<<"R3">>, Profile, Rows),
        #{
            <<"profile_id">> => Profile,
            <<"r0_document_tokens">> => R0,
            <<"r3_document_tokens">> => R3,
            <<"saved_document_tokens">> => R0 - R3,
            <<"savings_basis_points">> => basis_points(R0, R3)
        }
    end || Profile <- ?PROFILES],
    #{
        <<"r0_representation_bytes">> => R0Bytes,
        <<"r3_representation_bytes">> => R3Bytes,
        <<"saved_representation_bytes">> => R0Bytes - R3Bytes,
        <<"byte_savings_basis_points">> => basis_points(R0Bytes, R3Bytes),
        <<"document_token_savings">> => TokenSavings,
        <<"interpretation">> => <<"offline-screening-only-not-model-efficacy">>
    }.

surface_bytes(SurfaceId, Rows) ->
    lists:sum([maps:get(<<"representation_bytes">>, Row) || Row <- Rows,
        maps:get(<<"surface_id">>, Row) =:= SurfaceId]).

surface_tokens(SurfaceId, Profile, Rows) ->
    lists:sum([maps:get(<<"document_tokens">>, report(Profile, Row)) || Row <- Rows,
        maps:get(<<"surface_id">>, Row) =:= SurfaceId]).

report(Profile, Row) ->
    [Value] = [Item || Item <- maps:get(<<"token_reports">>, Row),
        maps:get(<<"profile_id">>, Item) =:= Profile],
    Value.

basis_points(Baseline, Candidate) when Baseline > 0 ->
    ((Baseline - Candidate) * 10000 + Baseline div 2) div Baseline.

shuffle(Value) when is_map(Value) ->
    maps:from_list(lists:reverse([{Key, shuffle(Child)} ||
        {Key, Child} <- lists:sort(maps:to_list(Value))]));
shuffle(Value) when is_list(Value) -> [shuffle(Item) || Item <- Value];
shuffle(Value) -> Value.

development_oracles() ->
    {ok, Manifest} = alang_fidelity_json:decode_file(development_manifest_path()),
    [begin
        ControlPath = filename:join([development_corpus_dir(),
            binary_to_list(maps:get(<<"path">>, maps:get(<<"control">>, Case)))]),
        {ok, Control} = alang_fidelity_json:decode_file(ControlPath),
        {ok, Decoded} = alang_fidelity_representation:validate_control(Control),
        Oracle = (maps:get(<<"semantic">>, Decoded))#{
            <<"format">> => <<"alang_task_comprehension_v1">>,
            <<"case_id">> => maps:get(<<"case_id">>, Control)
        },
        {ok, _} = alang_fidelity_contract:validate_comprehension(Oracle),
        true = alang_fidelity_contract:semantic_digest(Oracle) =:=
            maps:get(<<"semantic_digest">>, Case),
        Oracle
    end || Case <- maps:get(<<"cases">>, Manifest)].

compact_assets_dir() -> filename:join(["assets", "compact-projection-fidelity"]).
corpus_path() -> filename:join([compact_assets_dir(), "corpus", "confirmatory-corpus-v1.json"]).
protocol_registry_path() -> filename:join([compact_assets_dir(), "campaign", "protocol-registry-v1.json"]).
phase2_dir() -> filename:join([compact_assets_dir(), "phase-02"]).
registry_path() -> filename:join([phase2_dir(), "contracts", "surface-registry-v1.json"]).
audit_contract_path() -> filename:join([phase2_dir(), "contracts", "token-audit-contract-v1.json"]).
tokenizer_dir() -> filename:join([phase2_dir(), "tokenizers"]).
development_corpus_dir() -> filename:join(["assets", "effectful-source-fidelity", "corpus"]).
development_manifest_path() -> filename:join([development_corpus_dir(), "corpus-manifest-v1.json"]).
