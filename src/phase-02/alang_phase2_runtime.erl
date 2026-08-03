-module(alang_phase2_runtime).

-export([main/0, run/0]).

-define(ARTIFACT, "build/phase-02/artifact").
-define(FIXTURE, "build/phase-02/frontend/phase1-semantic-fixture.config").
-define(CONFIG, "src/phase-01/toolchain.config").
-define(EVIDENCE, "build/phase-02/evidence").
-define(AGREEMENT, "build/phase-02/frontend/agreement.config").

-spec main() -> no_return().
main() ->
    case run() of
        {ok, Evidence} ->
            print_lines(maps:get(normalized_trace, Evidence)),
            io:format(
                "phase_2_agreement_ok reference_result=42 beam_result=42 no_interpreter=true~n"
            ),
            halt(0);
        {error, Reason} ->
            io:format(standard_error, "phase_2_runtime_error ~tp~n", [Reason]),
            halt(1)
    end.

-spec run() -> {ok, map()} | {error, term()}.
run() ->
    case load_agreement() of
        {ok, Agreement} ->
            case alang_phase1_runtime:run_canonical(
                ?ARTIFACT,
                ?FIXTURE,
                ?CONFIG,
                ?EVIDENCE
            ) of
                {ok, Evidence} -> validate_agreement(Agreement, Evidence);
                {error, _} = Error -> Error
            end;
        {error, _} = Error -> Error
    end.

load_agreement() ->
    case file:consult(?AGREEMENT) of
        {ok, [Agreement]} when is_map(Agreement) -> {ok, Agreement};
        {ok, Terms} -> {error, {invalid_phase2_agreement, Terms}};
        {error, Reason} -> {error, {phase2_agreement_read_failed, Reason}}
    end.

validate_agreement(
    #{
        format := alang_phase2_agreement_v1,
        task := <<"task:Counter.successor/1">>,
        input := 41,
        reference_result := 42,
        reference_completion := true,
        reference_effects := [],
        manifest_effects := []
    } = Agreement,
    #{
        classification := ok,
        exit_reason := normal,
        loaded_module := phase1_counter_v1,
        messages := Messages,
        no_interpreter_proof := #{passed := true}
    } = Evidence
) ->
    case lists:member(
        {alang_v1, result, <<"phase-1-success">>, {ok, 42}},
        Messages
    ) of
        true -> {ok, Evidence#{phase2_agreement => Agreement}};
        false -> {error, {phase2_result_disagreement, Messages}}
    end;
validate_agreement(Agreement, Evidence) ->
    {error, {phase2_semantic_disagreement, Agreement, Evidence}}.

print_lines(Lines) ->
    lists:foreach(fun(Line) -> io:format("~s~n", [Line]) end, Lines).
