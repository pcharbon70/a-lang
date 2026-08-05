-module(alang_fidelity_corpus).

-export([
    validate/1,
    validate_campaign/1,
    validate_campaign_policy/1,
    validate_candidate_binary/3,
    validate_corpus/1,
    validate_manifest/2,
    validate_provider_profiles/1
]).

-define(FAMILIES, [
    <<"single-model-artifact">>,
    <<"repair-and-publish">>,
    <<"attenuated-delegation">>
]).
-define(VARIANTS, [
    <<"simple">>,
    <<"constraint-heavy">>,
    <<"scope-budget">>,
    <<"error-branch">>,
    <<"missing-information">>,
    <<"irrelevant-context">>,
    <<"prompt-injection">>,
    <<"semantic-perturbation">>
]).

-spec validate(file:filename()) -> {ok, map()} | {error, term()}.
validate(Base) ->
    CorpusDirectory = filename:join(Base, "corpus"),
    CampaignDirectory = filename:join(Base, "campaign"),
    case validate_corpus(CorpusDirectory) of
        {ok, CorpusEvidence} ->
            case validate_campaign(CampaignDirectory) of
                {ok, CampaignEvidence} ->
                    {ok, #{
                        <<"format">> => <<"alang-fidelity-phase1-registration-v1">>,
                        <<"corpus">> => CorpusEvidence,
                        <<"campaign">> => CampaignEvidence,
                        <<"hosted_calls_observed">> => 0
                    }};
                {error, _} = Error -> Error
            end;
        {error, _} = Error -> Error
    end.

-spec validate_corpus(file:filename()) -> {ok, map()} | {error, term()}.
validate_corpus(CorpusDirectory) ->
    ManifestPath = filename:join(CorpusDirectory, "corpus-manifest-v1.json"),
    case alang_fidelity_json:decode_file(ManifestPath) of
        {ok, Manifest} -> validate_manifest(Manifest, CorpusDirectory);
        {error, Reason} -> {error, {corpus_error, [<<"manifest">>], Reason}}
    end.

-spec validate_manifest(term(), file:filename()) -> {ok, map()} | {error, term()}.
validate_manifest(Manifest, CorpusDirectory) ->
    try
        ManifestKeys = [<<"format">>, <<"families">>, <<"variants">>, <<"cases">>],
        closed(Manifest, ManifestKeys, ManifestKeys, [<<"manifest">>]),
        exact(maps:get(<<"format">>, Manifest), <<"alang-fidelity-corpus-v1">>, [<<"manifest">>, <<"format">>]),
        exact(maps:get(<<"families">>, Manifest), ?FAMILIES, [<<"manifest">>, <<"families">>]),
        exact(maps:get(<<"variants">>, Manifest), ?VARIANTS, [<<"manifest">>, <<"variants">>]),
        Cases = maps:get(<<"cases">>, Manifest),
        ensure(is_list(Cases), [<<"manifest">>, <<"cases">>], expected_array),
        ensure(length(Cases) =:= 24, [<<"manifest">>, <<"cases">>], {expected_case_count, 24, length(Cases)}),
        CaseEvidence = [validate_case(Case, CorpusDirectory, Index) || {Case, Index} <- indexed(Cases)],
        CaseIds = [maps:get(<<"case_id">>, Case) || Case <- Cases],
        unique(CaseIds, [<<"manifest">>, <<"cases">>], duplicate_case_id),
        Cells = [{maps:get(<<"family">>, Case), maps:get(<<"variant">>, Case)} || Case <- Cases],
        unique(Cells, [<<"manifest">>, <<"cases">>], duplicate_family_variant_cell),
        ExpectedCells = [{Family, Variant} || Family <- ?FAMILIES, Variant <- ?VARIANTS],
        exact(lists:sort(Cells), lists:sort(ExpectedCells), [<<"manifest">>, <<"cases">>]),
        assert_file_inventory(CorpusDirectory),
        CandidateHashes = [maps:get(<<"candidate_sha256">>, Evidence) || Evidence <- CaseEvidence],
        ControlHashes = [maps:get(<<"control_sha256">>, Evidence) || Evidence <- CaseEvidence],
        unique(CandidateHashes, [<<"manifest">>, <<"cases">>], duplicate_candidate_document),
        unique(ControlHashes, [<<"manifest">>, <<"cases">>], duplicate_control_document),
        {ok, #{
            <<"format">> => <<"alang-fidelity-corpus-evidence-v1">>,
            <<"semantic_cases">> => 24,
            <<"candidate_documents">> => 24,
            <<"control_documents">> => 24,
            <<"answer_keys">> => 24,
            <<"family_variant_cells">> => 24,
            <<"balanced">> => true,
            <<"semantic_digests">> => lists:sort([maps:get(<<"semantic_digest">>, Evidence) || Evidence <- CaseEvidence])
        }}
    catch
        throw:{corpus_error, Path, Reason} ->
            {error, {corpus_error, Path, Reason}}
    end.

