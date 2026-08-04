-module(alang_phase6_repair_verifier_tests).

-include_lib("eunit/include/eunit.hrl").

bounded_repair_preserves_provenance_test() ->
    Request = request(),
    {ok, Failure} = failure(Request, invalid_syntax, <<"{">>),
    {ok, State0} = alang_phase6_repair:new(Request, 1),
    Gate = repair_gate(),
    {ok, RepairRequest, State1} = alang_phase6_repair:plan(State0, Failure, Gate),
    ?assertEqual(ok, alang_phase6_model_protocol:validate_request(RepairRequest)),
    ?assertEqual(maps:get(output_schema, Request), maps:get(output_schema, RepairRequest)),
    ?assertEqual(1, length(maps:get(context, RepairRequest))),
    ?assertEqual(maps:get(operation_id, Request),
        maps:get(parent_call_id, maps:get(provenance, RepairRequest))),
    {ok, RepairResult} = alang_phase6_model_protocol:success(RepairRequest,
        <<"# Report\n\n## Findings\n\nFixed.\n">>,
        #{format => markdown_draft_v1,
            markdown => <<"# Report\n\n## Findings\n\nFixed.\n">>},
        usage(RepairRequest, 32), metadata()),
    {ok, State2} = alang_phase6_repair:record_response(State1, RepairRequest, RepairResult),
    [Entry] = maps:get(history, alang_phase6_repair:snapshot(State2)),
    ?assertEqual(accepted, maps:get(disposition, maps:get(response, Entry))),
    ?assertEqual(1, maps:get(attempt, Entry)),
    ?assertMatch(<<_:64/binary>>, maps:get(original_context_digest, Entry)),
    ?assertEqual({terminal, repair_budget_exhausted, State2},
        alang_phase6_repair:plan(State2, Failure, Gate)).

