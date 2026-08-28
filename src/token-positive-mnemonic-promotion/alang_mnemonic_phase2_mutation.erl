-module(alang_mnemonic_phase2_mutation).

-export([run/2]).

-spec run(file:filename(), map()) -> {ok, map()} | {error, term()}.
run(Root, Evidence) ->
    try
        Case = hd(cases(Root)), Oracle = alang_mnemonic_corpus:oracle(Case),
        {ok, P1} = alang_mnemonic_candidate:render(<<"P1">>, Oracle, Root),
        Bytes = maps:get(bytes, P1), SourceMap = maps:get(source_map, P1),
        CandidateContract = decode(filename:join(Root,
            "assets/token-positive-mnemonic-promotion/phase-02/contracts/candidate-contract-v1.json")),
        [Reference | ReferenceRest] = maps:get(<<"references">>, CandidateContract),
        ProtocolContract = decode(filename:join(Root,
            "assets/token-positive-mnemonic-promotion/phase-02/contracts/protocol-contract-v1.json")),
        QualificationContract = decode(filename:join(Root,
            "assets/token-positive-mnemonic-promotion/phase-02/contracts/qualification-contract-v1.json")),
        Thresholds = maps:get(<<"thresholds">>, QualificationContract),
        Results = [
            item(<<"candidate-reference-drift">>, is_error(alang_mnemonic_candidate:validate(
                CandidateContract#{<<"references">> := [Reference#{<<"sha256">> := zeros()} | ReferenceRest]}, Root))),
            item(<<"candidate-byte-drift">>, <<Bytes/binary, " ">> =/= direct_r2(Oracle, Root)),
            item(<<"cross-group-alias">>, is_error(alang_mnemonic_candidate:decode(<<"P1">>,
                binary:replace(Bytes, <<"cap{">>, <<"at{">>), Root))),
            item(<<"unknown-alias">>, is_error(alang_mnemonic_candidate:decode(<<"P1">>,
                binary:replace(Bytes, <<"~s=">>, <<"~zz=">>), Root))),
            item(<<"version-drift">>, is_error(alang_mnemonic_candidate:decode_versioned(<<"P1">>,
                <<"alang-source-v2-alias-v2">>, Bytes, Root))),
            item(<<"source-map-gap">>, source_map_gap(SourceMap, P1, Oracle)),
            item(<<"token-negative-document">>, not valid_evidence(token_mutant(Evidence, document))),
            item(<<"token-negative-request">>, not valid_evidence(token_mutant(Evidence, request))),
            item(<<"missing-attribution">>, not valid_evidence(Evidence#{
                <<"attribution_categories">> := tl(maps:get(<<"attribution_categories">>, Evidence))})),
            item(<<"threshold-relaxation">>, throws(fun() ->
                alang_mnemonic_qualification:validate_contract(QualificationContract#{
                    <<"thresholds">> := Thresholds#{
                        <<"minimum_aggregate_request_savings_basis_points">> := 0}}, Root) end)),
            item(<<"semantic-oracle-drift">>, semantic_mutant_detected(Oracle, Root)),
            item(<<"prompt-policy-digest-drift">>, is_error(alang_mnemonic_protocol:validate(
                ProtocolContract#{<<"prompt_policy_sha256">> := zeros()}, Root))),
            item(<<"authorization-digest-drift">>, authorization_digest_detected(Evidence, Root)),
            item(<<"missing-live-opt-in">>, is_error(alang_mnemonic_authorization:authorize(
                Evidence, Root, #{}))),
            item(<<"model-profile-drift">>, profile_drift(Root)),
            item(<<"schedule-seed-drift">>, schedule_drift(Root)),
            item(<<"foreign-trusted-source">>, throws(fun() ->
                alang_mnemonic_phase2_residency:validate_sources([fake_record(<<"mutant.py">>)]) end)),
            item(<<"forbidden-runtime-import">>, throws(fun() ->
                alang_mnemonic_phase2_residency:validate_imports([
                    (fake_record(<<"mutant.erl">>))#{<<"imports">> := [<<"os:cmd/1">>]}]) end))
        ],
        Names = [Name || {Name, true} <- Results], Total = length(Results),
        case length(Names) =:= Total of
            true -> {ok, #{<<"detected">> => Total, <<"total">> => Total,
                <<"all_detected">> => true, <<"names">> => Names}};
            false -> {error, {undetected_mutants,
                [Name || {Name, false} <- Results]}}
        end
    catch Class:Reason -> {error, {mnemonic_phase2_mutation_error, Class, Reason}} end.

source_map_gap(Map, Surface, Oracle) ->
    [First | Rest] = maps:get(<<"tokens">>, Map),
    is_error(alang_compact_source_map:validate(Map#{<<"tokens">> :=
        [First#{<<"from">> := 1} | Rest]}, Surface, Oracle)).

token_mutant(Evidence, Kind) ->
    [First | Rest] = maps:get(<<"profiles">>, Evidence),
    Mutant = case Kind of
        document -> First#{<<"p1_document_tokens">> := maps:get(<<"p0_document_tokens">>, First) + 1};
        request -> First#{<<"p1_request_tokens">> := maps:get(<<"p0_request_tokens">>, First) + 1}
    end,
    Evidence#{<<"profiles">> := [Mutant | Rest]}.

valid_evidence(Evidence) ->
    maps:get(<<"attribution_categories">>, Evidence, []) =:= categories() andalso
    maps:get(<<"pass">>, maps:get(<<"gate">>, Evidence, #{}), false) andalso
    lists:all(fun(P) ->
        maps:get(<<"p1_document_tokens">>, P) < maps:get(<<"p0_document_tokens">>, P) andalso
        maps:get(<<"p1_request_tokens">>, P) < maps:get(<<"p0_request_tokens">>, P) andalso
        maps:get(<<"document_aggregate_savings_basis_points">>, P) >= 500 andalso
        maps:get(<<"document_median_savings_basis_points">>, P) >= 500 andalso
        maps:get(<<"request_aggregate_savings_basis_points">>, P) >= 500 andalso
        maps:get(<<"request_median_savings_basis_points">>, P) >= 500
    end, maps:get(<<"profiles">>, Evidence, [])).

semantic_mutant_detected(Oracle, Root) ->
    Response = alang_mnemonic_protocol:oracle_response(<<"comprehension">>, <<"P1">>, Oracle),
    Mutant = Oracle#{<<"goal_facts">> := maps:get(<<"goal_facts">>, Oracle) ++
        [<<"mutant authority fact">>]},
    {ok, Score} = alang_mnemonic_protocol:score(<<"comprehension">>, <<"P1">>,
        Response, Mutant, Root),
    maps:get(<<"exact">>, Score) =:= false.

authorization_digest_detected(Evidence, Root) ->
    Contract = decode(filename:join(Root,
        "assets/token-positive-mnemonic-promotion/phase-02/contracts/authorization-v1.json")),
    maps:get(<<"qualification_digest">>, Contract) =/=
        maps:get(<<"qualification_digest">>, Evidence#{<<"qualification_digest">> := zeros()}).

profile_drift(Root) ->
    Profiles = decode(filename:join(Root,
        "assets/token-positive-mnemonic-promotion/campaign/provider-profiles-v1.json")),
    [First | Rest] = maps:get(<<"profiles">>, Profiles),
    is_error(alang_mnemonic_registration:validate_profiles(Profiles#{<<"profiles">> :=
        [First#{<<"manifest_sha256">> := zeros()} | Rest]})).

schedule_drift(Root) ->
    Campaign = filename:join([Root, "assets", "token-positive-mnemonic-promotion", "campaign"]),
    {ok, Schedule} = alang_mnemonic_schedule:materialize(Campaign),
    Policy = decode(filename:join(Campaign, "schedule-policy-v1.json")),
    Design = decode(filename:join(Campaign, "case-design-v1.json")),
    is_error(alang_mnemonic_schedule:validate(Schedule,
        Policy#{<<"seed">> := 2026082505}, maps:get(<<"cases">>, Design))).

direct_r2(Oracle, Root) ->
    Registry = filename:join([Root, "assets", "compact-projection-fidelity",
        "phase-02", "contracts", "surface-registry-v1.json"]),
    {ok, Surface} = alang_compact_surface:render(<<"R2">>,
        <<"alang-source-v2-alias-v1">>, Oracle, Registry), maps:get(bytes, Surface).

fake_record(Source) -> #{<<"module">> => <<"mutant">>, <<"source_path">> => Source,
    <<"source_sha256">> => zeros(), <<"beam_sha256">> => zeros(), <<"imports">> => []}.
cases(Root) -> maps:get(<<"cases">>, decode(filename:join([Root, "assets",
    "token-positive-mnemonic-promotion", "corpus", "confirmatory-corpus-v1.json"]))).
categories() -> [<<"layout">>, <<"vocabulary">>, <<"identifiers">>, <<"facts">>,
    <<"paths">>, <<"budgets">>, <<"authority">>, <<"completion">>, <<"legends">>,
    <<"instructions">>, <<"output-scaffolding">>].
item(Name, Pass) -> {Name, Pass}.
is_error({error, _}) -> true;
is_error(_) -> false.
throws(Fun) -> try Fun(), false catch _:_ -> true end.
decode(Path) -> {ok, Value} = alang_fidelity_json:decode_file(Path), Value.
zeros() -> <<"0000000000000000000000000000000000000000000000000000000000000000">>.
