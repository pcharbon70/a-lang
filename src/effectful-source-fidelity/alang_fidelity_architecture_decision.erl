-module(alang_fidelity_architecture_decision).

-export([build/2, from_input/2, main/0, read/1, validate/1, write/4]).

-define(DEFAULT_BASE, "assets/effectful-source-fidelity").
-define(DEFAULT_FREEZE,
    "build/effectful-source-fidelity/phase-06/evidence/campaign-freeze.json").
-define(OWNED_ROOT, "build/effectful-source-fidelity/phase-06/evidence").
-define(MODELS, [<<"anthropic">>, <<"openai">>]).

-spec main() -> no_return().
main() ->
    case init:get_plain_arguments() of
        [MachineOutput, HumanOutput] ->
            case write(?DEFAULT_BASE, ?DEFAULT_FREEZE, MachineOutput, HumanOutput) of
                {ok, Decision} ->
                    io:format(
                        "fidelity_phase6_decision_ok digest=~s outcome=~s "
                        "campaign_valid=~p efficacy=none output=~s report=~s~n",
                        [
                            maps:get(<<"decision_digest">>, Decision),
                            maps:get(<<"outcome">>, Decision),
                            maps:get(<<"campaign_valid">>, Decision),
                            MachineOutput,
                            HumanOutput
                        ]
                    ),
                    halt(0);
                {error, Reason} ->
                    io:format(standard_error,
                        "fidelity_phase6_decision_error ~tp~n", [Reason]),
                    halt(1)
            end;
        _ ->
            io:format(standard_error,
                "usage: alang_fidelity_architecture_decision MACHINE_JSON REPORT_MD~n", []),
            halt(2)
    end.

-spec build(file:filename(), file:filename()) -> {ok, map()} | {error, term()}.
build(Base, FreezePath) ->
    try
        {ok, Freeze} = alang_fidelity_freeze:read(FreezePath),
        ContractPath = filename:join([Base, "contracts", "metrics-and-decision-v1.json"]),
        {ok, Contract} = alang_fidelity_decision:load_contract(ContractPath),
        Input = #{
            <<"campaign_valid">> => false,
            <<"validity_failures">> => maps:get(<<"failing_predicates">>, Freeze)
        },
        Context = #{
            <<"decision_contract_digest">> => alang_fidelity_json:digest(Contract),
            <<"freeze_digest">> => maps:get(<<"freeze_digest">>, Freeze),
            <<"inherited_gates">> => inherited_gates(),
            <<"task_family_results">> => null
        },
        from_input(Input, Context)
    catch
        error:{badmatch, {error, Reason}} -> {error, Reason};
        error:{badkey, Key} -> {error, {missing_decision_field, Key}}
    end.

-spec from_input(map(), map()) -> {ok, map()} | {error, term()}.
from_input(Input, Context) when is_map(Input), is_map(Context) ->
    try
        validate_context(Context),
        {ok, Outcome} = alang_fidelity_decision:decide(Input),
        Valid = maps:get(<<"campaign_valid">>, Input),
        Families = case Valid of
            true -> maps:get(<<"model_families">>, Input);
            false -> null
        end,
        TaskFamilies = case Valid of
            true -> maps:get(<<"task_family_results">>, Context);
            false -> null
        end,
        Failures = maps:get(<<"validity_failures">>, Input, []),
        Safety = safety_record(Valid, Input, Context),
        Predicates = ordered_predicates(Valid, Input),
        OutcomeName = maps:get(<<"outcome">>, Outcome),
        Body = #{
            <<"format">> => <<"alang-fidelity-architecture-decision-v1">>,
            <<"canonical_disposition">> => true,
            <<"decision_contract_digest">> =>
                maps:get(<<"decision_contract_digest">>, Context),
            <<"freeze_digest">> => maps:get(<<"freeze_digest">>, Context),
            <<"campaign_valid">> => Valid,
            <<"validity_failures">> => Failures,
            <<"outcome">> => OutcomeName,
            <<"basis">> => maps:get(<<"basis">>, Outcome),
            <<"model_family_results">> => Families,
            <<"task_family_results">> => TaskFamilies,
            <<"safety_and_regression">> => Safety,
            <<"ordered_predicates">> => Predicates,
            <<"sensitivity_analysis">> => #{
                <<"status">> => <<"not-run">>,
                <<"may_change_canonical_disposition">> => false
            },
            <<"supported_surface">> => supported_surface(OutcomeName),
            <<"efficacy_conclusion">> => efficacy_conclusion(Valid),
            <<"limitations">> => limitations()
        },
        Decision = Body#{<<"decision_digest">> => alang_fidelity_json:digest(Body)},
        ok = validate(Decision),
        {ok, Decision}
    catch
        throw:{architecture_decision_error, Reason} -> {error, Reason};
        error:{badmatch, {error, Reason}} -> {error, Reason};
        error:{badkey, Key} -> {error, {missing_decision_field, Key}}
    end;
