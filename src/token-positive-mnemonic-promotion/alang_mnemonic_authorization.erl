-module(alang_mnemonic_authorization).

-export([authorize/3, load/1, validate/1]).

-define(CONTRACT, "assets/token-positive-mnemonic-promotion/phase-02/contracts/authorization-v1.json").

-spec load(file:filename()) -> {ok, map()} | {error, term()}.
load(Path) ->
    case alang_fidelity_json:decode_file(Path) of
        {ok, Contract} -> validate(Contract);
        {error, Reason} -> {error, {mnemonic_authorization_error, contract_read, Reason}}
    end.

-spec validate(term()) -> {ok, map()} | {error, term()}.
validate(Contract) ->
    try
        exact(maps:keys(Contract), [<<"drift_policy">>, <<"environment_variable">>,
            <<"format">>, <<"network_default">>, <<"qualification_digest">>,
            <<"required_value">>], fields),
        exact(maps:get(<<"format">>, Contract),
            <<"alang-token-positive-live-authorization-v1">>, format),
        Digest = maps:get(<<"qualification_digest">>, Contract),
        ensure(is_binary(Digest) andalso byte_size(Digest) =:= 64 andalso
            Digest =/= zeros(), invalid_qualification_digest),
        exact(maps:get(<<"environment_variable">>, Contract),
            <<"ALANG_ALLOW_MNEMONIC_MODEL_CALLS">>, environment_variable),
        exact(maps:get(<<"required_value">>, Contract), <<"1">>, required_value),
        exact(maps:get(<<"network_default">>, Contract), <<"disabled">>, network_default),
        exact(maps:get(<<"drift_policy">>, Contract),
            <<"reject-and-requalify">>, drift_policy),
        {ok, Contract}
    catch
        error:{badkey, Key} -> {error, {mnemonic_authorization_error, {missing_field, Key}}};
        throw:{mnemonic_authorization_error, Reason} ->
            {error, {mnemonic_authorization_error, Reason}}
    end.

-spec authorize(map(), file:filename(), map()) -> {ok, map()} | {error, term()}.
authorize(Evidence, RepoRoot, Environment) ->
    try
        {ok, Contract} = checked(load(filename:join(RepoRoot, ?CONTRACT))),
        Variable = maps:get(<<"environment_variable">>, Contract),
        exact(maps:get(Variable, Environment, undefined),
            maps:get(<<"required_value">>, Contract), explicit_opt_in),
        {ok, Current} = checked(alang_mnemonic_qualification:build(RepoRoot)),
        exact(Evidence, Current, stale_or_mutated_evidence),
        Digest = maps:get(<<"qualification_digest">>, Current),
        exact(Digest, maps:get(<<"qualification_digest">>, Contract),
            qualification_digest),
        exact(maps:get(<<"pass">>, maps:get(<<"gate">>, Current)), true, gate),
        exact(maps:get(<<"hosted_calls_observed">>, Current), 0, hosted_calls),
        exact(maps:get(<<"network_authorized">>, Current), false, prior_network_state),
        {ok, #{<<"format">> => <<"alang-token-positive-authorization-token-v1">>,
            <<"qualification_digest">> => Digest,
            <<"authorized">> => true,
            <<"scope">> => <<"phase-3-registered-runner-only">>}}
    catch
        error:{badkey, Key} -> {error, {mnemonic_authorization_error, {missing_field, Key}}};
        throw:{mnemonic_authorization_error, Reason} ->
            {error, {mnemonic_authorization_error, Reason}}
    end.

checked({ok, _} = Result) -> Result;
checked({error, Reason}) -> fail(Reason).
exact(Value, Expected, _Reason) when Value =:= Expected -> ok;
exact(Value, Expected, Reason) -> fail({expected, Reason, Expected, Value}).
ensure(true, _Reason) -> ok;
ensure(false, Reason) -> fail(Reason).
fail(Reason) -> throw({mnemonic_authorization_error, Reason}).
zeros() -> <<"0000000000000000000000000000000000000000000000000000000000000000">>.
