-module(alang_phase5_resume).

-export([resume/1]).

-spec resume(map()) -> {ok, pid(), map()} | {paused, map()} | {error, tuple()}.
resume(#{store_options := StoreOptions, expected := Expected, broker_options := BrokerOptions}) ->
    case open_snapshot(StoreOptions) of
        {ok, Snapshot} ->
            case alang_phase5_recovery:recover(Snapshot, Expected) of
                {ok, Recovery} -> persist_generation_and_start(
                    Recovery,
                    StoreOptions,
                    BrokerOptions
                );
                {error, _} = Error -> Error
            end;
        {error, Reason} -> {error, {recovery_rejected, {storage_unavailable, Reason}, #{}}}
    end;
resume(_Options) -> {error, {recovery_rejected, invalid_resume_options, #{}}}.

open_snapshot(StoreOptions) ->
    case alang_phase5_store:start(StoreOptions) of
        {ok, Store} ->
            try alang_phase5_store:read(Store, deadline()) of
                Result -> Result
            after
                alang_phase5_store:stop(Store)
            end;
        {error, Reason} -> {error, Reason};
        ignore -> {error, store_unavailable}
    end.

persist_generation_and_start(Recovery, StoreOptions, BrokerOptions) ->
    case alang_phase5_store:start(StoreOptions) of
        {ok, Store} ->
            State = maps:get(state, Recovery),
            Sequence = maps:get(journal_next_sequence, Recovery),
            CheckpointResult = try alang_phase5_store:checkpoint(
                Store,
                State,
                Sequence,
                deadline()
            ) of
                Result -> Result
            after
                alang_phase5_store:stop(Store)
            end,
            case CheckpointResult of
                {ok, Ack} -> start_supervision(Recovery#{resume_checkpoint => Ack}, StoreOptions,
                    BrokerOptions);
                {error, Reason} ->
                    {error, {recovery_rejected, {checkpoint_publish_failed, Reason}, #{}}}
            end;
        {error, Reason} ->
            {error, {recovery_rejected, {storage_unavailable, Reason}, #{}}};
        ignore -> {error, {recovery_rejected, store_unavailable, #{}}}
    end.

start_supervision(Recovery, StoreOptions, BrokerOptions) ->
    case alang_phase5_session_sup:start_link(#{
        recovery => Recovery,
        store_options => StoreOptions,
        broker_options => BrokerOptions
    }) of
        {ok, Supervisor} -> activate_recovery(Supervisor, Recovery);
        {error, Reason} -> {error, {recovery_rejected, {supervision_start_failed, Reason}, #{}}}
    end.

activate_recovery(Supervisor, Recovery) ->
    case alang_phase5_session_sup:topology(Supervisor) of
        {ok, Topology} ->
            Store = maps:get(durable_store, Topology),
            Broker = maps:get(broker, Topology),
            Coordinator = maps:get(coordinator, Topology),
            case alang_phase5_effect_recovery:reconcile(Store, Broker, Recovery, deadline()) of
                {ok, Reconciled} -> restore_authority(Supervisor, Broker, Coordinator, Reconciled);
                {paused, Paused} ->
                    alang_phase5_session_sup:stop(Supervisor),
                    {paused, Paused};
                {error, Reason} ->
                    alang_phase5_session_sup:stop(Supervisor),
                    {error, {recovery_rejected, Reason, #{}}}
            end;
        {error, Reason} ->
            alang_phase5_session_sup:stop(Supervisor),
            {error, {recovery_rejected, {incomplete_supervision, Reason}, #{}}}
    end.

restore_authority(Supervisor, Broker, Coordinator, Recovery) ->
    State = maps:get(state, Recovery),
    case alang_phase5_authority:restore(
        Broker,
        State,
        Coordinator,
        erlang:system_time(millisecond),
        erlang:monotonic_time(millisecond)
    ) of
        {ok, Authority} -> {ok, Supervisor, Recovery#{recovered_authority => Authority}};
        {error, Reason} ->
            alang_phase5_session_sup:stop(Supervisor),
            {error, {recovery_rejected, Reason, #{}}}
    end.

deadline() -> erlang:monotonic_time(millisecond) + 2000.
