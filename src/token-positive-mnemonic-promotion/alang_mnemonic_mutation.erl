-module(alang_mnemonic_mutation).

-export([run/1]).

-spec run(file:filename()) -> {ok, map()} | {error, term()}.
run(Base) ->
    try
        RepoRoot = filename:dirname(filename:dirname(Base)),
        Campaign = filename:join(Base, "campaign"),
        Contracts = filename:join(Base, "contracts"),
        Contract = decode(filename:join(Contracts, "campaign-contract-v1.json")),
        Power = decode(filename:join(Campaign, "power-design-v1.json")),
        Policy = decode(filename:join(Campaign, "campaign-policy-v1.json")),
        SchedulePolicy = decode(filename:join(Campaign, "schedule-policy-v1.json")),
        Design = decode(filename:join(Campaign, "case-design-v1.json")),
        Corpus = decode(filename:join([Base, "corpus", "confirmatory-corpus-v1.json"])),
        Profiles = decode(filename:join(Campaign, "provider-profiles-v1.json")),
        Prompts = decode(filename:join(Campaign, "prompt-policy-v1.json")),
        {ok, Schedule} = alang_mnemonic_schedule:materialize(Campaign),
        Results = contract_mutants(Contract, RepoRoot) ++
            design_mutants(Power, Policy, SchedulePolicy, Design, Corpus,
                Profiles, Prompts, Schedule, RepoRoot),
        Detected = [Name || {Name, true} <- Results],
        Total = length(Results),
        case length(Detected) =:= Total of
            true -> {ok, #{
                <<"detected">> => Total,
                <<"total">> => Total,
                <<"all_detected">> => true,
                <<"names">> => Detected
            }};
            false -> {error, {undetected_mutants,
                [Name || {Name, false} <- Results]}}
        end
    catch
        Class:Reason -> {error, {mnemonic_mutation_error, Class, Reason}}
    end.

