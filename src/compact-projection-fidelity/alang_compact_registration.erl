-module(alang_compact_registration).

-export([load/1, validate_policy/1, validate_profiles/1, validate_tokenizers/1]).

-spec load(file:filename()) -> {ok, map()} | {error, term()}.
load(AssetsDirectory) ->
    Campaign = filename:join(AssetsDirectory, "campaign"),
    Inputs = [
        {profiles, filename:join(Campaign, "provider-profiles-v1.json")},
        {tokenizers, filename:join(Campaign, "tokenizer-profiles-v1.json")},
        {policy, filename:join(Campaign, "campaign-policy-v1.json")}
    ],
    case decode_all(Inputs, #{}) of
        {ok, #{profiles := Profiles, tokenizers := Tokenizers, policy := Policy}} ->
            combine(AssetsDirectory, Profiles, Tokenizers, Policy);
        {error, _} = Error -> Error
    end.

combine(AssetsDirectory, Profiles, Tokenizers, Policy) ->
    case {alang_compact_corpus:load(AssetsDirectory), validate_profiles(Profiles),
            validate_tokenizers(Tokenizers), validate_policy(Policy)} of
        {{ok, CorpusEvidence}, {ok, ProfileEvidence}, {ok, TokenizerEvidence}, {ok, PolicyEvidence}} ->
            {ok, #{
                <<"format">> => <<"alang-compact-section-1-3-registration-v1">>,
                <<"corpus">> => CorpusEvidence,
                <<"profiles">> => ProfileEvidence,
                <<"tokenizers">> => TokenizerEvidence,
                <<"policy">> => PolicyEvidence,
                <<"hosted_calls_observed">> => 0,
                <<"network_authorized">> => false
            }};
        {{error, _} = Error, _, _, _} -> Error;
        {_, {error, _} = Error, _, _} -> Error;
        {_, _, {error, _} = Error, _} -> Error;
        {_, _, _, {error, _} = Error} -> Error
    end.

-spec validate_profiles(term()) -> {ok, map()} | {error, term()}.
validate_profiles(Value) ->
    try
        closed(Value, [<<"format">>, <<"selection_record">>, <<"profiles">>], [<<"profiles">>]),
        exact(maps:get(<<"format">>, Value), <<"alang-compact-provider-profiles-v1">>, [<<"profiles">>, <<"format">>]),
        Selection = maps:get(<<"selection_record">>, Value),
        closed(Selection, [<<"prior_stream">>, <<"families_retained">>, <<"identifier_change_reason">>, <<"replacement_after_preregistration">>], [<<"profiles">>, <<"selection_record">>]),
        exact(maps:get(<<"prior_stream">>, Selection), <<"effectful-source-fidelity">>, [<<"profiles">>, <<"selection_record">>]),
        exact(maps:get(<<"families_retained">>, Selection), [<<"ornith">>, <<"mixtral">>], [<<"profiles">>, <<"selection_record">>]),
        nonempty(maps:get(<<"identifier_change_reason">>, Selection), [<<"profiles">>, <<"selection_record">>]),
        exact(maps:get(<<"replacement_after_preregistration">>, Selection), <<"forbidden">>, [<<"profiles">>, <<"selection_record">>]),
        Profiles = maps:get(<<"profiles">>, Value),
        ensure(is_list(Profiles) andalso length(Profiles) =:= 2, [<<"profiles">>], expected_two_profiles),
        lists:foreach(fun validate_profile/1, Profiles),
        Expected = lists:sort([
            {<<"ornith">>, <<"hf.co/unsloth/Ornith-1.0-35B-GGUF:UD-Q5_K_M">>, <<"6959cafd1e245e8fd083f223c951d6f1e3c778b13d1ad33b4919f3c465927a25">>},
            {<<"mixtral">>, <<"mixtral:8x7b">>, <<"a3b6bef0f836ff29ddb576a80eeb1b7def43ec9b809466f62e96adb871fe8498">>}
        ]),
        Actual = lists:sort([{maps:get(<<"family">>, P), maps:get(<<"model_id">>, P), maps:get(<<"manifest_sha256">>, P)} || P <- Profiles]),
        exact(Actual, Expected, [<<"profiles">>]),
        {ok, #{<<"format">> => <<"alang-compact-profile-evidence-v1">>, <<"exact_profiles">> => 2,
            <<"families_retained_from_stream_02">> => 2, <<"manifest_match_required">> => true,
            <<"aliases_allowed">> => false}}
    catch throw:{compact_registration_error, Path, Reason} -> {error, {compact_registration_error, Path, Reason}} end.

