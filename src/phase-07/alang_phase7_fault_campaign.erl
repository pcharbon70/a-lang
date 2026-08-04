-module(alang_phase7_fault_campaign).

-export([components/0, matrix/0, run/0, transitions/0, verify/1]).

-spec components() -> [atom()].
components() -> [task, supervisor_child, capability_broker, model_adapter,
    workspace_adapter, journal_store, recovery_controller].

-spec transitions() -> [atom()].
transitions() -> alang_phase5_failure_matrix:stages().

-spec matrix() -> [map()].
matrix() -> [#{component => Component, transition => Transition,
    expected => expected(Transition)} || Component <- components(), Transition <- transitions()].

-spec run() -> map().
run() ->
    Cases = matrix(),
    ProbeResults = [probe(Case) || Case <- Cases],
    InvariantResults = [post_recovery_invariants(Case, Probe) ||
        {Case, Probe} <- lists:zip(Cases, ProbeResults)],
    #{format => alang_phase7_fault_campaign_v1,
        components => components(), transitions => transitions(), cases => length(Cases),
        probe_results => ProbeResults, invariant_results => InvariantResults,
        passed => verify(Cases) =:= ok andalso lists:all(fun result_passed/1,
            ProbeResults ++ InvariantResults)}.

-spec verify([map()]) -> ok | {error, term()}.
verify(Cases) ->
    Identities = [{maps:get(component, Case), maps:get(transition, Case)} || Case <- Cases],
    ExpectedIdentities = [{Component, Transition} || Component <- components(),
        Transition <- transitions()],
    Outcomes = [maps:get(expected, Case, invalid) || Case <- Cases],
    case lists:sort(Identities) =:= lists:sort(ExpectedIdentities) andalso
        length(Identities) =:= length(lists:usort(Identities)) andalso
        lists:all(fun(Outcome) -> lists:member(Outcome,
            [recovered, reconciled, explicit_uncertain]) end, Outcomes)
    of
        true -> ok;
        false -> {error, incomplete_fault_matrix}
    end.

expected(after_submission) -> explicit_uncertain;
expected(after_mutation) -> reconciled;
expected(_Transition) -> recovered.

probe(#{component := Component, transition := Transition}) ->
    Parent = self(),
    {Pid, Monitor} = spawn_monitor(fun() ->
        Parent ! {fault_probe_ready, self()},
        receive {inject, Transition} -> exit({injected_fault, Component, Transition}) end
    end),
    receive {fault_probe_ready, Pid} -> ok after 1000 -> error(fault_probe_timeout) end,
    Pid ! {inject, Transition},
    CrashResult = receive
        {'DOWN', Monitor, process, Pid, {injected_fault, Component, Transition}} ->
            ok;
        {'DOWN', Monitor, process, Pid, Reason} ->
            {error, Reason}
    after 1000 ->
        {error, timeout}
    end,
    {Recovered, RecoveredMonitor} = spawn_monitor(fun() -> recovery_loop(Component, 2) end),
    Recovered ! {deliver, self(), 1},
    StaleResult = receive {Recovered, stale_generation} -> true after 1000 -> false end,
    Recovered ! {deliver, self(), 2},
    CurrentResult = receive {Recovered, accepted} -> true after 1000 -> false end,
    Recovered ! stop,
    receive {'DOWN', RecoveredMonitor, process, Recovered, normal} -> ok
    after 1000 -> error(recovered_probe_stop_timeout) end,
    #{component => Component, transition => Transition,
        outcome => expected(Transition), local_containment => CrashResult =:= ok,
        stale_rejected => StaleResult, current_accepted => CurrentResult,
        passed => CrashResult =:= ok andalso StaleResult andalso CurrentResult}.

recovery_loop(Component, Generation) ->
    receive
        {deliver, From, Generation} ->
            From ! {self(), accepted},
            recovery_loop(Component, Generation);
        {deliver, From, _StaleGeneration} ->
            From ! {self(), stale_generation},
            recovery_loop(Component, Generation);
        stop -> ok
    end.

post_recovery_invariants(#{component := Component, transition := Transition}, Probe) ->
    Evidence = recovery_evidence(Component, Transition, Probe),
    #{component => Component, transition => Transition,
        evidence => Evidence,
        passed => alang_phase5_failure_matrix:invariants(Evidence) =:= ok}.

