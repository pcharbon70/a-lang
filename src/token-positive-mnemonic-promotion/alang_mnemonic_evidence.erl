-module(alang_mnemonic_evidence).

-export([build/4, publish/1, replay_existing/2, validate/1]).

-define(PRIMARY_CELLS, 1536).
-define(PAIRS, 768).

-spec build(map(), map(), map(), map()) -> {ok, map()} | {error, term()}.
build(State, Replay, Mutation, Residency) ->
    try
        Runner = maps:get(runner, State), Journal = maps:get(journal, State),
        Token = maps:get(token, State),
        Body = #{
            <<"format">> => <<"alang-token-positive-phase-3-evidence-v1">>,
            <<"qualification_digest">> => maps:get(<<"qualification_digest">>,
                maps:get(qualification, State)),
            <<"schedule_digest">> => maps:get(schedule_digest, Runner),
            <<"profiles">> => maps:get(<<"profiles">>, Token),
            <<"environment">> => environment(),
            <<"primary_cells">> => maps:get(cursor, Runner),
            <<"all_requests">> => maps:get(calls, Runner),
            <<"replacement_requests">> => maps:size(maps:get(replacements, Runner)),
            <<"compute_ms">> => maps:get(compute_ms, Runner),
            <<"journal_records">> => preclose_count(Journal),
            <<"journal_head_digest">> => preclose_head(Journal),
            <<"journal_path">> =>
                <<"build/token-positive-mnemonic-promotion/phase-03/records">>,
            <<"observation_count">> => length(maps:get(observations, State)),
            <<"replay_digest">> => maps:get(<<"replay_digest">>, Replay),
            <<"usage_digest">> => maps:get(<<"usage_digest">>, Replay),
            <<"score_digest">> => maps:get(<<"score_digest">>, Replay),
            <<"safety_digest">> => maps:get(<<"safety_digest">>, Replay),
            <<"pair_count">> => length(maps:get(<<"pairs">>, Replay)),
            <<"candidate_only_safety_failures">> =>
                maps:get(<<"candidate_only_safety_failures">>, Replay),
            <<"mutation">> => Mutation,
            <<"residency">> => Residency,
            <<"retention_path">> =>
                <<"build/token-positive-mnemonic-promotion/phase-03/evidence">>,
            <<"minimum_retention_days">> => 365,
            <<"excluded">> => [<<"credentials">>, <<"authorization-headers">>,
                <<"provider-internal-traces">>],
            <<"observations_only">> => true,
            <<"decision_applied">> => false,
            <<"complete">> => maps:get(<<"complete">>, Replay)
        },
        Evidence = Body#{<<"evidence_digest">> => alang_fidelity_json:digest(Body)},
        ok = checked(validate(Evidence)), {ok, Evidence}
    catch
        error:{badkey, Key} -> {error, {mnemonic_evidence_error, {missing_field, Key}}};
        throw:{mnemonic_evidence_error, Reason} ->
            {error, {mnemonic_evidence_error, Reason}}
    end.