-spec validate_campaign(file:filename()) -> {ok, map()} | {error, term()}.
validate_campaign(CampaignDirectory) ->
    ProfilesPath = filename:join(CampaignDirectory, "provider-profiles-v1.json"),
    PolicyPath = filename:join(CampaignDirectory, "campaign-policy-v1.json"),
    PromptPath = filename:join(CampaignDirectory, "prompt-template-v1.txt"),
    case alang_fidelity_json:decode_file(ProfilesPath) of
        {ok, Profiles} ->
            case validate_provider_profiles(Profiles) of
                {ok, _} ->
                    case alang_fidelity_json:decode_file(PolicyPath) of
                        {ok, Policy} ->
                            case validate_campaign_policy(Policy) of
                                {ok, _} -> validate_prompt(PromptPath, Profiles, Policy);
                                {error, _} = Error -> Error
                            end;
                        {error, Reason} -> {error, {campaign_error, [<<"policy">>], Reason}}
                    end;
                {error, _} = Error -> Error
            end;
        {error, Reason} -> {error, {campaign_error, [<<"profiles">>], Reason}}
    end.

-spec validate_provider_profiles(term()) -> {ok, map()} | {error, term()}.
validate_provider_profiles(Value) ->
    validate_exact_campaign(Value, expected_provider_profiles(), [<<"profiles">>]).

-spec validate_campaign_policy(term()) -> {ok, map()} | {error, term()}.
validate_campaign_policy(Value) ->
    validate_exact_campaign(Value, expected_campaign_policy(), [<<"policy">>]).

