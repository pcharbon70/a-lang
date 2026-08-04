-module(alang_phase8_decision_tests).

-include_lib("eunit/include/eunit.hrl").

all_hypotheses_receive_bounded_evidence_backed_decisions_test() ->
    Record = alang_phase8_decision:decision(),
    ?assertEqual(ok, alang_phase8_decision:validate(Record)),
    Outcomes = maps:from_list([{maps:get(hypothesis, Entry), maps:get(outcome, Entry)}
        || Entry <- maps:get(dispositions, Record)]),
    ?assertEqual(narrow, maps:get(task_language, Outcomes)),
    ?assertEqual(narrow, maps:get(categorical_ir, Outcomes)),
    ?assertEqual(promote, maps:get(beam_compiler_and_runtime, Outcomes)),
    ?assertEqual(promote, maps:get(local_capability_broker, Outcomes)),
    ?assertEqual(promote, maps:get(explicit_durability, Outcomes)),
    ?assertEqual(revise, maps:get(combined_architecture, Outcomes)),
    ?assertEqual(not_approved, maps:get(production_status, Record)),
    ?assertEqual(one_bounded_prototype_approved,
        maps:get(continuation_status, Record)).

next_boundary_freezes_scope_and_requires_source_level_evidence_test() ->
    Boundary = maps:get(next_decision_boundary, alang_phase8_decision:decision()),
    Required = maps:get(required_evidence, Boundary),
    Frozen = maps:get(frozen_features, Boundary),
    ?assert(lists:member(no_manually_constructed_ir_in_acceptance_tasks, Required)),
    ?assert(lists:member(llm_fidelity_results_across_at_least_two_declared_model_families,
        Required)),
    ?assert(lists:member(general_recursion, Frozen)),
    ?assert(lists:member(portable_delegation, Frozen)).

decision_record_writes_only_below_owned_build_root_test() ->
    Path = filename:absname(filename:join(["build", "phase-08", "decision-tests",
        "decision.config"])),
    try
        ?assertMatch({ok, _}, alang_phase8_decision:write(Path)),
        ?assertMatch({ok, [_]}, file:consult(Path)),
        ?assertMatch({error, _}, alang_phase8_decision:write(
            filename:absname("build/not-phase-08-decision.config")))
    after
        _ = file:del_dir_r(filename:dirname(Path))
    end.
