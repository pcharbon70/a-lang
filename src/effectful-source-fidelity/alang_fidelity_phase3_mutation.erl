-module(alang_fidelity_phase3_mutation).

-export([run/0]).

-define(CORPUS_ROOT, "assets/effectful-source-fidelity/corpus").

-spec run() -> [map()].
run() ->
    [
        removed_effect_inference(),
        widened_child_limits(),
        ignored_completion_fields(),
        condition_specific_defaults(),
        unstable_node_identities(),
        direct_ir_acceptance()
    ].

removed_effect_inference() ->
    Ir = source_ir("single-model-artifact/sma-simple.alang"),
    Manifest = maps:get(manifest, Ir),
    [Task] = maps:get(tasks, Ir),
    MutantManifest = Manifest#{effects => [<<"model.generate">>]},
    Mutant = Ir#{
        manifest => MutantManifest,
        tasks => [Task#{manifest => MutantManifest}]
    },
    mutation(removed_effect_inference, manifest_effect_mismatch,
        error_code(alang_fidelity_ir:validate(Mutant))).

widened_child_limits() ->
    Ir = source_ir("attenuated-delegation/ad-simple.alang"),
    [Task] = maps:get(tasks, Ir),
    ParentLimits = maps:get(limits, Task),
    Child = maps:get(child, Task),
    ChildLimits = maps:get(limits, Child),
    MutantChild = Child#{limits => ChildLimits#{
        model_calls => maps:get(model_calls, ParentLimits) + 1
    }},
    MutantNodes = [case maps:get(kind, Node) of
        delegate -> Node#{child => MutantChild};
        _ -> Node
    end || Node <- maps:get(nodes, Ir)],
    Mutant = Ir#{
        tasks => [Task#{child => MutantChild}],
        nodes => MutantNodes
    },
    mutation(widened_child_limits, child_limit_widens_parent,
        error_code(alang_fidelity_ir:validate(Mutant))).

ignored_completion_fields() ->
    Source = read("attenuated-delegation/ad-simple.alang"),
    {ok, Checked} = alang_fidelity_semantics:check_source(Source),
    {ok, Lowered} = alang_fidelity_compiler:compile_source(Source),
    Ir = maps:get(ir, Lowered),
    [Task] = maps:get(tasks, Ir),
    Completion = maps:get(completion, Task),
    [First | _] = maps:get(predicates, Completion),
    MutantCompletion = Completion#{predicates => [First]},
    Mutant = Ir#{tasks => [Task#{completion => MutantCompletion}]},
    Actual = case {
        alang_fidelity_ir:validate(Mutant),
        MutantCompletion =:= maps:get(completion, Checked)
    } of
        {ok, false} -> completion_not_preserved;
        {{error, [Diagnostic]}, _} -> maps:get(code, Diagnostic);
        {ok, true} -> accepted
    end,
    mutation(ignored_completion_fields, completion_not_preserved, Actual).

condition_specific_defaults() ->
    Source = read("single-model-artifact/sma-simple.alang"),
    Control = read("single-model-artifact/sma-simple.json"),
    {ok, SourceLowered} = alang_fidelity_compiler:compile_source(Source),
    {ok, ControlLowered} = alang_fidelity_compiler:compile_control(Control),
    SourceIr = maps:get(ir, SourceLowered),
    ControlIr = maps:get(ir, ControlLowered),
    [Task] = maps:get(tasks, ControlIr),
    Limits = maps:get(limits, Task),
    MutantLimits = Limits#{timeout_ms => maps:get(timeout_ms, Limits) + 1},
    Mutant = ControlIr#{tasks => [Task#{limits => MutantLimits}]},
    Actual = case {
        alang_fidelity_ir:validate(Mutant),
        SourceIr =:= Mutant
    } of
        {ok, false} -> paired_ir_mismatch;
        {{error, [Diagnostic]}, _} -> maps:get(code, Diagnostic);
        {ok, true} -> accepted
    end,
    mutation(condition_specific_defaults, paired_ir_mismatch, Actual).

unstable_node_identities() ->
    Ir = source_ir("single-model-artifact/sma-simple.alang"),
    [First | Rest] = maps:get(nodes, Ir),
    Mutant = Ir#{nodes => [First#{id => <<"node:unstable">>} | Rest]},
    mutation(unstable_node_identities, unstable_node_identity,
        error_code(alang_fidelity_ir:validate(Mutant))).

direct_ir_acceptance() ->
    Ir = source_ir("single-model-artifact/sma-simple.alang"),
    mutation(direct_ir_acceptance, manual_ir_forbidden,
        error_code(alang_fidelity_compiler:compile_campaign(Ir))).

mutation(Name, Expected, Actual) ->
    #{
        name => Name,
        expected => Expected,
        actual => Actual,
        detected => Actual =:= Expected
    }.

source_ir(Relative) ->
    {ok, Lowered} = alang_fidelity_compiler:compile_source(read(Relative)),
    maps:get(ir, Lowered).

read(Relative) ->
    {ok, Binary} = file:read_file(filename:join(?CORPUS_ROOT, Relative)),
    Binary.

error_code(ok) -> accepted;
error_code({ok, _}) -> accepted;
error_code({error, [Diagnostic]}) -> maps:get(code, Diagnostic).
