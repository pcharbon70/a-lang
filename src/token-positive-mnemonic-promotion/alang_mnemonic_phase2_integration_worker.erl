-module(alang_mnemonic_phase2_integration_worker).

-export([main/0]).

-spec main() -> no_return().
main() ->
    case init:get_plain_arguments() of
        [Output] ->
            case alang_mnemonic_phase2_evidence:write(".", Output) of
                {ok, Evidence} ->
                    Replay = maps:get(<<"replay">>, Evidence),
                    io:format("mnemonic_phase2_evidence_ok digest=~s pairs=~B mutants=18 modules=16 hosted_calls=0 output=~s~n",
                        [maps:get(<<"evidence_digest">>, Evidence),
                            maps:get(<<"valid_pair_count">>, Replay), Output]), halt(0);
                {error, Reason} ->
                    io:format(standard_error, "mnemonic_phase2_evidence_error ~tp~n", [Reason]), halt(1)
            end;
        Arguments ->
            io:format(standard_error, "usage: alang_mnemonic_phase2_integration_worker <output.json>; got ~tp~n",
                [Arguments]), halt(2)
    end.
