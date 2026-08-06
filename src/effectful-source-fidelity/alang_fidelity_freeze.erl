-module(alang_fidelity_freeze).

-export([build/2, build_from/2, main/0, read/1, validate/1, write/3]).

-define(DEFAULT_BASE, "assets/effectful-source-fidelity").
-define(DEFAULT_CLOSURE,
    "assets/effectful-source-fidelity/evidence/hosted-campaign-closure-v1.json").
-define(OWNED_ROOT, "build/effectful-source-fidelity/phase-06/evidence").
-define(PRIMARY_CELLS, 288).
-define(ALL_CALL_CEILING, 576).
-define(COST_CEILING_MICROUSD, 200000000).
-define(SCHEDULE_DIGEST,
    <<"bb4b1544a038acd1c845d6575f326b890064f414678dd3a0ce1e175e0bdc07f7">>).

-spec main() -> no_return().
main() ->
    case init:get_plain_arguments() of
        [Output] ->
            case write(?DEFAULT_BASE, ?DEFAULT_CLOSURE, Output) of
                {ok, Freeze} ->
                    io:format(
                        "fidelity_phase6_freeze_ok digest=~s valid=~p missing=~B "
                        "hosted_calls=0 output=~s~n",
                        [
                            maps:get(<<"freeze_digest">>, Freeze),
                            maps:get(<<"campaign_valid">>, Freeze),
                            maps:get(<<"missing_primary_cells">>,
                                maps:get(<<"accounting">>, Freeze)),
                            Output
                        ]
                    ),
                    halt(0);
                {error, Reason} ->
                    io:format(standard_error, "fidelity_phase6_freeze_error ~tp~n", [Reason]),
                    halt(1)
            end;
        _ ->
            io:format(standard_error, "usage: alang_fidelity_freeze OUTPUT_PATH~n", []),
            halt(2)
    end.

-spec build(file:filename(), file:filename()) -> {ok, map()} | {error, term()}.
build(Base, ClosurePath) ->
    case alang_fidelity_json:decode_file(ClosurePath) of
        {ok, Closure} -> build_from(Base, Closure);
        {error, _} = Error -> Error
    end.

-spec build_from(file:filename(), term()) -> {ok, map()} | {error, term()}.
build_from(Base, Closure) ->
    try
        validate_closure(Closure),
        {ok, Registration} = alang_fidelity_preregister:build(Base),
        {ok, Schedule} = alang_fidelity_campaign:materialize(Base),
        ScheduleDigest = maps:get(schedule_digest, Schedule),
        exact(maps:get(<<"schedule_digest">>, Closure), ScheduleDigest,
            closure_schedule_digest_mismatch),
        Cells = maps:get(cells, Schedule),
        Missing = [missing_record(Cell, maps:get(<<"closure_reason">>, Closure))
            || Cell <- Cells],
        Profiles = load_json(Base, ["campaign", "provider-profiles-v1.json"]),
        Policy = load_json(Base, ["campaign", "campaign-policy-v1.json"]),
        DecisionContract = load_json(Base,
            ["contracts", "metrics-and-decision-v1.json"]),
        Predicates = predicates(Closure, Schedule, Missing, Profiles, Policy),
        Failures = [Name || {Name, false} <- lists:sort(maps:to_list(Predicates))],
        Accounting = accounting(Closure),
        Digests = input_digests(Base, Registration, ScheduleDigest, Closure),
        Body = #{
            <<"format">> => <<"alang-fidelity-campaign-freeze-v1">>,
            <<"campaign_id">> => maps:get(<<"campaign_id">>, Closure),
            <<"campaign_status">> => <<"invalid">>,
            <<"campaign_valid">> => false,
            <<"closure_reason">> => maps:get(<<"closure_reason">>, Closure),
            <<"schedule_digest">> => ScheduleDigest,
            <<"accounting">> => Accounting,
            <<"missing_cells">> => Missing,
            <<"attempts">> => maps:get(<<"attempts">>, Closure),
            <<"observations">> => maps:get(<<"observations">>, Closure),
            <<"scores">> => maps:get(<<"scores">>, Closure),
            <<"validity_predicates">> => Predicates,
            <<"failing_predicates">> => Failures,
            <<"analysis">> => suppressed_analysis(),
            <<"digests">> => Digests,
            <<"decision_contract_digest">> => alang_fidelity_json:digest(DecisionContract),
            <<"provider_profiles_digest">> => alang_fidelity_json:digest(Profiles),
            <<"campaign_policy_digest">> => alang_fidelity_json:digest(Policy)
        },
        Freeze = Body#{<<"freeze_digest">> => alang_fidelity_json:digest(Body)},
        ok = validate(Freeze),
        {ok, Freeze}
    catch
        throw:{freeze_error, Reason} -> {error, Reason};
        error:{badmatch, {error, Reason}} -> {error, Reason};
        error:{badkey, Key} -> {error, {missing_freeze_field, Key}}
    end.