from_input(_, _) -> {error, invalid_architecture_decision_input}.

-spec write(file:filename(), file:filename(), file:filename(), file:filename()) ->
    {ok, map()} | {error, term()}.
write(Base, FreezePath, MachinePath, HumanPath) ->
    case owned_paths([MachinePath, HumanPath]) of
        false -> {error, decision_path_outside_owned_root};
        true ->
            case build(Base, FreezePath) of
                {ok, Decision} ->
                    {ok, Machine} = alang_fidelity_json:encode_canonical(Decision),
                    {ok, Human} = alang_fidelity_decision_report:render(Decision),
                    ok = filelib:ensure_dir(MachinePath),
                    ok = filelib:ensure_dir(HumanPath),
                    case file:write_file(MachinePath, [Machine, <<"\n">>]) of
                        ok ->
                            case file:write_file(HumanPath, Human) of
                                ok -> {ok, Decision};
                                {error, Reason} -> {error, {report_write_failed, Reason}}
                            end;
                        {error, Reason} -> {error, {decision_write_failed, Reason}}
                    end;
                {error, _} = Error -> Error
            end
    end.

-spec read(file:filename()) -> {ok, map()} | {error, term()}.
read(Path) ->
    case alang_fidelity_json:decode_file(Path) of
        {ok, Decision} ->
            case validate(Decision) of
                ok -> {ok, Decision};
                {error, _} = Error -> Error
            end;
        {error, _} = Error -> Error
    end.

-spec validate(term()) -> ok | {error, term()}.
validate(#{
    <<"format">> := <<"alang-fidelity-architecture-decision-v1">>,
    <<"canonical_disposition">> := true,
    <<"campaign_valid">> := Valid,
    <<"validity_failures">> := Failures,
    <<"outcome">> := Outcome,
    <<"model_family_results">> := Families,
    <<"task_family_results">> := TaskFamilies,
    <<"safety_and_regression">> := Safety,
    <<"ordered_predicates">> := Predicates,
    <<"sensitivity_analysis">> := #{
        <<"status">> := <<"not-run">>,
        <<"may_change_canonical_disposition">> := false
    },
    <<"efficacy_conclusion">> := Efficacy,
    <<"decision_digest">> := Digest
} = Decision) ->
    try
        exact(maps:size(Decision), 17, invalid_decision_field_count),
        ensure(is_boolean(Valid), invalid_campaign_validity),
        ensure(lists:member(Outcome, [
            <<"promote-alang-source-v2">>, <<"replace-with-json-control">>,
            <<"stop-surface-expansion">>,
            <<"stop-invalid-campaign-no-efficacy-conclusion">>
        ]), invalid_decision_outcome),
        validate_branch(Valid, Failures, Families, TaskFamilies, Efficacy, Outcome),
        validate_safety(Safety),
        ensure(is_list(Predicates) andalso length(Predicates) =:= 6,
            invalid_decision_predicates),
        ensure(lists:all(fun(Predicate) ->
            maps:keys(Predicate) -- [<<"name">>, <<"satisfied">>, <<"explanation">>]
                =:= [] andalso
            is_boolean(maps:get(<<"satisfied">>, Predicate))
        end, Predicates), invalid_decision_predicate),
        exact(Digest,
            alang_fidelity_json:digest(maps:remove(<<"decision_digest">>, Decision)),
            decision_digest_mismatch),
        ok
    catch
        throw:{architecture_decision_error, Reason} -> {error, Reason};
        error:{badkey, Key} -> {error, {missing_decision_field, Key}}
    end;
