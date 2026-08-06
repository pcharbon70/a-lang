-module(alang_fidelity_completion).

-include_lib("kernel/include/file.hrl").

-export([validate_witness/1, verify/2]).

-spec verify(map(), map()) -> {ok, map()} | {error, atom()}.
verify(Metadata, Evidence) when is_map(Metadata), is_map(Evidence) ->
    case valid_inputs(Metadata, Evidence) of
        true -> build_witness(Metadata, Evidence);
        false -> {error, invalid_fidelity_completion_evidence}
    end;
verify(_Metadata, _Evidence) -> {error, invalid_fidelity_completion_evidence}.

-spec validate_witness(map()) -> ok | {error, atom()}.
validate_witness(#{
    format := alang_fidelity_completion_witness_v1,
    status := Status,
    terminal_class := TerminalClass,
    artifact := Artifact,
    predicates := Predicates,
    phase6_status := Phase6Status,
    phase6_witness_digest := Phase6Digest,
    journal_digest := JournalDigest,
    semantic_digest := SemanticDigest,
    model_completion_claim_accepted := false,
    witness_digest := WitnessDigest
} = Witness) when map_size(Witness) =:= 11, is_list(Predicates) ->
    Base = maps:remove(witness_digest, Witness),
    PredicatesValid = lists:all(fun valid_predicate_result/1, Predicates),
    AllPassed = PredicatesValid andalso
        lists:all(fun(#{passed := Passed}) -> Passed end, Predicates),
    VerificationPassed = AllPassed andalso Phase6Status =:= complete,
    StatusMatches = case {TerminalClass, VerificationPassed} of
        {<<"complete">>, true} -> Status =:= complete;
        {<<"complete">>, false} -> Status =:= incomplete;
        {<<"needs-clarification">>, _} -> Status =:= incomplete;
        {<<"failed">>, _} -> Status =:= failed
    end,
    case PredicatesValid andalso StatusMatches andalso valid_artifact(Artifact) andalso
        valid_phase6_evidence(Phase6Status, Phase6Digest) andalso
        valid_optional_digest(JournalDigest) andalso valid_digest(SemanticDigest) andalso
        valid_digest(WitnessDigest) andalso digest(Base) =:= WitnessDigest of
        true -> ok;
        false -> {error, invalid_fidelity_completion_witness}
    end;
validate_witness(_Witness) -> {error, invalid_fidelity_completion_witness}.

valid_inputs(Metadata, Evidence) ->
    maps:get(format, Metadata, invalid) =:= alang_backend_metadata_v2 andalso
        maps:get(format, Evidence, invalid) =:= alang_fidelity_completion_evidence_v1 andalso
        lists:sort(maps:keys(Evidence)) =:= lists:sort([
            format, workspace_root, relative_path, artifact_digest, artifact_bytes,
            journal_result, journal_action_id, clarifications
        ]) andalso
        is_list(maps:get(workspace_root, Evidence)) andalso
        is_binary(maps:get(relative_path, Evidence)) andalso
        valid_optional_digest(maps:get(artifact_digest, Evidence)) andalso
        valid_optional_bytes(maps:get(artifact_bytes, Evidence)) andalso
        is_list(maps:get(clarifications, Evidence)).

build_witness(Metadata, Evidence) ->
    Completion = maps:get(completion, Metadata),
    PredicateResults = [verify_predicate(Predicate, Evidence) || Predicate <-
        maps:get(predicates, Completion)],
    Phase6 = phase6_witness(Evidence, Metadata),
    Phase6Passed = case Phase6 of
        none -> maps:get(terminal_class, Metadata) =:= <<"needs-clarification">>;
        #{status := complete} -> true;
        _ -> false
    end,
    AllPassed = lists:all(fun(#{passed := Passed}) -> Passed end, PredicateResults),
    Terminal = maps:get(terminal_class, Metadata),
    Status = terminal_status(Terminal, AllPassed andalso Phase6Passed),
    Artifact = #{
        relative_path => maps:get(relative_path, Evidence),
        digest => maps:get(artifact_digest, Evidence),
        bytes => maps:get(artifact_bytes, Evidence)
    },
    Base = #{
        format => alang_fidelity_completion_witness_v1,
        status => Status,
        terminal_class => Terminal,
        artifact => Artifact,
        predicates => PredicateResults,
        phase6_status => optional_witness_status(Phase6),
        phase6_witness_digest => optional_witness_digest(Phase6),
        journal_digest => optional_journal_digest(maps:get(journal_result, Evidence)),
        semantic_digest => maps:get(semantic_sha256, Metadata),
        model_completion_claim_accepted => false
    },
    Witness = Base#{witness_digest => digest(Base)},
    case validate_witness(Witness) of
        ok -> {ok, Witness};
        {error, _} = Error -> Error
    end.

terminal_status(<<"complete">>, true) -> complete;
terminal_status(<<"complete">>, false) -> incomplete;
terminal_status(<<"needs-clarification">>, _Passed) -> incomplete;
terminal_status(<<"failed">>, _Passed) -> failed.

verify_predicate(#{kind := Kind, target := Target, expected := Expected}, Evidence) ->
    {Actual, EvidenceTerm} = predicate_actual(Kind, Target, Evidence),
    Passed = predicate_matches(Kind, Actual, Expected),
    #{
        kind => Kind,
        target => Target,
        expected => Expected,
        passed => Passed,
        evidence_digest => digest(EvidenceTerm)
    }.

predicate_actual(<<"artifact-exists">>, _Target, Evidence) ->
    Exists = artifact_regular(Evidence),
    {Exists, {artifact_exists, Exists, maps:get(relative_path, Evidence)}};
predicate_actual(<<"sha256">>, _Target, Evidence) ->
    Digest = maps:get(artifact_digest, Evidence),
    {Digest, {artifact_digest, Digest}};
predicate_actual(<<"max-bytes">>, _Target, Evidence) ->
    Bytes = maps:get(artifact_bytes, Evidence),
    {Bytes, {artifact_bytes, Bytes}};
predicate_actual(<<"utf8">>, _Target, Evidence) ->
    Utf8 = case read_artifact(Evidence) of
        {ok, Content} -> valid_utf8(Content);
        _ -> false
    end,
    {Utf8, {artifact_utf8, Utf8}};
predicate_actual(<<"markdown-h1">>, _Target, Evidence) ->
    H1 = case read_artifact(Evidence) of
        {ok, Content} -> first_h1(Content);
        _ -> none
    end,
    {H1, {artifact_h1, H1}};
predicate_actual(<<"journal-succeeded">>, Target, Evidence) ->
    Journal = maps:get(journal_result, Evidence),
    Succeeded = is_map(Journal) andalso
        maps:get(outcome, Journal, invalid) =:= succeeded andalso
        maps:get(journal_action_id, Evidence) =:= Target,
    {Succeeded, {journal, maps:get(journal_action_id, Evidence),
        optional_journal_digest(Journal)}};
predicate_actual(<<"clarification-recorded">>, Target, Evidence) ->
    Present = lists:member(Target, maps:get(clarifications, Evidence)),
    {Present, {clarification, Target, Present}}.

predicate_matches(<<"max-bytes">>, Actual, Expected) ->
    is_integer(Actual) andalso Actual =< Expected;
predicate_matches(_Kind, Actual, Expected) -> Actual =:= Expected.

phase6_witness(#{journal_result := none}, _Metadata) -> none;
phase6_witness(Evidence, Metadata) ->
    case maps:get(artifact_digest, Evidence) of
        none -> none;
        Digest ->
            Spec = #{
                format => alang_completion_spec_v1,
                workspace_root => maps:get(workspace_root, Evidence),
                relative_path => maps:get(relative_path, Evidence),
                expected_digest => Digest,
                max_bytes => maps:get(output_bytes, maps:get(task_limits, Metadata)),
                required_section => <<"Findings">>,
                journal_result => maps:get(journal_result, Evidence)
            },
            case alang_phase6_verifier:verify(Spec) of
                {ok, Witness} -> Witness;
                {error, _} -> none
            end
    end.

artifact_regular(Evidence) ->
    case artifact_path(Evidence) of
        none -> false;
        Path ->
            case file:read_link_info(Path) of
                {ok, #file_info{type = regular}} -> true;
                _ -> false
            end
    end.

read_artifact(Evidence) ->
    case artifact_path(Evidence) of
        none -> {error, no_artifact};
        Path -> file:read_file(Path)
    end.

artifact_path(#{workspace_root := Root, relative_path := Relative}) when Relative =/= <<>> ->
    Segments = binary:split(Relative, <<"/">>, [global]),
    case lists:all(fun safe_segment/1, Segments) of
        true -> filename:join([Root | [binary_to_list(Segment) || Segment <- Segments]]);
        false -> none
    end;
artifact_path(_) -> none.

safe_segment(Segment) ->
    Segment =/= <<>> andalso Segment =/= <<".">> andalso Segment =/= <<"..">> andalso
        binary:match(Segment, <<"\\">>) =:= nomatch andalso
        binary:match(Segment, <<0>>) =:= nomatch.

first_h1(Content) ->
    case [Title || <<"# ", Title/binary>> <- binary:split(Content, <<"\n">>, [global]),
            string:trim(binary_to_list(Title)) =/= []] of
        [Title | _] -> trim_cr(Title);
        [] -> none
    end.

trim_cr(Binary) ->
    case Binary of
        <<Prefix:(byte_size(Binary) - 1)/binary, "\r">> when byte_size(Binary) > 0 -> Prefix;
        _ -> Binary
    end.

valid_utf8(Content) ->
    try unicode:characters_to_binary(Content, utf8, utf8) of
        Binary when is_binary(Binary) -> true;
        _ -> false
    catch
        _:_ -> false
    end.

optional_witness_digest(none) -> none;
optional_witness_digest(Witness) -> maps:get(witness_digest, Witness).

optional_witness_status(none) -> none;
optional_witness_status(Witness) -> maps:get(status, Witness).

optional_journal_digest(none) -> none;
optional_journal_digest(Journal) when is_map(Journal) -> digest(Journal).

valid_predicate_result(#{kind := Kind, target := Target, expected := _Expected,
        passed := Passed, evidence_digest := EvidenceDigest} = Predicate) ->
    map_size(Predicate) =:= 5 andalso is_binary(Kind) andalso is_binary(Target) andalso
        is_boolean(Passed) andalso valid_digest(EvidenceDigest);
valid_predicate_result(_) -> false.

valid_artifact(#{relative_path := Relative, digest := Digest, bytes := Bytes} = Artifact) ->
    map_size(Artifact) =:= 3 andalso is_binary(Relative) andalso
        valid_optional_digest(Digest) andalso valid_optional_bytes(Bytes);
valid_artifact(_) -> false.

valid_optional_digest(none) -> true;
valid_optional_digest(Digest) -> valid_digest(Digest).

valid_phase6_evidence(none, none) -> true;
valid_phase6_evidence(Status, Digest) when Status =:= complete; Status =:= incomplete ->
    valid_digest(Digest);
valid_phase6_evidence(_Status, _Digest) -> false.

valid_optional_bytes(none) -> true;
valid_optional_bytes(Bytes) -> is_integer(Bytes) andalso Bytes >= 0.

valid_digest(Digest) when is_binary(Digest), byte_size(Digest) =:= 64 ->
    re:run(Digest, <<"^[0-9a-f]{64}$">>, [{capture, none}]) =:= match;
valid_digest(_) -> false.

digest(Term) -> hex(crypto:hash(sha256, term_to_binary(Term, [deterministic]))).
hex(Binary) -> << <<(hex_digit(Nibble))>> || <<Nibble:4>> <= Binary >>.
hex_digit(Nibble) when Nibble < 10 -> $0 + Nibble;
hex_digit(Nibble) -> $a + Nibble - 10.
