-module(alang_phase5_state).

-export([
    accept_gate/2,
    advance_effect/4,
    begin_effect/2,
    checkpoint_ack/2,
    checkpoint_digest/1,
    complete/2,
    completion_gate/2,
    dispatch_gate/2,
    durable_encoding/1,
    load/2,
    mark_effect/4,
    new/1,
    pause/2,
    result_ack/3,
    validate/1
]).

-define(FORMAT, alang_session_state_v1).
-define(STATE_SCHEMA, 1).
-define(ABI_VERSION, 1).
-define(MAX_STATE_BYTES, 262144).
-define(MAX_DEPTH, 32).
-define(MAX_COLLECTION, 4096).
-define(MAX_ID_BYTES, 128).
-define(MAX_OBSERVATIONS, 1024).
-define(MAX_EVIDENCE, 2048).
-define(MAX_BUDGET, 1000000).

-type state() :: map().
-type error() :: {error, atom()} | {error, tuple()}.

-spec new(map()) -> {ok, state()} | error().
new(Spec) when is_map(Spec) ->
    State = #{
        format => ?FORMAT,
        state_schema => ?STATE_SCHEMA,
        session_id => maps:get(session_id, Spec, undefined),
        generation => maps:get(generation, Spec, 1),
        program => maps:get(program, Spec, undefined),
        logical_state => maps:get(logical_state, Spec, undefined),
        observations => maps:get(observations, Spec, []),
        budgets => maps:get(budgets, Spec, #{}),
        deadline => maps:get(deadline, Spec, infinity),
        pending => maps:get(pending, Spec, none),
        terminal => maps:get(terminal, Spec, running),
        evidence => maps:get(evidence, Spec, []),
        authority => maps:get(authority, Spec, []),
        revocations => maps:get(revocations, Spec, []),
        next_transition => maps:get(next_transition, Spec, 1)
    },
    case validate(State) of
        ok -> {ok, State};
        {error, _} = Error -> Error
    end;
new(_Spec) -> {error, invalid_state_specification}.

-spec validate(term()) -> ok | error().
validate(State) when is_map(State) ->
    case exact_keys(State, state_keys()) of
        true -> validate_fields(State);
        false -> {error, invalid_state_shape}
    end;
validate(_State) -> {error, invalid_state_shape}.

-spec load(term(), map()) -> {ok, state()} | {error, tuple()}.
load(State, Expected) when is_map(Expected) ->
    case validate(State) of
        ok -> check_compatibility(State, Expected);
        {error, Reason} -> recovery_rejected(Reason, State)
    end;
load(State, _Expected) -> recovery_rejected(invalid_expectation, State).

-spec durable_encoding(state()) -> {ok, binary()} | error().
durable_encoding(State) ->
    case validate(State) of
        ok -> {ok, term_to_binary(State, [deterministic])};
        {error, _} = Error -> Error
    end.

-spec checkpoint_digest(state()) -> {ok, binary()} | error().
checkpoint_digest(State) ->
    case durable_encoding(State) of
        {ok, Binary} -> {ok, hex(crypto:hash(sha256, Binary))};
        {error, _} = Error -> Error
    end.

-spec checkpoint_ack(state(), non_neg_integer()) -> {ok, map()} | error().
checkpoint_ack(State, Sequence) when is_integer(Sequence), Sequence >= 0 ->
    case checkpoint_digest(State) of
        {ok, Digest} ->
            {ok, #{
                format => alang_checkpoint_ack_v1,
                session_id => maps:get(session_id, State),
                sequence => Sequence,
                state_digest => Digest
            }};
        {error, _} = Error -> Error
    end;
checkpoint_ack(_State, _Sequence) -> {error, invalid_checkpoint_sequence}.

-spec result_ack(state(), binary(), binary()) -> {ok, map()} | error().
result_ack(#{pending := Pending, session_id := SessionId}, ResultDigest, JournalDigest) when
    is_map(Pending)
->
    case {valid_digest(ResultDigest), valid_digest(JournalDigest)} of
        {true, true} ->
            {ok, #{
                format => alang_result_ack_v1,
                session_id => SessionId,
                operation_id => maps:get(operation_id, Pending),
                transition_id => maps:get(transition_id, Pending),
                result_digest => ResultDigest,
                journal_digest => JournalDigest
            }};
        _ -> {error, invalid_result_ack}
    end;
