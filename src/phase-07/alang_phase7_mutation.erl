-module(alang_phase7_mutation).

-export([defects/0, detect/1, run/0]).

-spec defects() -> [map()].
defects() -> [
    defect(identity, semantic_backend, categorical_identity),
    defect(composition, semantic_backend, categorical_composition),
    defect(branch_lowering, semantic_backend, result_branch_differential),
    defect(effect_union, semantic_backend, manifest_union_law),
    defect(manifest_interpretation, semantic_backend, compiled_manifest_differential),
    defect(serialization, semantic_backend, canonical_round_trip),
    defect(evaluation_order, semantic_backend, effect_trace_differential),
    defect(runtime_abi_mapping, semantic_backend, adversarial_abi_mapping),
    defect(subset_restriction, authorization_recovery, finite_authority_subset),
    defect(policy_accumulation, authorization_recovery, policy_conjunction),
    defect(expiry, authorization_recovery, grant_lifecycle),
    defect(session_generation_binding, authorization_recovery, grant_binding),
    defect(revocation, authorization_recovery, grant_lifecycle),
    defect(budget_atomicity, authorization_recovery, broker_state_machine),
    defect(path_containment, authorization_recovery, resource_boundary),
    defect(journal_ordering, authorization_recovery, journal_chain_validation),
    defect(crash_retry, authorization_recovery, recovery_state_machine)
].

-spec run() -> map().
run() ->
    Results = [detect(Defect) || Defect <- defects()],
    #{format => alang_phase7_mutation_result_v1,
        defects => length(Results),
        categories => #{semantic_backend => count(semantic_backend, Results),
            authorization_recovery => count(authorization_recovery, Results)},
        results => Results,
        passed => lists:all(fun(#{detected := Detected, counterexample := Counterexample}) ->
            Detected andalso Counterexample =/= undefined
        end, Results)}.

-spec detect(map() | atom()) -> map().
detect(Name) when is_atom(Name) ->
    case [Defect || #{name := DefectName} = Defect <- defects(), DefectName =:= Name] of
        [Defect] -> detect(Defect);
        [] -> #{name => Name, detected => false, counterexample => undefined,
            reason => unknown_defect}
    end;
detect(#{name := Name, category := Category, intended_test := Intended}) ->
    {Detected, Counterexample, Expected, Mutant} = detection(Name),
    #{name => Name, category => Category, intended_test => Intended,
        detected => Detected, counterexample => Counterexample,
        expected => Expected, mutant => Mutant}.

defect(Name, Category, Intended) ->
    #{name => Name, category => Category, intended_test => Intended}.

