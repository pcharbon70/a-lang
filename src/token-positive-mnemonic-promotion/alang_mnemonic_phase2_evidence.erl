-module(alang_mnemonic_phase2_evidence).

-export([build/1, write/2]).

-define(QUALIFICATION, <<"e00fe1b40807d052523a2999fc3584d9a4e5cf6736766cc4f0565f9c09c7417f">>).

-spec build(file:filename()) -> {ok, map()} | {error, term()}.
build(Root) ->
    try
        {ok, Qualification} = checked(alang_mnemonic_qualification:build(Root)),
        exact(maps:get(<<"qualification_digest">>, Qualification), ?QUALIFICATION,
            qualification_digest),
        {ok, Authorization} = checked(alang_mnemonic_authorization:load(filename:join([
            Root, "assets", "token-positive-mnemonic-promotion", "phase-02",
            "contracts", "authorization-v1.json"]))),
        exact(maps:get(<<"qualification_digest">>, Authorization), ?QUALIFICATION,
            authorization_digest),
        Replay = replay(Root),
        {ok, Mutation} = checked(alang_mnemonic_phase2_mutation:run(Root, Qualification)),
        {ok, Residency} = checked(alang_mnemonic_phase2_residency:audit(Root)),
        Body = #{
            <<"format">> => <<"alang-token-positive-phase-2-evidence-v1">>,
            <<"qualification_digest">> => ?QUALIFICATION,
            <<"registration_digest">> => maps:get(<<"registration_digest">>, Qualification),
            <<"token_report_digest">> => maps:get(<<"token_report_digest">>, Qualification),
            <<"protocol_oracle_digest">> => maps:get(<<"protocol_oracle_digest">>, Qualification),
            <<"schedule_digest">> => maps:get(<<"schedule_digest">>, Qualification),
            <<"replay">> => Replay,
            <<"mutation">> => Mutation,
            <<"residency">> => Residency,
            <<"hosted_calls_observed">> => 0,
            <<"efficacy_observations">> => 0,
            <<"network_authorized">> => false,
            <<"model_fidelity_claim">> => false
        },
        {ok, Body#{<<"evidence_digest">> => alang_fidelity_json:digest(Body)}}
    catch
        error:{badmatch, Reason} -> {error, {mnemonic_phase2_evidence_error, {badmatch, Reason}}};
        throw:{mnemonic_phase2_evidence_error, Reason} ->
            {error, {mnemonic_phase2_evidence_error, Reason}}
    end.

replay(Root) ->
    Development = development_oracles(Root), Prior = prior_oracles(Root),
    Fresh = fresh_oracles(Root), Generated = generated_oracles(Fresh),
    Oracles = Development ++ Prior ++ Fresh ++ Generated,
    Records = [begin
        {ok, Pair} = checked(alang_mnemonic_candidate:compare(Oracle, Root)),
        P0 = maps:get(<<"p0">>, Pair), P1 = maps:get(<<"p1">>, Pair),
        #{<<"semantic_digest">> => maps:get(<<"semantic_digest">>, Pair),
            <<"p0_sha256">> => maps:get(representation_sha256, P0),
            <<"p1_sha256">> => maps:get(representation_sha256, P1),
            <<"p0_map_digest">> => alang_fidelity_json:digest(maps:get(source_map, P0)),
            <<"p1_map_digest">> => alang_fidelity_json:digest(maps:get(source_map, P1)),
            <<"p1_r2_byte_equal">> => maps:get(<<"p1_r2_byte_equal">>, Pair)}
    end || Oracle <- Oracles],
    Invalid = invalid_conformance(hd(Fresh), Root),
    #{<<"development_cases">> => length(Development),
        <<"prior_confirmatory_cases">> => length(Prior),
        <<"fresh_cases">> => length(Fresh), <<"generated_cases">> => length(Generated),
        <<"valid_pair_count">> => length(Records),
        <<"source_map_count">> => length(Records) * 2,
        <<"invalid_conformance_inputs">> => length(Invalid),
        <<"invalid_acceptance_classes_equal">> => lists:all(fun(X) -> X end, Invalid),
        <<"replay_digest">> => alang_fidelity_json:digest(Records)}.

