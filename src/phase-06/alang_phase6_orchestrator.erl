-module(alang_phase6_orchestrator).
-behaviour(gen_server).

-export([after_artifact/2, after_model/4, before_model/2, before_write/2,
    draft_verified/2, snapshot/1, start_link/3, stop/1]).
-export([handle_call/3, handle_cast/2, handle_info/2, init/1, terminate/2]).

-spec start_link(map(), binary(), non_neg_integer()) -> gen_server:start_ret().
start_link(TaskSpec, ContextDigest, ContextBytes) ->
    gen_server:start_link(?MODULE, {TaskSpec, ContextDigest, ContextBytes}, []).

-spec before_model(pid(), map()) -> ok | {error, term()}.
before_model(Orchestrator, Request) ->
    gen_server:call(Orchestrator, {before_model, Request}, 3000).

-spec after_model(pid(), map(), map(), none | map()) -> ok | {error, term()}.
after_model(Orchestrator, Request, Result, RepairRequest) ->
    gen_server:call(Orchestrator, {after_model, Request, Result, RepairRequest}, 3000).

-spec draft_verified(pid(), binary()) -> ok | {error, term()}.
draft_verified(Orchestrator, Draft) ->
    gen_server:call(Orchestrator, {draft_verified, Draft}, 3000).

-spec before_write(pid(), binary()) -> ok | {error, term()}.
before_write(Orchestrator, OperationId) ->
    gen_server:call(Orchestrator, {before_write, OperationId}, 3000).

-spec after_artifact(pid(), map()) -> ok | {error, term()}.
after_artifact(Orchestrator, Witness) ->
    gen_server:call(Orchestrator, {after_artifact, Witness}, 3000).

-spec snapshot(pid()) -> map().
snapshot(Orchestrator) -> gen_server:call(Orchestrator, snapshot, 3000).

-spec stop(pid()) -> ok.
stop(Orchestrator) -> gen_server:stop(Orchestrator).

init({TaskSpec, ContextDigest, ContextBytes}) ->
    Now = monotonic_now(),
    case alang_phase6_task:new(TaskSpec, Now) of
        {ok, State0} ->
            case alang_phase6_task:transition(State0,
                {context_prepared, ContextDigest, ContextBytes}, Now) of
                {ok, State1} -> {ok, State1};
                {incomplete, Reason, _State} -> {stop, Reason};
                {error, Reason} -> {stop, Reason}
            end;
        {error, Reason} -> {stop, Reason}
    end.

handle_call({before_model, Request}, _From, State) ->
    case {request_matches_task(Request, State),
        alang_phase6_model_protocol:request_digest(Request)} of
        {true, {ok, RequestDigest}} ->
            {ok, Checkpoint} = alang_phase6_task:checkpoint(State),
            reply_transition(alang_phase6_task:transition(State,
                {model_requested, RequestDigest, Checkpoint}, monotonic_now()), State);
        {false, _} -> {reply, {error, model_request_task_mismatch}, State};
        {_, {error, Reason}} -> {reply, {error, Reason}, State}
    end;
handle_call({after_model, Request, Result, RepairRequest}, _From, State) ->
    case alang_phase6_model_protocol:validate_result(Result, Request) of
        ok -> after_valid_model(Result, RepairRequest, State);
        {error, Reason} -> {reply, {error, Reason}, State}
    end;
handle_call({draft_verified, Draft}, _From, #{draft := Draft} = State) when is_binary(Draft) ->
    reply_transition(alang_phase6_task:transition(State,
        {draft_verified, digest_binary(Draft)}, monotonic_now()), State);
handle_call({draft_verified, _Draft}, _From, State) ->
    {reply, {error, draft_identity_mismatch}, State};
handle_call({before_write, OperationId}, _From, State) ->
    {ok, Checkpoint} = alang_phase6_task:checkpoint(State),
    reply_transition(alang_phase6_task:transition(State,
        {write_requested, OperationId, Checkpoint}, monotonic_now()), State);
handle_call({after_artifact, Witness}, _From, State) ->
    reply_transition(alang_phase6_task:transition(State,
        {artifact_verified, Witness}, monotonic_now()), State);
handle_call(snapshot, _From, State) -> {reply, alang_phase6_task:snapshot(State), State};
handle_call(_Request, _From, State) -> {reply, {error, unsupported_orchestrator_call}, State}.

handle_cast(_Message, State) -> {noreply, State}.
handle_info(_Message, State) -> {noreply, State}.
terminate(_Reason, _State) -> ok.

after_valid_model(Result, RepairRequest, State) ->
    case alang_phase6_task:transition(State, {model_result, Result}, monotonic_now()) of
        {ok, ResultState} -> maybe_plan_repair(Result, RepairRequest, ResultState);
        {incomplete, Reason, Updated} -> {reply, {error, Reason}, Updated};
        {error, Reason} -> {reply, {error, Reason}, State}
    end.

maybe_plan_repair(#{status := Status}, RepairRequest, State) when
    Status =:= invalid_syntax; Status =:= schema_failure
->
    case alang_phase6_model_protocol:request_digest(RepairRequest) of
        {ok, RepairDigest} ->
            reply_transition(alang_phase6_task:transition(State,
                {repair_planned, RepairDigest}, monotonic_now()), State);
        {error, Reason} -> {reply, {error, Reason}, State}
    end;
maybe_plan_repair(#{status := success}, none, State) -> {reply, ok, State};
maybe_plan_repair(_Result, _RepairRequest, State) ->
    {reply, {error, invalid_repair_transition}, State}.

reply_transition({ok, Updated}, _Original) -> {reply, ok, Updated};
reply_transition({incomplete, Reason, Updated}, _Original) -> {reply, {error, Reason}, Updated};
reply_transition({error, Reason}, Original) -> {reply, {error, Reason}, Original}.

request_matches_task(#{profile := Profile, output_schema := Schema,
    deadline := Deadline, provenance := Provenance, context := Context}, State) ->
    Counters = maps:get(counters, State),
    RepairAttempts = maps:get(repair_attempts, Counters),
    ContextMatches = case RepairAttempts of
        0 -> maps:get(parent_call_id, Provenance) =:= none andalso
            context_digest(Context) =:= maps:get(context_digest, State);
        _ -> maps:get(parent_call_id, Provenance) =/= none
    end,
    maps:get(id, Profile) =:= maps:get(profile_id, State) andalso
        maps:get(id, Schema) =:= maps:get(output_schema_id, State) andalso
        maps:get(task_id, Provenance) =:= maps:get(task_id, State) andalso
        Deadline =< maps:get(deadline, State) andalso ContextMatches;
request_matches_task(_Request, _State) -> false.

context_digest(Context) -> digest([digest(Fragment) || Fragment <- Context]).

monotonic_now() -> erlang:monotonic_time(millisecond).
digest(Term) -> hex(crypto:hash(sha256, term_to_binary(Term, [deterministic]))).
digest_binary(Binary) -> hex(crypto:hash(sha256, Binary)).
hex(Binary) -> << <<(hex_digit(Nibble))>> || <<Nibble:4>> <= Binary >>.
hex_digit(Nibble) when Nibble < 10 -> $0 + Nibble;
hex_digit(Nibble) -> $a + Nibble - 10.
