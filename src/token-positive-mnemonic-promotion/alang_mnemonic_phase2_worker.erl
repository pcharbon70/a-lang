-module(alang_mnemonic_phase2_worker).

-export([main/0]).

-spec main() -> no_return().
main() ->
    case init:get_plain_arguments() of
        [Output] ->
            case alang_mnemonic_qualification:write(".", Output) of
                {ok, Evidence} ->
                    io:format("mnemonic_phase2_ok digest=~s files=~B cases=48 request_pairs=384 hosted_calls=0 output=~s~n",
                        [maps:get(<<"qualification_digest">>, Evidence),
                            maps:get(<<"registration_file_count">>, Evidence), Output]),
                    halt(0);
                {error, Reason} ->
                    io:format(standard_error, "mnemonic_phase2_error ~tp~n", [Reason]), halt(1)
            end;
        Arguments ->
            io:format(standard_error, "usage: alang_mnemonic_phase2_worker <output.json>; got ~tp~n",
                [Arguments]), halt(2)
    end.
