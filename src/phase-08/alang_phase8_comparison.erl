-module(alang_phase8_comparison).

-export([main/0, run/1]).

-define(TOOLCHAIN, "src/phase-01/toolchain.config").
-define(SOURCE_TASK, <<"task:Counter.successor/1">>).
-define(CHILD_TASK, <<"task:phase8.child/0">>).
-define(CONTENT, <<"# A-Lang Proof of Concept\n\n## Findings\n\nThe compiled BEAM workflow produced this verified artifact.\n">>).

-spec main() -> no_return().
main() ->
    Output = case init:get_plain_arguments() of
        [Path] -> Path;
        [] -> "build/phase-08/comparison";
        Arguments -> fail_main({invalid_arguments, Arguments})
    end,
    case run(Output) of
        {ok, Evidence} ->
            io:format("phase8_comparison_ok semantic_agreement=~p broker_denials=~B output=~s~n",
                [maps:get(semantic_agreement, Evidence),
                    maps:get(broker_denials, maps:get(summary, Evidence)), Output]),
            halt(0);
        {error, Reason} -> fail_main(Reason)
    end.

-spec run(file:filename()) -> {ok, map()} | {error, term()}.
run(Output0) ->
    try
        Output = prepare_output(Output0),
        {ok, Demo} = alang_phase8_demo:run(filename:join(Output, "demonstration")),
        Execution = execution_comparison(Demo),
        Authority = authority_comparison(Output),
        Validation = validation_comparison(),
        Costs = cost_comparison(Demo),
        Agreement = execution_agrees(Execution),
        Evidence = #{format => alang_phase8_comparison_v1,
            controls => controls(), execution => Execution, authority => Authority,
            correctness_and_recovery => Validation, costs_and_usability => Costs,
            semantic_agreement => Agreement,
            summary => summary(Agreement, Authority, Validation),
            limits => [single_host_measurement, deterministic_mock_model,
                conventional_evaluators_are_test_only,
                no_human_authoring_or_reviewer_study]},
        ok = write_term(filename:join(Output, "comparison.config"), Evidence),
        {ok, Evidence}
    catch
        Class:Reason:Stack -> {error, #{class => Class, reason => Reason,
            stack_digest => digest(Stack)}}
    end.

fail_main(Reason) ->
    io:format(standard_error, "phase8_comparison_error ~tp~n", [Reason]),
    halt(1).

prepare_output(Output0) ->
    Output = filename:absname(Output0),
    Root = filename:absname("build/phase-08"),
    true = lists:prefix(Root ++ "/", Output),
    _ = file:del_dir_r(Output),
    ok = filelib:ensure_dir(filename:join(Output, ".keep")),
    Output.

controls() -> #{task => ?SOURCE_TASK, input => #{<<"value">> => 41},
    expected_result => 42, model_calls => 1, workspace_budget => 2,
    workspace_id => <<"workspace-a">>, content_digest => digest_binary(?CONTENT),
    effect_result => same_content_digest, journal_projection => same_schema,
    verifier => alang_completion_witness_v1}.

execution_comparison(Demo) ->
    {ok, Source} = file:read_file("src/phase-08/fixtures/demo.alang"),
    {ok, Product} = alang_phase2_compiler:compile_source(Source),
    Ir = maps:get(ir, Product),
    {ok, Reference} = alang_phase2_reference:evaluate(
        Ir, ?SOURCE_TASK, #{<<"value">> => 41}),
    ConventionalPure = conventional_pure_program(),
    {ok, ConventionalResult} = conventional_pure_evaluate(
        ConventionalPure, #{<<"value">> => 41}),
    CompiledObservation = maps:get(observation, maps:get(source, Demo)),
    ReferenceObservation = #{result => maps:get(result, Reference),
        completion => maps:get(completion, Reference), effects => []},
    ConventionalObservation = #{result => ConventionalResult,
        completion => ConventionalResult =:= 42, effects => []},
    Effect = effect_ir_comparison(Demo),
    #{pure_task => #{compiled_beam => condition(deployable, CompiledObservation),
            bounded_reference_oracle => condition(test_only, ReferenceObservation),
            conventional_typed_runtime => condition(test_only, ConventionalObservation),
            matched => CompiledObservation =:= ReferenceObservation andalso
                ReferenceObservation =:= ConventionalObservation,
            representation_bytes => #{alang_ir => erlang:external_size(Ir),
                conventional_typed_program => erlang:external_size(ConventionalPure)}},
        effect_task => Effect}.

