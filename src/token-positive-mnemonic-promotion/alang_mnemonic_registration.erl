-module(alang_mnemonic_registration).

-export([load/1, validate_policy/1, validate_profiles/1,
    validate_prompts/1, validate_tokenizers/1]).

-define(PROMPT_SHA256, <<"1adfed75683c6da2867f4666bbb0502b1b6d5705147b7a61a76ead09fbc7df11">>).
-define(PROTOCOLS, [<<"action-completion">>, <<"comprehension">>,
    <<"diagnostic-repair">>, <<"generation">>]).

-spec load(file:filename()) -> {ok, map()} | {error, term()}.
load(AssetsDirectory) ->
    Campaign = filename:join(AssetsDirectory, "campaign"),
    Inputs = [{profiles, "provider-profiles-v1.json"}, {tokenizers, "tokenizer-profiles-v1.json"},
        {policy, "campaign-policy-v1.json"}, {prompts, "prompt-policy-v1.json"}],
    case decode_all(Campaign, Inputs, #{}) of
        {ok, Values} -> combine(AssetsDirectory, Campaign, Values);
        {error, _} = Error -> Error
    end.

combine(AssetsDirectory, Campaign, Values) ->
    Profiles = maps:get(profiles, Values), Tokenizers = maps:get(tokenizers, Values),
    Policy = maps:get(policy, Values), Prompts = maps:get(prompts, Values),
    case {alang_mnemonic_corpus:load(AssetsDirectory), validate_profiles(Profiles),
            validate_tokenizers(Tokenizers), validate_policy(Policy), validate_prompts(Prompts),
            prompt_digest(filename:join(Campaign, "prompt-policy-v1.json"))} of
        {{ok, Corpus}, {ok, ProfileEvidence}, {ok, TokenizerEvidence}, {ok, PolicyEvidence},
                {ok, PromptEvidence}, {ok, PromptDigest}} ->
            {ok, #{
                <<"format">> => <<"alang-token-positive-registration-evidence-v1">>,
                <<"corpus">> => Corpus, <<"profiles">> => ProfileEvidence,
                <<"tokenizers">> => TokenizerEvidence, <<"policy">> => PolicyEvidence,
                <<"prompts">> => PromptEvidence#{<<"sha256">> => PromptDigest},
                <<"hosted_calls_observed">> => 0, <<"network_authorized">> => false
            }};
        Results -> first_error(tuple_to_list(Results))
    end.

-spec validate_profiles(term()) -> {ok, map()} | {error, term()}.
validate_profiles(Value) -> alang_compact_registration:validate_profiles(Value).

-spec validate_tokenizers(term()) -> {ok, map()} | {error, term()}.
validate_tokenizers(Value) -> alang_compact_registration:validate_tokenizers(Value).

