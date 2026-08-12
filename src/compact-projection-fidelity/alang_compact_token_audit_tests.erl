-module(alang_compact_token_audit_tests).

-include_lib("eunit/include/eunit.hrl").

audit_contract_and_exact_attribution_are_closed_test_() ->
    {timeout, 60, fun() ->
        alang_compact_tokenizer:clear_cache(),
        ?assertMatch({ok, _}, alang_compact_token_audit:load_contract(contract_path())),
        Surface = rendered_surface(),
        {ok, Audit} = audit(Surface, unavailable),
        ?assertEqual(<<"alang-compact-token-audit-v1">>, maps:get(<<"format">>, Audit)),
        ?assertEqual(maps:get(byte_count, Surface), maps:get(<<"representation_bytes">>, Audit)),
        Tokenizer = maps:get(<<"tokenizer">>, Audit),
        ?assertEqual(<<"exact-registered-tokenizer">>, maps:get(<<"provenance">>, Tokenizer)),
        Counts = maps:get(<<"counts">>, Audit),
        ?assert(maps:get(<<"full_request">>, Counts) > maps:get(<<"document">>, Counts)),
        ?assertEqual(section_names(), lists:sort(maps:keys(maps:get(<<"semantic_sections">>, Audit)))),
        ?assertEqual(lexeme_names(), lists:sort(maps:keys(maps:get(<<"lexeme_classes">>, Audit)))),
        ?assertEqual(<<"unavailable">>, maps:get(<<"status">>, maps:get(<<"provider_usage">>, Audit)))
    end}.

provider_usage_is_authoritative_and_estimates_are_rejected_test_() ->
    {timeout, 60, fun() ->
        Surface = rendered_surface(),
        Usage = #{source => provider_reported, input_tokens => 101,
            output_tokens => 29, total_tokens => 130, estimated => false},
        {ok, Audit} = audit(Surface, Usage),
        Provider = maps:get(<<"provider_usage">>, Audit),
        ?assertEqual(<<"provider-reported-authoritative">>, maps:get(<<"provenance">>, Provider)),
        ?assertEqual(130, maps:get(<<"total_tokens">>, Provider)),
        ?assertMatch({error, invalid_or_estimated_provider_usage},
            audit(Surface, Usage#{estimated := true})),
        ?assertMatch({error, invalid_or_estimated_provider_usage},
            audit(Surface, Usage#{total_tokens := 129}))
    end}.

missing_or_unknown_attribution_categories_are_rejected_test() ->
    Surface = rendered_surface(),
    Sections = maps:get(sections, Surface),
    ?assertMatch({error, {invalid_closed_record, semantic_sections, _, _}},
        audit(Surface#{sections := maps:remove(paths, Sections)}, unavailable)),
    ?assertMatch({error, {invalid_closed_record, semantic_sections, _, _}},
        audit(Surface#{sections := Sections#{other => <<>>}}, unavailable)),
    ?assertMatch({error, {unknown_tokenizer_profile, <<"cl100k_base">>}},
        alang_compact_token_audit:audit(<<"cl100k_base">>, Surface, request_parts(), unavailable,
            tokenizer_dir(), contract_path())).

rendered_surface() ->
    {ok, Corpus} = alang_fidelity_json:decode_file(corpus_path()),
    Oracle = alang_compact_corpus:oracle(hd(maps:get(<<"cases">>, Corpus))),
    {ok, Surface} = alang_compact_surface:render(<<"R2">>, <<"alang-source-v2-alias-v1">>,
        Oracle, registry_path()),
    Surface.

audit(Surface, ProviderUsage) ->
    alang_compact_token_audit:audit(<<"tiktoken-0.12.0-cl100k-base">>, Surface,
        request_parts(), ProviderUsage, tokenizer_dir(), contract_path()).

request_parts() ->
    #{common_instructions => <<"Read the task and preserve every constraint.">>,
        legend => <<"f=facts;cap=limits;ok=completion">>,
        output_scaffolding => <<"Return one canonical JSON object.">>}.

section_names() ->
    lists:sort([<<"layout">>, <<"keywords">>, <<"identifiers">>, <<"facts">>,
        <<"paths">>, <<"budgets">>, <<"authority">>, <<"completion">>,
        <<"legends">>, <<"common_instructions">>, <<"output_scaffolding">>]).
lexeme_names() ->
    lists:sort([<<"layout">>, <<"keywords">>, <<"identifiers">>, <<"literals">>, <<"punctuation">>]).

registry_path() -> filename:join([phase2_dir(), "contracts", "surface-registry-v1.json"]).
contract_path() -> filename:join([phase2_dir(), "contracts", "token-audit-contract-v1.json"]).
tokenizer_dir() -> filename:join([phase2_dir(), "tokenizers"]).
phase2_dir() -> filename:join(["assets", "compact-projection-fidelity", "phase-02"]).
corpus_path() -> filename:join(["assets", "compact-projection-fidelity", "corpus", "confirmatory-corpus-v1.json"]).