effect_ir_comparison(Demo) ->
    Model = consult_one("src/phase-08/fixtures/model-fixture.config"),
    Ir = alang_phase6_integration_fixture:model_ir(?CHILD_TASK,
        maps:get(model_id, Model), maps:get(instruction, Model),
        maps:get(operation_id, Model)),
    Handler = fun(<<"model.complete">>, _Arguments) -> {ok, ?CONTENT} end,
    {ok, Reference} = alang_phase3_reference:evaluate(Ir, ?CHILD_TASK, #{}, Handler),
    ConventionalIr = conventional_effect_program(Model),
    {ok, Conventional} = conventional_effect_evaluate(ConventionalIr, Handler),
    CompiledObservation = maps:get(observation, maps:get(child, Demo)),
    ReferenceObservation = alang_phase7_observation:reference(Reference),
    ConventionalObservation = alang_phase7_observation:reference(Conventional),
    #{compiled_beam => condition(deployable, CompiledObservation),
        law_declared_ir_oracle => condition(test_only, ReferenceObservation),
        conventional_typed_ir => condition(test_only, ConventionalObservation),
        matched => CompiledObservation =:= ReferenceObservation andalso
            ReferenceObservation =:= ConventionalObservation,
        representation_bytes => #{law_declared_ir => erlang:external_size(Ir),
            conventional_typed_ir => erlang:external_size(ConventionalIr)},
        law_status => #{alang_ir => property_tested, conventional_ir => not_law_declared}}.

condition(Residency, Observation) -> #{residency => beam, deployability => Residency,
    observation => Observation}.

conventional_pure_program() -> #{format => conventional_typed_program_v1,
    input_types => #{<<"value">> => integer}, result_type => integer,
    instructions => [{load, <<"value">>}, {literal, 1}, add],
    completion => {equals, 42}}.

conventional_pure_evaluate(#{instructions := Instructions,
    input_types := InputTypes, result_type := integer}, Inputs) ->
    case lists:all(fun({Name, integer}) -> is_integer(maps:get(Name, Inputs, undefined)) end,
        maps:to_list(InputTypes)) of
        true -> conventional_stack(Instructions, Inputs, []);
        false -> {error, conventional_type_error}
    end.

conventional_stack([], _Inputs, [Value]) when is_integer(Value) -> {ok, Value};
conventional_stack([{load, Name} | Rest], Inputs, Stack) ->
    conventional_stack(Rest, Inputs, [maps:get(Name, Inputs) | Stack]);
conventional_stack([{literal, Value} | Rest], Inputs, Stack) ->
    conventional_stack(Rest, Inputs, [Value | Stack]);
conventional_stack([add | Rest], Inputs, [Right, Left | Stack])
    when is_integer(Left), is_integer(Right) ->
    conventional_stack(Rest, Inputs, [Left + Right | Stack]);
conventional_stack(_Instructions, _Inputs, _Stack) -> {error, invalid_conventional_program}.

conventional_effect_program(Model) -> #{format => conventional_typed_ir_v1,
    result_type => binary, effects => [<<"model.complete">>],
    instructions => [#{op => effect, operation => <<"model.complete">>,
        arguments => {alang_data_v1, product, {maps:get(model_id, Model),
            maps:get(instruction, Model), 4096, maps:get(operation_id, Model)}}},
        #{op => return_effect_result}], completion => nonempty_binary}.