-spec validate_candidate_binary(binary(), binary(), binary()) -> {ok, map()} | {error, term()}.
validate_candidate_binary(Binary, CaseId, Digest) ->
    try
        validate_candidate_document(Binary, CaseId, Digest, [<<"candidate">>]),
        {ok, #{<<"case_id">> => CaseId, <<"semantic_digest">> => Digest}}
    catch
        throw:{corpus_error, Path, Reason} -> {error, {corpus_error, Path, Reason}}
    end.

validate_case(Case, CorpusDirectory, Index) ->
    Path = [<<"manifest">>, <<"cases">>, Index],
    Keys = [
        <<"format">>, <<"case_id">>, <<"family">>, <<"variant">>,
        <<"candidate">>, <<"control">>, <<"answer_key">>,
        <<"semantic_digest">>, <<"review">>
    ],
    closed(Case, Keys, Keys, Path),
    exact(maps:get(<<"format">>, Case), <<"alang-semantic-pair-v1">>, Path ++ [<<"format">>]),
    CaseId = maps:get(<<"case_id">>, Case),
    identifier(CaseId, Path ++ [<<"case_id">>]),
    Family = maps:get(<<"family">>, Case),
    enum(Family, ?FAMILIES, Path ++ [<<"family">>]),
    Variant = maps:get(<<"variant">>, Case),
    enum(Variant, ?VARIANTS, Path ++ [<<"variant">>]),
    exact(CaseId, expected_case_id(Family, Variant), Path ++ [<<"case_id">>]),
    Digest = maps:get(<<"semantic_digest">>, Case),
    sha256(Digest, Path ++ [<<"semantic_digest">>]),
    Review = maps:get(<<"review">>, Case),
    ReviewKeys = [<<"hand_authored">>, <<"equivalent_detail">>, <<"no_answer_serialization">>, <<"no_condition_specific_demonstration">>],
    closed(Review, ReviewKeys, ReviewKeys, Path ++ [<<"review">>]),
    lists:foreach(fun(Key) -> exact(maps:get(Key, Review), true, Path ++ [<<"review">>, Key]) end, ReviewKeys),
    Candidate = validate_representation_ref(
        maps:get(<<"candidate">>, Case),
        <<"alang-source-v2">>,
        Digest,
        Family,
        CaseId,
        <<".alang">>,
        Path ++ [<<"candidate">>]
    ),
    Control = validate_representation_ref(
        maps:get(<<"control">>, Case),
        <<"alang-task-json-v1">>,
        Digest,
        Family,
        CaseId,
        <<".json">>,
        Path ++ [<<"control">>]
    ),
    Answer = validate_answer_ref(
        maps:get(<<"answer_key">>, Case), Family, CaseId, Path ++ [<<"answer_key">>]
    ),
    CandidatePath = resolve(CorpusDirectory, maps:get(<<"path">>, Candidate), Path ++ [<<"candidate">>, <<"path">>]),
    ControlPath = resolve(CorpusDirectory, maps:get(<<"path">>, Control), Path ++ [<<"control">>, <<"path">>]),
    AnswerPath = resolve(CorpusDirectory, maps:get(<<"path">>, Answer), Path ++ [<<"answer_key">>, <<"path">>]),
    assert_content_hash(CandidatePath, maps:get(<<"content_sha256">>, Candidate), Path ++ [<<"candidate">>]),
    assert_content_hash(ControlPath, maps:get(<<"content_sha256">>, Control), Path ++ [<<"control">>]),
    assert_content_hash(AnswerPath, maps:get(<<"content_sha256">>, Answer), Path ++ [<<"answer_key">>]),
    validate_candidate_source(CandidatePath, CaseId, Digest, Path ++ [<<"candidate">>]),
    ControlSemantic = validate_control_file(ControlPath, CaseId, Digest, Path ++ [<<"control">>]),
    Expected = validate_answer_file(AnswerPath, CaseId, Digest, Path ++ [<<"answer_key">>]),
    exact(ControlSemantic, alang_fidelity_contract:normalize(Expected), Path ++ [<<"semantic_digest">>]),
    validate_variant(Variant, Expected, Path),
    validate_family(Family, Variant, Expected, Path),
    #{
        <<"case_id">> => CaseId,
        <<"semantic_digest">> => Digest,
        <<"candidate_sha256">> => maps:get(<<"content_sha256">>, Candidate),
        <<"control_sha256">> => maps:get(<<"content_sha256">>, Control)
    }.

validate_representation_ref(Value, Format, Digest, Family, CaseId, Extension, Path) ->
    Keys = [<<"format">>, <<"path">>, <<"content_sha256">>, <<"semantic_digest">>],
    closed(Value, Keys, Keys, Path),
    exact(maps:get(<<"format">>, Value), Format, Path ++ [<<"format">>]),
    exact(maps:get(<<"semantic_digest">>, Value), Digest, Path ++ [<<"semantic_digest">>]),
    sha256(maps:get(<<"content_sha256">>, Value), Path ++ [<<"content_sha256">>]),
    ExpectedPath = <<Family/binary, "/", CaseId/binary, Extension/binary>>,
    exact(maps:get(<<"path">>, Value), ExpectedPath, Path ++ [<<"path">>]),
    Value.

validate_answer_ref(Value, Family, CaseId, Path) ->
    Keys = [<<"format">>, <<"path">>, <<"content_sha256">>],
    closed(Value, Keys, Keys, Path),
    exact(maps:get(<<"format">>, Value), <<"alang-answer-key-v1">>, Path ++ [<<"format">>]),
    sha256(maps:get(<<"content_sha256">>, Value), Path ++ [<<"content_sha256">>]),
    ExpectedPath = <<Family/binary, "/", CaseId/binary, ".answer.json">>,
    exact(maps:get(<<"path">>, Value), ExpectedPath, Path ++ [<<"path">>]),
    Value.

validate_candidate_source(Path, CaseId, Digest, ErrorPath) ->
    Binary = read_file(Path, ErrorPath),
    validate_candidate_document(Binary, CaseId, Digest, ErrorPath).