repair_classifier_denies_unsafe_retries_test() ->
    Request = request(),
    {ok, Syntax} = failure(Request, schema_failure, <<"missing">>),
    ?assertEqual(repairable, alang_phase6_repair:classify(Syntax, repair_gate())),
    ?assertEqual({terminal, consequential_effect_retry_forbidden},
        alang_phase6_repair:classify(Syntax, (repair_gate())#{consequential_effects := true})),
    ?assertEqual({terminal, cancelled},
        alang_phase6_repair:classify(Syntax, (repair_gate())#{cancelled := true})),
    ?assertEqual({terminal, authorization_failure},
        alang_phase6_repair:classify(Syntax, (repair_gate())#{authorized := false})),
    lists:foreach(fun(Status) ->
        {ok, Terminal} = failure(Request, Status, <<>>),
        ?assertEqual({terminal, Status}, alang_phase6_repair:classify(Terminal, repair_gate()))
    end, [content_policy_denial, timeout, provider_error, budget_exhausted, outcome_unknown]).

task_machine_counts_repairs_before_new_model_call_test() ->
    Now = 1000,
    {ok, State0} = alang_phase6_task:new(task_spec(), Now),
    {ok, State1} = alang_phase6_task:transition(State0,
        {context_prepared, digest(<<"context">>), 128}, Now + 1),
    {ok, Ack} = alang_phase6_task:checkpoint(State1),
    RequestDigest = digest(<<"request">>),
    {ok, State2} = alang_phase6_task:transition(State1,
        {model_requested, RequestDigest, Ack}, Now + 2),
    {ok, State3} = alang_phase6_task:transition(State2,
        {model_result, minimal_failure(RequestDigest)}, Now + 3),
    RepairDigest = digest(<<"repair">>),
    {ok, State4} = alang_phase6_task:transition(State3,
        {repair_planned, RepairDigest}, Now + 4),
    ?assertEqual(request_model, maps:get(phase, State4)),
    ?assertEqual(1, maps:get(repair_attempts, maps:get(counters, State4))),
    {ok, RepairAck} = alang_phase6_task:checkpoint(State4),
    {ok, State5} = alang_phase6_task:transition(State4,
        {model_requested, RepairDigest, RepairAck}, Now + 5),
    {ok, State6} = alang_phase6_task:transition(State5,
        {model_result, minimal_failure(RepairDigest)}, Now + 6),
    {incomplete, repair_bound_exhausted, Exhausted} = alang_phase6_task:transition(State6,
        {repair_planned, digest(<<"repair-2">>)}, Now + 7),
    ?assertEqual(incomplete, maps:get(phase, Exhausted)).

completion_witness_requires_every_artifact_and_journal_predicate_test() ->
    Root = verifier_root(),
    Relative = <<"reports/result.md">>,
    Path = filename:join(Root, "reports/result.md"),
    ok = filelib:ensure_dir(Path),
    Content = <<"# Report\n\n## Findings\n\nVerified.\n">>,
    ok = file:write_file(Path, Content),
    Expected = digest_binary(Content),
    Spec = completion_spec(Root, Relative, Expected),
    try
        {ok, Witness} = alang_phase6_verifier:verify(Spec),
        ?assertEqual(complete, maps:get(status, Witness)),
        ?assertEqual(ok, alang_phase6_verifier:validate_witness(Witness)),
        ?assertEqual({error, invalid_completion_witness},
            alang_phase6_verifier:validate_witness(Witness#{witness_digest := digest(<<"forged">>)})),
        ?assert(lists:all(fun(Predicate) -> maps:get(passed, Predicate) end,
            maps:get(predicates, Witness))),
        ?assertEqual([], maps:get(unresolved_uncertainty, Witness)),
        {ok, BadJournal} = alang_phase6_verifier:verify(Spec#{journal_result :=
            (maps:get(journal_result, Spec))#{artifact_digest := digest(<<"wrong">>)}}),
        ?assertEqual(incomplete, maps:get(status, BadJournal)),
        ?assert(lists:member(journal_binding, maps:get(unresolved_uncertainty, BadJournal))),
        ok = file:write_file(Path, <<"# Report\n\n## Findings\n\n">>),
        {ok, BadArtifact} = alang_phase6_verifier:verify(Spec),
        ?assertEqual(incomplete, maps:get(status, BadArtifact)),
        ?assert(lists:member(digest_match, maps:get(unresolved_uncertainty, BadArtifact))),
        ?assert(lists:member(required_section_nonempty,
            maps:get(unresolved_uncertainty, BadArtifact)))
    after
        _ = file:delete(Path),
        _ = file:del_dir(filename:join(Root, "reports")),
        _ = file:del_dir(Root)
    end.

symlink_and_traversal_are_not_completion_evidence_test() ->
    Root = verifier_root(),
    Outside = Root ++ "-outside.md",
    Link = filename:join(Root, "result.md"),
    ok = filelib:ensure_dir(Link),
    Content = <<"# Report\n\n## Findings\n\nOutside.\n">>,
    ok = file:write_file(Outside, Content),
    ok = file:make_symlink(Outside, Link),
    Spec = completion_spec(Root, <<"result.md">>, digest_binary(Content)),
    try
        {ok, Witness} = alang_phase6_verifier:verify(Spec),
        ?assertEqual(incomplete, maps:get(status, Witness)),
        ?assert(lists:member(regular_file, maps:get(unresolved_uncertainty, Witness))),
        ?assertEqual({error, invalid_completion_specification},
            alang_phase6_verifier:verify(Spec#{relative_path := <<"../escape.md">>}))
    after
        _ = file:delete(Link),
        _ = file:delete(Outside),
        _ = file:del_dir(Root)
    end.

request() ->
    {ok, Request} = alang_phase6_model_protocol:new_request(#{
        operation_id => <<"model-call-original">>,
        profile => profile(),
        context => [fragment(<<"goal">>, <<"Write a report">>)],
        instruction => <<"Draft the result">>,
        output_schema => #{format => alang_output_schema_v1, id => markdown_draft_v1,
            max_bytes => 4096, required_sections => [<<"Findings">>]},
        deadline => 20000,
        retry_class => repair_only,
        redaction_policy => #{format => alang_redaction_policy_v1, trace_content => digest_only,
            retain_provider_fields => []},
        provenance => #{format => alang_model_provenance_v1, task_id => <<"task:repair/0">>,
            goal_digest => digest(<<"goal">>), parent_call_id => none}
    }),
    Request.

profile() -> #{
    format => alang_model_profile_v1,
    id => <<"mock-deterministic-v1">>,
    provider_class => mock,
    model => <<"fixture-model-v1">>,
    sampling => #{temperature_milli => 0, top_p_milli => 1000},
    max_input_bytes => 16384,
    max_output_bytes => 8192,
    max_tokens => 8192,
    timeout_ms => 2000
}.

fragment(Id, Content) -> #{
    format => alang_context_fragment_v1,
    id => Id,
    visibility => public,
    provenance => digest({Id, Content}),
    trust => instruction,
    content => Content
}.

failure(Request, Status, Fragment) ->
    alang_phase6_model_protocol:failure(Request, Status,
        #{code => atom_to_binary(Status), fragment => Fragment, offset => none},
        usage(Request, 0), metadata()).

usage(Request, OutputBytes) -> #{input_tokens => 4, output_tokens => 0,
    input_bytes => byte_size(maps:get(instruction, Request)), output_bytes => OutputBytes}.
metadata() -> #{provider => <<>>, model => <<>>, request_id => <<>>, finish_reason => <<>>}.
repair_gate() -> #{consequential_effects => false, cancelled => false, authorized => true}.

task_spec() -> #{
    format => alang_task_spec_v1,
    task_id => <<"task:repair/0">>,
    original_goal => <<"Produce a verified report">>,
    profile_id => <<"mock-deterministic-v1">>,
    output_schema_id => markdown_draft_v1,
    limits => #{max_model_calls => 3, max_repair_attempts => 1, max_steps => 16,
        max_elapsed_ms => 10000, max_context_bytes => 4096, max_output_bytes => 4096,
        max_effects => 1},
    deadline => 20000
}.

minimal_failure(RequestDigest) -> #{format => alang_model_result_v1,
    status => invalid_syntax, request_digest => RequestDigest}.

completion_spec(Root, Relative, Expected) -> #{
    format => alang_completion_spec_v1,
    workspace_root => Root,
    relative_path => Relative,
    expected_digest => Expected,
    max_bytes => 4096,
    required_section => <<"Findings">>,
    journal_result => #{
        format => alang_workspace_result_evidence_v1,
        operation_id => <<"workspace-operation-1">>,
        operation => <<"workspace.write">>,
        relative_path => Relative,
        artifact_digest => Expected,
        result_digest => digest(<<"journal-result">>),
        outcome => succeeded
    }
}.

verifier_root() ->
    filename:absname(filename:join(["build", "phase-06",
        "verifier-" ++ integer_to_list(erlang:unique_integer([positive]))])).

digest_binary(Binary) -> hex(crypto:hash(sha256, Binary)).
digest(Term) -> hex(crypto:hash(sha256, term_to_binary(Term, [deterministic]))).
hex(Binary) -> << <<(hex_digit(Nibble))>> || <<Nibble:4>> <= Binary >>.
hex_digit(Nibble) when Nibble < 10 -> $0 + Nibble;
hex_digit(Nibble) -> $a + Nibble - 10.