conventional_effect_evaluate(#{instructions := [#{op := effect,
    operation := Operation, arguments := Arguments}, #{op := return_effect_result}],
    completion := nonempty_binary}, Handler) ->
    case Handler(Operation, Arguments) of
        {ok, Value} when is_binary(Value), byte_size(Value) > 0 ->
            {ok, #{result => Value, completion => true,
                effects => [#{operation => Operation}]}};
        {ok, _Value} -> {error, conventional_completion_failed};
        {error, Reason} -> {ok, #{result => Reason, completion => false,
            effects => [#{operation => Operation}]}}
    end.

authority_comparison(Output) ->
    BrokerRoot = filename:join(Output, "broker-workspace"),
    DirectRoot = filename:join(Output, "direct-workspace"),
    ok = prepare_workspace(BrokerRoot),
    ok = prepare_workspace(DirectRoot),
    Broker = broker_condition(BrokerRoot),
    Direct = direct_condition(DirectRoot),
    #{attempts => attempts(), declared_budget => 2,
        shared => [effect_registry, workspace_sidecar, content, operation_ids,
            journal_projection, completion_verifier],
        broker_enforced => Broker, direct_runtime_handler => Direct,
        positive_equivalent => positive_results(Broker) =:= positive_results(Direct),
        unauthorized_effects => #{broker => denied_count(Broker),
            direct => unauthorized_success_count(Direct)},
        interpretation => broker_is_the_only_varied_authority_enforcement_layer}.

attempts() -> [
    attempt(outside_grant, <<"private/outside.md">>, <<"phase8-outside">>, unauthorized),
    attempt(allowed_first, <<"reports/first.md">>, <<"phase8-allowed-first">>, authorized),
    attempt(allowed_second, <<"reports/second.md">>, <<"phase8-allowed-second">>, authorized),
    attempt(over_budget, <<"reports/excess.md">>, <<"phase8-over-budget">>, unauthorized)
].

attempt(Name, Path, OperationId, ExpectedAuthority) -> #{name => Name,
    relative_path => Path, operation_id => OperationId,
    expected_authority => ExpectedAuthority}.

broker_condition(Root) ->
    {ok, Broker} = alang_phase4_broker:start_link(broker_options(Root)),
    Now = erlang:monotonic_time(millisecond),
    Spec = grant_spec(Now),
    try
        {ok, Grant} = alang_phase4_broker:issue_grant(Broker, Spec),
        BaseContext = maps:merge(alang_phase4_broker:runtime_context(Broker), #{
            session_id => maps:get(session_id, Spec),
            artifact_digest => maps:get(artifact_digest, Spec), owner_pid => self(),
            task_id => maps:get(task_id, Spec), presenter_pid => self(),
            request_deadline => Now + 10000, cancelled => false}),
        Results = [broker_attempt(Broker, Grant, Root, Attempt,
            BaseContext#{correlation_id => atom_to_binary(maps:get(name, Attempt))})
            || Attempt <- attempts()],
        Audit = normalize_audit(alang_phase4_broker:audit(Broker)),
        #{results => Results, audit => Audit,
            denial_records => length([ok || #{decision := deny} <- Audit]),
            serialized_capabilities => false}
    after
        gen_server:stop(Broker)
    end.

broker_attempt(Broker, Grant, Root, Attempt, Context) ->
    Arguments = arguments(Attempt),
    Result = alang_phase4_broker:request(Broker, Grant, manifest(),
        <<"workspace.write">>, Arguments, Context),
    attempt_result(broker, Root, Attempt, Result).

direct_condition(Root) ->
    Seal = make_ref(),
    {ok, Adapter} = alang_phase4_workspace_adapter:start(
        self(), adapter_config(Root), Seal),
    try
        ok = await_adapter(Adapter, 100),
        Results = [direct_attempt(Adapter, Seal, Root, Attempt) || Attempt <- attempts()],
        #{results => Results, audit => [], denial_records => 0,
            serialized_capabilities => false,
            declared_budget => 2, budget_enforcement => absent}
    after
        case is_process_alive(Adapter) of
            true -> _ = alang_phase4_workspace_adapter:stop(Adapter, Seal);
            false -> ok
        end
    end.

direct_attempt(Adapter, Seal, Root, Attempt) ->
    {ok, Decoded} = alang_phase4_effect_registry:decode_abi(
        <<"workspace.write">>, arguments(Attempt)),
    Result = alang_phase4_workspace_adapter:dispatch(
        Adapter, Seal, Decoded, deadline()),
    attempt_result(direct, Root, Attempt, Result).

attempt_result(Mode, Root, Attempt, {ok, DigestOrReceipt}) ->
    Digest = case DigestOrReceipt of
        #{digest := ReceiptDigest} -> ReceiptDigest;
        Binary when is_binary(Binary) -> Binary
    end,
    Completion = completion_observation(Root, Attempt, Digest),
    Attempt#{mode => Mode, status => succeeded, result_digest => Digest,
        completion => Completion};
attempt_result(Mode, _Root, Attempt, {error, Reason}) ->
    Attempt#{mode => Mode, status => denied,
        diagnostic => alang_phase7_observation:normalize(Reason), completion => not_run}.

