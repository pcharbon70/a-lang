-module(alang_phase6_verifier).

-include_lib("kernel/include/file.hrl").

-export([validate_witness/1, verify/1]).

-spec verify(map()) -> {ok, map()} | {error, atom()}.
verify(Spec) ->
    case validate_spec(Spec) of
        {ok, Root, Segments} -> verify_path(Spec, Root, Segments);
        {error, _} = Error -> Error
    end.

-spec validate_witness(map()) -> ok | {error, atom()}.
validate_witness(#{
    format := alang_completion_witness_v1,
    status := Status,
    artifact := Artifact,
    journal_operation_id := OperationId,
    predicates := Predicates,
    unresolved_uncertainty := Unresolved,
    witness_digest := WitnessDigest
} = Witness) when map_size(Witness) =:= 7, is_list(Predicates), is_list(Unresolved) ->
    Base = maps:remove(witness_digest, Witness),
    Failed = [maps:get(name, Predicate, invalid) || Predicate <- Predicates,
        maps:get(passed, Predicate, false) =:= false],
    Names = [maps:get(name, Predicate, invalid) || Predicate <- Predicates],
    RequiredNames = [relative_path_safe, regular_file, digest_match, byte_bound, utf8,
        markdown, required_section_nonempty, journal_binding],
    StatusConsistent = case Status of
        complete -> Failed =:= [] andalso Unresolved =:= [];
        incomplete -> Failed =/= [] andalso Unresolved =:= Failed;
        _ -> false
    end,
    case valid_artifact_evidence(Artifact, Status) andalso
        valid_text(OperationId, 1, 128) andalso
        length(Predicates) =:= length(RequiredNames) andalso
        lists:sort(Names) =:= lists:sort(RequiredNames) andalso
        lists:all(fun valid_predicate/1, Predicates) andalso
        StatusConsistent andalso valid_digest(WitnessDigest) andalso
        digest(Base) =:= WitnessDigest
    of
        true -> ok;
        false -> {error, invalid_completion_witness}
    end;
validate_witness(_Witness) -> {error, invalid_completion_witness}.

verify_path(Spec, Root, Segments) ->
    Relative = maps:get(relative_path, Spec),
    Path = filename:join([Root | [binary_to_list(Segment) || Segment <- Segments]]),
    PathSafe = ancestors_are_directories(Root, Segments),
    {Regular, Content} = read_regular(Path, PathSafe),
    ActualDigest = case Regular of true -> digest_binary(Content); false -> none end,
    Bytes = case Regular of true -> byte_size(Content); false -> none end,
    Utf8 = Regular andalso valid_utf8(Content),
    Markdown = Utf8 andalso filename:extension(Path) =:= ".md" andalso has_h1(Content),
    Required = Markdown andalso required_section_nonempty(
        Content, maps:get(required_section, Spec)),
    Journal = maps:get(journal_result, Spec),
    Predicates = [
        predicate(relative_path_safe, PathSafe, spec, digest(Relative)),
        predicate(regular_file, Regular, artifact, value_or_expected(ActualDigest, Spec)),
        predicate(digest_match, ActualDigest =:= maps:get(expected_digest, Spec),
            artifact, value_or_expected(ActualDigest, Spec)),
        predicate(byte_bound, is_integer(Bytes) andalso Bytes =< maps:get(max_bytes, Spec),
            artifact, value_or_expected(ActualDigest, Spec)),
        predicate(utf8, Utf8, artifact, value_or_expected(ActualDigest, Spec)),
        predicate(markdown, Markdown, artifact, value_or_expected(ActualDigest, Spec)),
        predicate(required_section_nonempty, Required, artifact,
            value_or_expected(ActualDigest, Spec)),
        predicate(journal_binding, journal_matches(Journal, Spec), journal,
            maps:get(result_digest, Journal))
    ],
    Unresolved = [maps:get(name, Predicate) || Predicate <- Predicates,
        maps:get(passed, Predicate) =:= false],
    Status = case Unresolved of [] -> complete; _ -> incomplete end,
    Base = #{
        format => alang_completion_witness_v1,
        status => Status,
        artifact => #{relative_path => Relative, digest => ActualDigest, bytes => Bytes},
        journal_operation_id => maps:get(operation_id, Journal),
        predicates => Predicates,
        unresolved_uncertainty => Unresolved
    },
    Witness = Base#{witness_digest => digest(Base)},
    ok = validate_witness(Witness),
    {ok, Witness}.

validate_spec(#{
    format := alang_completion_spec_v1,
    workspace_root := Root0,
    relative_path := Relative,
    expected_digest := Expected,
    max_bytes := MaxBytes,
    required_section := RequiredSection,
    journal_result := Journal
} = Spec) when map_size(Spec) =:= 7, is_list(Root0), is_binary(Relative),
    is_integer(MaxBytes), MaxBytes > 0, MaxBytes =< 65536 ->
    Root = filename:absname(Root0),
    Segments = binary:split(Relative, <<"/">>, [global]),
    case filename:pathtype(Root0) =:= absolute andalso valid_segments(Segments) andalso
        valid_digest(Expected) andalso valid_text(RequiredSection, 1, 128) andalso
        valid_journal(Journal)
    of
        true -> {ok, Root, Segments};
        false -> {error, invalid_completion_specification}
    end;
validate_spec(_Spec) -> {error, invalid_completion_specification}.

valid_journal(#{
    format := alang_workspace_result_evidence_v1,
    operation_id := OperationId,
    operation := <<"workspace.write">>,
    relative_path := Relative,
    artifact_digest := ArtifactDigest,
    result_digest := ResultDigest,
    outcome := succeeded
} = Journal) when map_size(Journal) =:= 7 ->
    valid_text(OperationId, 1, 128) andalso valid_text(Relative, 1, 1024) andalso
        valid_digest(ArtifactDigest) andalso valid_digest(ResultDigest);