-spec write(file:filename(), file:filename(), file:filename()) ->
    {ok, map()} | {error, term()}.
write(Base, ClosurePath, Output) ->
    case owned_path(Output) of
        false -> {error, freeze_path_outside_owned_root};
        true ->
            case build(Base, ClosurePath) of
                {ok, Freeze} ->
                    case alang_fidelity_json:encode_canonical(Freeze) of
                        {ok, Binary} ->
                            ok = filelib:ensure_dir(Output),
                            case file:write_file(Output, [Binary, <<"\n">>]) of
                                ok -> {ok, Freeze};
                                {error, Reason} -> {error, {freeze_write_failed, Reason}}
                            end;
                        {error, _} = Error -> Error
                    end;
                {error, _} = Error -> Error
            end
    end.

-spec read(file:filename()) -> {ok, map()} | {error, term()}.
read(Path) ->
    case alang_fidelity_json:decode_file(Path) of
        {ok, Freeze} ->
            case validate(Freeze) of
                ok -> {ok, Freeze};
                {error, _} = Error -> Error
            end;
        {error, _} = Error -> Error
    end.

-spec validate(term()) -> ok | {error, term()}.
validate(#{
    <<"format">> := <<"alang-fidelity-campaign-freeze-v1">>,
    <<"campaign_id">> := CampaignId,
    <<"campaign_status">> := <<"invalid">>,
    <<"campaign_valid">> := false,
    <<"closure_reason">> := ClosureReason,
    <<"accounting">> := Accounting,
    <<"missing_cells">> := Missing,
    <<"attempts">> := [],
    <<"observations">> := [],
    <<"scores">> := [],
    <<"validity_predicates">> := Predicates,
    <<"failing_predicates">> := Failures,
    <<"analysis">> := Analysis,
    <<"digests">> := Digests,
    <<"decision_contract_digest">> := DecisionContractDigest,
    <<"provider_profiles_digest">> := ProviderProfilesDigest,
    <<"campaign_policy_digest">> := CampaignPolicyDigest,
    <<"freeze_digest">> := Digest
} = Freeze) ->
    try
        exact(maps:size(Freeze), 19, invalid_freeze_field_count),
        ScheduleDigest = maps:get(<<"schedule_digest">>, Freeze),
        exact(ScheduleDigest, ?SCHEDULE_DIGEST,
            invalid_frozen_schedule_digest),
        {ok, Closure} = alang_fidelity_json:decode_file(?DEFAULT_CLOSURE),
        ok = validate_closure(Closure),
        exact(CampaignId, maps:get(<<"campaign_id">>, Closure),
            invalid_frozen_campaign_id),
        exact(ClosureReason, maps:get(<<"closure_reason">>, Closure),
            invalid_frozen_closure_reason),
        validate_accounting(Accounting),
        exact(length(Missing), ?PRIMARY_CELLS, invalid_missing_record_count),
        exact([maps:get(<<"index">>, Cell) || Cell <- Missing],
            lists:seq(0, ?PRIMARY_CELLS - 1), invalid_missing_cell_indices),
        exact(length(lists:usort([maps:get(<<"trial_id">>, Cell) || Cell <- Missing])),
            ?PRIMARY_CELLS, duplicate_missing_trial),
        lists:foreach(fun validate_missing_record/1, Missing),
        {ok, Registration} = alang_fidelity_preregister:build(?DEFAULT_BASE),
        {ok, Schedule} = alang_fidelity_campaign:materialize(?DEFAULT_BASE),
        exact(maps:get(schedule_digest, Schedule), ScheduleDigest,
            frozen_schedule_reproduction_failed),
        exact(Missing, [missing_record(Cell, ClosureReason)
            || Cell <- maps:get(cells, Schedule)], missing_cell_reproduction_failed),
        Profiles = load_json(?DEFAULT_BASE,
            ["campaign", "provider-profiles-v1.json"]),
        Policy = load_json(?DEFAULT_BASE, ["campaign", "campaign-policy-v1.json"]),
        DecisionContract = load_json(?DEFAULT_BASE,
            ["contracts", "metrics-and-decision-v1.json"]),
        exact(Digests, input_digests(?DEFAULT_BASE, Registration,
            ScheduleDigest, Closure), invalid_frozen_input_digests),
        exact(DecisionContractDigest, alang_fidelity_json:digest(DecisionContract),
            invalid_frozen_decision_contract_digest),
        exact(ProviderProfilesDigest, alang_fidelity_json:digest(Profiles),
            invalid_frozen_provider_profiles_digest),
        exact(CampaignPolicyDigest, alang_fidelity_json:digest(Policy),
            invalid_frozen_campaign_policy_digest),
        exact(Failures,
            [<<"live_authorization">>, <<"reproducible_scores">>,
                <<"three_scorable_primary_observations_per_cell">>],
            invalid_failing_predicates),
        exact(Predicates, expected_invalid_predicates(),
            invalid_validity_predicates),
        exact(Analysis, suppressed_analysis(), invalid_analysis_suppression),
        exact(Digest,
            alang_fidelity_json:digest(maps:remove(<<"freeze_digest">>, Freeze)),
            freeze_digest_mismatch),
        ok
    catch
        throw:{freeze_error, Reason} -> {error, Reason};
        error:{badkey, Key} -> {error, {missing_freeze_field, Key}};
        Class:Reason -> {error, {invalid_campaign_freeze_semantics, Class, Reason}}
    end;
