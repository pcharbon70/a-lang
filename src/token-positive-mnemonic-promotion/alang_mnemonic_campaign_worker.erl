-module(alang_mnemonic_campaign_worker).

-export([main/0]).

main() ->
    case init:get_plain_arguments() of
        ["preflight"] -> finish(preflight());
        ["run", RunRoot] -> finish(run(RunRoot));
        ["replay", RunRoot] -> finish(replay(RunRoot));
        _ -> finish({error, invalid_campaign_worker_arguments})
    end.

preflight() ->
    case alang_mnemonic_campaign:preflight(".", environment()) of
        {ok, Ready} ->
            Token = maps:get(token, Ready),
            io:format("mnemonic_phase3_preflight_ok qualification=~ts token=~ts models=~B~n",
                [maps:get(<<"qualification_digest">>, maps:get(qualification, Ready)),
                 maps:get(<<"token_digest">>, Token), length(maps:get(inventory, Ready))]), ok;
        {error, _} = Error -> Error
    end.

run(RunRoot) ->
    case alang_mnemonic_campaign:preflight(".", environment()) of
        {ok, Ready} ->
            Inventory = maps:get(inventory, Ready),
            Opened = case has_records(RunRoot) of
                true -> alang_mnemonic_campaign:resume(".", RunRoot,
                    environment(), Inventory);
                false -> alang_mnemonic_campaign:start(".", RunRoot,
                    environment(), Inventory)
            end,
            case Opened of
                {ok, State} -> execute(State);
                {error, _} = Error -> Error;
                {error, Reason, _State} -> {error, Reason}
            end;
        {error, _} = Error -> Error
    end.

execute(State) ->
    case alang_mnemonic_campaign:run(State) of
        {ok, Complete} ->
            case alang_mnemonic_evidence:publish(Complete) of
                {ok, Evidence, _Closed} ->
                    io:format("mnemonic_phase3_ok evidence=~ts observations=~B calls=~B~n",
                        [maps:get(<<"evidence_digest">>, Evidence),
                         maps:get(<<"observation_count">>, Evidence),
                         maps:get(<<"all_requests">>, Evidence)]), ok;
                {error, _} = Error -> Error
            end;
        {error, Reason, _State} -> {error, Reason}
    end.

replay(RunRoot) ->
    case alang_mnemonic_evidence:replay_existing(".", RunRoot) of
        {ok, Reproduction} ->
            io:format("mnemonic_phase3_replay_ok digest=~ts observations=~B~n",
                [maps:get(<<"replay_digest">>, Reproduction),
                 maps:get(<<"observations">>, Reproduction)]), ok;
        {error, _} = Error -> Error
    end.

environment() -> #{<<"ALANG_ALLOW_MNEMONIC_MODEL_CALLS">> =>
    unicode:characters_to_binary(os:getenv("ALANG_ALLOW_MNEMONIC_MODEL_CALLS", ""))}.
has_records(RunRoot) -> filelib:wildcard(filename:join(
    [RunRoot, "records", "*.etf"])) =/= [].
finish(ok) -> halt(0);
finish({error, Reason}) -> io:format(standard_error,
    "mnemonic_phase3_error ~tp~n", [Reason]), halt(1).