result_ack(_State, _ResultDigest, _JournalDigest) -> {error, no_pending_effect}.

-spec accept_gate(state(), term()) -> ok | error().
accept_gate(#{terminal := running, pending := none} = State, Ack) ->
    validate_checkpoint_ack(State, Ack);
accept_gate(#{terminal := Terminal}, _Ack) when Terminal =/= running ->
    {error, session_not_running};
accept_gate(_State, _Ack) -> {error, unresolved_effect}.

-spec dispatch_gate(state(), term()) -> ok | error().
dispatch_gate(#{terminal := running, pending := #{stage := intent}} = State, Ack) ->
    validate_checkpoint_ack(State, Ack);
dispatch_gate(#{terminal := Terminal}, _Ack) when Terminal =/= running ->
    {error, session_not_running};
dispatch_gate(_State, _Ack) -> {error, effect_not_ready_for_dispatch}.

-spec begin_effect(state(), map()) -> {ok, state()} | error().
begin_effect(#{terminal := running, pending := none} = State, Intent) when is_map(Intent) ->
    case normalize_intent(Intent) of
        {ok, Pending} ->
            Candidate = State#{
                pending := Pending,
                next_transition := maps:get(next_transition, State) + 1
            },
            checked(Candidate);
        {error, _} = Error -> Error
    end;
begin_effect(#{terminal := Terminal}, _Intent) when Terminal =/= running ->
    {error, session_not_running};
begin_effect(_State, _Intent) -> {error, unresolved_effect}.

-spec mark_effect(state(), binary(), atom(), binary() | undefined) -> {ok, state()} | error().
mark_effect(#{pending := Pending} = State, OperationId, NextStage, AdapterIdentity) when
    is_map(Pending),
    is_binary(OperationId)
->
    case {
        maps:get(operation_id, Pending) =:= OperationId,
        valid_stage_transition(maps:get(stage, Pending), NextStage),
        valid_adapter_identity(NextStage, AdapterIdentity)
    } of
        {false, _, _} -> {error, operation_identity_mismatch};
        {_, false, _} -> {error, invalid_effect_transition};
        {_, _, false} -> {error, invalid_adapter_identity};
        {true, true, true} ->
            checked(State#{pending := Pending#{
                stage := NextStage,
                adapter_identity := AdapterIdentity
            }})
    end;
mark_effect(_State, _OperationId, _NextStage, _AdapterIdentity) ->
    {error, no_pending_effect}.

-spec advance_effect(state(), map(), term(), map()) -> {ok, state()} | error().
advance_effect(#{pending := Pending} = State, Ack, LogicalState, Budgets) when is_map(Pending) ->
    case {result_ack_matches(State, Ack), valid_budgets(Budgets)} of
        {true, true} ->
            ResultDigest = maps:get(result_digest, Ack),
            Candidate = State#{
                logical_state := LogicalState,
                budgets := Budgets,
                pending := none,
                evidence := append_bounded(maps:get(evidence, State), ResultDigest, ?MAX_EVIDENCE)
            },
            checked(Candidate);
        {false, _} -> {error, result_not_durable};
        {_, false} -> {error, invalid_budgets}
    end;
advance_effect(_State, _Ack, _LogicalState, _Budgets) -> {error, no_pending_effect}.

-spec pause(state(), binary()) -> {ok, state()} | error().
pause(#{terminal := running} = State, EvidenceDigest) ->
    case valid_digest(EvidenceDigest) of
        true -> checked(State#{
            terminal := paused,
            evidence := append_bounded(maps:get(evidence, State), EvidenceDigest, ?MAX_EVIDENCE)
        });
        false -> {error, invalid_evidence_digest}
    end;
pause(_State, _EvidenceDigest) -> {error, session_not_running}.

-spec complete(state(), [binary()]) -> {ok, state()} | error().
complete(#{terminal := running, pending := none} = State, Evidence) when is_list(Evidence) ->
    Combined = maps:get(evidence, State) ++ Evidence,
    case valid_evidence(Combined) andalso Combined =/= [] of
        true -> checked(State#{terminal := completed, evidence := Combined});
        false -> {error, completion_evidence_required}
    end;
complete(#{terminal := running}, _Evidence) -> {error, unresolved_effect};
complete(_State, _Evidence) -> {error, session_not_running}.

-spec completion_gate(state(), term()) -> ok | error().
completion_gate(#{terminal := completed, pending := none} = State, Ack) ->
    validate_checkpoint_ack(State, Ack);
completion_gate(#{pending := Pending}, _Ack) when Pending =/= none -> {error, unresolved_effect};
completion_gate(_State, _Ack) -> {error, session_not_completed}.

validate_fields(State) ->
    Checks = [
        maps:get(format, State) =:= ?FORMAT,
        maps:get(state_schema, State) =:= ?STATE_SCHEMA,
        valid_id(maps:get(session_id, State)),
        valid_generation(maps:get(generation, State)),
        valid_program(maps:get(program, State)),
        valid_durable(maps:get(logical_state, State)),
        valid_observations(maps:get(observations, State)),
        valid_budgets(maps:get(budgets, State)),
        valid_deadline(maps:get(deadline, State)),
        valid_pending(maps:get(pending, State)),
        valid_terminal(maps:get(terminal, State)),
        valid_evidence(maps:get(evidence, State)),
        valid_authority(maps:get(authority, State)),
        valid_revocations(maps:get(revocations, State)),
        valid_transition(maps:get(next_transition, State))
    ],
    case lists:all(fun(Boolean) -> Boolean end, Checks) of
        false -> {error, invalid_state_value};
        true -> validate_encoded_size(State)
    end.

validate_encoded_size(State) ->
    try term_to_binary(State, [deterministic]) of
        Binary when byte_size(Binary) =< ?MAX_STATE_BYTES -> ok;
        _Binary -> {error, durable_state_too_large}
    catch
        error:badarg -> {error, invalid_durable_value}
    end.

check_compatibility(State, Expected) ->
    Program = maps:get(program, State),
    Checks = [
        {state_schema, maps:get(state_schema, State), maps:get(state_schema, Expected, ?STATE_SCHEMA)},
        {abi_version, maps:get(abi_version, Program), maps:get(abi_version, Expected, ?ABI_VERSION)},
        {artifact_digest, maps:get(artifact_digest, Program), maps:get(artifact_digest, Expected, undefined)},
        {module_name, maps:get(module_name, Program), maps:get(module_name, Expected, undefined)}
    ],
    case first_mismatch(Checks) of
        none -> {ok, State};
        {Field, Actual, Wanted} ->
            recovery_rejected({incompatible, Field}, #{actual => Actual, expected => Wanted})
    end.

first_mismatch([]) -> none;
first_mismatch([{_Field, Actual, undefined} | Rest]) when Actual =/= undefined -> first_mismatch(Rest);
first_mismatch([{Field, Actual, Expected} | _Rest]) when Actual =/= Expected -> {Field, Actual, Expected};
first_mismatch([_Match | Rest]) -> first_mismatch(Rest).

recovery_rejected(Reason, Evidence) ->
    {error, {recovery_rejected, Reason, bounded_evidence(Evidence)}}.

bounded_evidence(Evidence) when is_map(Evidence) -> maps:with([actual, expected, format, state_schema], Evidence);
bounded_evidence(_Evidence) -> #{}.

normalize_intent(Intent) ->
    Required = [operation_id, transition_id, operation, payload_digest],
    case exact_keys(Intent, Required) andalso
        valid_id(maps:get(operation_id, Intent, undefined)) andalso
        valid_id(maps:get(transition_id, Intent, undefined)) andalso
        valid_id(maps:get(operation, Intent, undefined)) andalso
        valid_digest(maps:get(payload_digest, Intent, undefined))
    of
        true -> {ok, Intent#{stage => intent, adapter_identity => undefined}};
        false -> {error, invalid_effect_intent}
    end.

valid_stage_transition(intent, authorized) -> true;
valid_stage_transition(authorized, submitted) -> true;
valid_stage_transition(submitted, outcome_unknown) -> true;
valid_stage_transition(_, _) -> false.

valid_adapter_identity(intent, undefined) -> true;
valid_adapter_identity(authorized, undefined) -> true;
valid_adapter_identity(submitted, Identity) -> valid_id(Identity);
valid_adapter_identity(outcome_unknown, Identity) -> valid_id(Identity);
valid_adapter_identity(_, _) -> false.

validate_checkpoint_ack(State, Ack) when is_map(Ack) ->
    StateSessionId = maps:get(session_id, State),
    case checkpoint_digest(State) of
        {ok, Digest} ->
            case Ack of
                #{
                    format := alang_checkpoint_ack_v1,
                    session_id := SessionId,
                    sequence := Sequence,
                    state_digest := Digest
                } when SessionId =:= StateSessionId, is_integer(Sequence), Sequence >= 0 -> ok;
                _ -> {error, checkpoint_not_durable}
            end;
        {error, _} = Error -> Error
    end;
validate_checkpoint_ack(_State, _Ack) -> {error, checkpoint_not_durable}.

result_ack_matches(State, Ack) when is_map(Ack) ->
    Pending = maps:get(pending, State),
    lists:member(maps:get(stage, Pending), [submitted, outcome_unknown]) andalso
        maps:get(format, Ack, undefined) =:= alang_result_ack_v1 andalso
        maps:get(session_id, Ack, undefined) =:= maps:get(session_id, State) andalso
        maps:get(operation_id, Ack, undefined) =:= maps:get(operation_id, Pending) andalso
        maps:get(transition_id, Ack, undefined) =:= maps:get(transition_id, Pending) andalso
        valid_digest(maps:get(result_digest, Ack, undefined)) andalso
        valid_digest(maps:get(journal_digest, Ack, undefined));
result_ack_matches(_State, _Ack) -> false.

checked(State) ->
    case validate(State) of
        ok -> {ok, State};
        {error, _} = Error -> Error
    end.

state_keys() -> [
    format, state_schema, session_id, generation, program, logical_state,
    observations, budgets, deadline, pending, terminal, evidence, authority,
    revocations, next_transition
].

valid_program(Program) when is_map(Program) ->
    exact_keys(Program, [artifact_digest, module_name, abi_version, state_schema]) andalso
        valid_digest(maps:get(artifact_digest, Program, undefined)) andalso
        valid_id(maps:get(module_name, Program, undefined)) andalso
        maps:get(abi_version, Program, undefined) =:= ?ABI_VERSION andalso
        maps:get(state_schema, Program, undefined) =:= ?STATE_SCHEMA;
valid_program(_) -> false.

valid_observations(Observations) when is_list(Observations), length(Observations) =< ?MAX_OBSERVATIONS ->
    lists:all(fun valid_durable/1, Observations);
valid_observations(_) -> false.

valid_budgets(Budgets) when is_map(Budgets), map_size(Budgets) =< 64 ->
    maps:fold(
        fun(Key, Value, Acc) ->
            Acc andalso valid_id(Key) andalso is_integer(Value) andalso Value >= 0 andalso Value =< ?MAX_BUDGET
        end,
        true,
        Budgets
    );
valid_budgets(_) -> false.

valid_deadline(infinity) -> true;
valid_deadline(Value) -> is_integer(Value) andalso Value >= 0.

valid_pending(none) -> true;
valid_pending(Pending) when is_map(Pending) ->
    exact_keys(Pending, [operation_id, transition_id, operation, payload_digest, stage, adapter_identity]) andalso
        valid_id(maps:get(operation_id, Pending, undefined)) andalso
        valid_id(maps:get(transition_id, Pending, undefined)) andalso
        valid_id(maps:get(operation, Pending, undefined)) andalso
        valid_digest(maps:get(payload_digest, Pending, undefined)) andalso
        lists:member(maps:get(stage, Pending, invalid), [intent, authorized, submitted, outcome_unknown]) andalso
        valid_adapter_identity(maps:get(stage, Pending, invalid), maps:get(adapter_identity, Pending, invalid));
valid_pending(_) -> false.

valid_terminal(Value) -> lists:member(Value, [running, paused, failed, completed, cancelled]).

valid_evidence(Evidence) when is_list(Evidence), length(Evidence) =< ?MAX_EVIDENCE ->
    lists:all(fun valid_digest/1, Evidence);
valid_evidence(_) -> false.

valid_authority(Authority) when is_list(Authority), length(Authority) =< 128 ->
    lists:all(fun valid_durable/1, Authority);
valid_authority(_) -> false.

valid_revocations(Revocations) when is_list(Revocations), length(Revocations) =< 1024 ->
    lists:all(fun valid_id/1, Revocations);
valid_revocations(_) -> false.

valid_generation(Value) -> is_integer(Value) andalso Value > 0.
valid_transition(Value) -> is_integer(Value) andalso Value > 0.

valid_durable(Value) -> valid_durable(Value, 0, 0).

valid_durable(_Value, Depth, _Count) when Depth > ?MAX_DEPTH -> false;
valid_durable(Value, _Depth, _Count) when is_pid(Value); is_port(Value); is_reference(Value); is_function(Value) -> false;
valid_durable(Value, _Depth, _Count) when is_integer(Value); is_float(Value); is_atom(Value); is_binary(Value) -> true;
valid_durable(Value, _Depth, _Count) when is_bitstring(Value) -> false;
valid_durable([], _Depth, _Count) -> true;
valid_durable(Value, Depth, Count) when is_list(Value), Count =< ?MAX_COLLECTION ->
    case proper_list_length(Value, 0) of
        {ok, Length} when Length =< ?MAX_COLLECTION ->
            lists:all(fun(Item) -> valid_durable(Item, Depth + 1, Count + Length) end, Value);
        _ -> false
    end;
valid_durable(Value, Depth, Count) when is_tuple(Value), tuple_size(Value) =< ?MAX_COLLECTION ->
    lists:all(
        fun(Item) -> valid_durable(Item, Depth + 1, Count + tuple_size(Value)) end,
        tuple_to_list(Value)
    );
valid_durable(Value, Depth, Count) when is_map(Value), map_size(Value) =< ?MAX_COLLECTION ->
    maps:fold(
        fun(Key, Item, Acc) ->
            Acc andalso valid_durable(Key, Depth + 1, Count + map_size(Value)) andalso
                valid_durable(Item, Depth + 1, Count + map_size(Value))
        end,
        true,
        Value
    );
valid_durable(_Value, _Depth, _Count) -> false.

proper_list_length([], Count) -> {ok, Count};
proper_list_length([_Head | Tail], Count) when Count < ?MAX_COLLECTION -> proper_list_length(Tail, Count + 1);
proper_list_length(_Other, _Count) -> error.

valid_id(Value) -> is_binary(Value) andalso byte_size(Value) > 0 andalso byte_size(Value) =< ?MAX_ID_BYTES.

valid_digest(Value) when is_binary(Value), byte_size(Value) =:= 64 ->
    lists:all(fun is_hex/1, binary_to_list(Value));
valid_digest(_) -> false.

is_hex(Character) when Character >= $0, Character =< $9 -> true;
is_hex(Character) when Character >= $a, Character =< $f -> true;
is_hex(_) -> false.

exact_keys(Map, Keys) -> lists:sort(maps:keys(Map)) =:= lists:sort(Keys).

append_bounded(List, Item, Maximum) when length(List) < Maximum -> List ++ [Item];
append_bounded(List, _Item, _Maximum) -> List.

hex(Binary) -> << <<(hex_digit(Nibble))>> || <<Nibble:4>> <= Binary >>.

hex_digit(Nibble) when Nibble < 10 -> $0 + Nibble;
hex_digit(Nibble) -> $a + Nibble - 10.