contract_mutants(Contract, RepoRoot) ->
    Historical = maps:get(<<"historical_registration">>, Contract),
    Conditions = maps:get(<<"conditions">>, Contract),
    P0Promotable = [case maps:get(<<"id">>, C) of
        <<"P0">> -> C#{<<"promotable">> := true}; _ -> C end || C <- Conditions],
    Reference = maps:get(<<"r2_reference">>, Contract),
    Promotion = maps:get(<<"promotion">>, Contract),
    Offline = maps:get(<<"offline">>, Promotion),
    Inference = maps:get(<<"inference">>, Contract),
    Outcomes = maps:get(<<"outcomes_ordered">>, Contract),
    [
        detected(<<"historical-r2-promotable">>, alang_mnemonic_contract:validate(
            Contract#{<<"historical_registration">> := Historical#{<<"r2_promotable">> := true}})),
        detected(<<"second-promotable-condition">>, alang_mnemonic_contract:validate(
            Contract#{<<"conditions">> := P0Promotable})),
        detected(<<"r2-render-digest-drift">>, alang_mnemonic_contract:validate_reference(
            Contract#{<<"r2_reference">> := Reference#{<<"renderer_sha256">> := zeros()}}, RepoRoot)),
        detected(<<"r2-acceptance-conformance-drift">>, alang_mnemonic_contract:validate(
            Contract#{<<"r2_reference">> := Reference#{<<"acceptance_conformance">> := <<"subset">>}})),
        detected(<<"r2-decode-conformance-drift">>, alang_mnemonic_contract:validate(
            Contract#{<<"r2_reference">> := Reference#{<<"decode_conformance">> := <<"similar-semantics">>}})),
        detected(<<"token-threshold-relaxation">>, alang_mnemonic_contract:validate(
            Contract#{<<"promotion">> := Promotion#{<<"offline">> :=
                Offline#{<<"minimum_aggregate_document_savings">> := -0.01}}})),
        detected(<<"pooled-family-inference">>, alang_mnemonic_contract:validate(
            Contract#{<<"inference">> := Inference#{<<"model_families_separate">> := false}})),
        detected(<<"pseudoreplication">>, alang_mnemonic_contract:validate(
            Contract#{<<"inference">> := Inference#{<<"repetitions_retained_within_case">> := 3}})),
        detected(<<"fidelity-before-token-order">>, alang_mnemonic_contract:validate(
            Contract#{<<"outcomes_ordered">> := swap_second_and_fourth(Outcomes)})),
        detected(<<"hidden-weighted-score">>, alang_mnemonic_contract:validate(
            Contract#{<<"weighted_score">> => 0.8}))
    ].

design_mutants(Power, Policy, SchedulePolicy, Design, Corpus, Profiles, Prompts,
        Schedule, RepoRoot) ->
    Cases = maps:get(<<"cases">>, Corpus),
    [First, Second | Rest] = Cases,
    DesignCases = maps:get(<<"cases">>, Design),
    [FirstDesign | DesignRest] = DesignCases,
    ProfileList = maps:get(<<"profiles">>, Profiles),
    [FirstProfile | ProfileRest] = ProfileList,
    Protocols = maps:get(<<"protocols">>, Prompts),
    [FirstProtocol | ProtocolRest] = Protocols,
    Replacement = maps:get(<<"replacement">>, Policy),
    ScheduleCells = maps:get(<<"cells">>, Schedule),
    [
        detected(<<"power-seed-drift">>, alang_mnemonic_power:audit(Power#{<<"seed">> := 2026082505})),
        detected(<<"duplicate-corpus-case">>, alang_mnemonic_corpus:validate(
            Corpus#{<<"cases">> := [First, First | Rest]}, Design, RepoRoot)),
        detected(<<"condition-leak">>, alang_mnemonic_corpus:validate(
            Corpus#{<<"cases">> := [First#{<<"request">> :=
                <<(maps:get(<<"request">>, First))/binary, " Use P1.">>} , Second | Rest]},
            Design, RepoRoot)),
        detected(<<"case-family-imbalance">>, alang_mnemonic_corpus:validate(
            Corpus, Design#{<<"cases">> := [FirstDesign#{<<"runtime_family">> :=
                <<"repair-and-publish">>} | DesignRest]}, RepoRoot)),
        detected(<<"schedule-missing-cell">>, alang_mnemonic_schedule:validate(
            Schedule#{<<"cells">> := tl(ScheduleCells)}, SchedulePolicy, DesignCases)),
        detected(<<"schedule-seed-drift">>, alang_mnemonic_schedule:validate(
            Schedule, SchedulePolicy#{<<"seed">> := 2026082505}, DesignCases)),
        detected(<<"expanded-replacement">>, alang_mnemonic_registration:validate_policy(
            Policy#{<<"replacement">> := Replacement#{
                <<"max_replacements_per_primary_cell">> := 2}})),
        detected(<<"model-profile-drift">>, alang_mnemonic_registration:validate_profiles(
            Profiles#{<<"profiles">> := [FirstProfile#{<<"manifest_sha256">> := zeros()} | ProfileRest]})),
        detected(<<"prompt-condition-asymmetry">>, alang_mnemonic_registration:validate_prompts(
            Prompts#{<<"protocols">> := [FirstProtocol#{<<"conditions">> := [<<"P0">>]} | ProtocolRest]}))
    ].

detected(Name, {error, _}) -> {Name, true};
detected(Name, _) -> {Name, false}.

decode(Path) ->
    case alang_fidelity_json:decode_file(Path) of
        {ok, Value} -> Value;
        {error, Reason} -> erlang:error({decode_failed, Path, Reason})
    end.

zeros() -> <<"0000000000000000000000000000000000000000000000000000000000000000">>.

swap_second_and_fourth([A, B, C, D | Rest]) -> [A, D, C, B | Rest].