validate(_) -> {error, invalid_architecture_decision}.

validate_context(Context) ->
    Keys = [<<"decision_contract_digest">>, <<"freeze_digest">>,
        <<"inherited_gates">>, <<"task_family_results">>],
    exact(lists:sort(maps:keys(Context)), lists:sort(Keys), invalid_decision_context),
    validate_gates(maps:get(<<"inherited_gates">>, Context)).

validate_gates(Gates) when is_map(Gates), map_size(Gates) =:= 8 ->
    ensure(lists:all(fun(Value) -> Value =:= <<"passed">> end, maps:values(Gates)),
        inherited_regression_gate_failed);
validate_gates(_) -> throw({architecture_decision_error, invalid_inherited_gates}).

validate_branch(false, Failures, null, null, null,
        <<"stop-invalid-campaign-no-efficacy-conclusion">>) ->
    ensure(is_list(Failures) andalso Failures =/= [], invalid_validity_failures);
validate_branch(true, [], Families, TaskFamilies, <<"registered-comparison-applied">>,
        Outcome) when is_map(Families), is_map(TaskFamilies) ->
    ensure(Outcome =/= <<"stop-invalid-campaign-no-efficacy-conclusion">>,
        valid_campaign_has_invalid_outcome);
validate_branch(_, _, _, _, _, _) ->
    throw({architecture_decision_error, invalid_decision_branch}).

validate_safety(#{
    <<"hosted_comparative_status">> := Hosted,
    <<"inherited_gates">> := Gates,
    <<"promotion_veto">> := Veto
}) ->
    ensure(lists:member(Hosted,
        [<<"evaluated">>, <<"not-evaluable-invalid-campaign">>]),
        invalid_hosted_safety_status),
    validate_gates(Gates),
    ensure(Veto =:= null orelse is_binary(Veto), invalid_promotion_veto);
validate_safety(_) -> throw({architecture_decision_error, invalid_safety_record}).

safety_record(false, _Input, Context) -> #{
    <<"hosted_comparative_status">> => <<"not-evaluable-invalid-campaign">>,
    <<"inherited_gates">> => maps:get(<<"inherited_gates">>, Context),
    <<"promotion_veto">> => <<"campaign-invalid">>
};
safety_record(true, Input, Context) ->
    Regressions = maps:get(<<"safety_regressions">>, Input),
    #{
        <<"hosted_comparative_status">> => <<"evaluated">>,
        <<"inherited_gates">> => maps:get(<<"inherited_gates">>, Context),
        <<"promotion_veto">> => case Regressions of
            [] -> null;
            [_ | _] -> <<"hosted-safety-regression">>
        end
    }.

