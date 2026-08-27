-module(alang_mnemonic_contract).

-export([decide/2, load/1, validate/1, validate_reference/2]).

-define(FORMAT, <<"alang-token-positive-campaign-contract-v1">>).
-define(PROTOCOLS, [
    <<"action-completion">>, <<"comprehension">>,
    <<"diagnostic-repair">>, <<"generation">>
]).
-define(MODELS, [<<"mixtral">>, <<"ornith">>]).
-define(TOKENIZERS, [<<"cl100k_base">>, <<"o200k_base">>]).
-define(OUTCOMES, [
    <<"stop-invalid-token-positive-campaign">>,
    <<"ineligible-token-negative-candidate">>,
    <<"reject-unsafe-mnemonic-candidate">>,
    <<"retain-readable-insufficient-fidelity">>,
    <<"promote-token-positive-mnemonic-view">>
]).

-spec load(file:filename()) -> {ok, map()} | {error, term()}.
load(Path) ->
    case alang_fidelity_json:decode_file(Path) of
        {ok, Contract} -> validate(Contract);
        {error, _} = Error -> Error
    end.

-spec validate(term()) -> {ok, map()} | {error, term()}.
validate(Contract) ->
    try
        validate_contract(Contract),
        {ok, Contract}
    catch throw:{mnemonic_contract_error, Path, Reason} ->
        {error, {mnemonic_contract_error, Path, Reason}}
    end.

-spec validate_reference(map(), file:filename()) -> {ok, map()} | {error, term()}.
validate_reference(Contract, RepoRoot) ->
    try
        validate_contract(Contract),
        Reference = maps:get(<<"r2_reference">>, Contract),
        Checks = [
            reference_check(Reference, RepoRoot, <<"renderer_path">>, <<"renderer_sha256">>),
            reference_check(Reference, RepoRoot, <<"vocabulary_path">>, <<"vocabulary_sha256">>),
            reference_check(Reference, RepoRoot, <<"surface_registry_path">>, <<"surface_registry_sha256">>)
        ],
        {ok, #{
            <<"format">> => <<"alang-token-positive-r2-reference-evidence-v1">>,
            <<"checks">> => Checks,
            <<"all_match">> => true
        }}
    catch throw:{mnemonic_contract_error, Path, Reason} ->
        {error, {mnemonic_contract_error, Path, Reason}}
    end.

-spec decide(map(), term()) -> {ok, map()} | {error, term()}.
decide(Contract, Evidence) ->
    try
        validate_contract(Contract),
        validate_evidence(Evidence),
        Outcome = choose(Contract, Evidence),
        {ok, #{
            <<"format">> => <<"alang-token-positive-campaign-outcome-v1">>,
            <<"outcome">> => Outcome,
            <<"candidate">> => <<"P1">>,
            <<"reference_condition">> => <<"R2">>,
            <<"canonical_source">> => <<"alang-source-v2">>
        }}
    catch
        throw:{mnemonic_contract_error, Path, Reason} ->
            {error, {mnemonic_contract_error, Path, Reason}};
        throw:{mnemonic_evidence_error, Path, Reason} ->
            {error, {mnemonic_evidence_error, Path, Reason}}
    end.

validate_contract(Contract) ->
    Keys = [<<"format">>, <<"question">>, <<"canonical_source">>,
        <<"candidate_condition">>, <<"conditions">>, <<"historical_registration">>,
        <<"r2_reference">>, <<"task_protocols">>, <<"inference">>,
        <<"promotion">>, <<"outcomes_ordered">>, <<"claims_not_authorized">>],
    cclosed(Contract, Keys, []),
    cexact(maps:get(<<"format">>, Contract), ?FORMAT, [<<"format">>]),
    cnonempty(maps:get(<<"question">>, Contract), [<<"question">>]),
    cexact(maps:get(<<"canonical_source">>, Contract), <<"alang-source-v2">>, [<<"canonical_source">>]),
    cexact(maps:get(<<"candidate_condition">>, Contract), <<"P1">>, [<<"candidate_condition">>]),
    validate_conditions(maps:get(<<"conditions">>, Contract)),
    validate_historical(maps:get(<<"historical_registration">>, Contract)),
    validate_r2_reference(maps:get(<<"r2_reference">>, Contract)),
    cexact(lists:sort(maps:get(<<"task_protocols">>, Contract)), ?PROTOCOLS, [<<"task_protocols">>]),
    validate_inference(maps:get(<<"inference">>, Contract)),
    validate_promotion(maps:get(<<"promotion">>, Contract)),
    cexact(maps:get(<<"outcomes_ordered">>, Contract), ?OUTCOMES, [<<"outcomes_ordered">>]),
    unique_nonempty(maps:get(<<"claims_not_authorized">>, Contract), [<<"claims_not_authorized">>]).

