-module(alang_fidelity_phase4_mutation).

-export([seed/2]).

-spec seed(atom(), term()) -> term().
seed(ignored_manifest, Metadata) when is_map(Metadata) ->
    Manifest = maps:get(manifest, Metadata),
    Metadata#{manifest := Manifest#{effects := []}};
seed(increased_runtime_limits, Options) when is_map(Options) ->
    Options#{limits => #{steps => 999999}};
seed(condition_specific_handler, Options) when is_map(Options) ->
    Options#{handler => fun(_Operation, _Arguments) -> bypass end};
seed(json_frontend_bypass, {Content, SemanticDigest}) when is_binary(Content) ->
    #{
        format => alang_campaign_input_v1,
        frontend => alang_source,
        content => Content,
        content_digest => alang_fidelity_json:hex(crypto:hash(sha256, Content)),
        semantic_digest => SemanticDigest
    };
seed(source_map_swap, {SourceMetadata, JsonMetadata}) ->
    SourceMetadata#{source_map := maps:get(source_map, JsonMetadata)};
seed(skipped_repair_accounting,
        #{snapshot := #{counters := Counters} = Snapshot} = Observation) ->
    Observation#{snapshot := Snapshot#{counters := Counters#{repair_calls := 0}}};
seed(child_authority_widening, Ir) when is_map(Ir) ->
    [Task] = maps:get(tasks, Ir),
    Child = maps:get(child, Task),
    Limits = maps:get(limits, Child),
    Widened = Child#{limits := Limits#{child_calls := 1}},
    [Delegate] = [Node || Node <- maps:get(nodes, Ir),
        maps:get(kind, Node) =:= delegate],
    Nodes = [case maps:get(id, Node) =:= maps:get(id, Delegate) of
        true -> Node#{child := Widened};
        false -> Node
    end || Node <- maps:get(nodes, Ir)],
    Ir#{tasks := [Task#{child := Widened}], nodes := Nodes};
seed(Name, Value) -> {unknown_mutant, Name, Value}.
