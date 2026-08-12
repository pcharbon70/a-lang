-module(alang_compact_phase2_integration_tests).

-include_lib("eunit/include/eunit.hrl").

clean_process_evidence_is_byte_identical_test_() ->
    {timeout, 60, fun() ->
        {ok, FirstBytes} = file:read_file(reproduction_a()),
        {ok, SecondBytes} = file:read_file(reproduction_b()),
        ?assertEqual(FirstBytes, SecondBytes),
        {ok, Evidence} = alang_fidelity_json:decode(FirstBytes),
        ?assertEqual(<<"alang-compact-phase-2-integration-evidence-v1">>,
            maps:get(<<"format">>, Evidence)),
        ?assertEqual(48, maps:get(<<"confirmatory_cases">>, Evidence)),
        ?assertEqual(24, maps:get(<<"development_cases">>, Evidence)),
        ?assertEqual(72, maps:get(<<"semantic_cases">>, Evidence)),
        ?assertEqual(6, maps:get(<<"registered_surfaces">>, Evidence)),
        ?assertEqual(432, maps:get(<<"surface_case_cells">>, Evidence)),
        ?assertEqual(432, maps:get(<<"canonical_round_trips">>, Evidence)),
        ?assertEqual(432, maps:get(<<"source_mapped_surfaces">>, Evidence)),
        ?assertEqual(864, maps:get(<<"token_reports">>,
            maps:get(<<"token_accounting">>, Evidence)))
    end}.

all_surface_rows_are_semantic_source_map_and_accounting_complete_test_() ->
    {timeout, 30, fun() ->
        Evidence = evidence(),
        Rows = maps:get(<<"rows">>, Evidence),
        ?assertEqual([<<"R0">>, <<"R1">>, <<"R2">>, <<"R3">>, <<"R4">>, <<"R5">>],
            lists:usort([maps:get(<<"surface_id">>, Row) || Row <- Rows])),
        ?assert(lists:all(fun(Row) ->
            maps:get(<<"source_map_coverage">>, Row) =:=
                <<"contiguous-every-byte-exactly-once">> andalso
            maps:get(<<"source_map_tokens">>, Row) > 0 andalso
            maps:get(<<"security_fields">>, Row) > 0 andalso
            length(maps:get(<<"token_reports">>, Row)) =:= 2 andalso
            lists:all(fun(Report) ->
                maps:get(<<"provenance">>, Report) =:= <<"exact-registered-tokenizer">> andalso
                maps:get(<<"document_tokens">>, Report) > 0 andalso
                maps:get(<<"full_request_tokens">>, Report) >
                    maps:get(<<"document_tokens">>, Report)
            end, maps:get(<<"token_reports">>, Row))
        end, Rows)),
        Accounting = maps:get(<<"token_accounting">>, Evidence),
        ?assertEqual(0, maps:get(<<"proxy_counts">>, Accounting)),
        ?assertEqual(<<"unavailable">>, maps:get(<<"provider_usage">>, Accounting)),
        Savings = maps:get(<<"r3_savings_vs_r0">>, Evidence),
        ?assert(maps:get(<<"saved_representation_bytes">>, Savings) > 0),
        ?assert(lists:all(fun(Value) ->
            R0 = maps:get(<<"r0_document_tokens">>, Value),
            R3 = maps:get(<<"r3_document_tokens">>, Value),
            R0 > 0 andalso R3 > 0 andalso
                maps:get(<<"saved_document_tokens">>, Value) =:= R0 - R3 andalso
                is_integer(maps:get(<<"savings_basis_points">>, Value))
        end, maps:get(<<"document_token_savings">>, Savings)))
    end}.

generated_valid_tasks_round_trip_every_surface_test_() ->
    {timeout, 30, fun() ->
        Base = executable_oracle(),
        lists:foreach(fun(Index) ->
            Oracle = generated_oracle(Base, Index),
            ?assertMatch({ok, _}, alang_fidelity_contract:validate_comprehension(Oracle)),
            lists:foreach(fun(Surface) -> assert_round_trip(Oracle, Surface) end, surfaces())
        end, lists:seq(1, 16))
    end}.

invalid_checked_tasks_fail_before_every_renderer_test() ->
    Base = delegated_oracle(),
    Invalid = invalid_oracles(Base),
    ?assertEqual(8, length(Invalid)),
    lists:foreach(fun(Oracle) ->
        ?assertMatch({error, _}, alang_fidelity_contract:validate_comprehension(Oracle)),
        lists:foreach(fun(Surface) ->
            ?assertMatch({error, {invalid_checked_semantics, _}}, render(Oracle, Surface))
        end, surfaces())
    end, Invalid).

