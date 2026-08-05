-module(alang_fidelity_phase2_integration_tests).

-include_lib("proper/include/proper.hrl").
-include_lib("eunit/include/eunit.hrl").

-export([prop_canonical_boundary_never_crashes/0, prop_text_boundary_never_crashes/0]).

-define(EVIDENCE_PATH, "build/effectful-source-fidelity/phase-02/evidence/frontend-evidence.etf").
-define(V1_TEST_MODULE, alang_phase2_compiler_tests).
-define(EVIDENCE_SHA256, <<"1cb5dda589ed04aa1e9f20fc4b69f56cbf5878bd447aff7b502ffd3d310c97da">>).
-define(AST_MANIFEST_SHA256, <<"fe669efed7d5d915ca5cfaac32017fca7da433ec270c814a45ba5830c2fac27b">>).
-define(CANONICAL_BUNDLE_SHA256, <<"f5c3b26017c5dc8e8994b79fae53433c5c28acb3869e9b7ea2a99c0b3ab1b143">>).
-define(SOURCE_MAP_BUNDLE_SHA256, <<"23aa22b62b5c0d01b3c730fc2166e4833ca0a726ebf87a1b3163b823b05a429f">>).
-define(V1_CANONICAL_SHA256, <<"0ac9fab3031c93311ae0e42f9f494c17797d2b05662443c281b2b6f7af781d28">>).

all_frozen_sources_parse_round_trip_and_retain_origins_test() ->
    Files = lists:sort(filelib:wildcard("assets/effectful-source-fidelity/corpus/*/*.alang")),
    ?assertEqual(24, length(Files)),
    Results = [round_trip(Path) || Path <- Files],
    ?assert(lists:all(fun(#{round_trip := RoundTrip}) -> RoundTrip end, Results)),
    ?assertEqual(24, length(lists:usort([maps:get(case_id, Result) || Result <- Results]))),
    ?assert(lists:all(fun(#{origin_count := Count}) -> Count >= 30 end, Results)).

evidence_is_reproducible_and_records_closed_gate_test() ->
    {ok, First} = alang_fidelity_frontend_evidence:build(),
    {ok, Second} = alang_fidelity_frontend_evidence:build(),
    ?assertEqual(First, Second),
    Body = maps:get(evidence, First),
    ?assertEqual(?EVIDENCE_SHA256, maps:get(evidence_sha256, First)),
    ?assertEqual(?AST_MANIFEST_SHA256, maps:get(ast_manifest_sha256, Body)),
    ?assertEqual(?CANONICAL_BUNDLE_SHA256, maps:get(canonical_bundle_sha256, Body)),
    ?assertEqual(?SOURCE_MAP_BUNDLE_SHA256, maps:get(source_map_bundle_sha256, Body)),
    ?assertEqual(24, maps:get(corpus_count, Body)),
    ?assertEqual(8, maps:get(negative_case_count, Body)),
    ?assertEqual(0, maps:get(hosted_calls, Body)),
    ?assertEqual([], maps:get(parser_runtime_effects, Body)),
    ?assertEqual([], maps:get(foreign_compiler_executables, Body)),
    ?assertEqual(0, maps:get(atom_growth, maps:get(robustness, Body))),
    Legacy = maps:get(legacy_v1, Body),
    ?assertEqual(true, maps:get(accepted_unchanged, Legacy)),
    ?assertEqual(?V1_CANONICAL_SHA256, maps:get(canonical_sha256, Legacy)),
    ?assert(lists:all(fun(Entry) -> maps:get(matched, Entry) end, maps:get(negative_cases, Body))),
    ?assert(lists:all(fun(Entry) -> maps:get(is_beam, Entry) end, maps:get(module_residency, Body))).

written_evidence_safe_decodes_and_matches_body_digest_test() ->
    {ok, Written} = alang_fidelity_frontend_evidence:write(?EVIDENCE_PATH),
    {ok, Binary} = file:read_file(?EVIDENCE_PATH),
    {Artifact, Used} = binary_to_term(Binary, [safe, used]),
    ?assertEqual(byte_size(Binary), Used),
    ?assertEqual(maps:remove(artifact_sha256, Written), Artifact),
    ?assertEqual(maps:get(evidence_sha256, Written), digest(maps:get(evidence, Written))),
    ?assertEqual(hex(crypto:hash(sha256, Binary)), maps:get(artifact_sha256, Written)),
    ?assertEqual({error, evidence_path_outside_owned_root}, alang_fidelity_frontend_evidence:write("build/outside.etf")).

seeded_negative_matrix_detects_each_boundary_test() ->
    Cases = alang_fidelity_frontend_evidence:negative_cases(),
    ?assertEqual(8, length(Cases)),
    lists:foreach(fun(Case) ->
        {error, [Diagnostic]} = alang_fidelity_parser:parse(maps:get(source, Case)),
        ?assertEqual(maps:get(expected, Case), maps:get(code, Diagnostic)),
        ?assertMatch(#{byte := _, line := _, column := _}, maps:get(origin, Diagnostic))
    end, Cases).

generated_text_and_canonical_boundaries_never_crash_test_() ->
    {timeout, 30, fun() ->
        Options = [{numtests, 256}, {max_size, 512}, quiet],
        ?assertEqual(true, proper:quickcheck(prop_text_boundary_never_crashes(), Options)),
        ?assertEqual(true, proper:quickcheck(prop_canonical_boundary_never_crashes(), Options))
    end}.

legacy_v1_eunit_suite_remains_available_test() ->
    ?assertEqual({module, ?V1_TEST_MODULE}, code:ensure_loaded(?V1_TEST_MODULE)).

prop_text_boundary_never_crashes() ->
    ?FORALL(Binary, proper_types:resize(512, proper_types:binary()), safe_parse(Binary)).

prop_canonical_boundary_never_crashes() ->
    ?FORALL(Binary, proper_types:resize(512, proper_types:binary()), safe_decode(Binary)).

round_trip(Path) ->
    {ok, Source} = file:read_file(Path),
    {ok, Ast} = alang_fidelity_parser:parse(Source),
    {ok, Encoded1} = alang_fidelity_canonical:encode(Ast),
    {ok, Ast} = alang_fidelity_canonical:decode(Encoded1),
    {ok, Encoded2} = alang_fidelity_canonical:encode(Ast),
    Task = maps:get(task, Ast),
    #{
        case_id => maps:get(name, Task),
        round_trip => Encoded1 =:= Encoded2,
        origin_count => count_origins(Ast)
    }.

count_origins(#{byte := Byte, line := Line, column := Column} = Map) when map_size(Map) =:= 3 ->
    case is_integer(Byte) andalso is_integer(Line) andalso is_integer(Column) of
        true -> 1;
        false -> 0
    end;
count_origins(Map) when is_map(Map) ->
    lists:sum([count_origins(Value) || Value <- maps:values(Map)]);
count_origins(List) when is_list(List) ->
    lists:sum([count_origins(Value) || Value <- List]);
count_origins(_) -> 0.

safe_parse(Binary) ->
    try alang_fidelity_parser:parse(Binary) of
        _ -> true
    catch
        _:_ -> false
    end.

safe_decode(Binary) ->
    try alang_fidelity_canonical:decode(Binary) of
        _ -> true
    catch
        _:_ -> false
    end.

digest(Term) ->
    hex(crypto:hash(sha256, term_to_binary(Term, [deterministic]))).

hex(Binary) ->
    iolist_to_binary([io_lib:format("~2.16.0b", [Byte]) || <<Byte>> <= Binary]).
