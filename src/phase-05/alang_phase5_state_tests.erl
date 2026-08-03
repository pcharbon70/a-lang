-module(alang_phase5_state_tests).

-include_lib("eunit/include/eunit.hrl").

durable_state_round_trip_test() ->
    State = state(),
    ?assertEqual(ok, alang_phase5_state:validate(State)),
    {ok, Encoded} = alang_phase5_state:durable_encoding(State),
    Decoded = binary_to_term(Encoded, [safe]),
    ?assertEqual(State, Decoded),
    ?assertMatch({ok, <<_:64/binary>>}, alang_phase5_state:checkpoint_digest(State)).

ephemeral_runtime_terms_are_rejected_recursively_test() ->
    Ephemeral = [
        self(),
        make_ref(),
        fun() -> ok end,
        hd(erlang:ports())
    ],
    lists:foreach(
        fun(Value) ->
            Candidate = (state())#{logical_state := #{<<"nested">> => [Value]}},
            ?assertEqual({error, invalid_state_value}, alang_phase5_state:validate(Candidate))
        end,
        Ephemeral
    ),
    Improper = (state())#{logical_state := [<<"one">> | <<"two">>]},
    ?assertEqual({error, invalid_state_value}, alang_phase5_state:validate(Improper)).

source_controlled_atoms_are_rejected_test() ->
    Candidate = (state())#{logical_state := source_controlled_atom},
    ?assertEqual({error, invalid_state_value}, alang_phase5_state:validate(Candidate)).

unknown_versions_and_artifacts_fail_closed_test() ->
    State = state(),
    Program = maps:get(program, State),
    UnknownSchema = State#{state_schema := 99},
    ?assertMatch(
        {error, {recovery_rejected, invalid_state_value, _}},
        alang_phase5_state:load(UnknownSchema, expected())
    ),
    ?assertMatch(
        {error, {recovery_rejected, {incompatible, artifact_digest}, _}},
        alang_phase5_state:load(State, (expected())#{artifact_digest := digest($b)})
    ),
    ?assertMatch(
        {error, {recovery_rejected, {incompatible, module_name}, _}},
        alang_phase5_state:load(State, (expected())#{module_name := <<"other">>})
    ),
    IncompatibleAbi = State#{program := Program#{abi_version := 2}},
    ?assertMatch(
        {error, {recovery_rejected, invalid_state_value, _}},
        alang_phase5_state:load(IncompatibleAbi, expected())
    ).

pre_effect_checkpoint_gate_test() ->
    State = state(),
    ?assertEqual({error, checkpoint_not_durable}, alang_phase5_state:accept_gate(State, #{})),
    {ok, InitialAck} = alang_phase5_state:checkpoint_ack(State, 0),
    ?assertEqual(ok, alang_phase5_state:accept_gate(State, InitialAck)),
    {ok, IntentState} = alang_phase5_state:begin_effect(State, intent()),
    ?assertEqual({error, unresolved_effect}, alang_phase5_state:accept_gate(IntentState, InitialAck)),
    ?assertEqual(
        {error, checkpoint_not_durable},
        alang_phase5_state:dispatch_gate(IntentState, InitialAck)
    ),
    {ok, IntentAck} = alang_phase5_state:checkpoint_ack(IntentState, 1),
    ?assertEqual(ok, alang_phase5_state:dispatch_gate(IntentState, IntentAck)),
    ?assertEqual({error, checkpoint_not_durable}, alang_phase5_state:accept_gate(State, IntentAck)),
    ?assertEqual(intent, maps:get(stage, maps:get(pending, IntentState))).

post_effect_result_precedes_state_advance_test() ->
    {ok, IntentState} = alang_phase5_state:begin_effect(state(), intent()),
    {ok, Authorized} = alang_phase5_state:mark_effect(IntentState, <<"op-1">>, authorized, undefined),
    {ok, Submitted} = alang_phase5_state:mark_effect(Authorized, <<"op-1">>, submitted, <<"workspace-v1">>),
    ?assertEqual(
        {error, result_not_durable},
        alang_phase5_state:advance_effect(Submitted, #{}, done, #{<<"workspace.write">> => 0})
    ),
    {ok, Ack} = alang_phase5_state:result_ack(Submitted, digest($c), digest($d)),
    {ok, Advanced} = alang_phase5_state:advance_effect(
        Submitted,
        Ack,
        <<"done">>,
        #{<<"workspace.write">> => 0}
    ),
    ?assertEqual(none, maps:get(pending, Advanced)),
    ?assertEqual(<<"done">>, maps:get(logical_state, Advanced)),
    ?assertEqual([digest($c)], maps:get(evidence, Advanced)).

invalid_effect_order_and_identity_are_rejected_test() ->
    {ok, IntentState} = alang_phase5_state:begin_effect(state(), intent()),
    ?assertEqual(
        {error, invalid_effect_transition},
        alang_phase5_state:mark_effect(IntentState, <<"op-1">>, submitted, <<"adapter">>)
    ),
    ?assertEqual(
        {error, operation_identity_mismatch},
        alang_phase5_state:mark_effect(IntentState, <<"op-2">>, authorized, undefined)
    ),
    ?assertEqual({error, unresolved_effect}, alang_phase5_state:begin_effect(IntentState, intent())).

terminal_completion_requires_evidence_and_durable_checkpoint_test() ->
    State = state(),
    ?assertEqual({error, completion_evidence_required}, alang_phase5_state:complete(State, [])),
    {ok, Completed} = alang_phase5_state:complete(State, [digest($e)]),
    ?assertEqual({error, checkpoint_not_durable}, alang_phase5_state:completion_gate(Completed, #{})),
    {ok, CompletionAck} = alang_phase5_state:checkpoint_ack(Completed, 4),
    ?assertEqual(ok, alang_phase5_state:completion_gate(Completed, CompletionAck)),
    ?assertEqual({error, session_not_running}, alang_phase5_state:begin_effect(Completed, intent())),
    {ok, Pending} = alang_phase5_state:begin_effect(State, intent()),
    ?assertEqual({error, unresolved_effect}, alang_phase5_state:complete(Pending, [digest($f)])).

pause_retains_pending_intent_and_evidence_test() ->
    {ok, IntentState} = alang_phase5_state:begin_effect(state(), intent()),
    {ok, Paused} = alang_phase5_state:pause(IntentState, digest($a)),
    ?assertEqual(paused, maps:get(terminal, Paused)),
    ?assert(is_map(maps:get(pending, Paused))),
    ?assertEqual([digest($a)], maps:get(evidence, Paused)).

state() ->
    {ok, State} = alang_phase5_state:new(#{
        session_id => <<"session-5">>,
        program => #{
            artifact_digest => digest($a),
            module_name => <<"alang_generated_phase5">>,
            abi_version => 1,
            state_schema => 1
        },
        logical_state => #{<<"step">> => 0, <<"value">> => {ok, <<"ready">>}},
        observations => [#{<<"kind">> => <<"input">>, <<"value">> => <<"start">>}],
        budgets => #{<<"workspace.write">> => 1},
        deadline => 2000000000000
    }),
    State.

expected() -> #{
    state_schema => 1,
    abi_version => 1,
    artifact_digest => digest($a),
    module_name => <<"alang_generated_phase5">>
}.

intent() -> #{
    operation_id => <<"op-1">>,
    transition_id => <<"transition-1">>,
    operation => <<"workspace.write">>,
    payload_digest => digest($b)
}.

digest(Character) -> binary:copy(<<Character>>, 64).