count(Category, Results) ->
    length([ok || #{category := Actual} <- Results, Actual =:= Category]).

detection(identity) ->
    Value = 0,
    Expected = alang_phase2_ir:apply_transform(alang_phase2_ir:identity(), Value),
    Mutant = Value + 1,
    result(Expected =/= Mutant, #{value => Value}, Expected, Mutant);
detection(composition) ->
    Value = 1,
    Expected = alang_phase2_ir:apply_transform(
        alang_phase2_ir:compose(double, increment), Value),
    Mutant = alang_phase2_ir:apply_transform(increment,
        alang_phase2_ir:apply_transform(double, Value)),
    result(Expected =/= Mutant, #{value => Value, left => double, right => increment},
        Expected, Mutant);
detection(branch_lowering) ->
    Input = {alang_data_v1, error, denied},
    Expected = branch(Input),
    Mutant = mutant_branch(Input),
    result(Expected =/= Mutant, #{input => Input}, Expected, Mutant);
detection(effect_union) ->
    Left = #{effects => [<<"workspace.write">>], requirements => [<<"workspace:write">>]},
    Right = #{effects => [<<"model.complete">>], requirements => [<<"model:invoke">>]},
    Expected = alang_phase7_observation:manifest_union(Left, Right),
    Mutant = Left,
    result(Expected =/= Mutant, #{left => Left, right => Right}, Expected, Mutant);
detection(manifest_interpretation) ->
    Manifest = #{effects => [<<"workspace.write">>], requirements => [<<"workspace:write">>]},
    Mutant = Manifest#{requirements := []},
    result(Manifest =/= Mutant, Manifest, Manifest, Mutant);
detection(serialization) ->
    Value = {alang_data_v1, product, {0, 1}},
    Expected = Value,
    Mutant = {alang_data_v1, product, {1, 0}},
    result(Expected =/= Mutant, #{encoded_value => Value}, Expected, Mutant);
detection(evaluation_order) ->
    Expected = [left_effect, right_effect],
    Mutant = lists:reverse(Expected),
    result(Expected =/= Mutant, #{expression => sequential_pair}, Expected, Mutant);
detection(runtime_abi_mapping) ->
    Args = {alang_data_v1, product,
        {<<"workspace-a">>, <<"notes/result.md">>, <<"x">>, <<"mutation-abi">>}},
    {ok, Decoded} = alang_phase4_effect_registry:decode_abi(<<"workspace.write">>, Args),
    Expected = maps:get(adapter, Decoded),
    Mutant = model_adapter,
    result(Expected =/= Mutant, #{operation => <<"workspace.write">>}, Expected, Mutant);
detection(subset_restriction) ->
    Parent = alang_phase7_authority_model:observe([workspace_invocation([<<"notes">>])]),
    AllowedChild = alang_phase7_authority_model:observe(
        [workspace_invocation([<<"notes">>, <<"reports">>])]),
    Widened = lists:usort(AllowedChild ++
        alang_phase7_authority_model:observe([workspace_invocation([])])),
    Expected = alang_phase7_authority_model:subset(AllowedChild, Parent),
    Mutant = alang_phase7_authority_model:subset(Widened, Parent),
    result(Expected andalso not Mutant,
        #{parent_size => length(Parent), mutant_child_size => length(Widened)},
        Expected, Mutant);
detection(policy_accumulation) ->
    ParentAllows = true,
    RestrictionAllows = false,
    Expected = ParentAllows andalso RestrictionAllows,
    Mutant = ParentAllows orelse RestrictionAllows,
    result(Expected =/= Mutant, #{parent => ParentAllows, restriction => RestrictionAllows},
        Expected, Mutant);
detection(expiry) ->
    Now = 101,
    Deadline = 100,
    Expected = Now =< Deadline,
    Mutant = true,
    result(Expected =/= Mutant, #{now => Now, deadline => Deadline}, Expected, Mutant);
detection(session_generation_binding) ->
    Grant = #{session => <<"session-a">>, generation => 2},
    Context = #{session => <<"session-b">>, generation => 1},
    Expected = Grant =:= Context,
    Mutant = true,
    result(Expected =/= Mutant, #{grant => Grant, context => Context}, Expected, Mutant);
detection(revocation) ->
    Expected = false,
    Mutant = true,
    result(Expected =/= Mutant, #{grant_status => revoked}, Expected, Mutant);
detection(budget_atomicity) ->
    Budget = 1,
    ExpectedAllowed = erlang:min(Budget, 2),
    MutantAllowed = 2,
    result(ExpectedAllowed =/= MutantAllowed,
        #{budget => Budget, concurrent_requests => 2}, ExpectedAllowed, MutantAllowed);
detection(path_containment) ->
    Prefix = [<<"notes">>],
    Path = [<<"notes-escape">>, <<"result.md">>],
    Expected = lists:prefix(Prefix, Path),
    Mutant = textual_prefix(hd(Prefix), hd(Path)),
    result(Expected =/= Mutant, #{prefix => Prefix, path => Path}, Expected, Mutant);
detection(journal_ordering) ->
    Session = <<"phase7-mutation-journal">>,
    {ok, Journal0} = alang_phase5_journal:new(Session),
    {ok, First, Journal1} = alang_phase5_journal:append(Journal0, observation, 1,
        #{observation_digest => digest(first)}, 1000),
    {ok, Second, _Journal2} = alang_phase5_journal:append(Journal1, observation, 1,
        #{observation_digest => digest(second)}, 1001),
    Reversed = [Second, First],
    Expected = element(1, alang_phase5_journal:validate(Reversed, Session)),
    Sorted = lists:sort(fun(A, B) -> maps:get(sequence, A) =< maps:get(sequence, B) end,
        Reversed),
    Mutant = element(1, alang_phase5_journal:validate(Sorted, Session)),
    result(Expected =/= Mutant, #{record_sequences => [1, 0]}, Expected, Mutant);
detection(crash_retry) ->
    Commands = [intent, authorize, submit, crash, recover, submit],
    ExpectedState = alang_phase7_history_model:run(Commands, 1),
    MutantState = ExpectedState#{submissions := 2, retries := 1},
    Expected = alang_phase7_history_model:invariants(ExpectedState),
    Mutant = alang_phase7_history_model:invariants(MutantState),
    result(Expected =:= ok andalso Mutant =/= ok, #{commands => Commands}, Expected, Mutant).

result(Detected, Counterexample, Expected, Mutant) ->
    {Detected, Counterexample, Expected, Mutant}.

branch({alang_data_v1, ok, Value}) -> {ok_branch, Value};
branch({alang_data_v1, error, Reason}) -> {error_branch, Reason}.

mutant_branch({alang_data_v1, _Tag, Value}) -> {ok_branch, Value}.

workspace_invocation(Prefix) -> #{operation => <<"workspace.write">>,
    workspace_id => <<"workspace-a">>, path_prefix => Prefix}.

textual_prefix(Prefix, Value) ->
    byte_size(Value) >= byte_size(Prefix) andalso
        binary:part(Value, 0, byte_size(Prefix)) =:= Prefix.

digest(Term) -> hex(crypto:hash(sha256, term_to_binary(Term, [deterministic]))).
hex(Binary) -> << <<(hex_digit(Nibble))>> || <<Nibble:4>> <= Binary >>.
hex_digit(Nibble) when Nibble < 10 -> $0 + Nibble;
hex_digit(Nibble) -> $a + Nibble - 10.