validate_conditions(Value) ->
    Expected = [
        condition(<<"P0">>, <<"alang-source-v2-readable">>, <<"alang-source-v2">>, <<"R0">>, <<"canonical-baseline">>, false),
        condition(<<"P1">>, <<"alang-source-v2-mnemonic-aliases">>, <<"alang-source-v2-alias-v1">>, <<"R2">>, <<"sole-promotion-candidate">>, true)
    ],
    cexact(Value, Expected, [<<"conditions">>]).

condition(Id, Representation, Version, Source, Role, Promotable) -> #{
    <<"id">> => Id, <<"representation">> => Representation,
    <<"version">> => Version, <<"source_condition">> => Source,
    <<"role">> => Role, <<"promotable">> => Promotable}.

validate_historical(Value) ->
    Expected = #{
        <<"stream">> => <<"03-compact-projection-fidelity">>,
        <<"r2_role">> => <<"closed-vocabulary-ablation">>,
        <<"r2_promotable">> => false,
        <<"r3_role">> => <<"sole-promotion-candidate">>,
        <<"rewrite">> => <<"forbidden">>
    },
    cexact(Value, Expected, [<<"historical_registration">>]).

validate_r2_reference(Value) ->
    Keys = [<<"renderer_path">>, <<"renderer_sha256">>, <<"vocabulary_path">>,
        <<"vocabulary_sha256">>, <<"surface_registry_path">>,
        <<"surface_registry_sha256">>, <<"rendering_conformance">>,
        <<"acceptance_conformance">>, <<"decode_conformance">>],
    Path = [<<"r2_reference">>],
    cclosed(Value, Keys, Path),
    lists:foreach(fun(Key) -> cnonempty(maps:get(Key, Value), Path ++ [Key]) end,
        [<<"renderer_path">>, <<"vocabulary_path">>, <<"surface_registry_path">>]),
    lists:foreach(fun(Key) -> sha256(maps:get(Key, Value), Path ++ [Key]) end,
        [<<"renderer_sha256">>, <<"vocabulary_sha256">>, <<"surface_registry_sha256">>]),
    cexact(maps:get(<<"rendering_conformance">>, Value), <<"byte-for-byte">>, Path ++ [<<"rendering_conformance">>]),
    cexact(maps:get(<<"acceptance_conformance">>, Value), <<"same-accept-or-reject">>, Path ++ [<<"acceptance_conformance">>]),
    cexact(maps:get(<<"decode_conformance">>, Value), <<"same-checked-semantics">>, Path ++ [<<"decode_conformance">>]).

validate_inference(Value) ->
    Expected = #{
        <<"sampling_unit">> => <<"semantic-case">>, <<"paired">> => true,
        <<"stratified_by">> => <<"runtime-family">>,
        <<"repetitions_retained_within_case">> => 2,
        <<"resamples">> => 20000, <<"seed">> => 2026082504,
        <<"confidence_percent">> => 95, <<"interval">> => <<"one-sided-percentile">>,
        <<"model_families_separate">> => true, <<"protocols_separate">> => true,
        <<"pooled_results">> => <<"descriptive-only">>
    },
    cexact(Value, Expected, [<<"inference">>]).

