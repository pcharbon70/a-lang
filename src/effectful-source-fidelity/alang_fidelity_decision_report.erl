-module(alang_fidelity_decision_report).

-export([render/1]).

-spec render(map()) -> {ok, binary()} | {error, term()}.
render(Decision) ->
    case alang_fidelity_architecture_decision:validate(Decision) of
        ok ->
            Predicates = maps:get(<<"ordered_predicates">>, Decision),
            Lines = [predicate_line(Predicate) || Predicate <- Predicates],
            {ok, iolist_to_binary([
                "# A-Lang Effectful Source Fidelity Decision\n\n",
                "## Canonical disposition\n\n",
                "- Outcome: `", maps:get(<<"outcome">>, Decision), "`\n",
                "- Basis: `", maps:get(<<"basis">>, Decision), "`\n",
                "- Campaign valid: **", boolean(maps:get(<<"campaign_valid">>, Decision)),
                "**\n",
                "- Decision digest: `", maps:get(<<"decision_digest">>, Decision), "`\n",
                "- Supported surface: `", maps:get(<<"supported_surface">>, Decision),
                "`\n\n",
                "The hosted campaign was closed before any call because live authorization "
                "was not granted. All 288 registered primary cells are explicitly missing. "
                "This outcome stops user-facing surface expansion without concluding that "
                "A-Lang or typed JSON is more effective.\n\n",
                "## Ordered rule\n\n",
                "| Predicate | Satisfied | Explanation |\n",
                "| --- | --- | --- |\n",
                Lines,
                "\n## Model and task-family results\n\n",
                "No OpenAI, Anthropic, pooled, or task-family efficacy result was produced. "
                "Rates, effect sizes, paired intervals, component comparisons, and "
                "sensitivity analyses are intentionally absent for the invalid campaign.\n\n",
                "## Safety and regression boundary\n\n",
                "Hosted comparative safety is not evaluable. The inherited compiler, broker, "
                "durability, child, workspace, completion, adversarial, and mutation gates "
                "remain required and green; they do not substitute for hosted efficacy.\n\n",
                "## Scope\n\n",
                "Retain the evidence-supported BEAM compiler and runtime enforcement "
                "fixtures. Freeze both experimental authoring surfaces. This is not "
                "production approval, model-general evidence, or human-usability evidence.\n"
            ])};
        {error, _} = Error -> Error
    end.

predicate_line(Predicate) -> [
    "| `", maps:get(<<"name">>, Predicate), "` | ",
    boolean(maps:get(<<"satisfied">>, Predicate)), " | ",
    maps:get(<<"explanation">>, Predicate), " |\n"
].

boolean(true) -> <<"true">>;
boolean(false) -> <<"false">>.