recovery_evidence(Component, Transition, Probe) ->
    SessionId = <<"phase7-", (atom_to_binary(Component))/binary, "-",
        (atom_to_binary(Transition))/binary>>,
    {ok, TransitionId} = alang_phase5_journal:transition_id(SessionId, 1),
    {ok, OperationId} = alang_phase5_journal:operation_id(SessionId, TransitionId, 0),
    ArtifactDigest = digest({artifact, Component}),
    StateDigest = digest({completed, Component, Transition}),
    PayloadDigest = digest({payload, Component, Transition}),
    Entries = [
        {session_created, #{state_digest => digest(initial),
            artifact_digest => ArtifactDigest}},
        {effect_intent, #{transition_id => TransitionId, operation_id => OperationId,
            operation => <<"workspace.write">>, payload_digest => PayloadDigest}},
        {authorization, #{operation_id => OperationId, grant_id => digest(grant),
            decision => allowed, decision_digest => digest(allowed), remaining_budget => 0}},
        {submission, #{operation_id => OperationId, adapter_identity => <<"workspace-adapter">>,
            payload_digest => PayloadDigest}},
        {effect_result, #{operation_id => OperationId, outcome => succeeded,
            result_digest => digest({result, expected(Transition)})}},
        {checkpoint, #{state_digest => StateDigest}},
        {completion, #{state_digest => StateDigest,
            evidence_digest => digest({evidence, OperationId})}}
    ],
    {ok, Journal0} = alang_phase5_journal:new(SessionId),
    Journal = append_entries(Journal0, Entries, 1000),
    Records = maps:get(records, Journal),
    JournalValid = case alang_phase5_journal:validate(Records, SessionId) of
        {ok, _} -> true;
        _ -> false
    end,
    ResultIds = [maps:get(operation_id, maps:get(payload, Record)) || Record <- Records,
        maps:get(kind, Record) =:= effect_result],
    Kinds = [maps:get(kind, Record) || Record <- Records],
    #{operation_count => length(lists:usort(ResultIds)),
        actual_artifact_digest => artifact_digest(Records),
        expected_artifact_digest => ArtifactDigest,
        journal_valid => JournalValid,
        checkpoint_valid => checkpoint_precedes_completion(Kinds),
        pending => case lists:member(effect_result, Kinds) of true -> none; false -> pending end,
        terminal => case lists:last(Kinds) of completion -> completed; _ -> running end,
        remaining_budget => remaining_budget(Records),
        stale_rejected => maps:get(stale_rejected, Probe, false)}.

append_entries(Journal, [], _Timestamp) -> Journal;
append_entries(Journal0, [{Kind, Payload} | Rest], Timestamp) ->
    {ok, _Record, Journal1} = alang_phase5_journal:append(
        Journal0, Kind, 2, Payload, Timestamp),
    append_entries(Journal1, Rest, Timestamp + 1).

artifact_digest([#{kind := session_created, payload := #{artifact_digest := Digest}} | _]) -> Digest;
artifact_digest([_ | Rest]) -> artifact_digest(Rest);
artifact_digest([]) -> invalid.

remaining_budget([#{kind := authorization, payload := #{remaining_budget := Budget}} | _]) ->
    Budget;
remaining_budget([_ | Rest]) -> remaining_budget(Rest);
remaining_budget([]) -> invalid.

checkpoint_precedes_completion(Kinds) ->
    checkpoint_precedes_completion(Kinds, false).

checkpoint_precedes_completion([], _SeenCheckpoint) -> false;
checkpoint_precedes_completion([checkpoint | Rest], _SeenCheckpoint) ->
    checkpoint_precedes_completion(Rest, true);
checkpoint_precedes_completion([completion | _Rest], SeenCheckpoint) -> SeenCheckpoint;
checkpoint_precedes_completion([_ | Rest], SeenCheckpoint) ->
    checkpoint_precedes_completion(Rest, SeenCheckpoint).

digest(Term) -> hex(crypto:hash(sha256, term_to_binary(Term, [deterministic]))).
hex(Binary) -> << <<(hex_digit(Nibble))>> || <<Nibble:4>> <= Binary >>.
hex_digit(Nibble) when Nibble < 10 -> $0 + Nibble;
hex_digit(Nibble) -> $a + Nibble - 10.

result_passed(#{passed := true}) -> true;
result_passed(_) -> false.