validate_profile(Profile) ->
    Keys = [<<"family">>, <<"provider">>, <<"api">>, <<"model_id">>, <<"manifest_sha256">>,
        <<"request_parameters">>, <<"seed_policy">>, <<"turns">>, <<"tools_enabled">>,
        <<"provider_schema_constraint">>, <<"accepted_output_bytes">>,
        <<"exact_identifier_required">>, <<"manifest_match_required">>],
    closed(Profile, Keys, [<<"profiles">>]),
    exact(maps:get(<<"provider">>, Profile), <<"Ollama">>, [<<"profiles">>, <<"provider">>]),
    exact(maps:get(<<"api">>, Profile), <<"ChatCompletions">>, [<<"profiles">>, <<"api">>]),
    Params = maps:get(<<"request_parameters">>, Profile),
    exact(Params, #{<<"temperature">> => 0.2, <<"top_p">> => 0.9, <<"top_k">> => 40,
        <<"num_ctx">> => 32768, <<"num_predict">> => 8192, <<"stream">> => false}, [<<"profiles">>, <<"request_parameters">>]),
    exact(maps:get(<<"seed_policy">>, Profile), <<"sha256-trial-id-low-31-bits">>, [<<"profiles">>, <<"seed_policy">>]),
    lists:foreach(fun(Key) -> exact(maps:get(Key, Profile), true, [<<"profiles">>, Key]) end,
        [<<"exact_identifier_required">>, <<"manifest_match_required">>]),
    exact(maps:get(<<"turns">>, Profile), 1, [<<"profiles">>, <<"turns">>]),
    exact(maps:get(<<"tools_enabled">>, Profile), false, [<<"profiles">>, <<"tools_enabled">>]),
    exact(maps:get(<<"provider_schema_constraint">>, Profile), false, [<<"profiles">>, <<"provider_schema_constraint">>]),
    exact(maps:get(<<"accepted_output_bytes">>, Profile), 8192, [<<"profiles">>, <<"accepted_output_bytes">>]),
    sha256(maps:get(<<"manifest_sha256">>, Profile), [<<"profiles">>, <<"manifest_sha256">>]).

-spec validate_tokenizers(term()) -> {ok, map()} | {error, term()}.
validate_tokenizers(Value) ->
    try
        closed(Value, [<<"format">>, <<"provider_accounting">>, <<"screening_tokenizers">>], [<<"tokenizers">>]),
        exact(maps:get(<<"format">>, Value), <<"alang-compact-tokenizer-profiles-v1">>, [<<"tokenizers">>, <<"format">>]),
        exact(maps:get(<<"provider_accounting">>, Value), #{
            <<"role">> => <<"authoritative-for-provider-and-full-request-metrics">>,
            <<"missing_usage">> => <<"invalid-trial">>, <<"estimated_usage">> => <<"forbidden">>}, [<<"tokenizers">>, <<"provider_accounting">>]),
        Tokenizers = maps:get(<<"screening_tokenizers">>, Value),
        Expected = lists:sort([
            tokenizer(<<"tiktoken-0.12.0-cl100k-base">>, <<"cl100k_base">>),
            tokenizer(<<"tiktoken-0.12.0-o200k-base">>, <<"o200k_base">>)
        ]),
        exact(lists:sort(Tokenizers), Expected, [<<"tokenizers">>, <<"screening_tokenizers">>]),
        {ok, #{<<"format">> => <<"alang-compact-tokenizer-evidence-v1">>,
            <<"screening_tokenizers">> => 2, <<"provider_usage_authoritative">> => true,
            <<"estimated_provider_usage_allowed">> => false}}
    catch throw:{compact_registration_error, Path, Reason} -> {error, {compact_registration_error, Path, Reason}} end.