validate_promotion(Value) ->
    cclosed(Value, [<<"offline">>, <<"provider">>, <<"safety">>, <<"fidelity">>], [<<"promotion">>]),
    cexact(maps:get(<<"offline">>, Value), #{
        <<"every_document_strictly_cheaper">> => true,
        <<"every_full_request_strictly_cheaper">> => true,
        <<"minimum_aggregate_document_savings">> => 0.05,
        <<"minimum_median_document_savings">> => 0.05,
        <<"minimum_aggregate_request_savings">> => 0.05,
        <<"minimum_median_request_savings">> => 0.05,
        <<"each_registered_tokenizer">> => true}, [<<"promotion">>, <<"offline">>]),
    cexact(maps:get(<<"provider">>, Value), #{
        <<"usage_complete_and_unestimated">> => true,
        <<"no_higher_input_pair">> => true,
        <<"minimum_input_savings_each_family_protocol">> => 0.05,
        <<"maximum_total_token_delta_each_family_protocol">> => 0.0}, [<<"promotion">>, <<"provider">>]),
    cexact(maps:get(<<"safety">>, Value), #{
        <<"round_trip_required">> => true,
        <<"inherited_gates_required">> => true,
        <<"candidate_only_events">> => 0}, [<<"promotion">>, <<"safety">>]),
    cexact(maps:get(<<"fidelity">>, Value), #{
        <<"exact_lower_strictly_above">> => -0.05,
        <<"minimum_point_difference">> => -0.05,
        <<"minimum_validity_difference">> => -0.05,
        <<"minimum_repair_difference">> => -0.05,
        <<"robustness_required">> => true,
        <<"each_model_family">> => true,
        <<"each_protocol">> => true}, [<<"promotion">>, <<"fidelity">>]).

validate_evidence(Value) ->
    eclosed(Value, [<<"campaign_valid">>, <<"offline_token">>, <<"provider_token">>,
        <<"safety">>, <<"fidelity">>], []),
    boolean(maps:get(<<"campaign_valid">>, Value), [<<"campaign_valid">>]),
    validate_offline_evidence(maps:get(<<"offline_token">>, Value)),
    validate_provider_evidence(maps:get(<<"provider_token">>, Value)),
    validate_safety_evidence(maps:get(<<"safety">>, Value)),
    validate_fidelity_evidence(maps:get(<<"fidelity">>, Value)).

validate_offline_evidence(Value) ->
    Path = [<<"offline_token">>],
    eclosed(Value, [<<"every_document_strictly_cheaper">>,
        <<"every_full_request_strictly_cheaper">>, <<"tokenizers">>], Path),
    boolean(maps:get(<<"every_document_strictly_cheaper">>, Value), Path),
    boolean(maps:get(<<"every_full_request_strictly_cheaper">>, Value), Path),
    Tokenizers = maps:get(<<"tokenizers">>, Value),
    eclosed(Tokenizers, ?TOKENIZERS, Path ++ [<<"tokenizers">>]),
    lists:foreach(fun(Id) ->
        Item = maps:get(Id, Tokenizers),
        ItemPath = Path ++ [<<"tokenizers">>, Id],
        Keys = [<<"document_aggregate_savings">>, <<"document_median_savings">>,
            <<"request_aggregate_savings">>, <<"request_median_savings">>],
        eclosed(Item, Keys, ItemPath),
        lists:foreach(fun(Key) -> fraction(maps:get(Key, Item), ItemPath ++ [Key]) end, Keys)
    end, ?TOKENIZERS).

validate_provider_evidence(Value) ->
    Path = [<<"provider_token">>],
    eclosed(Value, [<<"usage_complete_and_unestimated">>, <<"no_higher_input_pair">>, <<"strata">>], Path),
    boolean(maps:get(<<"usage_complete_and_unestimated">>, Value), Path),
    boolean(maps:get(<<"no_higher_input_pair">>, Value), Path),
    validate_strata(maps:get(<<"strata">>, Value), fun validate_provider_stratum/2, Path ++ [<<"strata">>]).

validate_provider_stratum(Value, Path) ->
    eclosed(Value, [<<"input_savings">>, <<"total_token_delta">>], Path),
    signed_fraction(maps:get(<<"input_savings">>, Value), Path ++ [<<"input_savings">>]),
    signed_number(maps:get(<<"total_token_delta">>, Value), Path ++ [<<"total_token_delta">>]).

validate_safety_evidence(Value) ->
    Path = [<<"safety">>],
    eclosed(Value, [<<"round_trip_pass">>, <<"inherited_gates_pass">>, <<"candidate_only_events">>], Path),
    boolean(maps:get(<<"round_trip_pass">>, Value), Path),
    boolean(maps:get(<<"inherited_gates_pass">>, Value), Path),
    Events = maps:get(<<"candidate_only_events">>, Value),
    eensure(is_integer(Events) andalso Events >= 0, Path ++ [<<"candidate_only_events">>], expected_nonnegative_integer).

