-module(alang_mnemonic_phase1_worker).

-export([main/0]).

-define(BASE, "assets/token-positive-mnemonic-promotion").

-spec main() -> no_return().
main() ->
    case init:get_plain_arguments() of
        [Output] ->
            case alang_mnemonic_preregister:write(?BASE, Output) of
                {ok, Evidence} ->
                    io:format("mnemonic_phase1_ok digest=~s files=~B cases=48 cells=1536 hosted_calls=0 output=~s~n",
                        [maps:get(<<"registration_digest">>, Evidence),
                            maps:get(<<"registration_file_count">>, Evidence), Output]),
                    halt(0);
                {error, Reason} ->
                    io:format(standard_error, "mnemonic_phase1_error ~tp~n", [Reason]),
                    halt(1)
            end;
        Arguments ->
            io:format(standard_error, "usage: alang_mnemonic_phase1_worker <output.json>; got ~tp~n",
                [Arguments]),
            halt(2)
    end.