-spec validate(map()) -> ok | {error, term()}.
validate(Evidence) ->
    try
        Keys = [<<"all_requests">>, <<"candidate_only_safety_failures">>,
            <<"complete">>, <<"compute_ms">>, <<"decision_applied">>,
            <<"environment">>, <<"evidence_digest">>, <<"excluded">>, <<"format">>,
            <<"journal_head_digest">>, <<"journal_path">>, <<"journal_records">>,
            <<"minimum_retention_days">>, <<"mutation">>, <<"observation_count">>,
            <<"observations_only">>, <<"pair_count">>,
            <<"primary_cells">>, <<"profiles">>, <<"qualification_digest">>,
            <<"replacement_requests">>, <<"replay_digest">>, <<"residency">>,
            <<"retention_path">>, <<"safety_digest">>, <<"schedule_digest">>,
            <<"score_digest">>, <<"usage_digest">>],
        ensure(lists:sort(maps:keys(Evidence)) =:= lists:sort(Keys), evidence_fields),
        ensure(maps:get(<<"format">>, Evidence) =:=
            <<"alang-token-positive-phase-3-evidence-v1">>, evidence_format),
        ensure(maps:get(<<"primary_cells">>, Evidence) =:= ?PRIMARY_CELLS,
            primary_cell_count),
        ensure(maps:get(<<"observation_count">>, Evidence) =:= ?PRIMARY_CELLS,
            observation_count),
        ensure(maps:get(<<"pair_count">>, Evidence) =:= ?PAIRS, pair_count),
        ensure(maps:get(<<"all_requests">>, Evidence) >= ?PRIMARY_CELLS andalso
            maps:get(<<"all_requests">>, Evidence) =< 3072, request_count),
        ensure(maps:get(<<"replacement_requests">>, Evidence) =:=
            maps:get(<<"all_requests">>, Evidence) - ?PRIMARY_CELLS,
            replacement_accounting),
        ensure(maps:get(<<"journal_records">>, Evidence) >= ?PRIMARY_CELLS * 2
            andalso maps:get(<<"journal_records">>, Evidence) =< 7680,
            journal_record_count),
        ensure(maps:get(<<"journal_records">>, Evidence) =:=
            ?PRIMARY_CELLS * 2 + maps:get(<<"replacement_requests">>, Evidence) * 3,
            journal_request_accounting),
        ensure(maps:get(<<"compute_ms">>, Evidence) >= 0 andalso
            maps:get(<<"compute_ms">>, Evidence) =< 6400 * 60000, compute_ceiling),
        ensure(length(maps:get(<<"profiles">>, Evidence)) =:= 2, profile_count),
        ensure(maps:get(<<"minimum_retention_days">>, Evidence) =:= 365,
            retention_period),
        ensure(maps:get(<<"retention_path">>, Evidence) =:=
            <<"build/token-positive-mnemonic-promotion/phase-03/evidence">>
            andalso maps:get(<<"journal_path">>, Evidence) =:=
            <<"build/token-positive-mnemonic-promotion/phase-03/records">>,
            retention_paths),
        ensure(maps:get(<<"complete">>, Evidence) =:= true, incomplete_replay),
        ensure(maps:get(<<"observations_only">>, Evidence) =:= true andalso
            maps:get(<<"decision_applied">>, Evidence) =:= false, decision_boundary),
        Mutation = maps:get(<<"mutation">>, Evidence),
        ensure(maps:get(<<"all_detected">>, Mutation) =:= true andalso
            maps:get(<<"detected">>, Mutation) =:= 21 andalso
            maps:get(<<"total">>, Mutation) =:= 21,
            mutation_evidence),
        Residency = maps:get(<<"residency">>, Evidence),
        ensure(maps:get(<<"engine">>, Residency) =:= <<"ERTS">> andalso
            maps:get(<<"module_count">>, Residency) =:= 12 andalso
            maps:get(<<"foreign_source_count">>, Residency) =:= 0 andalso
            maps:get(<<"forbidden_import_count">>, Residency) =:= 0,
            residency_evidence),
        Digest = maps:get(<<"evidence_digest">>, Evidence),
        ensure(valid_digest(Digest), evidence_digest),
        ensure(lists:all(fun(Key) -> valid_digest(maps:get(Key, Evidence)) end,
            [<<"qualification_digest">>, <<"schedule_digest">>,
             <<"journal_head_digest">>, <<"replay_digest">>, <<"usage_digest">>,
             <<"score_digest">>, <<"safety_digest">>]), evidence_digests),
        ensure(Digest =:= alang_fidelity_json:digest(
            maps:remove(<<"evidence_digest">>, Evidence)), evidence_digest_mismatch), ok
    catch
        error:{badkey, Key} -> {error, {mnemonic_evidence_error, {missing_field, Key}}};
        throw:{mnemonic_evidence_error, Reason} ->
            {error, {mnemonic_evidence_error, Reason}}
    end.

-spec publish(map()) -> {ok, map(), map()} | {error, term()}.
publish(State) ->
    try
        Runner = maps:get(runner, State),
        ensure(maps:get(invalid, Runner) =:= false, invalid_campaign),
        ensure(maps:get(pending, Runner) =:= none, submission_pending),
        ensure(maps:get(cursor, Runner) =:= length(maps:get(cells, Runner)),
            incomplete_campaign),
        {ok, Replay} = checked(alang_mnemonic_replay:build(
            maps:get(observations, State), maps:get(cells, Runner))),
        {ok, Mutation} = checked(alang_mnemonic_phase3_mutation:run(maps:get(root, State))),
        {ok, Residency} = checked(alang_mnemonic_phase3_residency:audit(maps:get(root, State))),
        {ok, Evidence} = checked(build(State, Replay, Mutation, Residency)),
        {ok, Closed} = checked(close_journal(State, Evidence)),
        ok = checked(write_bundle(Closed, Replay, Evidence)),
        {ok, Evidence, Closed}
    catch throw:{mnemonic_evidence_error, Reason} ->
        {error, {mnemonic_evidence_error, Reason}}
    end.