tokenizer(Id, Encoding) -> #{<<"id">> => Id, <<"implementation">> => <<"tiktoken">>,
    <<"version">> => <<"0.12.0">>, <<"encoding">> => Encoding,
    <<"role">> => <<"document-screening-only">>, <<"exact_version_required">> => true}.

-spec validate_policy(term()) -> {ok, map()} | {error, term()}.
validate_policy(Value) ->
    try
        Keys = [<<"format">>, <<"network_default">>, <<"live_opt_in">>, <<"availability">>,
            <<"design">>, <<"per_request_ceilings">>, <<"campaign_ceilings">>,
            <<"replacement">>, <<"retention">>, <<"invalid_campaign_triggers">>],
        closed(Value, Keys, [<<"policy">>]),
        exact(maps:get(<<"format">>, Value), <<"alang-compact-campaign-policy-v1">>, [<<"policy">>, <<"format">>]),
        exact(maps:get(<<"network_default">>, Value), <<"disabled">>, [<<"policy">>, <<"network_default">>]),
        exact(maps:get(<<"live_opt_in">>, Value), #{<<"environment_variable">> => <<"ALANG_ALLOW_COMPACT_MODEL_CALLS">>,
            <<"required_value">> => <<"1">>, <<"endpoint">> => <<"http://127.0.0.1:11434">>,
            <<"credentials_required">> => []}, [<<"policy">>, <<"live_opt_in">>]),
        exact(maps:get(<<"availability">>, Value), #{<<"probe">> => <<"ollama-manifest-sha256">>,
            <<"all_profiles_required_before_authorization">> => true, <<"missing_profile">> => <<"block-campaign">>,
            <<"manifest_mismatch">> => <<"invalidate-campaign">>}, [<<"policy">>, <<"availability">>]),
        exact(maps:get(<<"design">>, Value), #{<<"semantic_cases">> => 48, <<"primary_cells">> => 2304,
            <<"hard_request_ceiling">> => 4608, <<"model_families">> => 2,
            <<"paired_repetitions">> => 2}, [<<"policy">>, <<"design">>]),
        exact(maps:get(<<"per_request_ceilings">>, Value), #{<<"accepted_source_bytes">> => 8192,
            <<"accepted_input_bytes">> => 32768, <<"accepted_response_bytes">> => 8192,
            <<"max_output_tokens">> => 8192, <<"timeout_ms">> => 120000}, [<<"policy">>, <<"per_request_ceilings">>]),
        exact(maps:get(<<"campaign_ceilings">>, Value), #{<<"primary_requests">> => 2304,
            <<"all_requests">> => 4608, <<"local_compute_minutes">> => 9600,
            <<"monetary_cost_usd">> => 0}, [<<"policy">>, <<"campaign_ceilings">>]),
        Replacement = maps:get(<<"replacement">>, Value),
        closed(Replacement, [<<"blind_retry">>, <<"max_replacements_per_primary_cell">>,
            <<"allowed_only_when">>, <<"forbidden_when">>], [<<"policy">>, <<"replacement">>]),
        exact(maps:get(<<"blind_retry">>, Replacement), false, [<<"policy">>, <<"replacement">>]),
        exact(maps:get(<<"max_replacements_per_primary_cell">>, Replacement), 1, [<<"policy">>, <<"replacement">>]),
        exact(maps:get(<<"allowed_only_when">>, Replacement), [<<"transport-failure-before-response">>, <<"timeout-before-response-metadata">>], [<<"policy">>, <<"replacement">>]),
        exact(maps:get(<<"forbidden_when">>, Replacement), [<<"definitive-response-received">>,
            <<"definitive-refusal">>, <<"truncated">>, <<"malformed-output">>,
            <<"score-failure">>, <<"uncertain-submission">>], [<<"policy">>, <<"replacement">>]),
        Retention = maps:get(<<"retention">>, Value),
        closed(Retention, [<<"retain">>, <<"exclude">>, <<"path">>, <<"minimum_days">>], [<<"policy">>, <<"retention">>]),
        exact(maps:get(<<"retain">>, Retention), [<<"redacted-prompt">>, <<"raw-response">>,
            <<"normalized-response">>, <<"deterministic-score">>, <<"bounded-request-metadata">>,
            <<"provider-token-usage">>, <<"content-digest">>], [<<"policy">>, <<"retention">>]),
        exact(maps:get(<<"exclude">>, Retention), [<<"credential">>, <<"authorization-header">>,
            <<"unredacted-secret">>, <<"provider-internal-trace">>], [<<"policy">>, <<"retention">>]),
        exact(maps:get(<<"path">>, Retention), <<"build/compact-projection-fidelity/phase-05/evidence">>, [<<"policy">>, <<"retention">>]),
        exact(maps:get(<<"minimum_days">>, Retention), 365, [<<"policy">>, <<"retention">>]),
        Triggers = maps:get(<<"invalid_campaign_triggers">>, Value),
        exact(Triggers, [<<"model-identifier-drift">>, <<"model-manifest-drift">>,
            <<"provider-parameter-drift">>, <<"tokenizer-version-drift">>,
            <<"case-or-schedule-digest-drift">>, <<"request-ceiling-exceeded">>,
            <<"compute-ceiling-exceeded">>, <<"unregistered-replacement">>,
            <<"missing-provider-token-usage">>, <<"model-visible-call-before-authorization">>],
            [<<"policy">>, <<"invalid_campaign_triggers">>]),
        {ok, #{<<"format">> => <<"alang-compact-policy-evidence-v1">>,
            <<"network_default">> => <<"disabled">>, <<"primary_requests">> => 2304,
            <<"hard_request_ceiling">> => 4608, <<"local_compute_minutes">> => 9600,
            <<"credentials_required">> => 0, <<"invalid_campaign_triggers">> => 10}}
    catch throw:{compact_registration_error, Path, Reason} -> {error, {compact_registration_error, Path, Reason}} end.