validate_candidate_document(Binary, CaseId, Digest, ErrorPath) ->
    ensure(byte_size(Binary) =< 8192, ErrorPath, source_document_too_large),
    ensure(valid_utf8(Binary), ErrorPath, invalid_utf8),
    [First | Lines] = binary:split(Binary, <<"\n">>, [global]),
    exact(First, <<"#!alang-source-v2">>, ErrorPath ++ [<<"header">>]),
    exact(single_header(Lines, <<"// corpus-case: ">>, ErrorPath), CaseId, ErrorPath ++ [<<"case_id">>]),
    exact(single_header(Lines, <<"// semantic-sha256: ">>, ErrorPath), Digest, ErrorPath ++ [<<"semantic_digest">>]),
    Marker = <<"// model-visible-begin\n">>,
    case binary:split(Binary, Marker) of
        [Metadata, Visible] ->
            ensure(binary:match(Metadata, <<"PENDING">>) =:= nomatch, ErrorPath, pending_digest),
            ensure(binary:match(Visible, Marker) =:= nomatch, ErrorPath, duplicate_model_visible_marker),
            ensure(binary:match(Visible, <<"task ", CaseId/binary, " {">>) =/= nomatch, ErrorPath, missing_task_declaration),
            lists:foreach(
                fun(Forbidden) ->
                    ensure(binary:match(Visible, Forbidden) =:= nomatch, ErrorPath, {model_visible_leak, Forbidden})
                end,
                [<<"semantic-sha256">>, <<"alang-answer-key-v1">>, <<"alang_task_comprehension_v1">>, <<"\"expected\"">>]
            );
        _ ->
            fail(ErrorPath, missing_model_visible_marker)
    end.

validate_control_file(Path, CaseId, Digest, ErrorPath) ->
    Binary = read_file(Path, ErrorPath),
    ensure(byte_size(Binary) =< 8192, ErrorPath, control_document_too_large),
    lists:foreach(
        fun(Forbidden) ->
            ensure(binary:match(Binary, Forbidden) =:= nomatch, ErrorPath, {control_leaks_answer, Forbidden})
        end,
        [<<"alang-answer-key-v1">>, <<"semantic_digest">>]
    ),
    case alang_fidelity_representation:decode_control(Binary) of
        {ok, Decoded} ->
            {ok, Raw} = alang_fidelity_json:decode(Binary),
            exact(maps:get(<<"case_id">>, Raw), CaseId, ErrorPath ++ [<<"case_id">>]),
            exact(maps:get(<<"semantic_digest">>, Decoded), Digest, ErrorPath ++ [<<"semantic_digest">>]),
            maps:get(<<"semantic">>, Decoded);
        {error, Reason} -> fail(ErrorPath, {invalid_control, Reason})
    end.

validate_answer_file(Path, CaseId, Digest, ErrorPath) ->
    Binary = read_file(Path, ErrorPath),
    case alang_fidelity_contract:decode_answer_key(Binary) of
        {ok, Answer} ->
            exact(maps:get(<<"case_id">>, Answer), CaseId, ErrorPath ++ [<<"case_id">>]),
            exact(maps:get(<<"semantic_digest">>, Answer), Digest, ErrorPath ++ [<<"semantic_digest">>]),
            maps:get(<<"expected">>, Answer);
        {error, Reason} -> fail(ErrorPath, {invalid_answer_key, Reason})
    end.

validate_variant(<<"simple">>, Expected, Path) ->
    exact(maps:get(<<"terminal_class">>, Expected), <<"complete">>, Path ++ [<<"variant">>]);
validate_variant(<<"constraint-heavy">>, Expected, Path) ->
    ensure(length(maps:get(<<"goal_facts">>, Expected)) >= 4, Path ++ [<<"variant">>], insufficient_constraints),
    ensure(length(maps:get(<<"completion_predicates">>, Expected)) >= 4, Path ++ [<<"variant">>], insufficient_completion_constraints);
validate_variant(<<"scope-budget">>, Expected, Path) ->
    Budgets = maps:get(<<"budgets">>, Expected),
    ensure(maps:get(<<"output_bytes">>, Budgets) =< 1536, Path ++ [<<"variant">>], scope_budget_not_tight);
validate_variant(<<"error-branch">>, Expected, Path) ->
    ensure(maps:get(<<"error_branches">>, Expected) =/= [], Path ++ [<<"variant">>], missing_error_branch);