seeded_mutation_campaign_detects_every_named_defect_test() ->
    {ok, Mutation} = alang_compact_phase2_mutation:run(),
    ?assertEqual(7, maps:get(<<"seeded">>, Mutation)),
    ?assertEqual(7, maps:get(<<"detected">>, Mutation)),
    ?assertEqual(10000, maps:get(<<"mutation_score_basis_points">>, Mutation)),
    ?assertEqual([
        <<"alias-reverse-entry-removal">>,
        <<"authority-budget-widening">>,
        <<"decoder-unknown-field">>,
        <<"derivation-witness-removal">>,
        <<"representation-version-change">>,
        <<"source-map-range-shift">>,
        <<"token-attribution-category-removal">>
    ], lists:sort([maps:get(<<"name">>, Mutant) ||
        Mutant <- maps:get(<<"mutants">>, Mutation)])).

trusted_module_closure_is_deterministic_beam_only_test() ->
    {ok, Residency} = alang_compact_phase2_residency:audit("."),
    Modules = maps:get(<<"trusted_modules">>, Residency),
    ?assertEqual(length(alang_compact_phase2_residency:trusted_modules()), length(Modules)),
    ?assert(lists:all(fun(Module) ->
        filename:extension(binary_to_list(maps:get(<<"artifact">>, Module))) =:= ".beam"
    end, Modules)),
    ?assertEqual([], maps:get(<<"foreign_build_inputs">>, Residency)),
    ?assertEqual([], maps:get(<<"forbidden_runtime_imports">>, Residency)),
    ?assertEqual(0, maps:get(<<"ports_or_shell_commands">>, Residency)),
    ?assertEqual(0, maps:get(<<"provider_sdks">>, Residency)).

registered_versions_representation_and_alias_bounds_fail_closed_test() ->
    Oracle = executable_oracle(),
    Oversized = binary:copy(<<"x">>, 32769),
    lists:foreach(fun(Surface) ->
        SurfaceId = maps:get(<<"id">>, Surface),
        Version = maps:get(<<"version">>, Surface),
        MutantVersion = <<Version/binary, "-mutant">>,
        ?assertMatch({error, {surface_version_mismatch, _, _, _}},
            alang_compact_surface:render(SurfaceId, MutantVersion, Oracle, registry_path())),
        OversizeResult = case SurfaceId of
            <<"R4">> -> alang_compact_surface:decode(SurfaceId, Version, Oversized,
                #{opaque_reverse_map => #{}});
            _ -> alang_compact_surface:decode(SurfaceId, Version, Oversized)
        end,
        ?assertEqual({error, {representation_too_large, 32769, 32768}}, OversizeResult)
    end, surfaces()),
    {ok, ModelSurface} = render(Oracle, surface(<<"R3">>)),
    Compact = compact_value(maps:get(bytes, ModelSurface)),
    TooManyLocal = maps:from_list([{<<"n", (integer_to_binary(Index))/binary>>,
        <<"local-name-", (integer_to_binary(Index))/binary>>} || Index <- lists:seq(0, 64)]),
    ?assertMatch({error, {compact_model_error, [<<"aliases">>], too_many_aliases}},
        alang_compact_model:decode(compact_binary(Compact#{<<"aliases">> := TooManyLocal}))),
    {ok, OpaqueSurface} = render(Oracle, surface(<<"R4">>)),
    TooManyOpaque = maps:from_list([{<<"o", (integer_to_binary(Index))/binary>>,
        #{<<"kind">> => <<"action">>,
            <<"original">> => <<"opaque-name-", (integer_to_binary(Index))/binary>>}}
        || Index <- lists:seq(0, 128)]),
    ?assertMatch({error, {compact_opaque_error, [<<"reverse_map">>],
        too_many_opaque_aliases}}, alang_compact_surface:decode(<<"R4">>,
            <<"alang-model-v1-opaque-control">>, maps:get(bytes, OpaqueSurface),
            #{opaque_reverse_map => TooManyOpaque})).

offline_evidence_makes_no_model_fidelity_claim_test() ->
    Evidence = evidence(),
    ?assertEqual(0, maps:get(<<"model_calls">>, Evidence)),
    ?assertEqual(0, maps:get(<<"provider_calls">>, Evidence)),
    ?assertEqual(false, maps:get(<<"model_fidelity_claimed">>, Evidence)),
    ?assertEqual(<<"disabled-by-construction">>, maps:get(<<"network_access">>, Evidence)).

assert_round_trip(Oracle, Surface) ->
    {ok, Rendered} = render(Oracle, Surface),
    {ok, Map} = alang_compact_source_map:build(Rendered, Oracle),
    ?assertEqual(<<"contiguous-every-byte-exactly-once">>, maps:get(<<"coverage">>, Map)),
    SurfaceId = maps:get(<<"id">>, Surface),
    Version = maps:get(<<"version">>, Surface),
    Decoded = case SurfaceId of
        <<"R4">> ->
            Provenance = maps:get(provenance, Rendered),
            alang_compact_surface:decode(SurfaceId, Version, maps:get(bytes, Rendered),
                #{opaque_reverse_map => maps:get(opaque_reverse_map, Provenance)});
        _ -> alang_compact_surface:decode(SurfaceId, Version, maps:get(bytes, Rendered))
    end,
    {ok, Value} = Decoded,
    ?assertEqual(alang_fidelity_contract:semantic_digest(Oracle),
        maps:get(semantic_digest, Value)).

render(Oracle, Surface) ->
    alang_compact_surface:render(maps:get(<<"id">>, Surface),
        maps:get(<<"version">>, Surface), Oracle, registry_path()).

generated_oracle(Base, Index) ->
    Bytes = 256 + Index * 97,
    Budgets = (maps:get(<<"budgets">>, Base))#{<<"output_bytes">> := Bytes},
    Predicates = [case maps:get(<<"kind">>, Predicate) of
        <<"max-bytes">> -> Predicate#{<<"expected">> := Bytes};
        _ -> Predicate
    end || Predicate <- maps:get(<<"completion_predicates">>, Base)],
    Base#{
        <<"case_id">> := <<"phase2-generated-", (integer_to_binary(Index))/binary>>,
        <<"budgets">> := Budgets,
        <<"completion_predicates">> := Predicates,
        <<"goal_facts">> := [<<"Generated phase 2 constraint ",
            (integer_to_binary(Index))/binary>> | maps:get(<<"goal_facts">>, Base)]
    }.

invalid_oracles(Base) ->
    Scopes = maps:get(<<"scopes">>, Base),
    Budgets = maps:get(<<"budgets">>, Base),
    Child = maps:get(<<"child_attenuation">>, Base),
    [FirstError | RestErrors] = maps:get(<<"error_branches">>, Base),
    [FirstPredicate | RestPredicates] = maps:get(<<"completion_predicates">>, Base),
    [FirstAction | RestActions] = maps:get(<<"actions">>, Base),
    [
        Base#{<<"effects">> := [<<"shell.execute">>]},
        Base#{<<"requirements">> := [#{<<"kind">> => <<"network">>,
            <<"resource">> => <<"public-internet">>}]},
        Base#{<<"scopes">> := Scopes#{<<"models">> := <<"not-a-list">>}},
        Base#{<<"budgets">> := Budgets#{<<"timeout_ms">> := 0}},
        Base#{<<"error_branches">> := [FirstError#{<<"terminal_class">> := <<"continue">>} |
            RestErrors]},
        Base#{<<"child_attenuation">> := Child#{<<"effects">> := [<<"shell.execute">>]}},
        Base#{<<"completion_predicates">> := [FirstPredicate#{<<"kind">> := <<"always">>} |
            RestPredicates]},
        Base#{<<"actions">> := [FirstAction#{<<"operation">> := <<"shell.execute">>} |
            RestActions]}
    ].