validate(_) -> {error, invalid_campaign_freeze}.

validate_accounting(Accounting) ->
    exact(Accounting, #{
        <<"scheduled_primary_cells">> => ?PRIMARY_CELLS,
        <<"observed_primary_cells">> => 0,
        <<"missing_primary_cells">> => ?PRIMARY_CELLS,
        <<"attempts">> => 0,
        <<"hosted_calls">> => 0,
        <<"repairs">> => 0,
        <<"replacements">> => 0,
        <<"input_tokens">> => 0,
        <<"output_tokens">> => 0,
        <<"cost_microusd">> => 0,
        <<"all_call_ceiling">> => ?ALL_CALL_CEILING,
        <<"cost_ceiling_microusd">> => ?COST_CEILING_MICROUSD
    }, invalid_closed_campaign_accounting).

validate_missing_record(Record) ->
    Keys = [<<"case_id">>, <<"condition">>, <<"failure_cause">>, <<"index">>,
        <<"model_family">>, <<"model_id">>, <<"pair_id">>, <<"repetition">>,
        <<"request_digest">>, <<"status">>, <<"task_family">>, <<"trial_id">>],
    exact(lists:sort(maps:keys(Record)), Keys, invalid_missing_record_fields),
    exact(maps:get(<<"status">>, Record), <<"missing">>, invalid_missing_status),
    exact(maps:get(<<"failure_cause">>, Record),
        <<"live-authorization-not-granted">>, invalid_missing_failure_cause),
    Family = maps:get(<<"model_family">>, Record),
    ensure(lists:member(Family, [<<"anthropic">>, <<"openai">>]),
        invalid_missing_model_family),
    ExpectedModel = case Family of
        <<"anthropic">> -> <<"claude-sonnet-5">>;
        <<"openai">> -> <<"gpt-5.6-terra">>
    end,
    exact(maps:get(<<"model_id">>, Record), ExpectedModel,
        missing_model_substitution),
    ensure(lists:member(maps:get(<<"condition">>, Record),
        [<<"alang">>, <<"json">>]), invalid_missing_condition),
    Repetition = maps:get(<<"repetition">>, Record),
    ensure(is_integer(Repetition) andalso Repetition >= 1 andalso Repetition =< 3,
        invalid_missing_repetition),
    lists:foreach(fun(Key) ->
        Value = maps:get(Key, Record),
        ensure(is_binary(Value) andalso byte_size(Value) > 0,
            {invalid_missing_identifier, Key})
    end, [<<"case_id">>, <<"pair_id">>, <<"task_family">>, <<"trial_id">>]),
    Digest = maps:get(<<"request_digest">>, Record),
    ensure(is_binary(Digest) andalso byte_size(Digest) =:= 64,
        invalid_missing_request_digest).

