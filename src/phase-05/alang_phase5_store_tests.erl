-module(alang_phase5_store_tests).

-include_lib("eunit/include/eunit.hrl").

commit_read_restart_and_duplicate_ack_test() ->
    with_store(fun(Root, Store) ->
        {Record, _Journal} = creation_record(),
        {ok, Ack} = alang_phase5_store:append(Store, Record, deadline()),
        ?assertEqual(committed, maps:get(status, Ack)),
        {ok, DuplicateAck} = alang_phase5_store:append(Store, Record, deadline()),
        ?assertEqual(duplicate, maps:get(status, DuplicateAck)),
        {ok, Snapshot} = alang_phase5_store:read(Store, deadline()),
        ?assertEqual([Record], maps:get(records, Snapshot)),
        ok = alang_phase5_store:stop(Store),
        {ok, Restarted} = alang_phase5_store:start_link(options(Root)),
        {ok, RestartedSnapshot} = alang_phase5_store:read(Restarted, deadline()),
        ?assertEqual([Record], maps:get(records, RestartedSnapshot)),
        ok = alang_phase5_store:stop(Restarted)
    end).

conditional_sequence_and_conflict_test() ->
    with_store(fun(_Root, Store) ->
        {Record, Journal} = creation_record(),
        {ok, _Ack} = alang_phase5_store:append(Store, Record, deadline()),
        {ok, Conflicting, _} = alang_phase5_journal:append(
            element(2, alang_phase5_journal:new(<<"store-session">>)),
            session_created,
            1,
            #{state_digest => digest($f), artifact_digest => digest($b)},
            1
        ),
        ?assertEqual(
            {error, {sequence_conflict, 0}},
            alang_phase5_store:append(Store, Conflicting, deadline())
        ),
        {ok, Future, _} = alang_phase5_journal:append(
            Journal,
            observation,
            1,
            #{observation_digest => digest($c)},
            2
        ),
        TooFar = Future#{sequence := 3},
        ?assertEqual(
            {error, {sequence_conflict, 1, 3}},
            alang_phase5_store:append(Store, TooFar, deadline())
        )
    end).

checkpoint_publication_is_read_after_commit_and_restart_safe_test() ->
    with_store(fun(Root, Store) ->
        {Record, _Journal} = creation_record(),
        {ok, _} = alang_phase5_store:append(Store, Record, deadline()),
        State = session_state(),
        {ok, Ack} = alang_phase5_store:checkpoint(Store, State, 1, deadline()),
        ?assertEqual(ok, alang_phase5_state:accept_gate(State, Ack)),
        {ok, Snapshot} = alang_phase5_store:read(Store, deadline()),
        #{state := State} = maps:get(checkpoint, Snapshot),
        ok = alang_phase5_store:stop(Store),
        {ok, Restarted} = alang_phase5_store:start_link(options(Root)),
        {ok, RestartedSnapshot} = alang_phase5_store:read(Restarted, deadline()),
        #{state := State} = maps:get(checkpoint, RestartedSnapshot),
        ok = alang_phase5_store:stop(Restarted)
    end).

limits_deadlines_and_unavailability_are_typed_test() ->
    with_store(fun(_Root, Store) ->
        {Record, _Journal} = creation_record(),
        Expired = erlang:monotonic_time(millisecond) - 1,
        ?assertEqual({error, deadline_exceeded}, alang_phase5_store:append(Store, Record, Expired)),
        ok = alang_phase5_store:inject_test_fault(Store, unavailable_once),
        ?assertEqual({error, store_unavailable}, alang_phase5_store:append(Store, Record, deadline())),
        ok = alang_phase5_store:inject_test_fault(Store, timeout_once),
        ?assertEqual({error, store_timeout}, alang_phase5_store:append(Store, Record, deadline())),
        {ok, _} = alang_phase5_store:append(Store, Record, deadline())
    end).

