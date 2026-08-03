-module(alang_phase5_journal_tests).

-include_lib("eunit/include/eunit.hrl").

all_record_kinds_form_valid_chain_test() ->
    SessionId = <<"journal-session">>,
    {ok, TransitionId} = alang_phase5_journal:transition_id(SessionId, 1),
    {ok, OperationId} = alang_phase5_journal:operation_id(SessionId, TransitionId, 0),
    Entries = [
        {session_created, #{state_digest => digest($a), artifact_digest => digest($b)}},
        {observation, #{observation_digest => digest($c)}},
        {transition, #{transition_id => TransitionId, state_digest => digest($d)}},
        {effect_intent, #{transition_id => TransitionId, operation_id => OperationId,
            operation => <<"workspace.write">>, payload_digest => digest($e)}},
        {authorization, #{operation_id => OperationId, decision => allowed,
            decision_digest => digest($f)}},
        {submission, #{operation_id => OperationId, adapter_identity => <<"workspace-v1">>,
            payload_digest => digest($e)}},
        {effect_result, #{operation_id => OperationId, outcome => succeeded,
            result_digest => digest($1)}},
        {checkpoint, #{state_digest => digest($2)}},
        {cancellation, #{reason_digest => digest($3)}},
        {failure, #{class => recovery, evidence_digest => digest($4)}},
        {completion, #{state_digest => digest($5), evidence_digest => digest($6)}}
    ],
    {ok, Journal0} = alang_phase5_journal:new(SessionId),
    {Journal, Records} = lists:foldl(
        fun({Kind, Payload}, {Current, Acc}) ->
            {ok, Record, Next} = alang_phase5_journal:append(Current, Kind, 1, Payload, 1785760000000),
            {Next, Acc ++ [Record]}
        end,
        {Journal0, []},
        Entries
    ),
    {ok, Validated} = alang_phase5_journal:validate(Records, SessionId),
    ?assertEqual(maps:get(head_digest, Journal), maps:get(head_digest, Validated)),
    ?assertEqual(length(Entries), maps:get(next_sequence, Validated)).

stable_identities_do_not_depend_on_process_identity_test() ->
    {ok, Transition1} = alang_phase5_journal:transition_id(<<"s">>, 7),
    {ok, Transition2} = alang_phase5_journal:transition_id(<<"s">>, 7),
    {ok, Operation1} = alang_phase5_journal:operation_id(<<"s">>, Transition1, 2),
    {ok, Operation2} = alang_phase5_journal:operation_id(<<"s">>, Transition2, 2),
    ?assertEqual(Transition1, Transition2),
    ?assertEqual(Operation1, Operation2),
    ?assertNotEqual(Operation1, element(2, alang_phase5_journal:operation_id(<<"s">>, Transition1, 3))).

integrity_failures_are_classified_test() ->
    {Records, SessionId} = two_records(),
    [First, Second] = Records,
    ?assertMatch(
        {error, {sequence_gap, 1, 4}},
        alang_phase5_journal:validate([First, Second#{sequence := 4}], SessionId)
    ),
    ?assertMatch(
        {error, {previous_digest_mismatch, 1}},
        alang_phase5_journal:validate([First, Second#{previous_digest := digest($f)}], SessionId)
    ),
    Payload = maps:get(payload, Second),
    ?assertMatch(
        {error, {record_digest_mismatch, 1}},
        alang_phase5_journal:validate([First, Second#{payload := Payload#{observation_digest := digest($e)}}], SessionId)
    ).

unknown_record_kind_is_rejected_test() ->
    {ok, Journal} = alang_phase5_journal:new(<<"s">>),
    ?assertEqual(
        {error, invalid_journal_record_input},
        alang_phase5_journal:append(Journal, invented, 1, #{}, 1)
    ).

two_records() ->
    SessionId = <<"integrity-session">>,
    {ok, Journal0} = alang_phase5_journal:new(SessionId),
    {ok, First, Journal1} = alang_phase5_journal:append(
        Journal0,
        session_created,
        1,
        #{state_digest => digest($a), artifact_digest => digest($b)},
        1
    ),
    {ok, Second, _Journal2} = alang_phase5_journal:append(
        Journal1,
        observation,
        1,
        #{observation_digest => digest($c)},
        2
    ),
    {[First, Second], SessionId}.

digest(Character) -> binary:copy(<<Character>>, 64).
