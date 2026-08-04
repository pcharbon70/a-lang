-module(alang_phase8_inspect).

-export([explain/1, verify/1]).

-spec verify(file:filename()) -> {ok, map()} | {error, term()}.
verify(Output) ->
    try
        Evidence = consult_one(filename:join(Output, "evidence.config")),
        Expected = consult_one("src/phase-08/fixtures/expected.config"),
        EvidenceDigest = maps:get(evidence_digest, Evidence),
        EvidenceDigest = digest(maps:remove(evidence_digest, Evidence)),
        ok = verify_artifacts(Output, maps:get(artifacts, Evidence)),
        ok = verify_source_products(Output, maps:get(source, Evidence)),
        ok = verify_expected(Expected, Evidence),
        false = contains_runtime_identity(Evidence),
        false = contains_capability_shape(Evidence),
        {ok, Explanation} = explain(Output),
        true = binary:match(Explanation, <<"# A-Lang Phase 8 Demonstration">>) =/= nomatch,
        {ok, #{format => alang_phase8_inspection_v1, status => accepted,
            evidence_digest => EvidenceDigest,
            artifact_count => map_size(maps:get(artifacts, Evidence)),
            redacted => true}}
    catch
        Class:Reason -> {error, {Class, Reason}}
    end.

-spec explain(file:filename()) -> {ok, binary()} | {error, term()}.
explain(Output) -> file:read_file(filename:join(Output, "explanation.md")).

verify_artifacts(Output, Artifacts) ->
    maps:foreach(fun(_Name, Artifact) ->
        Path = filename:join(Output, binary_to_list(maps:get(file, Artifact))),
        {ok, Beam} = file:read_file(Path),
        true = maps:get(beam_sha256, Artifact) =:= digest_binary(Beam),
        true = maps:get(bytes, Artifact) =:= byte_size(Beam),
        {ok, Inspection} = alang_phase3_artifact:inspect(Beam),
        true = maps:get(beam_sha256, Artifact) =:= maps:get(beam_sha256, Inspection),
        accepted = maps:get(policy, Inspection)
    end, Artifacts),
    ok.

verify_source_products(Output, SourceEvidence) ->
    {ok, Canonical} = file:read_file(filename:join(Output, "canonical-source.etf")),
    true = maps:get(canonical_sha256, SourceEvidence) =:= digest_binary(Canonical),
    {ok, _Ast} = alang_phase2_canonical:decode(Canonical),
    {ok, IrBinary} = file:read_file(filename:join(Output, "typed-task-ir.etf")),
    Ir = binary_to_term(IrBinary, [safe]),
    true = maps:get(ir_sha256, SourceEvidence) =:= digest(Ir),
    ok = alang_phase3_contract:validate_ir(Ir),
    ok.

verify_expected(Expected, Evidence) ->
    Source = maps:get(source, Evidence),
    Artifacts = maps:get(artifacts, Evidence),
    Values = #{source_result => maps:get(result, Source),
        source_canonical_sha256 => maps:get(canonical_sha256, Source),
        source_ir_sha256 => maps:get(ir_sha256, Source),
        source_beam_sha256 => maps:get(beam_sha256, maps:get(source, Artifacts)),
        child_beam_sha256 => maps:get(beam_sha256, maps:get(child, Artifacts)),
        workspace_beam_sha256 => maps:get(beam_sha256, maps:get(workspace, Artifacts)),
        output_sha256 => maps:get(artifact_digest, maps:get(workspace, Evidence)),
        witness_digest => maps:get(witness_digest, maps:get(completion_witness, Evidence)),
        evidence_digest => maps:get(evidence_digest, Evidence)},
    Differences = [{Key, Wanted, maps:get(Key, Values)} || Key <- maps:keys(Values),
        Wanted <- [maps:get(Key, Expected)],
        Wanted =/= maps:get(Key, Values)],
    case Differences of [] -> ok; _ -> error({expected_mismatch, Differences}) end.

consult_one(Path) ->
    {ok, [Term]} = file:consult(Path),
    Term.

contains_runtime_identity(Term) when is_pid(Term); is_reference(Term); is_port(Term) -> true;
contains_runtime_identity(Term) when is_map(Term) ->
    lists:any(fun contains_runtime_identity/1, maps:keys(Term) ++ maps:values(Term));
contains_runtime_identity(Term) when is_tuple(Term) ->
    contains_runtime_identity(tuple_to_list(Term));
contains_runtime_identity(Term) when is_list(Term) ->
    lists:any(fun contains_runtime_identity/1, Term);
contains_runtime_identity(_Term) -> false.

contains_capability_shape({capability, local, _Reference}) -> true;
contains_capability_shape(Term) when is_map(Term) ->
    lists:any(fun contains_capability_shape/1, maps:keys(Term) ++ maps:values(Term));
contains_capability_shape(Term) when is_tuple(Term) ->
    contains_capability_shape(tuple_to_list(Term));
contains_capability_shape(Term) when is_list(Term) ->
    lists:any(fun contains_capability_shape/1, Term);
contains_capability_shape(_Term) -> false.

digest_binary(Binary) -> hex(crypto:hash(sha256, Binary)).
digest(Term) -> hex(crypto:hash(sha256, term_to_binary(Term, [deterministic]))).
hex(Binary) -> << <<(hex_digit(Nibble))>> || <<Nibble:4>> <= Binary >>.
hex_digit(Nibble) when Nibble < 10 -> $0 + Nibble;
hex_digit(Nibble) -> $a + Nibble - 10.