evidence() ->
    {ok, Bytes} = file:read_file(reproduction_a()),
    {ok, Value} = alang_fidelity_json:decode(Bytes),
    Value.

surfaces() ->
    {ok, Registry} = alang_compact_surface:load_registry(registry_path()),
    maps:get(<<"surfaces">>, Registry).

surface(SurfaceId) ->
    [Value] = [Value || Value <- surfaces(), maps:get(<<"id">>, Value) =:= SurfaceId],
    Value.

compact_value(<<"#!alang-model-v1\n", Json/binary>>) ->
    {ok, Value} = alang_fidelity_json:decode(Json),
    Value.

compact_binary(Value) ->
    {ok, Json} = alang_fidelity_json:encode_canonical(Value),
    <<"#!alang-model-v1\n", Json/binary>>.

all_oracles() ->
    {ok, Corpus} = alang_fidelity_json:decode_file(corpus_path()),
    [alang_compact_corpus:oracle(Case) || Case <- maps:get(<<"cases">>, Corpus)].

executable_oracle() ->
    hd([Oracle || Oracle <- all_oracles(),
        maps:get(<<"terminal_class">>, Oracle) =:= <<"complete">>]).

delegated_oracle() ->
    hd([Oracle || Oracle <- all_oracles(),
        is_map(maps:get(<<"child_attenuation">>, Oracle)),
        maps:get(<<"error_branches">>, Oracle) =/= []]).

reproduction_a() -> filename:join([evidence_dir(), "reproduction-a.json"]).
reproduction_b() -> filename:join([evidence_dir(), "reproduction-b.json"]).
evidence_dir() -> filename:join(["build", "compact-projection-fidelity", "phase-02", "evidence"]).
registry_path() -> filename:join(["assets", "compact-projection-fidelity", "phase-02",
    "contracts", "surface-registry-v1.json"]).
corpus_path() -> filename:join(["assets", "compact-projection-fidelity", "corpus",
    "confirmatory-corpus-v1.json"]).
