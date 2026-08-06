-module(alang_fidelity_offline).

-export([
    compile_path/2,
    normalize_observation/1,
    run_fault_pair/3,
    run_matrix/1,
    run_pair/2,
    runtime_options/5,
    validate_accounting/1
]).

-define(TOOLCHAIN, "src/phase-01/toolchain.config").

-spec run_matrix(file:filename()) -> {ok, map()} | {error, term()}.
run_matrix(Base) ->
    try
        Pairs = [run_pair(Source, Base) || Source <- source_paths()],
        PairEvidence = [pair_evidence(Pair) || Pair <- Pairs],
        Equal = lists:all(fun(#{equal := Value}) -> Value end, Pairs),
        Distinct = lists:all(fun(#{raw_artifacts_distinct := Value}) -> Value end, Pairs),
        Accounted = lists:all(fun(#{accounting_valid := Value}) -> Value end, Pairs),
        case {Equal, Distinct, Accounted} of
            {true, true, true} ->
                Families = family_counts(Pairs),
                Evidence0 = #{
                    format => alang_fidelity_offline_matrix_v1,
                    case_count => length(Pairs),
                    representation_count => length(Pairs) * 2,
                    family_counts => Families,
                    pairs => PairEvidence,
                    network => disabled,
                    generated_execution => beam
                },
                {ok, Evidence0#{evidence_digest => digest(Evidence0)}};
            {false, _, _} -> {error, paired_observation_mismatch};
            {_, false, _} -> {error, representation_provenance_collapsed};
            {_, _, false} -> {error, runtime_accounting_mismatch}
        end
    catch
        Class:Reason:Stack -> {error, {offline_matrix_failed, Class, Reason,
            bounded_stack(Stack)}}
    end.

-spec run_pair(file:filename(), file:filename()) -> map().
run_pair(SourcePath, Base) ->
    JsonPath = filename:rootname(SourcePath, ".alang") ++ ".json",
    SourceProduct = compile_path(SourcePath, alang_source),
    JsonProduct = compile_path(JsonPath, typed_json),
    Metadata = maps:get(metadata, SourceProduct),
    CaseId = case_id(Metadata),
    SourceObservation = run_observation(SourceProduct, alang_source,
        filename:join(Base, binary_to_list(<<CaseId/binary, "-source">>)), none),
    JsonObservation = run_observation(JsonProduct, typed_json,
        filename:join(Base, binary_to_list(<<CaseId/binary, "-json">>)), none),
    SourceNormalized = normalize_observation(SourceObservation),
    JsonNormalized = normalize_observation(JsonObservation),
    SourceAccounting = validate_accounting(SourceObservation),
    JsonAccounting = validate_accounting(JsonObservation),
    #{
        case_id => CaseId,
        family => family(SourcePath),
        source => SourceObservation,
        json => JsonObservation,
        normalized => SourceNormalized,
        equal => SourceNormalized =:= JsonNormalized,
        accounting_valid => SourceAccounting =:= ok andalso JsonAccounting =:= ok,
        raw_artifacts_distinct => maps:get(raw_beam_sha256, SourceObservation) =/=
            maps:get(raw_beam_sha256, JsonObservation)
    }.

-spec run_fault_pair(atom(), file:filename(), file:filename()) -> map().
run_fault_pair(Scenario, SourcePath, Base) ->
    JsonPath = filename:rootname(SourcePath, ".alang") ++ ".json",
    SourceProduct = compile_path(SourcePath, alang_source),
    JsonProduct = compile_path(JsonPath, typed_json),
    CaseId = case_id(maps:get(metadata, SourceProduct)),
    SourceObservation = run_observation(SourceProduct, alang_source,
        filename:join(Base, binary_to_list(<<CaseId/binary, "-fault-source">>)), Scenario),
    JsonObservation = run_observation(JsonProduct, typed_json,
        filename:join(Base, binary_to_list(<<CaseId/binary, "-fault-json">>)), Scenario),
    SourceClass = outcome_class(maps:get(outcome, SourceObservation)),
    JsonClass = outcome_class(maps:get(outcome, JsonObservation)),
    #{scenario => Scenario, case_id => CaseId, source_class => SourceClass,
        json_class => JsonClass, equal => SourceClass =:= JsonClass}.

-spec compile_path(file:filename(), alang_source | typed_json) -> map().
compile_path(Path, Frontend) ->
    {ok, Binary} = file:read_file(Path),
    Result = case Frontend of
        alang_source -> alang_fidelity_compiler:compile_source(Binary);
        typed_json -> alang_fidelity_compiler:compile_control(Binary)
    end,
    {ok, Lowered} = Result,
    {ok, Product} = alang_fidelity_backend_v2:compile(Lowered, ?TOOLCHAIN),
    Product.

run_observation(Product, Frontend, Base, Scenario) ->
    Metadata = maps:get(metadata, Product),
    Responses0 = positive_responses(Metadata),
    {Responses, Fault} = scenario_config(Scenario, Metadata, Responses0),
    Options = runtime_options(Product, Base, Responses, Fault, true),
    ok = filelib:ensure_dir(filename:join(Base, ".keep")),
    try
        {ok, Handle} = alang_fidelity_runtime:start(maps:get(beam, Product),
            Metadata, Options),
        try
            Outcome = alang_fidelity_runtime:run(Handle, task_inputs(Metadata)),
            Snapshot = alang_fidelity_runtime:snapshot(Handle),
            Inspection = maps:get(inspection, Product),
            Artifact = observed_artifact(Outcome, Options),
            #{
                format => alang_fidelity_offline_observation_v1,
                frontend => Frontend,
                source_sha256 => maps:get(source_sha256, Metadata),
                raw_beam => maps:get(beam, Product),
                raw_beam_sha256 => maps:get(beam_sha256, Inspection),
                metadata => Metadata,
                metadata_sha256 => maps:get(metadata_sha256, Inspection),
                semantic_artifact_sha256 => maps:get(semantic_artifact_sha256, Inspection),
                semantic_sha256 => maps:get(semantic_sha256, Metadata),
                execution_plan => maps:get(execution_plan, Metadata),
                child => maps:get(child, Metadata),
                artifact => Artifact,
                outcome => Outcome,
                snapshot => Snapshot
            }
        after alang_fidelity_runtime:stop(Handle) end
    after cleanup(Base) end.

-spec normalize_observation(map()) -> map().
normalize_observation(Observation) ->
    Snapshot = maps:get(snapshot, Observation),
    Outcome = maps:get(outcome, Observation),
    #{
        format => alang_fidelity_normalized_observation_v1,
        semantic_sha256 => maps:get(semantic_sha256, Observation),
        semantic_artifact_sha256 => maps:get(semantic_artifact_sha256, Observation),
        outcome_class => outcome_class(Outcome),
        witness_digest => outcome_witness_digest(Outcome),
        counters => maps:get(counters, Snapshot),
        remaining => maps:get(remaining, Snapshot),
        trace => maps:get(trace, Snapshot),
        broker => broker_projection(maps:get(broker_audit, Snapshot)),
        journal => journal_projection(maps:get(journal, Snapshot))
    }.

-spec validate_accounting(map()) -> ok | {error, counter_mismatch}.
validate_accounting(#{execution_plan := Plan, child := Child,
        snapshot := #{counters := Counters}}) ->
    Expected = expected_counters(Plan, Child),
    Keys = [steps, model_calls, repair_calls, child_calls, workspace_writes],
    case maps:with(Keys, Counters) =:= Expected of
        true -> ok;
        false -> {error, counter_mismatch}
    end;
validate_accounting(_) -> {error, counter_mismatch}.

-spec runtime_options(map(), file:filename(), map(), atom(), boolean()) -> map().
runtime_options(Product, Base, Responses, Fault, TestMode) ->
    Metadata = maps:get(metadata, Product),
    Resources = maps:get(resources, maps:get(manifest, Metadata)),
    WorkspaceRoot = filename:absname(filename:join(Base, "workspace")),
    StoreRoot = filename:absname(filename:join(Base, "store")),
    Models = maps:from_list([{Logical, model_binding()} || Logical <-
        maps:get(models, Resources)]),
    Workspaces = maps:from_list([{Logical, #{workspace_id => <<"workspace-a">>,
        root => list_to_binary(WorkspaceRoot)}} || Logical <-
        maps:get(workspaces, Resources)]),
    #{
        format => alang_fidelity_runtime_options_v1,
        session_id => session_id(Metadata),
        bindings => #{models => Models, workspaces => Workspaces},
        responses => Responses,
        store_root => StoreRoot,
        test_mode => TestMode,
        test_fault => Fault
    }.

observed_artifact({ok, #{artifact := #{relative_path := Relative}}}, Options)
        when is_binary(Relative), Relative =/= <<>> ->
    Workspaces = maps:values(maps:get(workspaces, maps:get(bindings, Options))),
    case Workspaces of
        [#{root := Root}] ->
            Path = filename:join(binary_to_list(Root), binary_to_list(Relative)),
            case file:read_file(Path) of
                {ok, Content} -> #{
                    relative_path => Relative,
                    bytes => byte_size(Content),
                    sha256 => hex(crypto:hash(sha256, Content)),
                    content => Content
                };
                {error, Reason} -> {error, Reason}
            end;
        [] -> none
    end;
observed_artifact(_Outcome, _Options) -> none.

positive_responses(Metadata) ->
    Plan = maps:get(execution_plan, Metadata),
    HasRepair = lists:any(fun(Step) ->
        maps:get(operation, Step, none) =:= <<"model.repair">>
    end, Plan),
    Final = final_output(Metadata),
    maps:from_list(lists:filtermap(fun(Step) ->
        ActionId = maps:get(action_id, Step),
        case maps:get(operation, Step, none) of
            <<"model.generate">> when HasRepair ->
                {true, {ActionId, #{status => invalid_syntax, fragment => <<"{">>}}};
            <<"model.generate">> ->
                Output = case lists:any(fun(Candidate) ->
                    maps:get(kind, Candidate) =:= delegate
                end, Plan) of
                    true -> parent_output(Metadata);
                    false -> Final
                end,
                {true, {ActionId, #{status => success, output => Output}}};
            <<"model.repair">> ->
                {true, {ActionId, #{status => success, output => Final}}};
            <<"child.run">> ->
                {true, {ActionId, #{status => success, output => Final}}};
            _ -> false
        end
    end, Plan)).

scenario_config(none, _Metadata, Responses) -> {Responses, none};
scenario_config(denied_scope, _Metadata, Responses) -> {Responses, denied_scope};
scenario_config(exhausted_budget, Metadata, Responses) ->
    {replace_first_model(Responses, Metadata, #{status => budget_exhausted}), none};
scenario_config(malformed_response, Metadata, Responses) ->
    {replace_first_model(Responses, Metadata,
        #{status => invalid_syntax, fragment => <<"not-json">>}), none};
scenario_config(repair_failure, Metadata, Responses) ->
    Repair = first_action(<<"model.repair">>, Metadata),
    {Responses#{Repair => #{status => schema_failure, fragment => <<"still-bad">>}}, none};
scenario_config(cancellation, _Metadata, Responses) -> {Responses, cancel_before_child};
scenario_config(uncertain_workspace, _Metadata, Responses) ->
    {Responses, workspace_outcome_unknown};
scenario_config(wrong_digest, _Metadata, Responses) -> {Responses, wrong_digest};
scenario_config(missing_information, _Metadata, Responses) -> {Responses, none}.

replace_first_model(Responses, Metadata, Fixture) ->
    Action = first_action(<<"model.generate">>, Metadata),
    Responses#{Action => Fixture}.

first_action(Operation, Metadata) ->
    [Action | _] = [maps:get(action_id, Step) || Step <-
        maps:get(execution_plan, Metadata),
        maps:get(operation, Step, none) =:= Operation],
    Action.

final_output(Metadata) ->
    H1 = case [maps:get(expected, Predicate) || Predicate <-
            maps:get(predicates, maps:get(completion, Metadata)),
            maps:get(kind, Predicate) =:= <<"markdown-h1">>] of
        [Title] -> Title;
        [] -> human_title(case_id(Metadata))
    end,
    Semantic = maps:get(semantic_sha256, Metadata),
    <<"# ", H1/binary, "\n\n## Findings\n\nOffline deterministic result ",
        Semantic/binary, ".\n">>.

parent_output(Metadata) ->
    <<"# Parent Frame\n\n## Findings\n\nBounded parent frame for ",
        (maps:get(semantic_sha256, Metadata))/binary, ".\n">>.

human_title(CaseId) ->
    Words = binary:split(CaseId, <<"-">>, [global]),
    iolist_to_binary(lists:join(<<" ">>, [capitalize(Word) || Word <- Words])).

capitalize(<<First, Rest/binary>>) when First >= $a, First =< $z ->
    <<(First - 32), Rest/binary>>;
capitalize(Word) -> Word.

task_inputs(Metadata) ->
    case maps:get(terminal_class, Metadata) of
        <<"needs-clarification">> -> #{};
        _ -> maps:from_list([{maps:get(name, Parameter), input_value(maps:get(type, Parameter))}
            || Parameter <- maps:get(parameters, Metadata)])
    end.

input_value(binary) -> <<"offline-fixture">>;
input_value(path) -> <<"fixture/path">>;
input_value(model_profile) -> <<"fidelity-offline-v1">>;
input_value(json) -> #{<<"fixture">> => true}.

model_binding() -> #{model_id => <<"fixture-model-v1">>, profile => profile()}.

profile() -> #{
    format => alang_model_profile_v1,
    id => <<"fidelity-offline-v1">>,
    provider_class => mock,
    model => <<"fixture-model-v1">>,
    sampling => #{temperature_milli => 0, top_p_milli => 1000},
    max_input_bytes => 65536,
    max_output_bytes => 65536,
    max_tokens => 32768,
    timeout_ms => 5000
}.

session_id(Metadata) ->
    Prefix = binary:part(maps:get(semantic_sha256, Metadata), 0, 24),
    <<"offline-", Prefix/binary>>.

outcome_class({ok, #{status := Status}}) -> Status;
outcome_class({error, {budget_exhausted, _Key}}) -> budget_exhausted;
outcome_class({error, Reason}) when is_atom(Reason) -> Reason;
outcome_class({error, Reason}) -> bounded_reason(Reason);
outcome_class(Other) -> bounded_reason(Other).

outcome_witness_digest({ok, Witness}) -> maps:get(witness_digest, Witness);
outcome_witness_digest(_) -> none.

broker_projection(#{events := Events}) ->
    [maps:with([decision, stage, reason, operation, resource, remaining_budget], Event)
        || Event <- Events].

journal_projection(none) -> none;
journal_projection(#{records := Records}) ->
    [project_record(Record) || Record <- Records];
journal_projection(#{error := Reason}) -> {error, Reason}.

project_record(#{kind := Kind, payload := Payload}) ->
    Selected = case Kind of
        effect_intent -> maps:with([operation_id, operation, payload_digest], Payload);
        authorization -> maps:with([operation_id, decision, remaining_budget], Payload);
        submission -> maps:with([operation_id, adapter_identity, payload_digest], Payload);
        effect_result -> maps:with([operation_id, outcome, result_digest], Payload);
        _ -> #{}
    end,
    #{kind => Kind, payload => Selected}.

source_paths() ->
    lists:sort(filelib:wildcard(
        "assets/effectful-source-fidelity/corpus/*/*.alang")).

case_id(Metadata) ->
    <<"task:", Rest/binary>> = maps:get(task_id, Metadata),
    [CaseId, _Arity] = binary:split(Rest, <<"/">>),
    CaseId.

family(Path) -> list_to_binary(filename:basename(filename:dirname(Path))).

family_counts(Pairs) ->
    lists:foldl(fun(#{family := Family}, Acc) ->
        Acc#{Family => maps:get(Family, Acc, 0) + 1}
    end, #{}, Pairs).

pair_evidence(Pair) ->
    Normalized = maps:get(normalized, Pair),
    #{
        case_id => maps:get(case_id, Pair),
        family => maps:get(family, Pair),
        outcome_class => maps:get(outcome_class, Normalized),
        observation_sha256 => digest(Normalized),
        semantic_artifact_sha256 => maps:get(semantic_artifact_sha256, Normalized),
        raw_artifacts_distinct => maps:get(raw_artifacts_distinct, Pair),
        accounting_valid => maps:get(accounting_valid, Pair)
    }.

expected_counters(Plan, Child) ->
    lists:foldl(fun expected_counter/2, #{
        steps => 0,
        model_calls => 0,
        repair_calls => 0,
        child_calls => 0,
        workspace_writes => 0
    }, [{Step, Child} || Step <- Plan]).

expected_counter({Step, Child}, Acc) ->
    WithStep = increment(steps, 1, Acc),
    case maps:get(operation, Step, complete) of
        <<"model.generate">> -> increment(model_calls, 1, WithStep);
        <<"model.repair">> -> increment(repair_calls, 1,
            increment(model_calls, 1, WithStep));
        <<"workspace.write">> -> increment(workspace_writes, 1, WithStep);
        <<"child.run">> -> increment(model_calls, child_model_calls(Child),
            increment(child_calls, 1, WithStep));
        complete -> WithStep
    end.

child_model_calls(none) -> 0;
child_model_calls(Child) -> maps:get(model_calls, maps:get(limits, Child)).

increment(Key, Amount, Counters) ->
    Counters#{Key := maps:get(Key, Counters) + Amount}.

cleanup(Base) ->
    case filelib:is_dir(Base) of
        true -> file:del_dir_r(Base);
        false -> ok
    end.

bounded_reason(Term) ->
    Binary = iolist_to_binary(io_lib:format("~tp", [Term])),
    case byte_size(Binary) =< 128 of
        true -> Binary;
        false -> binary:part(Binary, 0, 128)
    end.

bounded_stack(Stack) -> lists:sublist(Stack, 3).

digest(Term) -> hex(crypto:hash(sha256, term_to_binary(Term, [deterministic]))).
hex(Binary) -> << <<(hex_digit(Nibble))>> || <<Nibble:4>> <= Binary >>.
hex_digit(Nibble) when Nibble < 10 -> $0 + Nibble;
hex_digit(Nibble) -> $a + Nibble - 10.