decode_all([], Acc) -> {ok, Acc};
decode_all([{Name, Path} | Rest], Acc) ->
    case alang_fidelity_json:decode_file(Path) of
        {ok, Value} -> decode_all(Rest, Acc#{Name => Value});
        {error, Reason} -> {error, {compact_registration_error, [atom_to_binary(Name)], Reason}}
    end.

closed(Value, Keys, Path) ->
    ensure(is_map(Value), Path, expected_object),
    Actual = maps:keys(Value),
    ensure(Actual -- Keys =:= [], Path, {unknown_fields, lists:sort(Actual -- Keys)}),
    ensure(Keys -- Actual =:= [], Path, {missing_fields, lists:sort(Keys -- Actual)}).
exact(Value, Expected, Path) -> ensure(Value =:= Expected, Path, {expected_exact_value, Expected, Value}).
nonempty(Value, Path) -> ensure(is_binary(Value) andalso byte_size(Value) > 0, Path, expected_nonempty_string).
sha256(Value, Path) -> ensure(is_binary(Value) andalso re:run(Value, <<"^[0-9a-f]{64}$">>, [{capture, none}]) =:= match, Path, expected_sha256).
ensure(true, _Path, _Reason) -> ok;
ensure(false, Path, Reason) -> throw({compact_registration_error, Path, Reason}).
