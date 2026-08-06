-module(alang_fidelity_compiler).

-export([compile_campaign/1, compile_control/1, compile_source/1]).

-spec compile_source(binary()) -> {ok, map()} | {error, [map()]}.
compile_source(Binary) ->
    compile_checked(alang_fidelity_semantics:check_source(Binary)).

-spec compile_control(binary()) -> {ok, map()} | {error, [map()]}.
compile_control(Binary) ->
    compile_checked(alang_fidelity_semantics:check_control(Binary)).

-spec compile_campaign(map()) -> {ok, map()} | {error, [map()]}.
compile_campaign(#{format := alang_typed_task_ir_v2}) ->
    manual_ir_error();
compile_campaign(#{ir := _Ir}) ->
    manual_ir_error();
compile_campaign(#{fixture := _Fixture}) ->
    fixture_error();
compile_campaign(#{reference_evaluator := _Evaluator}) ->
    fixture_error();
compile_campaign(Artifact) when is_map(Artifact) ->
    Keys = [format, frontend, content, content_digest, semantic_digest],
    case lists:sort(maps:keys(Artifact)) =:= lists:sort(Keys) of
        false ->
            {error, [diagnostic(invalid_campaign_input,
                <<"campaign input has unknown or missing provenance fields">>)]};
        true ->
            compile_campaign_artifact(Artifact)
    end;
compile_campaign(_) ->
    {error, [diagnostic(invalid_campaign_input,
        <<"campaign input must be a closed map">>)]}.

compile_campaign_artifact(Artifact) ->
    case maps:get(format, Artifact) of
        alang_campaign_input_v1 ->
            Content = maps:get(content, Artifact),
            case is_binary(Content) of
                false ->
                    {error, [diagnostic(invalid_campaign_content,
                        <<"campaign content must be original source bytes">>)]};
                true ->
                    compile_campaign_content(Artifact, Content)
            end;
        _ ->
            {error, [diagnostic(invalid_campaign_input_version,
                <<"expected alang_campaign_input_v1">>)]}
    end.

compile_campaign_content(Artifact, Content) ->
    ContentDigest = alang_fidelity_json:hex(crypto:hash(sha256, Content)),
    case ContentDigest =:= maps:get(content_digest, Artifact) of
        false ->
            {error, [diagnostic(content_digest_mismatch,
                <<"campaign content digest does not match the supplied bytes">>)]};
        true ->
            Result = case maps:get(frontend, Artifact) of
                alang_source -> compile_source(Content);
                typed_json -> compile_control(Content);
                _ -> {error, [diagnostic(unknown_campaign_frontend,
                    <<"campaign frontend is outside the closed representation set">>)]}
            end,
            verify_campaign_result(Result, Artifact, ContentDigest)
    end.

verify_campaign_result({ok, Lowered}, Artifact, ContentDigest) ->
    Provenance = maps:get(provenance, Lowered),
    ExpectedSemantic = maps:get(semantic_digest, Artifact),
    case {
        maps:get(frontend, Provenance) =:= maps:get(frontend, Artifact),
        maps:get(source_digest, Provenance) =:= ContentDigest,
        maps:get(semantic_digest, Provenance) =:= ExpectedSemantic
    } of
        {true, true, true} -> {ok, Lowered};
        {_, _, false} ->
            {error, [diagnostic(semantic_digest_mismatch,
                <<"campaign semantic digest does not match checked semantics">>)]};
        _ ->
            {error, [diagnostic(provenance_mismatch,
                <<"lowering provenance does not match the accepted campaign input">>)]}
    end;
verify_campaign_result({error, _} = Error, _Artifact, _ContentDigest) -> Error.

compile_checked({ok, Checked}) ->
    case alang_fidelity_authority:derive(Checked) of
        {ok, Derived} -> alang_fidelity_ir:lower(Derived);
        {error, _} = Error -> Error
    end;
compile_checked({error, _} = Error) -> Error.

manual_ir_error() ->
    {error, [diagnostic(manual_ir_forbidden,
        <<"campaign acceptance requires original A-Lang or typed-JSON bytes">>)]}.

fixture_error() ->
    {error, [diagnostic(non_deployable_fixture_forbidden,
        <<"fixtures and reference evaluators cannot enter campaign acceptance">>)]}.

diagnostic(Code, Message) ->
    #{class => provenance, code => Code, severity => error, message => Message}.