valid_journal(_Journal) -> false.

journal_matches(Journal, Spec) ->
    maps:get(relative_path, Journal) =:= maps:get(relative_path, Spec) andalso
        maps:get(artifact_digest, Journal) =:= maps:get(expected_digest, Spec).

valid_segments(Segments) ->
    Segments =/= [] andalso length(Segments) =< 32 andalso
        lists:all(fun(Segment) ->
            valid_text(Segment, 1, 255) andalso Segment =/= <<".">> andalso Segment =/= <<"..">> andalso
                binary:match(Segment, <<"\\">>) =:= nomatch andalso
                binary:match(Segment, <<0>>) =:= nomatch
        end, Segments).

ancestors_are_directories(Root, Segments) ->
    case file:read_link_info(Root) of
        {ok, #file_info{type = directory}} -> ancestors_are_directories(Root, Segments, 1);
        _ -> false
    end.

ancestors_are_directories(_Current, [_File], _Depth) -> true;
ancestors_are_directories(Current, [Segment | Rest], Depth) when Depth =< 32 ->
    Next = filename:join(Current, binary_to_list(Segment)),
    case file:read_link_info(Next) of
        {ok, #file_info{type = directory}} -> ancestors_are_directories(Next, Rest, Depth + 1);
        _ -> false
    end;
ancestors_are_directories(_Current, _Segments, _Depth) -> false.

read_regular(Path, true) ->
    case file:read_link_info(Path) of
        {ok, #file_info{type = regular}} ->
            case file:read_file(Path) of
                {ok, Content} -> {true, Content};
                _ -> {false, <<>>}
            end;
        _ -> {false, <<>>}
    end;
read_regular(_Path, false) -> {false, <<>>}.

valid_utf8(Content) -> is_binary(unicode:characters_to_binary(Content, utf8, utf8)).

has_h1(Content) ->
    lists:any(fun(Line) ->
        case Line of <<"# ", Rest/binary>> -> nonempty(Rest); _ -> false end
    end, lines(Content)).

required_section_nonempty(Content, Required) ->
    Heading = <<"## ", Required/binary>>,
    section_has_content(lines(Content), Heading, false).

section_has_content([], _Heading, _Inside) -> false;
section_has_content([Line | Rest], Heading, false) ->
    section_has_content(Rest, Heading, trim_cr(Line) =:= Heading);
section_has_content([Line | Rest], Heading, true) ->
    Clean = trim_cr(Line),
    case Clean of
        <<"#", _/binary>> -> false;
        _ -> nonempty(Clean) orelse section_has_content(Rest, Heading, true)
    end.

lines(Content) -> binary:split(Content, <<"\n">>, [global]).
trim_cr(Line) ->
    case Line of
        <<Prefix:(byte_size(Line) - 1)/binary, "\r">> when byte_size(Line) > 0 -> Prefix;
        _ -> Line
    end.
nonempty(Binary) -> string:trim(binary_to_list(Binary)) =/= [].

predicate(Name, Passed, Kind, Reference) -> #{
    name => Name,
    passed => Passed,
    evidence => #{kind => Kind, reference => Reference}
}.

valid_predicate(#{name := Name, passed := Passed,
    evidence := #{kind := Kind, reference := Reference} = Evidence} = Predicate) when
    map_size(Predicate) =:= 3, map_size(Evidence) =:= 2 ->
    lists:member(Name, [relative_path_safe, regular_file, digest_match, byte_bound, utf8,
        markdown, required_section_nonempty, journal_binding]) andalso
        is_boolean(Passed) andalso lists:member(Kind, [artifact, journal, spec]) andalso
        valid_digest(Reference);
valid_predicate(_Predicate) -> false.

valid_artifact_evidence(#{relative_path := Relative, digest := Digest, bytes := Bytes} = Artifact,
    Status) when map_size(Artifact) =:= 3 ->
    valid_text(Relative, 1, 1024) andalso
        case Status of
            complete -> valid_digest(Digest) andalso is_integer(Bytes) andalso Bytes >= 0;
            incomplete -> (Digest =:= none orelse valid_digest(Digest)) andalso
                (Bytes =:= none orelse (is_integer(Bytes) andalso Bytes >= 0));
            _ -> false
        end;
valid_artifact_evidence(_Artifact, _Status) -> false.

value_or_expected(none, Spec) -> maps:get(expected_digest, Spec);
value_or_expected(Digest, _Spec) -> Digest.

valid_text(Value, Minimum, Maximum) ->
    is_binary(Value) andalso byte_size(Value) >= Minimum andalso byte_size(Value) =< Maximum.
valid_digest(Value) when is_binary(Value), byte_size(Value) =:= 64 ->
    lists:all(fun is_hex/1, binary_to_list(Value));
valid_digest(_Value) -> false.

digest_binary(Binary) -> hex(crypto:hash(sha256, Binary)).
digest(Term) -> hex(crypto:hash(sha256, term_to_binary(Term, [deterministic]))).
is_hex(Character) when Character >= $0, Character =< $9 -> true;
is_hex(Character) when Character >= $a, Character =< $f -> true;
is_hex(_Character) -> false.
hex(Binary) -> << <<(hex_digit(Nibble))>> || <<Nibble:4>> <= Binary >>.
hex_digit(Nibble) when Nibble < 10 -> $0 + Nibble;
hex_digit(Nibble) -> $a + Nibble - 10.
