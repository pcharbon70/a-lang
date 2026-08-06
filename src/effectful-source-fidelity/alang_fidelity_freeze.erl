-module(alang_fidelity_freeze).

-export([build/2, build_from/2, main/0, read/1, validate/1, write/3]).

-define(DEFAULT_BASE, "assets/effectful-source-fidelity").
-define(DEFAULT_CLOSURE,
    "assets/effectful-source-fidelity/evidence/hosted-campaign-closure-v1.json").
-define(OWNED_ROOT, "build/effectful-source-fidelity/phase-06/evidence").
-define(PRIMARY_CELLS, 288).
-define(ALL_CALL_CEILING, 576).
-define(COST_CEILING_MICROUSD, 200000000).

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
    <<"campaign_status">> := <<"invalid">>,
    <<"campaign_valid">> := false,
    <<"accounting">> := Accounting,
    <<"missing_cells">> := Missing,
    <<"attempts">> := [],
    <<"observations">> := [],
    <<"scores">> := [],
    <<"validity_predicates">> := Predicates,
    <<"failing_predicates">> := Failures,
    <<"analysis">> := Analysis,
    <<"freeze_digest">> := Digest
} = Freeze) ->
    try
        exact(maps:size(Freeze), 19, invalid_freeze_field_count),
        exact(length(Missing), ?PRIMARY_CELLS, invalid_missing_record_count),
        exact(length(lists:usort([maps:get(<<"trial_id">>, Cell) || Cell <- Missing])),
            ?PRIMARY_CELLS, duplicate_missing_trial),
        exact(maps:get(<<"hosted_calls">>, Accounting), 0, hosted_calls_not_zero),
        exact(maps:get(<<"missing_primary_cells">>, Accounting), ?PRIMARY_CELLS,
            invalid_missing_accounting),
        exact(Failures,
            [<<"live_authorization">>, <<"reproducible_scores">>,
                <<"three_scorable_primary_observations_per_cell">>],
            invalid_failing_predicates),
        exact([Name || {Name, false} <- lists:sort(maps:to_list(Predicates))],
            Failures, predicate_failure_mismatch),
        exact(Analysis, suppressed_analysis(), invalid_analysis_suppression),
        exact(Digest,
            alang_fidelity_json:digest(maps:remove(<<"freeze_digest">>, Freeze)),
            freeze_digest_mismatch),
        ok
    catch
        throw:{freeze_error, Reason} -> {error, Reason};
        error:{badkey, Key} -> {error, {missing_freeze_field, Key}}
    end;
validate(_) -> {error, invalid_campaign_freeze}.

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