expected_invalid_predicates() -> #{
    <<"authorized_transitions">> => true,
    <<"byte_stable_prompts">> => true,
    <<"clean_redaction">> => true,
    <<"complete_cost_accounting">> => true,
    <<"exact_registered_models">> => true,
    <<"live_authorization">> => false,
    <<"matched_semantic_pairs">> => true,
    <<"reproducible_scores">> => false,
    <<"three_scorable_primary_observations_per_cell">> => false,
    <<"within_call_ceiling">> => true,
    <<"within_cost_ceiling">> => true
}.

validate_closure(Closure) when is_map(Closure) ->
    Keys = [
        <<"attempt_count">>, <<"attempts">>, <<"campaign_id">>, <<"closed_on">>,
        <<"closure_reason">>, <<"cost_microusd">>, <<"expected_primary_cells">>,
        <<"format">>, <<"hosted_call_count">>, <<"input_tokens">>,
        <<"missing_primary_cells">>, <<"observations">>, <<"observed_primary_cells">>,
        <<"operator_authorized">>, <<"output_tokens">>, <<"repair_count">>,
        <<"replacement_count">>, <<"schedule_digest">>, <<"scores">>, <<"status">>
    ],
    exact(lists:sort(maps:keys(Closure)), lists:sort(Keys), invalid_closure_fields),
    exact(maps:get(<<"format">>, Closure),
        <<"alang-fidelity-hosted-campaign-closure-v1">>, invalid_closure_format),
    exact(maps:get(<<"status">>, Closure), <<"invalid">>, invalid_closure_status),
    exact(maps:get(<<"closure_reason">>, Closure),
        <<"live-authorization-not-granted">>, invalid_closure_reason),
    exact(maps:get(<<"operator_authorized">>, Closure), false,
        unexpected_live_authorization),
    exact(maps:get(<<"expected_primary_cells">>, Closure), ?PRIMARY_CELLS,
        invalid_expected_cell_count),
    exact(maps:get(<<"observed_primary_cells">>, Closure), 0,
        invalid_observed_cell_count),
    exact(maps:get(<<"missing_primary_cells">>, Closure), ?PRIMARY_CELLS,
        invalid_missing_cell_count),
    lists:foreach(fun(Key) -> exact(maps:get(Key, Closure), 0,
        {nonzero_closed_campaign_accounting, Key}) end,
        [<<"attempt_count">>, <<"hosted_call_count">>, <<"repair_count">>,
            <<"replacement_count">>, <<"input_tokens">>, <<"output_tokens">>,
            <<"cost_microusd">>]),
    lists:foreach(fun(Key) -> exact(maps:get(Key, Closure), [],
        {unexpected_closed_campaign_records, Key}) end,
        [<<"attempts">>, <<"observations">>, <<"scores">>]),
    ok;