validate_variant(<<"missing-information">>, Expected, Path) ->
    exact(maps:get(<<"terminal_class">>, Expected), <<"needs-clarification">>, Path ++ [<<"variant">>]),
    ensure(maps:get(<<"clarification_needs">>, Expected) =/= [], Path ++ [<<"variant">>], missing_clarification);
validate_variant(<<"irrelevant-context">>, Expected, Path) ->
    Inputs = maps:get(<<"inputs">>, Expected),
    ensure(lists:any(fun(Input) -> maps:get(<<"required">>, Input) =:= false end, Inputs), Path ++ [<<"variant">>], missing_irrelevant_optional_input);
validate_variant(<<"prompt-injection">>, Expected, Path) ->
    Facts = iolist_to_binary(lists:join(<<" ">>, maps:get(<<"goal_facts">>, Expected))),
    Lower = string:lowercase(Facts),
    ensure(
        binary:match(Lower, <<"untrusted">>) =/= nomatch orelse binary:match(Lower, <<"embedded">>) =/= nomatch,
        Path ++ [<<"variant">>],
        missing_injection_boundary
    );
validate_variant(<<"semantic-perturbation">>, _Expected, _Path) ->
    ok.

validate_family(_Family, <<"missing-information">>, _Expected, _Path) ->
    ok;
validate_family(<<"single-model-artifact">>, _Variant, Expected, Path) ->
    Operations = operations(Expected),
    ensure(lists:member(<<"model.generate">>, Operations), Path ++ [<<"family">>], missing_model_generation),
    ensure(lists:member(<<"workspace.write">>, Operations), Path ++ [<<"family">>], missing_workspace_publish),
    ensure(not lists:member(<<"model.repair">>, Operations), Path ++ [<<"family">>], unexpected_repair),
    exact(maps:get(<<"child_attenuation">>, Expected), null, Path ++ [<<"family">>]);
validate_family(<<"repair-and-publish">>, _Variant, Expected, Path) ->
    Operations = operations(Expected),
    ensure(lists:member(<<"model.generate">>, Operations), Path ++ [<<"family">>], missing_model_generation),
    ensure(lists:member(<<"model.repair">>, Operations), Path ++ [<<"family">>], missing_model_repair),
    ensure(lists:member(<<"workspace.write">>, Operations), Path ++ [<<"family">>], missing_workspace_publish);
validate_family(<<"attenuated-delegation">>, _Variant, Expected, Path) ->
    Operations = operations(Expected),
    ensure(lists:member(<<"model.generate">>, Operations), Path ++ [<<"family">>], missing_parent_model_judgment),
    ensure(lists:member(<<"child.run">>, Operations), Path ++ [<<"family">>], missing_child_run),
    ensure(is_map(maps:get(<<"child_attenuation">>, Expected)), Path ++ [<<"family">>], missing_child_attenuation).

validate_prompt(PromptPath, Profiles, Policy) ->
    try
        Prompt = read_file(PromptPath, [<<"prompt">>]),
        ensure(byte_size(Prompt) =< 4096, [<<"prompt">>], prompt_too_large),
        ensure(count(Prompt, <<"@@TASK_SPECIFICATION@@">>) =:= 1, [<<"prompt">>], expected_one_task_placeholder),
        Lower = string:lowercase(Prompt),
        lists:foreach(
            fun(Forbidden) ->
                ensure(binary:match(Lower, Forbidden) =:= nomatch, [<<"prompt">>], {prompt_leaks_condition, Forbidden})
            end,
            [<<"answer key">>, <<"semantic digest">>, <<"condition label">>, <<"a-lang source">>, <<"json control">>]
        ),
        Ceilings = maps:get(<<"ceilings">>, Policy),
        {ok, #{
            <<"format">> => <<"alang-fidelity-campaign-evidence-v1">>,
            <<"model_profiles">> => length(maps:get(<<"profiles">>, Profiles)),
            <<"primary_call_ceiling">> => maps:get(<<"primary_calls">>, Ceilings),
            <<"all_call_ceiling">> => maps:get(<<"all_calls">>, Ceilings),
            <<"cost_ceiling_usd">> => maps:get(<<"cost_usd">>, Ceilings),
            <<"network_default">> => maps:get(<<"network_default">>, Policy),
            <<"prompt_sha256">> => content_sha(PromptPath),
            <<"live_opt_in_required">> => true
        }}
    catch
        throw:{corpus_error, Path, Reason} -> {error, {campaign_error, Path, Reason}}
    end.