-spec replay_existing(file:filename(), file:filename()) -> {ok, map()} | {error, term()}.
replay_existing(Root, RunRoot) ->
    try
        {ok, Qualification} = checked(alang_mnemonic_qualification:build(Root)),
        {ok, Journal} = checked(alang_mnemonic_journal:load(
            RunRoot, maps:get(<<"qualification_digest">>, Qualification))),
        {ok, Schedule} = checked(alang_mnemonic_schedule:materialize(filename:join(
            Root, "assets/token-positive-mnemonic-promotion/campaign"))),
        Cells = maps:get(<<"cells">>, Schedule),
        {ok, Observations} = checked(alang_mnemonic_replay:from_records(
            maps:get(records, Journal), Root)),
        {ok, Replay} = checked(alang_mnemonic_replay:build(Observations, Cells)),
        ok = checked(compare_file(filename:join([RunRoot, "evidence",
            "observations-v1.json"]), Observations)),
        ok = checked(compare_file(filename:join([RunRoot, "evidence",
            "replay-v1.json"]), Replay)),
        {ok, #{<<"format">> => <<"alang-token-positive-phase-3-reproduction-v1">>,
            <<"observation_digest">> => maps:get(<<"observation_digest">>, Replay),
            <<"replay_digest">> => maps:get(<<"replay_digest">>, Replay),
            <<"observations">> => length(Observations), <<"byte_identical">> => true}}
    catch throw:{mnemonic_evidence_error, Reason} ->
        {error, {mnemonic_evidence_error, Reason}}
    end.

close_journal(State, Evidence) ->
    Journal = maps:get(journal, State),
    Closures = [R || R <- maps:get(records, Journal), maps:get(kind, R) =:= campaign_closed],
    case Closures of
        [] ->
            Payload = #{calls => maps:get(calls, maps:get(runner, State)),
                evidence_digest => maps:get(<<"evidence_digest">>, Evidence), valid => true},
            case alang_mnemonic_journal:append_file(maps:get(run_root, State),
                    Journal, campaign_closed, Payload) of
                {ok, _Record, Updated} -> {ok, State#{journal := Updated}};
                {error, Reason} -> {error, Reason}
            end;
        [Record] ->
            Payload = maps:get(payload, Record),
            ensure(maps:get(evidence_digest, Payload) =:=
                maps:get(<<"evidence_digest">>, Evidence), closure_digest),
            {ok, State};
        _ -> fail(duplicate_campaign_closure)
    end.

write_bundle(State, Replay, Evidence) ->
    Directory = filename:join(maps:get(run_root, State), "evidence"),
    ok = checked(write_once(filename:join(Directory, "observations-v1.json"),
        maps:get(observations, State))),
    ok = checked(write_once(filename:join(Directory, "replay-v1.json"), Replay)),
    write_once(filename:join(Directory, "phase-3-evidence-v1.json"), Evidence).

write_once(Path, Value) ->
    {ok, Bytes} = checked(alang_fidelity_json:encode_canonical(Value)),
    ok = filelib:ensure_dir(Path),
    case file:write_file(Path, Bytes, [raw, binary, exclusive, sync]) of
        ok -> ok;
        {error, eexist} ->
            case file:read_file(Path) of
                {ok, Bytes} -> ok;
                {ok, _} -> {error, retained_evidence_mismatch};
                {error, Reason} -> {error, {evidence_read_failed, Reason}}
            end;
        {error, Reason} -> {error, {evidence_write_failed, Reason}}
    end.

compare_file(Path, Value) ->
    {ok, Expected} = checked(alang_fidelity_json:encode_canonical(Value)),
    case file:read_file(Path) of
        {ok, Expected} -> ok;
        {ok, _} -> {error, replay_byte_mismatch};
        {error, Reason} -> {error, {replay_read_failed, Reason}}
    end.

preclose_count(Journal) -> length(preclose_records(Journal)).
preclose_head(Journal) ->
    case preclose_records(Journal) of
        [] -> <<"0000000000000000000000000000000000000000000000000000000000000000">>;
        Records -> maps:get(record_digest, lists:last(Records))
    end.
preclose_records(Journal) -> [R || R <- maps:get(records, Journal),
    maps:get(kind, R) =/= campaign_closed].
environment() -> #{
    <<"erts_version">> => unicode:characters_to_binary(erlang:system_info(version)),
    <<"otp_release">> => unicode:characters_to_binary(erlang:system_info(otp_release)),
    <<"system_architecture">> =>
        unicode:characters_to_binary(erlang:system_info(system_architecture))}.
checked(ok) -> ok;
checked({ok, _} = Result) -> Result;
checked({error, Reason}) -> fail(Reason).
ensure(true, _Reason) -> ok;
ensure(false, Reason) -> fail(Reason).
fail(Reason) -> throw({mnemonic_evidence_error, Reason}).
valid_digest(Value) when is_binary(Value), byte_size(Value) =:= 64 ->
    re:run(Value, <<"^[0-9a-f]{64}$">>, [{capture, none}]) =:= match;
valid_digest(_) -> false.