invalid_conformance(Oracle, Root) ->
    {ok, P1} = alang_mnemonic_candidate:render(<<"P1">>, Oracle, Root), Bytes = maps:get(bytes, P1),
    Inputs = [Bytes, binary:replace(Bytes, <<"cap{">>, <<"at{">>),
        binary:replace(Bytes, <<"~s=">>, <<"~zz=">>),
        <<"#!alang-source-v2-alias-v1\ntask broken{wat[]}">>,
        <<16#ff, 16#fe>>, binary:copy(<<"x">>, 32769)],
    [classify(alang_mnemonic_candidate:decode(<<"P1">>, Input, Root)) =:=
        classify(alang_compact_surface:decode(<<"R2">>,
            <<"alang-source-v2-alias-v1">>, Input)) || Input <- Inputs].

development_oracles(Root) ->
    Directory = filename:join([Root, "assets", "effectful-source-fidelity", "corpus"]),
    Manifest = decode(filename:join(Directory, "corpus-manifest-v1.json")),
    [begin
        Control = decode(filename:join(Directory,
            binary_to_list(maps:get(<<"path">>, maps:get(<<"control">>, Case))))),
        {ok, Decoded} = alang_fidelity_representation:validate_control(Control),
        (maps:get(<<"semantic">>, Decoded))#{
            <<"format">> => <<"alang_task_comprehension_v1">>,
            <<"case_id">> => maps:get(<<"case_id">>, Control)}
    end || Case <- maps:get(<<"cases">>, Manifest)].

prior_oracles(Root) ->
    Corpus = decode(filename:join([Root, "assets", "compact-projection-fidelity",
        "corpus", "confirmatory-corpus-v1.json"])),
    [alang_compact_corpus:oracle(Case) || Case <- maps:get(<<"cases">>, Corpus)].
fresh_oracles(Root) ->
    Corpus = decode(filename:join([Root, "assets", "token-positive-mnemonic-promotion",
        "corpus", "confirmatory-corpus-v1.json"])),
    [alang_mnemonic_corpus:oracle(Case) || Case <- maps:get(<<"cases">>, Corpus)].
generated_oracles(Fresh) -> [Oracle#{<<"case_id">> :=
    <<"tp-generated-", (integer_to_binary(I))/binary>>} ||
    {Oracle, I} <- lists:zip(lists:sublist(Fresh, 16), lists:seq(1, 16))].

-spec write(file:filename(), file:filename()) -> {ok, map()} | {error, term()}.
write(Root, Output) ->
    try
        Absolute = filename:absname(Output),
        Owned = filename:join([root_abs(Root), "build", "token-positive-mnemonic-promotion",
            "phase-02"]),
        ensure(lists:prefix(Owned ++ "/", Absolute), {output_outside_owned_root, Output}),
        {ok, Evidence} = checked(build(Root)),
        {ok, Bytes} = alang_fidelity_json:encode_canonical(Evidence),
        ok = filelib:ensure_dir(Absolute), ok = file:write_file(Absolute, [Bytes, <<"\n">>]),
        {ok, Evidence}
    catch
        throw:{mnemonic_phase2_evidence_error, Reason} ->
            {error, {mnemonic_phase2_evidence_error, Reason}};
        Class:Reason -> {error, {mnemonic_phase2_evidence_write_error, Class, Reason}}
    end.

root_abs(Root) -> filename:dirname(filename:absname(filename:join(Root, ".repo-root-marker"))).
classify({ok, _}) -> ok;
classify({error, _}) -> error.
decode(Path) -> {ok, Value} = checked(alang_fidelity_json:decode_file(Path)), Value.
checked({ok, _} = Result) -> Result;
checked({error, Reason}) -> fail(Reason).
exact(Value, Expected, _Reason) when Value =:= Expected -> ok;
exact(Value, Expected, Reason) -> fail({expected, Reason, Expected, Value}).
ensure(true, _Reason) -> ok;
ensure(false, Reason) -> fail(Reason).
fail(Reason) -> throw({mnemonic_phase2_evidence_error, Reason}).