-spec validate_policy(term()) -> {ok, map()} | {error, term()}.
validate_policy(Value) ->
    try
        Keys = [<<"format">>, <<"network_default">>, <<"live_opt_in">>, <<"availability">>,
            <<"design">>, <<"per_request_ceilings">>, <<"campaign_ceilings">>,
            <<"replacement">>, <<"retention">>, <<"invalid_campaign_triggers">>],
        closed(Value, Keys, [<<"policy">>]),
        exact(maps:get(<<"format">>, Value), <<"alang-token-positive-campaign-policy-v1">>, [<<"policy">>, <<"format">>]),
        exact(maps:get(<<"network_default">>, Value), <<"disabled">>, [<<"policy">>, <<"network_default">>]),
        exact(maps:get(<<"live_opt_in">>, Value), #{
            <<"environment_variable">> => <<"ALANG_ALLOW_MNEMONIC_MODEL_CALLS">>,
            <<"required_value">> => <<"1">>, <<"endpoint">> => <<"http://127.0.0.1:11434">>,
            <<"credentials_required">> => []}, [<<"policy">>, <<"live_opt_in">>]),
        exact(maps:get(<<"availability">>, Value), #{
            <<"probe">> => <<"ollama-manifest-sha256">>,
            <<"all_profiles_required_before_authorization">> => true,
            <<"missing_profile">> => <<"block-campaign">>,
            <<"manifest_mismatch">> => <<"invalidate-campaign">>}, [<<"policy">>, <<"availability">>]),
        exact(maps:get(<<"design">>, Value), #{
            <<"semantic_cases">> => 48, <<"primary_cells">> => 1536,
            <<"hard_request_ceiling">> => 3072, <<"model_families">> => 2,
            <<"paired_repetitions">> => 2, <<"protocols">> => 4,
            <<"conditions">> => 2}, [<<"policy">>, <<"design">>]),
        exact(maps:get(<<"per_request_ceilings">>, Value), #{
            <<"accepted_source_bytes">> => 8192, <<"accepted_input_bytes">> => 32768,
            <<"accepted_response_bytes">> => 8192, <<"max_output_tokens">> => 8192,
            <<"timeout_ms">> => 120000}, [<<"policy">>, <<"per_request_ceilings">>]),
        exact(maps:get(<<"campaign_ceilings">>, Value), #{
            <<"primary_requests">> => 1536, <<"all_requests">> => 3072,
            <<"local_compute_minutes">> => 6400, <<"monetary_cost_usd">> => 0},
            [<<"policy">>, <<"campaign_ceilings">>]),
        validate_replacement(maps:get(<<"replacement">>, Value)),
        validate_retention(maps:get(<<"retention">>, Value)),
        exact(maps:get(<<"invalid_campaign_triggers">>, Value), [
            <<"model-identifier-drift">>, <<"model-manifest-drift">>,
            <<"provider-parameter-drift">>, <<"tokenizer-version-drift">>,
            <<"r2-reference-drift">>, <<"case-or-schedule-digest-drift">>,
            <<"request-ceiling-exceeded">>, <<"compute-ceiling-exceeded">>,
            <<"unregistered-replacement">>, <<"missing-provider-token-usage">>,
            <<"model-visible-call-before-authorization">>], [<<"policy">>, <<"invalid_campaign_triggers">>]),
        {ok, #{<<"format">> => <<"alang-token-positive-policy-evidence-v1">>,
            <<"primary_requests">> => 1536, <<"hard_request_ceiling">> => 3072,
            <<"network_default_disabled">> => true, <<"explicit_authorization_required">> => true}}
    catch throw:{mnemonic_registration_error, Path, Reason} ->
        {error, {mnemonic_registration_error, Path, Reason}}
    end.

validate_replacement(Value) ->
    exact(Value, #{
        <<"blind_retry">> => false, <<"max_replacements_per_primary_cell">> => 1,
        <<"allowed_only_when">> => [<<"transport-failure-before-response">>,
            <<"timeout-before-response-metadata">>],
        <<"forbidden_when">> => [<<"definitive-response-received">>,
            <<"definitive-refusal">>, <<"truncated">>, <<"malformed-output">>,
            <<"score-failure">>, <<"uncertain-submission">>]}, [<<"policy">>, <<"replacement">>]).

validate_retention(Value) ->
    exact(Value, #{
        <<"retain">> => [<<"redacted-prompt">>, <<"raw-response">>,
            <<"normalized-response">>, <<"deterministic-score">>,
            <<"bounded-request-metadata">>, <<"provider-token-usage">>, <<"content-digest">>],
        <<"exclude">> => [<<"credential">>, <<"authorization-header">>,
            <<"unredacted-secret">>, <<"provider-internal-trace">>],
        <<"path">> => <<"build/token-positive-mnemonic-promotion/phase-03/evidence">>,
        <<"minimum_days">> => 365}, [<<"policy">>, <<"retention">>]).

