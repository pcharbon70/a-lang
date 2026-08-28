-module(alang_mnemonic_protocol_tests).

-include_lib("eunit/include/eunit.hrl").

contract_and_prompt_policy_are_frozen_test() ->
    ?assertMatch({ok, _}, alang_mnemonic_protocol:load(contract_path(), ".")),
    {ok, Contract} = alang_fidelity_json:decode_file(contract_path()),
    ?assertMatch({error, _}, alang_mnemonic_protocol:validate(
        Contract#{<<"prompt_policy_sha256">> := zeros()}, ".")).

all_four_protocols_are_condition_symmetric_and_exact_test_() ->
    {timeout, 120, fun() ->
        lists:foreach(fun(Case) ->
            Oracle = alang_mnemonic_corpus:oracle(Case),
            lists:foreach(fun(Protocol) ->
                lists:foreach(fun(Condition) ->
                    {ok, Prompt} = alang_mnemonic_protocol:materialize(
                        Case, Oracle, Condition, Protocol, "."),
                    ?assertEqual(Protocol, maps:get(<<"protocol">>, Prompt)),
                    ?assertEqual(Condition, maps:get(<<"condition">>, Prompt)),
                    Bytes = maps:get(<<"bytes">>, Prompt),
                    ?assertEqual(nomatch, binary:match(Bytes, <<"answer-key">>)),
                    ?assertEqual(nomatch, binary:match(Bytes, <<"semantic-digest">>)),
                    Response = alang_mnemonic_protocol:oracle_response(Protocol,
                        Condition, Oracle),
                    {ok, Score} = alang_mnemonic_protocol:score(Protocol,
                        Condition, Response, Oracle, "."),
                    ?assertEqual(true, maps:get(<<"valid">>, Score)),
                    ?assertEqual(true, maps:get(<<"exact">>, Score))
                end, [<<"P0">>, <<"P1">>])
            end, protocols())
        end, cases())
    end}.

semantic_and_authority_mutants_score_distinctly_test_() ->
    {timeout, 60, fun() ->
        Oracle = alang_mnemonic_corpus:oracle(hd(cases())),
        Mutants = mutants(Oracle),
        ?assertEqual(17, length(Mutants)),
        lists:foreach(fun(Condition) ->
            Response = alang_mnemonic_protocol:oracle_response(
                <<"comprehension">>, Condition, Oracle),
            lists:foreach(fun({_Name, Mutant}) ->
                {ok, Score} = alang_mnemonic_protocol:score(<<"comprehension">>,
                    Condition, Response, Mutant, "."),
                ?assertEqual(false, maps:get(<<"exact">>, Score))
            end, Mutants)
        end, [<<"P0">>, <<"P1">>])
    end}.

malformed_and_cross_condition_responses_fail_test() ->
    Oracle = alang_mnemonic_corpus:oracle(hd(cases())),
    {ok, Bad} = alang_mnemonic_protocol:score(<<"comprehension">>, <<"P0">>,
        <<"not-json">>, Oracle, "."),
    ?assertEqual(false, maps:get(<<"valid">>, Bad)),
    P0Response = alang_mnemonic_protocol:oracle_response(<<"generation">>, <<"P0">>, Oracle),
    {ok, WrongSurface} = alang_mnemonic_protocol:score(<<"generation">>, <<"P1">>,
        P0Response, Oracle, "."),
    ?assertEqual(false, maps:get(<<"exact">>, WrongSurface)).

trusted_protocol_module_loads_from_beam_test() ->
    Path = code:which(alang_mnemonic_protocol),
    ?assert(is_list(Path)), ?assertEqual(".beam", filename:extension(Path)).

mutants(O) ->
    Inputs = maps:get(<<"inputs">>, O), [Input | InputRest] = Inputs,
    Requirements = maps:get(<<"requirements">>, O),
    ReqMut = case Requirements of [] -> [#{<<"kind">> => <<"resource">>, <<"resource">> => <<"mutant">>}];
        [Req | Rest] -> [Req#{<<"resource">> := <<"mutant-resource">>} | Rest] end,
    Scopes = maps:get(<<"scopes">>, O), Budgets = maps:get(<<"budgets">>, O),
    Actions = maps:get(<<"actions">>, O), [Action | ActionRest] = Actions,
    Errors = maps:get(<<"error_branches">>, O), Completion = maps:get(<<"completion_predicates">>, O),
    CompletionMut = case Completion of [] -> [#{<<"kind">> => <<"artifact-exists">>, <<"target">> => <<"mutant">>, <<"expected">> => true}];
        [Predicate | Rest2] -> [Predicate#{<<"expected">> := not maps:get(<<"expected">>, Predicate)} | Rest2] end,
    Child = maps:get(<<"child_attenuation">>, O),
    ChildMut = case Child of null -> #{<<"effects">> => [], <<"requirements">> => [],
        <<"scopes">> => #{<<"models">> => [], <<"workspaces">> => [], <<"paths">> => []},
        <<"budgets">> => Budgets}; _ -> Child#{<<"effects">> := maps:get(<<"effects">>, Child) ++ [<<"mutant.effect">>]} end,
    [
        {facts, O#{<<"goal_facts">> := maps:get(<<"goal_facts">>, O) ++ [<<"mutant fact">>]}},
        {inputs, O#{<<"inputs">> := [Input#{<<"name">> := <<"mutant-input">>} | InputRest]}},
        {effects, O#{<<"effects">> := maps:get(<<"effects">>, O) ++ [<<"mutant.effect">>]}},
        {requirements, O#{<<"requirements">> := ReqMut}},
        {scopes, O#{<<"scopes">> := Scopes#{<<"models">> := maps:get(<<"models">>, Scopes) ++ [<<"mutant-model">>]}}},
        {budgets, O#{<<"budgets">> := Budgets#{<<"steps">> := maps:get(<<"steps">>, Budgets) + 1}}},
        {actions, O#{<<"actions">> := [Action#{<<"operation">> := <<"model.repair">>} | ActionRest]}},
        {dependencies, O#{<<"actions">> := [Action#{<<"depends_on">> := [<<"mutant-dependency">>]} | ActionRest]}},
        {error_branches, O#{<<"error_branches">> := Errors ++ [#{<<"action">> => maps:get(<<"id">>, Action), <<"on">> => <<"mutant">>, <<"terminal_class">> => <<"failed">>}] }},
        {child_grants, O#{<<"child_attenuation">> := ChildMut}},
        {completion, O#{<<"completion_predicates">> := CompletionMut}},
        {clarification, O#{<<"clarification_needs">> := maps:get(<<"clarification_needs">>, O) ++ [<<"mutant clarification">>]}},
        {terminal, O#{<<"terminal_class">> := <<"failed">>}},
        {negation, O#{<<"goal_facts">> := [<<"not ", (hd(maps:get(<<"goal_facts">>, O)))/binary>> | tl(maps:get(<<"goal_facts">>, O))]}},
        {digits, O#{<<"budgets">> := Budgets#{<<"output_bytes">> := maps:get(<<"output_bytes">>, Budgets) + 10}}},
        {units, O#{<<"requirements">> := ReqMut ++ [#{<<"kind">> => <<"unit">>, <<"resource">> => <<"milliseconds">>}]}},
        {paths, O#{<<"scopes">> := Scopes#{<<"paths">> := [<<"/mutant/path">>]}}}
    ].

cases() ->
    {ok, Corpus} = alang_fidelity_json:decode_file(filename:join([
        "assets", "token-positive-mnemonic-promotion", "corpus", "confirmatory-corpus-v1.json"])),
    maps:get(<<"cases">>, Corpus).
protocols() -> [<<"action-completion">>, <<"comprehension">>,
    <<"diagnostic-repair">>, <<"generation">>].
contract_path() -> filename:join(["assets", "token-positive-mnemonic-promotion",
    "phase-02", "contracts", "protocol-contract-v1.json"]).
zeros() -> <<"0000000000000000000000000000000000000000000000000000000000000000">>.