validate_closure(_) -> throw({freeze_error, invalid_campaign_closure}).

missing_record(Cell, Reason) -> #{
    <<"index">> => maps:get(index, Cell),
    <<"trial_id">> => maps:get(trial_id, Cell),
    <<"pair_id">> => maps:get(pair_id, Cell),
    <<"case_id">> => maps:get(case_id, Cell),
    <<"task_family">> => maps:get(task_family, Cell),
    <<"condition">> => atom_to_binary(maps:get(condition, Cell)),
    <<"model_family">> => atom_to_binary(maps:get(model_family, Cell)),
    <<"model_id">> => maps:get(model_id, Cell),
    <<"repetition">> => maps:get(repetition, Cell),
    <<"request_digest">> => maps:get(request_digest, Cell),
    <<"status">> => <<"missing">>,
    <<"failure_cause">> => Reason
}.

predicates(Closure, Schedule, Missing, Profiles, Policy) ->
    ProfileIds = lists:sort([maps:get(<<"model_id">>, Profile)
        || Profile <- maps:get(<<"profiles">>, Profiles)]),
    ScheduleIds = lists:sort(lists:usort([maps:get(model_id, Cell)
        || Cell <- maps:get(cells, Schedule)])),
    Ceilings = maps:get(<<"ceilings">>, Policy),
    #{
        <<"authorized_transitions">> => maps:get(<<"attempts">>, Closure) =:= [],
        <<"byte_stable_prompts">> => valid_request_digests(maps:get(cells, Schedule)),
        <<"clean_redaction">> => no_forbidden_keys(Closure),
        <<"complete_cost_accounting">> => maps:get(<<"cost_microusd">>, Closure) =:= 0,
        <<"exact_registered_models">> => ProfileIds =:= ScheduleIds,
        <<"live_authorization">> => maps:get(<<"operator_authorized">>, Closure),
        <<"matched_semantic_pairs">> => matched_pairs(maps:get(cells, Schedule)),
        <<"reproducible_scores">> => maps:get(<<"scores">>, Closure) =/= [],
        <<"three_scorable_primary_observations_per_cell">> => Missing =:= [],
        <<"within_call_ceiling">> => maps:get(<<"hosted_call_count">>, Closure)
            =< maps:get(<<"all_calls">>, Ceilings),
        <<"within_cost_ceiling">> => maps:get(<<"cost_microusd">>, Closure)
            =< maps:get(<<"cost_usd">>, Ceilings) * 1000000
    }.

accounting(Closure) -> #{
    <<"scheduled_primary_cells">> => ?PRIMARY_CELLS,
    <<"observed_primary_cells">> => 0,
    <<"missing_primary_cells">> => ?PRIMARY_CELLS,
    <<"attempts">> => maps:get(<<"attempt_count">>, Closure),
    <<"hosted_calls">> => maps:get(<<"hosted_call_count">>, Closure),
    <<"repairs">> => maps:get(<<"repair_count">>, Closure),
    <<"replacements">> => maps:get(<<"replacement_count">>, Closure),
    <<"input_tokens">> => maps:get(<<"input_tokens">>, Closure),
    <<"output_tokens">> => maps:get(<<"output_tokens">>, Closure),
    <<"cost_microusd">> => maps:get(<<"cost_microusd">>, Closure),
    <<"all_call_ceiling">> => ?ALL_CALL_CEILING,
    <<"cost_ceiling_microusd">> => ?COST_CEILING_MICROUSD
}.

