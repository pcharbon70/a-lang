-module(alang_fidelity_phase5_worker).

-export([build/1, main/0]).

-define(BASE, "assets/effectful-source-fidelity").

-spec build(file:filename()) -> {ok, map()} | {error, term()}.
build(OutputPath) ->
    case alang_fidelity_offline_campaign:run(?BASE) of
        {ok, Campaign} ->
            Statistics = #{
                aggregate => maps:get(aggregate, Campaign),
                bootstrap => maps:get(bootstrap, Campaign),
                accounting => maps:get(accounting, Campaign),
                validity => maps:get(validity, Campaign),
                offline_analysis_digest => maps:get(analysis_digest, Campaign)
            },
            Options = #{
                campaign_status => offline_fixture,
                campaign_journal => maps:get(journal, Campaign),
                provenance => #{
                    campaign_mode => offline_fixture,
                    provider_profiles_verified => false
                }
            },
            case alang_fidelity_evidence:build(
                ?BASE,
                maps:get(schedule, Campaign),
                maps:get(observations, Campaign),
                maps:get(scores, Campaign),
                Statistics,
                Options
            ) of
                {ok, Evidence} ->
                    case alang_fidelity_evidence:write(OutputPath, Evidence) of
                        {ok, WriteEvidence} -> {ok, #{
                            evidence => Evidence,
                            write => WriteEvidence,
                            offline_campaign_digest => maps:get(offline_digest, Campaign)
                        }};
                        {error, _} = Error -> Error
                    end;
                {error, _} = Error -> Error
            end;
        {error, _} = Error -> Error
    end.

-spec main() -> no_return().
main() ->
    case init:get_plain_arguments() of
        [OutputPath] ->
            case build(OutputPath) of
                {ok, Built} ->
                    Evidence = maps:get(evidence, Built),
                    Completeness = maps:get(completeness, Evidence),
                    Accounting = maps:get(accounting, maps:get(statistics, Evidence)),
                    io:format(
                        "fidelity_phase5_offline_ok digest=~s campaign=~s cells=~p calls=~p "
                        "cost_microusd=~p hosted_calls=0 otp=~s output=~s~n",
                        [
                            maps:get(evidence_digest, Evidence),
                            maps:get(offline_campaign_digest, Built),
                            maps:get(observed, Completeness),
                            maps:get(calls, Accounting),
                            maps:get(cost_microusd, Accounting),
                            erlang:system_info(otp_release),
                            OutputPath
                        ]
                    ),
                    halt(0);
                {error, Reason} ->
                    io:format(standard_error, "fidelity_phase5_offline_error ~tp~n", [Reason]),
                    halt(1)
            end;
        _ ->
            io:format(standard_error, "usage: alang_fidelity_phase5_worker OUTPUT_PATH~n", []),
            halt(2)
    end.