mailbox_admission_returns_backpressure_test() ->
    with_store(fun(_Root, Store) ->
        {Record, _Journal} = creation_record(),
        ok = sys:suspend(Store),
        Parent = self(),
        _Callers = [
            spawn(fun() -> Parent ! {queued_result, alang_phase5_store:append(Store, Record, deadline())} end)
         || _ <- lists:seq(1, 32)
        ],
        ok = wait_for_queue(Store, 32, 200),
        ?assertEqual(
            {error, store_backpressure},
            alang_phase5_store:append(Store, Record, deadline())
        ),
        ok = sys:resume(Store),
        Results = receive_results(32, []),
        ?assertEqual(32, length([Result || {ok, Result} <- Results]))
    end).

corruption_prevents_restart_test() ->
    Root = temp_root(),
    try
        {ok, Store} = alang_phase5_store:start_link(options(Root)),
        {Record, _Journal} = creation_record(),
        {ok, _} = alang_phase5_store:append(Store, Record, deadline()),
        ok = alang_phase5_store:stop(Store),
        RecordPath = filename:join([Root, "records", "00000000000000000000.rec"]),
        ok = file:write_file(RecordPath, <<"corrupt">>),
        ?assertMatch(
            {error, {store_open_failed, {corrupt_record_file, _, invalid_external_term}}},
            alang_phase5_store:start(options(Root))
        )
    after
        remove_tree(Root)
    end.

with_store(Fun) ->
    Root = temp_root(),
    {ok, Store} = alang_phase5_store:start_link(options(Root)),
    try
        Fun(Root, Store)
    after
        safe_stop(Store),
        remove_tree(Root)
    end.

safe_stop(Store) ->
    case is_process_alive(Store) of
        true ->
            try alang_phase5_store:stop(Store) of
                ok -> ok
            catch
                exit:_Reason -> ok
            end;
        false -> ok
    end.

wait_for_queue(_Store, _Minimum, 0) -> {error, queue_did_not_fill};
wait_for_queue(Store, Minimum, Attempts) ->
    case process_info(Store, message_queue_len) of
        {message_queue_len, Length} when Length >= Minimum -> ok;
        _ ->
            timer:sleep(5),
            wait_for_queue(Store, Minimum, Attempts - 1)
    end.

receive_results(0, Acc) -> Acc;
receive_results(Remaining, Acc) ->
    receive
        {queued_result, Result} -> receive_results(Remaining - 1, [Result | Acc])
    after 3000 ->
        erlang:error({missing_store_results, Remaining})
    end.

creation_record() ->
    {ok, Journal0} = alang_phase5_journal:new(<<"store-session">>),
    {ok, Record, Journal1} = alang_phase5_journal:append(
        Journal0,
        session_created,
        1,
        #{state_digest => digest($a), artifact_digest => digest($b)},
        1
    ),
    {Record, Journal1}.

session_state() ->
    {ok, State} = alang_phase5_state:new(#{
        session_id => <<"store-session">>,
        program => #{
            artifact_digest => digest($b),
            module_name => <<"alang_generated_phase5">>,
            abi_version => 1,
            state_schema => 1
        },
        logical_state => <<"ready">>,
        budgets => #{<<"workspace.write">> => 1}
    }),
    State.

options(Root) -> #{root => Root, session_id => <<"store-session">>, test_faults => true}.

deadline() -> erlang:monotonic_time(millisecond) + 2000.

temp_root() ->
    filename:join(
        filename:absname("build/phase-05/store-tests"),
        integer_to_list(erlang:system_time(nanosecond)) ++ "-" ++
            integer_to_list(erlang:unique_integer([monotonic, positive]))
    ).

remove_tree(Path) ->
    case file:list_dir(Path) of
        {ok, Names} ->
            lists:foreach(
                fun(Name) ->
                    Child = filename:join(Path, Name),
                    case filelib:is_dir(Child) of
                        true -> remove_tree(Child);
                        false -> _ = file:delete(Child)
                    end
                end,
                Names
            ),
            _ = file:del_dir(Path),
            ok;
        {error, enoent} -> ok;
        {error, _Reason} -> ok
    end.

digest(Character) -> binary:copy(<<Character>>, 64).