validate_exact_campaign(Value, Expected, _Path) when Value =:= Expected ->
    {ok, Value};
validate_exact_campaign(Value, Expected, Path) ->
    {error, {
        campaign_error,
        Path,
        {frozen_contract_mismatch, alang_fidelity_json:digest(Expected), alang_fidelity_json:digest(Value)}
    }}.

expected_provider_profiles() ->
    #{
        <<"format">> => <<"alang-fidelity-provider-profiles-v1">>,
        <<"profiles">> => [
            profile(<<"openai">>, <<"OpenAI">>, <<"Responses">>, <<"gpt-5.6-terra">>),
            profile(<<"anthropic">>, <<"Anthropic">>, <<"Messages">>, <<"claude-sonnet-5">>)
        ]
    }.

profile(Family, Provider, Api, ModelId) ->
    #{
        <<"family">> => Family,
        <<"provider">> => Provider,
        <<"api">> => Api,
        <<"model_id">> => ModelId,
        <<"effort">> => <<"medium">>,
        <<"turns">> => 1,
        <<"tools_enabled">> => false,
        <<"provider_schema_constraint">> => false,
        <<"max_output_tokens">> => 8192,
        <<"accepted_output_bytes">> => 8192,
        <<"exact_identifier_required">> => true
    }.

expected_campaign_policy() ->
    #{
        <<"format">> => <<"alang-fidelity-campaign-policy-v1">>,
        <<"network_default">> => <<"disabled">>,
        <<"live_opt_in">> => #{
            <<"environment_variable">> => <<"ALANG_ALLOW_LIVE_MODEL_CALLS">>,
            <<"required_value">> => <<"1">>,
            <<"credentials_required">> => [<<"ALANG_OPENAI_API_KEY">>, <<"ALANG_ANTHROPIC_API_KEY">>]
        },
        <<"design">> => #{
            <<"semantic_cases">> => 24,
            <<"conditions">> => 2,
            <<"model_families">> => 2,
            <<"paired_repetitions">> => 3
        },
        <<"ceilings">> => #{
            <<"primary_calls">> => 288,
            <<"all_calls">> => 576,
            <<"cost_usd">> => 200,
            <<"accepted_source_bytes">> => 8192,
            <<"accepted_response_bytes">> => 8192
        },
        <<"replacement">> => #{
            <<"blind_retry">> => false,
            <<"max_replacements_per_primary_cell">> => 1,
            <<"allowed_only_when">> => [
                <<"transport-failure-before-response">>,
                <<"timeout-before-response-metadata">>
            ],
            <<"forbidden_when">> => [
                <<"definitive-response-received">>,
                <<"definitive-refusal">>,
                <<"truncated">>,
                <<"malformed-json">>,
                <<"schema-invalid">>
            ]
        },
        <<"repair">> => #{
            <<"max_per_definitive_response">> => 1,
            <<"allowed_for">> => [<<"malformed-json">>, <<"schema-invalid">>],
            <<"primary_score_changes">> => false,
            <<"counts_toward_all_calls">> => true
        },
        <<"submission_retry">> => #{
            <<"max_per_primary_cell">> => 1,
            <<"allowed_only_when">> => <<"request-proved-not-submitted">>,
            <<"counts_toward_all_calls">> => true
        },
        <<"uncertain_outcomes">> => [
            <<"connection-state-unknown">>,
            <<"provider-accepted-request-without-definitive-response">>
        ],
        <<"retention">> => #{
            <<"retain">> => [
                <<"redacted-prompt">>,
                <<"normalized-response">>,
                <<"deterministic-score">>,
                <<"bounded-request-metadata">>,
                <<"content-digest">>
            ],
            <<"exclude">> => [
                <<"credential">>,
                <<"authorization-header">>,
                <<"unredacted-secret">>,
                <<"provider-internal-trace">>
            ]
        }
    }.

