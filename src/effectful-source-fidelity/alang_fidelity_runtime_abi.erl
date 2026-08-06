-module(alang_fidelity_runtime_abi).

-export([begin_task/3, complete/5, delegate/6, effect/6]).

-define(CALL_TIMEOUT, 15000).

-spec begin_task(map(), binary(), map()) -> {ok, reference()} | {error, term()}.
begin_task(Context, TaskId, Inputs) ->
    call(Context, {begin_task, TaskId, Inputs}).

-spec effect(map(), reference(), non_neg_integer(), binary(), binary(), [binary()]) ->
    {ok, term()} | {error, term()}.
effect(Context, Token, Ordinal, ActionId, Operation, Dependencies) ->
    call(Context, {effect, Token, Ordinal, ActionId, Operation, Dependencies}).

-spec delegate(map(), reference(), non_neg_integer(), binary(), binary(), [binary()]) ->
    {ok, term()} | {error, term()}.
delegate(Context, Token, Ordinal, ActionId, Operation, Dependencies) ->
    call(Context, {delegate, Token, Ordinal, ActionId, Operation, Dependencies}).

-spec complete(map(), reference(), binary(), map(), binary()) ->
    {ok, map()} | {error, term()}.
complete(Context, Token, ActionId, Completion, TerminalClass) ->
    call(Context, {complete, Token, ActionId, Completion, TerminalClass}).

call(#{format := alang_fidelity_runtime_context_v1, runtime := Runtime,
        binding_digest := BindingDigest} = Context, Request) when
    map_size(Context) =:= 3, is_pid(Runtime), is_binary(BindingDigest)
->
    try gen_server:call(Runtime, {abi, BindingDigest, Request}, ?CALL_TIMEOUT) of
        Reply -> Reply
    catch
        exit:{timeout, _} -> {error, runtime_timeout};
        exit:{noproc, _} -> {error, runtime_unavailable};
        exit:_ -> {error, runtime_unavailable}
    end;
call(_Context, _Request) -> {error, invalid_runtime_context}.