-spec validate_prompts(term()) -> {ok, map()} | {error, term()}.
validate_prompts(Value) ->
    try
        Keys = [<<"format">>, <<"single_turn">>, <<"conversation_memory">>, <<"examples">>,
            <<"common_instruction">>, <<"request_order">>, <<"protocols">>, <<"legends">>,
            <<"leakage_forbidden">>, <<"definitive_response">>],
        closed(Value, Keys, [<<"prompts">>]),
        exact(maps:get(<<"format">>, Value), <<"alang-token-positive-prompt-policy-v1">>, [<<"prompts">>, <<"format">>]),
        exact(maps:get(<<"single_turn">>, Value), true, [<<"prompts">>, <<"single_turn">>]),
        exact(maps:get(<<"conversation_memory">>, Value), false, [<<"prompts">>, <<"conversation_memory">>]),
        exact(maps:get(<<"examples">>, Value), false, [<<"prompts">>, <<"examples">>]),
        nonempty(maps:get(<<"common_instruction">>, Value), [<<"prompts">>, <<"common_instruction">>]),
        exact(maps:get(<<"request_order">>, Value), [<<"opaque-trial-id">>,
            <<"common-instruction">>, <<"protocol-instruction">>, <<"condition-legend">>,
            <<"case-material">>, <<"output-contract">>], [<<"prompts">>, <<"request_order">>]),
        Protocols = maps:get(<<"protocols">>, Value),
        exact(lists:sort([maps:get(<<"id">>, P) || P <- Protocols]), ?PROTOCOLS, [<<"prompts">>, <<"protocols">>]),
        lists:foreach(fun(P) ->
            closed(P, [<<"id">>, <<"conditions">>, <<"instruction">>, <<"output_contract">>], [<<"prompts">>, <<"protocols">>]),
            exact(maps:get(<<"conditions">>, P), [<<"P0">>, <<"P1">>], [<<"prompts">>, <<"conditions">>]),
            nonempty(maps:get(<<"instruction">>, P), [<<"prompts">>, <<"instruction">>]),
            nonempty(maps:get(<<"output_contract">>, P), [<<"prompts">>, <<"output_contract">>])
        end, Protocols),
        Legends = maps:get(<<"legends">>, Value),
        exact(lists:sort([maps:get(<<"condition">>, L) || L <- Legends]), [<<"P0">>, <<"P1">>], [<<"prompts">>, <<"legends">>]),
        lists:foreach(fun(L) -> closed(L, [<<"condition">>, <<"title">>, <<"content">>], [<<"prompts">>, <<"legends">>]) end, Legends),
        ensure(lists:member(<<"answer-key">>, maps:get(<<"leakage_forbidden">>, Value)), [<<"prompts">>], missing_answer_key_rule),
        exact(maps:get(<<"definitive_response">>, Value), <<"first-provider-response-only">>, [<<"prompts">>, <<"definitive_response">>]),
        {ok, #{<<"format">> => <<"alang-token-positive-prompt-evidence-v1">>,
            <<"protocols">> => 4, <<"conditions_per_protocol">> => 2,
            <<"single_turn">> => true, <<"examples">> => false}}
    catch throw:{mnemonic_registration_error, Path, Reason} ->
        {error, {mnemonic_registration_error, Path, Reason}}
    end.

prompt_digest(Path) ->
    case file:read_file(Path) of
        {ok, Bytes} ->
            Digest = alang_fidelity_json:hex(crypto:hash(sha256, Bytes)),
            case Digest =:= ?PROMPT_SHA256 of
                true -> {ok, Digest};
                false -> {error, {mnemonic_registration_error, [<<"prompts">>, <<"sha256">>],
                    {expected_frozen_value, ?PROMPT_SHA256, Digest}}}
            end;
        {error, Reason} -> {error, {mnemonic_registration_error, [<<"prompts">>], {read_failed, Reason}}}
    end.

decode_all(_Campaign, [], Acc) -> {ok, Acc};
decode_all(Campaign, [{Key, Name} | Rest], Acc) ->
    case alang_fidelity_json:decode_file(filename:join(Campaign, Name)) of
        {ok, Value} -> decode_all(Campaign, Rest, Acc#{Key => Value});
        {error, Reason} -> {error, {mnemonic_registration_error, [atom_to_binary(Key)], Reason}}
    end.

first_error([{error, _} = Error | _]) -> Error;
first_error([_ | Rest]) -> first_error(Rest).
closed(Value, Keys, Path) ->
    ensure(is_map(Value), Path, expected_object), Actual = maps:keys(Value),
    ensure(Actual -- Keys =:= [], Path, {unknown_fields, lists:sort(Actual -- Keys)}),
    ensure(Keys -- Actual =:= [], Path, {missing_fields, lists:sort(Keys -- Actual)}).
exact(Value, Expected, Path) -> ensure(Value =:= Expected, Path, {expected_frozen_value, Expected, Value}).
nonempty(Value, Path) -> ensure(is_binary(Value) andalso byte_size(Value) > 0, Path, expected_nonempty_string).
ensure(true, _Path, _Reason) -> ok;
ensure(false, Path, Reason) -> throw({mnemonic_registration_error, Path, Reason}).