validate_fidelity_evidence(Value) ->
    eclosed(Value, [<<"strata">>], [<<"fidelity">>]),
    validate_strata(maps:get(<<"strata">>, Value), fun validate_fidelity_stratum/2, [<<"fidelity">>, <<"strata">>]).

validate_fidelity_stratum(Value, Path) ->
    Keys = [<<"exact_lower">>, <<"point_difference">>, <<"validity_difference">>,
        <<"repair_difference">>, <<"robustness_pass">>],
    eclosed(Value, Keys, Path),
    lists:foreach(fun(Key) -> signed_fraction(maps:get(Key, Value), Path ++ [Key]) end, lists:sublist(Keys, 4)),
    boolean(maps:get(<<"robustness_pass">>, Value), Path ++ [<<"robustness_pass">>]).

validate_strata(Value, Validator, Path) ->
    eclosed(Value, ?MODELS, Path),
    lists:foreach(fun(Model) ->
        Protocols = maps:get(Model, Value),
        eclosed(Protocols, ?PROTOCOLS, Path ++ [Model]),
        lists:foreach(fun(Protocol) -> Validator(maps:get(Protocol, Protocols), Path ++ [Model, Protocol]) end, ?PROTOCOLS)
    end, ?MODELS).

choose(_Contract, #{<<"campaign_valid">> := false}) ->
    <<"stop-invalid-token-positive-campaign">>;
choose(Contract, Evidence) ->
    case token_pass(Contract, Evidence) of
        false -> <<"ineligible-token-negative-candidate">>;
        true -> case safety_pass(Evidence) of
            false -> <<"reject-unsafe-mnemonic-candidate">>;
            true -> case fidelity_pass(Contract, Evidence) of
                true -> <<"promote-token-positive-mnemonic-view">>;
                false -> <<"retain-readable-insufficient-fidelity">>
            end
        end
    end.

token_pass(Contract, Evidence) ->
    Promotion = maps:get(<<"promotion">>, Contract),
    OfflineRule = maps:get(<<"offline">>, Promotion),
    Offline = maps:get(<<"offline_token">>, Evidence),
    OfflinePairs = maps:get(<<"every_document_strictly_cheaper">>, Offline)
        andalso maps:get(<<"every_full_request_strictly_cheaper">>, Offline),
    OfflineCounts = lists:all(fun(Item) ->
        maps:get(<<"document_aggregate_savings">>, Item) >= maps:get(<<"minimum_aggregate_document_savings">>, OfflineRule)
        andalso maps:get(<<"document_median_savings">>, Item) >= maps:get(<<"minimum_median_document_savings">>, OfflineRule)
        andalso maps:get(<<"request_aggregate_savings">>, Item) >= maps:get(<<"minimum_aggregate_request_savings">>, OfflineRule)
        andalso maps:get(<<"request_median_savings">>, Item) >= maps:get(<<"minimum_median_request_savings">>, OfflineRule)
    end, maps:values(maps:get(<<"tokenizers">>, Offline))),
    ProviderRule = maps:get(<<"provider">>, Promotion),
    Provider = maps:get(<<"provider_token">>, Evidence),
    ProviderBase = maps:get(<<"usage_complete_and_unestimated">>, Provider)
        andalso maps:get(<<"no_higher_input_pair">>, Provider),
    ProviderStrata = strata_values(maps:get(<<"strata">>, Provider)),
    ProviderCounts = lists:all(fun(Item) ->
        maps:get(<<"input_savings">>, Item) >= maps:get(<<"minimum_input_savings_each_family_protocol">>, ProviderRule)
        andalso maps:get(<<"total_token_delta">>, Item) =< maps:get(<<"maximum_total_token_delta_each_family_protocol">>, ProviderRule)
    end, ProviderStrata),
    OfflinePairs andalso OfflineCounts andalso ProviderBase andalso ProviderCounts.

safety_pass(Evidence) ->
    Safety = maps:get(<<"safety">>, Evidence),
    maps:get(<<"round_trip_pass">>, Safety)
        andalso maps:get(<<"inherited_gates_pass">>, Safety)
        andalso maps:get(<<"candidate_only_events">>, Safety) =:= 0.

fidelity_pass(Contract, Evidence) ->
    Rule = maps:get(<<"fidelity">>, maps:get(<<"promotion">>, Contract)),
    lists:all(fun(Item) ->
        maps:get(<<"exact_lower">>, Item) > maps:get(<<"exact_lower_strictly_above">>, Rule)
        andalso maps:get(<<"point_difference">>, Item) >= maps:get(<<"minimum_point_difference">>, Rule)
        andalso maps:get(<<"validity_difference">>, Item) >= maps:get(<<"minimum_validity_difference">>, Rule)
        andalso maps:get(<<"repair_difference">>, Item) >= maps:get(<<"minimum_repair_difference">>, Rule)
        andalso maps:get(<<"robustness_pass">>, Item)
    end, strata_values(maps:get(<<"strata">>, maps:get(<<"fidelity">>, Evidence)))).

strata_values(Strata) -> lists:append([maps:values(maps:get(Model, Strata)) || Model <- ?MODELS]).

reference_check(Reference, RepoRoot, PathKey, DigestKey) ->
    Relative = maps:get(PathKey, Reference),
    Path = filename:join(RepoRoot, binary_to_list(Relative)),
    case file:read_file(Path) of
        {ok, Bytes} ->
            Actual = alang_fidelity_json:hex(crypto:hash(sha256, Bytes)),
            Expected = maps:get(DigestKey, Reference),
            cexact(Actual, Expected, [<<"r2_reference">>, DigestKey]),
            #{<<"path">> => Relative, <<"sha256">> => Actual, <<"match">> => true};
        {error, Reason} -> cfail([<<"r2_reference">>, PathKey], {read_failed, Reason})
    end.

cclosed(Value, Keys, Path) ->
    censure(is_map(Value), Path, expected_object),
    Actual = maps:keys(Value),
    censure(Actual -- Keys =:= [], Path, {unknown_fields, lists:sort(Actual -- Keys)}),
    censure(Keys -- Actual =:= [], Path, {missing_fields, lists:sort(Keys -- Actual)}).
eclosed(Value, Keys, Path) ->
    eensure(is_map(Value), Path, expected_object),
    Actual = maps:keys(Value),
    eensure(Actual -- Keys =:= [], Path, {unknown_fields, lists:sort(Actual -- Keys)}),
    eensure(Keys -- Actual =:= [], Path, {missing_fields, lists:sort(Keys -- Actual)}).
cexact(Value, Expected, Path) -> censure(Value =:= Expected, Path, {expected_frozen_value, Expected, Value}).
cnonempty(Value, Path) -> censure(is_binary(Value) andalso byte_size(Value) > 0, Path, expected_nonempty_string).
unique_nonempty(Value, Path) ->
    censure(is_list(Value) andalso Value =/= [], Path, expected_nonempty_array),
    censure(length(Value) =:= length(lists:usort(Value)), Path, duplicate_value),
    lists:foreach(fun(Item) -> cnonempty(Item, Path) end, Value).
sha256(Value, Path) ->
    censure(is_binary(Value) andalso byte_size(Value) =:= 64, Path, expected_sha256),
    censure(lists:all(fun hex_digit/1, binary_to_list(Value)), Path, expected_sha256).
hex_digit(C) -> (C >= $0 andalso C =< $9) orelse (C >= $a andalso C =< $f).
boolean(Value, Path) -> eensure(is_boolean(Value), Path, expected_boolean).
fraction(Value, Path) -> eensure(is_number(Value) andalso Value >= 0 andalso Value =< 1, Path, expected_fraction).
signed_fraction(Value, Path) -> eensure(is_number(Value) andalso Value >= -1 andalso Value =< 1, Path, expected_signed_fraction).
signed_number(Value, Path) -> eensure(is_number(Value), Path, expected_number).
censure(true, _Path, _Reason) -> ok;
censure(false, Path, Reason) -> cfail(Path, Reason).
eensure(true, _Path, _Reason) -> ok;
eensure(false, Path, Reason) -> throw({mnemonic_evidence_error, Path, Reason}).
cfail(Path, Reason) -> throw({mnemonic_contract_error, Path, Reason}).