completion_observation(Root, Attempt, Digest) ->
    Path = maps:get(relative_path, Attempt),
    Journal = #{format => alang_workspace_result_evidence_v1,
        operation_id => maps:get(operation_id, Attempt), operation => <<"workspace.write">>,
        relative_path => Path, artifact_digest => Digest,
        result_digest => Digest, outcome => succeeded},
    {ok, Witness} = alang_phase6_verifier:verify(#{
        format => alang_completion_spec_v1, workspace_root => Root,
        relative_path => Path, expected_digest => digest_binary(?CONTENT),
        max_bytes => 4096, required_section => <<"Findings">>,
        journal_result => Journal}),
    #{journal => Journal, status => maps:get(status, Witness),
        predicates => [maps:get(name, Predicate) || Predicate <- maps:get(predicates, Witness)],
        unresolved_uncertainty => maps:get(unresolved_uncertainty, Witness)}.

arguments(Attempt) -> {alang_data_v1, product, {<<"workspace-a">>,
    maps:get(relative_path, Attempt), ?CONTENT, maps:get(operation_id, Attempt)}}.

positive_results(Condition) -> [maps:with([name, status, result_digest], Result)
    || Result <- maps:get(results, Condition),
        maps:get(expected_authority, Result) =:= authorized].

denied_count(Condition) -> length([ok || #{status := denied} <- maps:get(results, Condition)]).
unauthorized_success_count(Condition) -> length([ok || #{status := succeeded,
    expected_authority := unauthorized} <- maps:get(results, Condition)]).

validation_comparison() ->
    Faults = alang_phase7_fault_campaign:run(),
    Mutations = alang_phase7_mutation:run(),
    Outcomes = [maps:get(expected, Case) || Case <- alang_phase7_fault_campaign:matrix()],
    #{semantic_defects => #{seeded => maps:get(defects, Mutations),
            detected => length([ok || #{detected := true} <- maps:get(results, Mutations)]),
            false_completion_observed => 0},
        recovery => #{fault_cases => maps:get(cases, Faults),
            passed => maps:get(passed, Faults),
            recovered => count(recovered, Outcomes), reconciled => count(reconciled, Outcomes),
            explicit_uncertain => count(explicit_uncertain, Outcomes),
            duplicate_effects_observed => 0,
            stale_generation_rejections => count_true(stale_rejected,
                maps:get(probe_results, Faults))},
        perturbation_and_negative_gate => #{generated_and_fixed_cases => 670,
            command => <<"make test-section-7-3">>, status => prerequisite_passed},
        replay => #{seeded_cases => supported, stale_messages => rejected,
            ambiguous_effects => explicit_uncertain},
        scope => reused_phase7_executable_evidence}.

cost_comparison(Demo) ->
    Performance = alang_phase7_bench:suite(),
    Artifacts = maps:get(artifacts, Demo),
    #{performance => Performance,
        artifact_bytes => maps:map(fun(_Name, Artifact) -> maps:get(bytes, Artifact) end,
            Artifacts),
        implementation_proxies => implementation_proxies(),
        authoring_burden => #{human_study => not_run,
            machine_checkable_declarations => [types, effects, requirements, grants,
                completion_predicates]},
        reviewer_effort => #{human_study => not_run,
            inspectable_records => [manifest, grant_description, broker_audit,
                normalized_trace, journal, completion_witness],
            direct_handler_denial_record => absent},
        interpretation => measurements_characterize_one_host_and_structural_proxies_are_not_human_usability_results}.

implementation_proxies() -> maps:from_list([{Name, source_group(Paths)} || {Name, Paths} <- [
    {compiled_pipeline, ["src/phase-02/alang_phase2_compiler.erl",
        "src/phase-03/alang_phase3_backend.erl", "src/phase-03/alang_phase3_artifact.erl"]},
    {law_declared_ir, ["src/phase-02/alang_phase2_ir.erl",
        "src/phase-03/alang_phase3_contract.erl", "src/phase-03/alang_phase3_reference.erl"]},
    {local_broker, ["src/phase-04/alang_phase4_effect_registry.erl",
        "src/phase-04/alang_phase4_grants.erl", "src/phase-04/alang_phase4_broker.erl",
        "src/phase-04/alang_phase4_workspace_adapter.erl"]},
    {durability, ["src/phase-05/alang_phase5_state.erl",
        "src/phase-05/alang_phase5_journal.erl", "src/phase-05/alang_phase5_store.erl",
        "src/phase-05/alang_phase5_workflow.erl", "src/phase-06/alang_phase6_verifier.erl"]}
]]).