ordered_predicates(false, _Input) -> [
    predicate(<<"campaign-validity">>, false,
        <<"The hosted campaign has three explicit failing validity predicates.">>),
    predicate(<<"promotion-five-point-margin-each-family">>, false,
        <<"Not evaluated because efficacy inputs are forbidden for an invalid campaign.">>),
    predicate(<<"promotion-positive-paired-lower-bound-each-family">>, false,
        <<"Not evaluated because no hosted bootstrap interval exists.">>),
    predicate(<<"promotion-safety-and-regression-veto-free">>, false,
        <<"Hosted comparative safety is not evaluable; inherited gates remain green.">>),
    predicate(<<"replacement-json-eighty-percent-each-family">>, false,
        <<"Not evaluated because no hosted JSON fidelity rates exist.">>),
    predicate(<<"invalid-campaign-conservative-stop">>, true,
        <<"The frozen ordered rule requires stop without an efficacy conclusion.">>)
];
ordered_predicates(true, Input) ->
    Families = maps:get(<<"model_families">>, Input),
    Safety = maps:get(<<"safety_regressions">>, Input),
    Margin = lists:all(fun(Family) ->
        Cell = maps:get(Family, Families),
        maps:get(<<"alang_exact_percent">>, Cell) -
            maps:get(<<"json_exact_percent">>, Cell) >= 5
    end, ?MODELS),
    Positive = lists:all(fun(Family) ->
        maps:get(<<"paired_ci_lower_percentage_points">>, maps:get(Family, Families)) > 0
    end, ?MODELS),
    Floor = lists:all(fun(Family) ->
        maps:get(<<"json_exact_percent">>, maps:get(Family, Families)) >= 80
    end, ?MODELS),
    [
        predicate(<<"campaign-validity">>, true,
            <<"All frozen campaign validity predicates passed.">>),
        predicate(<<"promotion-five-point-margin-each-family">>, Margin,
            <<"A-Lang must exceed JSON by at least five points in each family.">>),
        predicate(<<"promotion-positive-paired-lower-bound-each-family">>, Positive,
            <<"Each paired 95% lower bound must be strictly above zero.">>),
        predicate(<<"promotion-safety-and-regression-veto-free">>, Safety =:= [],
            <<"Promotion requires no safety regression and green inherited gates.">>),
        predicate(<<"replacement-json-eighty-percent-each-family">>, Floor,
            <<"Replacement requires at least 80% JSON exact fidelity in each family.">>),
        predicate(<<"invalid-campaign-conservative-stop">>, false,
            <<"The campaign is valid, so the invalid-campaign branch does not apply.">>)
    ].

predicate(Name, Satisfied, Explanation) -> #{
    <<"name">> => Name,
    <<"satisfied">> => Satisfied,
    <<"explanation">> => Explanation
}.

supported_surface(<<"promote-alang-source-v2">>) -> <<"alang-source-v2-closed-subset">>;
supported_surface(<<"replace-with-json-control">>) -> <<"alang-task-json-v1">>;
supported_surface(_) -> <<"runtime-enforcement-only-authoring-frozen">>.

efficacy_conclusion(false) -> null;
efficacy_conclusion(true) -> <<"registered-comparison-applied">>.

inherited_gates() -> #{
    <<"adversarial">> => <<"passed">>,
    <<"broker">> => <<"passed">>,
    <<"child">> => <<"passed">>,
    <<"compiler">> => <<"passed">>,
    <<"completion">> => <<"passed">>,
    <<"durability">> => <<"passed">>,
    <<"mutation">> => <<"passed">>,
    <<"workspace">> => <<"passed">>
}.

limitations() -> [
    <<"no-hosted-model-observations">>,
    <<"no-efficacy-comparison">>,
    <<"no-human-usability-evidence">>,
    <<"same-node-trust">>,
    <<"host-account-isolation">>,
    <<"local-durability">>,
    <<"fixed-module-lifecycle">>,
    <<"single-otp-support">>,
    <<"not-production-ready">>
].

owned_paths(Paths) ->
    Root = filename:absname(?OWNED_ROOT),
    lists:all(fun(Path) ->
        lists:prefix(Root ++ "/", filename:absname(Path))
    end, Paths).

exact(Value, Value, _Reason) -> ok;
exact(_Value, _Expected, Reason) -> throw({architecture_decision_error, Reason}).

ensure(true, _Reason) -> ok;
ensure(false, Reason) -> throw({architecture_decision_error, Reason}).
