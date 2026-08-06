-module(alang_fidelity_phase6_mutation).

-export([apply/2, names/0]).

-spec names() -> [atom()].
names() -> [
    freeze_digest_mismatch,
    missing_cell_deleted,
    missing_request_digest_changed,
    missing_model_aliased,
    cost_ceiling_exceeded,
    decision_digest_mismatch,
    decision_basis_changed,
    invalid_campaign_promoted,
    efficacy_attached_to_invalid,
    invalid_safety_veto_removed,
    decision_predicate_flipped,
    sensitivity_override,
    replay_artifact_digest_changed,
    otp_release_changed,
    module_residency_changed
].

-spec apply(atom(), map()) -> map().
apply(freeze_digest_mismatch, Bundle) ->
    Freeze = maps:get(freeze, Bundle),
    finalize_bundle(Bundle#{freeze :=
        Freeze#{<<"freeze_digest">> := <<"corrupt">>}});
apply(missing_cell_deleted, Bundle) ->
    Freeze = maps:get(freeze, Bundle),
    [_Deleted | Rest] = maps:get(<<"missing_cells">>, Freeze),
    finalize_bundle(Bundle#{freeze :=
        finalize_freeze(Freeze#{<<"missing_cells">> := Rest})});
apply(missing_request_digest_changed, Bundle) ->
    Freeze = maps:get(freeze, Bundle),
    [First | Rest] = maps:get(<<"missing_cells">>, Freeze),
    Mutant = First#{<<"request_digest">> := binary:copy(<<"0">>, 64)},
    finalize_bundle(Bundle#{freeze := finalize_freeze(
        Freeze#{<<"missing_cells">> := [Mutant | Rest]})});
apply(missing_model_aliased, Bundle) ->
    Freeze = maps:get(freeze, Bundle),
    [First | Rest] = maps:get(<<"missing_cells">>, Freeze),
    Mutant = First#{<<"model_id">> := <<"latest-model-alias">>},
    finalize_bundle(Bundle#{freeze := finalize_freeze(
        Freeze#{<<"missing_cells">> := [Mutant | Rest]})});
apply(cost_ceiling_exceeded, Bundle) ->
    Freeze = maps:get(freeze, Bundle),
    Accounting = maps:get(<<"accounting">>, Freeze),
    Mutant = Accounting#{<<"cost_microusd">> := 200000001},
    finalize_bundle(Bundle#{freeze :=
        finalize_freeze(Freeze#{<<"accounting">> := Mutant})});
apply(decision_digest_mismatch, Bundle) ->
    Decision = maps:get(decision, Bundle),
    finalize_bundle(Bundle#{decision :=
        Decision#{<<"decision_digest">> := <<"corrupt">>}});
apply(decision_basis_changed, Bundle) ->
    mutate_decision(Bundle, fun(Decision) ->
        Decision#{<<"basis">> := <<"post-hoc-basis">>}
    end);
apply(invalid_campaign_promoted, Bundle) ->
    mutate_decision(Bundle, fun(Decision) ->
        Decision#{<<"outcome">> := <<"promote-alang-source-v2">>}
    end);
apply(efficacy_attached_to_invalid, Bundle) ->
    mutate_decision(Bundle, fun(Decision) ->
        Decision#{<<"model_family_results">> := #{<<"pooled">> => 100}}
    end);
apply(invalid_safety_veto_removed, Bundle) ->
    mutate_decision(Bundle, fun(Decision) ->
        Safety = maps:get(<<"safety_and_regression">>, Decision),
        Decision#{<<"safety_and_regression">> :=
            Safety#{<<"promotion_veto">> := null}}
    end);
apply(decision_predicate_flipped, Bundle) ->
    mutate_decision(Bundle, fun(Decision) ->
        [First | Rest] = maps:get(<<"ordered_predicates">>, Decision),
        Decision#{<<"ordered_predicates">> :=
            [First#{<<"satisfied">> := true} | Rest]}
    end);
apply(sensitivity_override, Bundle) ->
    mutate_decision(Bundle, fun(Decision) ->
        Sensitivity = maps:get(<<"sensitivity_analysis">>, Decision),
        Decision#{<<"sensitivity_analysis">> :=
            Sensitivity#{<<"may_change_canonical_disposition">> := true}}
    end);
apply(replay_artifact_digest_changed, Bundle) ->
    finalize_bundle(Bundle#{freeze_artifact_sha256 := <<"corrupt">>});
apply(otp_release_changed, Bundle) ->
    finalize_bundle(Bundle#{otp_release := <<"future">>});
apply(module_residency_changed, Bundle) ->
    [_First | Rest] = maps:get(module_residency, Bundle),
    finalize_bundle(Bundle#{module_residency := Rest}).

mutate_decision(Bundle, Fun) ->
    Decision = maps:get(decision, Bundle),
    finalize_bundle(Bundle#{decision := finalize_decision(Fun(Decision))}).

finalize_bundle(Bundle0) ->
    Bundle = maps:remove(bundle_digest, Bundle0),
    Bundle#{bundle_digest => alang_fidelity_json:digest(Bundle)}.

finalize_freeze(Freeze0) ->
    Freeze = maps:remove(<<"freeze_digest">>, Freeze0),
    Freeze#{<<"freeze_digest">> => alang_fidelity_json:digest(Freeze)}.

finalize_decision(Decision0) ->
    Decision = maps:remove(<<"decision_digest">>, Decision0),
    Decision#{<<"decision_digest">> => alang_fidelity_json:digest(Decision)}.