assert_file_inventory(CorpusDirectory) ->
    CandidateFiles = filelib:wildcard(filename:join([CorpusDirectory, "*", "*.alang"])),
    JsonFiles = filelib:wildcard(filename:join([CorpusDirectory, "*", "*.json"])),
    AnswerFiles = [Path || Path <- JsonFiles, string:find(Path, ".answer.json") =/= nomatch],
    ControlFiles = JsonFiles -- AnswerFiles,
    ensure(length(CandidateFiles) =:= 24, [<<"inventory">>], {candidate_file_count, length(CandidateFiles)}),
    ensure(length(ControlFiles) =:= 24, [<<"inventory">>], {control_file_count, length(ControlFiles)}),
    ensure(length(AnswerFiles) =:= 24, [<<"inventory">>], {answer_file_count, length(AnswerFiles)}).

resolve(CorpusDirectory, Relative, Path) ->
    ensure(is_binary(Relative), Path, expected_relative_path),
    Parts = filename:split(binary_to_list(Relative)),
    ensure(length(Parts) =:= 2, Path, unsafe_relative_path),
    ensure(not lists:member("..", Parts), Path, unsafe_relative_path),
    filename:join([CorpusDirectory | Parts]).

assert_content_hash(Path, Expected, ErrorPath) ->
    exact(content_sha(Path), Expected, ErrorPath ++ [<<"content_sha256">>]).

content_sha(Path) ->
    alang_fidelity_json:hex(crypto:hash(sha256, read_file(Path, [<<"file">>]))).

read_file(Path, ErrorPath) ->
    case file:read_file(Path) of
        {ok, Binary} -> Binary;
        {error, Reason} -> fail(ErrorPath, {read_failed, Path, Reason})
    end.

single_header(Lines, Prefix, Path) ->
    Values = [binary:part(Line, byte_size(Prefix), byte_size(Line) - byte_size(Prefix))
              || Line <- Lines, byte_size(Line) >= byte_size(Prefix), binary:part(Line, 0, byte_size(Prefix)) =:= Prefix],
    case Values of
        [Value] -> Value;
        _ -> fail(Path, {expected_one_header, Prefix, length(Values)})
    end.

expected_case_id(<<"single-model-artifact">>, Variant) -> <<"sma-", Variant/binary>>;
expected_case_id(<<"repair-and-publish">>, Variant) -> <<"rap-", Variant/binary>>;
expected_case_id(<<"attenuated-delegation">>, Variant) -> <<"ad-", Variant/binary>>.

operations(Expected) ->
    [maps:get(<<"operation">>, Action) || Action <- maps:get(<<"actions">>, Expected)].

count(Binary, Needle) ->
    length(binary:matches(Binary, Needle)).

closed(Value, Allowed, Required, Path) ->
    ensure(is_map(Value), Path, expected_object),
    Keys = maps:keys(Value),
    Unknown = Keys -- Allowed,
    Missing = Required -- Keys,
    ensure(Unknown =:= [], Path, {unknown_fields, lists:sort(Unknown)}),
    ensure(Missing =:= [], Path, {missing_fields, lists:sort(Missing)}).

identifier(Value, Path) ->
    ensure(is_binary(Value), Path, expected_identifier),
    ensure(re:run(Value, <<"^[a-z][a-z0-9-]{0,63}$">>, [{capture, none}]) =:= match, Path, invalid_identifier).

sha256(Value, Path) ->
    ensure(is_binary(Value), Path, expected_sha256),
    ensure(re:run(Value, <<"^[0-9a-f]{64}$">>, [{capture, none}]) =:= match, Path, expected_sha256).

enum(Value, Allowed, Path) ->
    ensure(lists:member(Value, Allowed), Path, {not_in_closed_enum, Value}).

unique(Values, Path, Reason) ->
    ensure(length(Values) =:= length(lists:usort(Values)), Path, Reason).

exact(Value, Expected, Path) ->
    ensure(Value =:= Expected, Path, {expected_exact_value, Expected, Value}).

valid_utf8(Value) ->
    case unicode:characters_to_list(Value, utf8) of
        List when is_list(List) -> true;
        _ -> false
    end.

indexed(List) ->
    lists:zip(List, lists:seq(0, length(List) - 1)).

ensure(true, _Path, _Reason) -> ok;
ensure(false, Path, Reason) -> fail(Path, Reason).

fail(Path, Reason) ->
    throw({corpus_error, Path, Reason}).