input_digests(Base, Registration, ScheduleDigest, Closure) -> #{
    <<"algorithm">> => <<"sha-256">>,
    <<"pre_registration">> => maps:get(<<"registration_digest">>, Registration),
    <<"corpus_manifest">> => file_digest(Base,
        ["corpus", "corpus-manifest-v1.json"]),
    <<"prompt">> => file_digest(Base, ["campaign", "prompt-template-v1.txt"]),
    <<"result_schema">> => file_digest(Base,
        ["contracts", "alang-task-comprehension-v1.schema.json"]),
    <<"provider_profiles">> => file_digest(Base,
        ["campaign", "provider-profiles-v1.json"]),
    <<"decision_contract">> => file_digest(Base,
        ["contracts", "metrics-and-decision-v1.json"]),
    <<"schedule">> => ScheduleDigest,
    <<"closure">> => alang_fidelity_json:digest(Closure),
    <<"normalized_responses">> => alang_fidelity_json:digest([]),
    <<"scores">> => alang_fidelity_json:digest([]),
    <<"scorer_beam">> => module_digest(alang_fidelity_score),
    <<"bootstrap_beam">> => module_digest(alang_fidelity_bootstrap),
    <<"freeze_beam">> => module_digest(?MODULE)
}.

suppressed_analysis() -> #{
    <<"status">> => <<"suppressed-invalid-campaign">>,
    <<"primary_table">> => null,
    <<"secondary_table">> => null,
    <<"bootstrap_intervals">> => null,
    <<"efficacy_conclusion">> => <<"forbidden">>
}.

load_json(Base, Segments) ->
    {ok, Value} = alang_fidelity_json:decode_file(filename:join([Base | Segments])),
    Value.

file_digest(Base, Segments) ->
    {ok, Binary} = file:read_file(filename:join([Base | Segments])),
    alang_fidelity_json:hex(crypto:hash(sha256, Binary)).

module_digest(Module) ->
    {module, Module} = code:ensure_loaded(Module),
    {Module, Binary, _Path} = code:get_object_code(Module),
    alang_fidelity_json:hex(crypto:hash(sha256, Binary)).

valid_request_digests(Cells) -> lists:all(fun(Cell) ->
    Digest = maps:get(request_digest, Cell),
    is_binary(Digest) andalso byte_size(Digest) =:= 64
end, Cells).

matched_pairs(Cells) ->
    Pairs = lists:foldl(fun(Cell, Acc) ->
        Pair = maps:get(pair_id, Cell),
        Condition = maps:get(condition, Cell),
        Acc#{Pair => [Condition | maps:get(Pair, Acc, [])]}
    end, #{}, Cells),
    maps:size(Pairs) =:= 144 andalso lists:all(fun(Conditions) ->
        lists:sort(Conditions) =:= [alang, json]
    end, maps:values(Pairs)).

no_forbidden_keys(Value) when is_map(Value) -> lists:all(fun({Key, Item}) ->
    not lists:member(Key, [<<"authorization">>, <<"headers">>, <<"raw_http_envelope">>,
        <<"hidden_reasoning">>, <<"api_key">>, <<"credential">>,
        <<"provider_request_id">>, <<"provider_response_id">>])
        andalso no_forbidden_keys(Item)
end, maps:to_list(Value));
no_forbidden_keys(Value) when is_list(Value) -> lists:all(fun no_forbidden_keys/1, Value);
no_forbidden_keys(_Value) -> true.

owned_path(Path) ->
    Root = filename:absname(?OWNED_ROOT),
    Absolute = filename:absname(Path),
    lists:prefix(Root ++ "/", Absolute).

exact(Value, Value, _Reason) -> ok;
exact(_Value, _Expected, Reason) -> throw({freeze_error, Reason}).

ensure(true, _Reason) -> ok;
ensure(false, Reason) -> throw({freeze_error, Reason}).