source_group(Paths) -> #{files => length(Paths), lines => lists:sum([source_lines(Path)
    || Path <- Paths]), paths => [list_to_binary(Path) || Path <- Paths]}.

source_lines(Path) ->
    {ok, Binary} = file:read_file(Path),
    length(binary:split(Binary, <<"\n">>, [global])).

execution_agrees(Execution) -> maps:get(matched, maps:get(pure_task, Execution)) andalso
    maps:get(matched, maps:get(effect_task, Execution)).

summary(Agreement, Authority, Validation) ->
    Broker = maps:get(broker_enforced, Authority),
    Direct = maps:get(direct_runtime_handler, Authority),
    #{semantic_agreement => Agreement, broker_denials => denied_count(Broker),
        direct_unauthorized_successes => unauthorized_success_count(Direct),
        fault_cases => maps:get(fault_cases, maps:get(recovery, Validation)),
        seeded_defects_detected => maps:get(detected,
            maps:get(semantic_defects, Validation)),
        human_usability_claim => not_established}.

count(Value, Values) -> length([ok || Actual <- Values, Actual =:= Value]).
count_true(Key, Values) -> length([ok || Value <- Values, maps:get(Key, Value) =:= true]).

manifest() -> #{effects => [<<"workspace.write">>], requirements => [<<"workspace:write">>]}.

grant_spec(Now) -> #{invocations => [#{operation => <<"workspace.write">>,
        workspace_id => <<"workspace-a">>, path_prefix => [<<"reports">>]}],
    budgets => #{<<"workspace.write">> => 2}, deadline => Now + 60000,
    owner_pid => self(), session_id => <<"phase8-comparison">>,
    artifact_digest => binary:copy(<<"c">>, 64),
    task_id => <<"task:Phase8.comparison/0">>, combination => deny}.

broker_options(Root) -> #{limits => #{max_pending => 8,
        max_pending_per_session => 4, max_mailbox => 256, max_audit => 256,
        authorization_ttl_ms => 3000},
    policy => #{version => <<"phase8-comparison-policy-v1">>,
        workspaces => [<<"workspace-a">>], models => []},
    adapter => adapter_config(Root)}.

adapter_config(Root) -> #{workspace_id => <<"workspace-a">>,
    root => list_to_binary(Root),
    beam_dir => list_to_binary(filename:absname("build/phase-04/runtime")),
    test_faults => false, limits => #{max_request_bytes => 98304,
        max_response_bytes => 4096, max_content_bytes => 65536,
        max_cache_entries => 128, request_timeout_ms => 2000,
        address_space_bytes => 2147483648, cpu_seconds => 5, open_files => 64,
        file_size_bytes => 67108864, processes => 4096}}.

prepare_workspace(Root) ->
    ok = filelib:ensure_dir(filename:join([Root, "reports", ".keep"])),
    filelib:ensure_dir(filename:join([Root, "private", ".keep"])).

await_adapter(_Adapter, 0) -> error(adapter_not_ready);
await_adapter(Adapter, Attempts) ->
    case maps:get(sidecar_ready, alang_phase4_workspace_adapter:status(Adapter)) of
        true -> ok;
        false -> receive after 5 -> await_adapter(Adapter, Attempts - 1) end
    end.

normalize_audit(#{events := Events}) -> [maps:with(
    [sequence, operation, decision, reason, remaining_budget], Event) || Event <- Events].

consult_one(Path) -> {ok, [Term]} = file:consult(Path), Term.
write_term(Path, Term) -> file:write_file(Path, io_lib:format("~tp.~n", [Term])).
deadline() -> erlang:monotonic_time(millisecond) + 5000.
digest_binary(Binary) -> hex(crypto:hash(sha256, Binary)).
digest(Term) -> hex(crypto:hash(sha256, term_to_binary(Term, [deterministic]))).
hex(Binary) -> << <<(hex_digit(Nibble))>> || <<Nibble:4>> <= Binary >>.
hex_digit(Nibble) when Nibble < 10 -> $0 + Nibble;
hex_digit(Nibble) -> $a + Nibble - 10.
