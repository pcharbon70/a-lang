-module(alang_fidelity_phase6_worker).

-export([build/1, decode/1, main/0, validate/1]).

-define(BASE, "assets/effectful-source-fidelity").
-define(CLOSURE,
    "assets/effectful-source-fidelity/evidence/hosted-campaign-closure-v1.json").
-define(OWNED_ROOT, "build/effectful-source-fidelity/phase-06/evidence").

-spec main() -> no_return().
main() ->
    case init:get_plain_arguments() of
        [Output] ->
            case build(Output) of
                {ok, Bundle} ->
                    io:format(
                        "fidelity_phase6_replay_ok digest=~s artifact=~s "
                        "outcome=~s hosted_calls=0 otp=~s output=~s~n",
                        [
                            maps:get(bundle_digest, Bundle),
                            maps:get(artifact_sha256, Bundle),
                            maps:get(<<"outcome">>, maps:get(decision, Bundle)),
                            erlang:system_info(otp_release),
                            Output
                        ]
                    ),
                    halt(0);
                {error, Reason} ->
                    io:format(standard_error, "fidelity_phase6_replay_error ~tp~n", [Reason]),
                    halt(1)
            end;
        _ ->
            io:format(standard_error, "usage: alang_fidelity_phase6_worker OUTPUT_PATH~n", []),
            halt(2)
    end.

-spec build(file:filename()) -> {ok, map()} | {error, term()}.
build(Output) ->
    case owned_path(Output) of
        false -> {error, phase6_bundle_path_outside_owned_root};
        true ->
            try
                Prefix = filename:rootname(Output),
                FreezePath = Prefix ++ "-freeze.json",
                DecisionPath = Prefix ++ "-decision.json",
                ReportPath = Prefix ++ "-report.md",
                {ok, Freeze} = alang_fidelity_freeze:write(?BASE, ?CLOSURE, FreezePath),
                {ok, Decision} = alang_fidelity_architecture_decision:write(
                    ?BASE, FreezePath, DecisionPath, ReportPath),
                {ok, FreezeBytes} = file:read_file(FreezePath),
                {ok, DecisionBytes} = file:read_file(DecisionPath),
                {ok, ReportBytes} = file:read_file(ReportPath),
                Body = #{
                    format => alang_fidelity_phase6_replay_bundle_v1,
                    engine => beam,
                    otp_release => list_to_binary(erlang:system_info(otp_release)),
                    network => disabled,
                    hosted_calls => 0,
                    freeze => Freeze,
                    decision => Decision,
                    freeze_artifact_sha256 => digest_binary(FreezeBytes),
                    decision_artifact_sha256 => digest_binary(DecisionBytes),
                    report => ReportBytes,
                    report_sha256 => digest_binary(ReportBytes),
                    module_residency => residency()
                },
                Bundle0 = Body#{bundle_digest => alang_fidelity_json:digest(Body)},
                ok = validate(Bundle0),
                Binary = term_to_binary(Bundle0, [deterministic]),
                ok = filelib:ensure_dir(Output),
                ok = file:write_file(Output, Binary, [binary]),
                {ok, Bundle0#{artifact_sha256 => digest_binary(Binary)}}
            catch
                error:{badmatch, {error, Reason}} -> {error, Reason};
                Class:Reason -> {error, {phase6_bundle_failed, Class, Reason}}
            end
    end.

-spec decode(binary()) -> {ok, map()} | {error, term()}.
decode(Binary) when is_binary(Binary) ->
    lists:foreach(fun(Module) -> {module, Module} = code:ensure_loaded(Module) end,
        trusted_modules()),
    try binary_to_term(Binary, [safe]) of
        Bundle ->
            case validate(Bundle) of
                ok -> {ok, Bundle};
                {error, _} = Error -> Error
            end
    catch
        error:badarg -> {error, unsafe_phase6_bundle}
    end;
decode(_) -> {error, unsafe_phase6_bundle}.

-spec validate(term()) -> ok | {error, term()}.
validate(#{
    format := alang_fidelity_phase6_replay_bundle_v1,
    engine := beam,
    otp_release := OtpRelease,
    network := disabled,
    hosted_calls := 0,
    freeze := Freeze,
    decision := Decision,
    freeze_artifact_sha256 := FreezeArtifactDigest,
    decision_artifact_sha256 := DecisionArtifactDigest,
    report := Report,
    report_sha256 := ReportDigest,
    module_residency := Residency,
    bundle_digest := Digest
} = Bundle) ->
    try
        13 = maps:size(Bundle),
        ok = alang_fidelity_freeze:validate(Freeze),
        ok = alang_fidelity_architecture_decision:validate(Decision),
        OtpRelease = list_to_binary(erlang:system_info(otp_release)),
        {ok, FreezeJson} = alang_fidelity_json:encode_canonical(Freeze),
        FreezeArtifactDigest = digest_binary(
            iolist_to_binary([FreezeJson, <<"\n">>])),
        {ok, DecisionJson} = alang_fidelity_json:encode_canonical(Decision),
        DecisionArtifactDigest = digest_binary(
            iolist_to_binary([DecisionJson, <<"\n">>])),
        {ok, Report} = alang_fidelity_decision_report:render(Decision),
        ReportDigest = digest_binary(Report),
        Residency = residency(),
        true = no_forbidden_content(Bundle),
        Digest = alang_fidelity_json:digest(maps:remove(bundle_digest, Bundle)),
        ok
    catch
        _:_ -> {error, invalid_phase6_replay_bundle}
    end;
validate(_) -> {error, invalid_phase6_replay_bundle}.

residency() -> [begin
    {module, Module} = code:ensure_loaded(Module),
    Path = code:which(Module),
    #{module => Module, beam_file => list_to_binary(filename:basename(Path)),
        is_beam => is_list(Path) andalso filename:extension(Path) =:= ".beam"}
end || Module <- trusted_modules()].

trusted_modules() -> [
    alang_fidelity_json,
    alang_fidelity_decision,
    alang_fidelity_freeze,
    alang_fidelity_architecture_decision,
    alang_fidelity_decision_report,
    alang_fidelity_phase6_mutation,
    alang_fidelity_phase6_worker
].

no_forbidden_content(Value) when is_map(Value) -> lists:all(fun({Key, Item}) ->
    not forbidden_key(Key) andalso no_forbidden_content(Item)
end, maps:to_list(Value));
no_forbidden_content(Value) when is_list(Value) -> lists:all(fun no_forbidden_content/1, Value);
no_forbidden_content(Value) when is_tuple(Value) -> no_forbidden_content(tuple_to_list(Value));
no_forbidden_content(Value) when is_binary(Value) ->
    lists:all(fun(Needle) -> binary:match(Value, Needle) =:= nomatch end, [
        <<"Bearer ">>, <<"Bearer sk-">>, <<"x-api-key:">>,
        <<"ALANG_SECTION_5_4_SECRET">>
    ]);
no_forbidden_content(_Value) -> true.

forbidden_key(Key) -> lists:member(Key, [
    authorization, headers, raw_http_envelope, hidden_reasoning, api_key,
    credential, provider_request_id, provider_response_id,
    <<"authorization">>, <<"headers">>, <<"raw_http_envelope">>,
    <<"hidden_reasoning">>, <<"api_key">>, <<"credential">>,
    <<"provider_request_id">>, <<"provider_response_id">>
]).

owned_path(Path) ->
    Root = filename:absname(?OWNED_ROOT),
    lists:prefix(Root ++ "/", filename:absname(Path)).

digest_binary(Binary) -> alang_fidelity_json:hex(crypto:hash(sha256, Binary)).
