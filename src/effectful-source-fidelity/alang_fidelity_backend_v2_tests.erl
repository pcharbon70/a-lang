-module(alang_fidelity_backend_v2_tests).

-include_lib("eunit/include/eunit.hrl").

-define(TOOLCHAIN, "src/phase-01/toolchain.config").

all_48_representations_compile_to_inspected_beam_test() ->
    Products = compile_all(),
    ?assertEqual(48, length(Products)),
    lists:foreach(fun(Product) ->
        Inspection = maps:get(inspection, Product),
        ?assertEqual(accepted, maps:get(policy, Inspection)),
        ?assertEqual(alang_fidelity_program_v2, maps:get(module, Inspection)),
        ?assertEqual(alang_typed_task_ir_v2,
            maps:get(ir_format, maps:get(metadata, Inspection)))
    end, Products).

paired_artifacts_share_executable_identity_but_retain_provenance_test() ->
    lists:foreach(fun({SourcePath, JsonPath}) ->
        Source = compile_path(SourcePath, alang_source),
        Json = compile_path(JsonPath, typed_json),
        SourceInspection = maps:get(inspection, Source),
        JsonInspection = maps:get(inspection, Json),
        ?assertEqual(maps:get(semantic_artifact_sha256, SourceInspection),
            maps:get(semantic_artifact_sha256, JsonInspection)),
        ?assertNotEqual(maps:get(beam_sha256, SourceInspection),
            maps:get(beam_sha256, JsonInspection)),
        ?assertNotEqual(maps:get(source_sha256, maps:get(metadata, SourceInspection)),
            maps:get(source_sha256, maps:get(metadata, JsonInspection)))
    end, pairs()).

generated_forms_use_only_closed_static_runtime_calls_test() ->
    Product = compile_path(sample_source(), alang_source),
    Forms = maps:get(forms, Product),
    ?assertEqual(ok, alang_fidelity_forms_v2:validate(Forms)),
    Calls = alang_fidelity_forms_v2:runtime_calls(Forms),
    ?assertEqual([
        {alang_fidelity_runtime_abi, begin_task, 3},
        {alang_fidelity_runtime_abi, complete, 5},
        {alang_fidelity_runtime_abi, effect, 6}
    ], Calls),
    ?assertEqual([], [Call || Call = {Module, _, _} <- Calls,
        Module =/= alang_fidelity_runtime_abi]).

backend_output_is_byte_deterministic_test() ->
    First = compile_path(sample_source(), alang_source),
    Second = compile_path(sample_source(), alang_source),
    ?assertEqual(maps:get(beam, First), maps:get(beam, Second)),
    ?assertEqual(maps:get(metadata_sha256, First), maps:get(metadata_sha256, Second)).

artifact_binding_rejects_tampered_source_metadata_test() ->
    {ok, Binary} = file:read_file(sample_source()),
    {ok, Lowered} = alang_fidelity_compiler:compile_source(Binary),
    {ok, Original} = alang_fidelity_backend_v2:compile(Lowered, ?TOOLCHAIN),
    Tampered = Lowered#{source_digest :=
        <<"0000000000000000000000000000000000000000000000000000000000000000">>},
    {ok, Forged} = alang_fidelity_backend_v2:compile(Tampered, ?TOOLCHAIN),
    ?assertEqual({error, {artifact_binding_mismatch, source_sha256}},
        alang_fidelity_artifact_v2:inspect(
            maps:get(beam, Forged), maps:get(metadata, Original))).

artifact_inspection_rejects_added_import_test() ->
    Product = compile_path(sample_source(), alang_source),
    Forms = maps:get(forms, Product),
    Mutant = replace_first_runtime_call(Forms),
    {ok, alang_fidelity_program_v2, Beam, []} = compile:forms(Mutant,
        [binary, deterministic, no_debug_info, no_docs, return_errors, return_warnings]),
    ?assertMatch({error, {unexpected_beam_imports, _}},
        alang_fidelity_artifact_v2:inspect(Beam)).

backend_diagnostics_remain_frontend_local_test() ->
    Source = compile_path(sample_source(), alang_source),
    Json = compile_path(sample_json(), typed_json),
    {error, SourceDiagnostic} = alang_fidelity_backend_v2:compile_forms(
        replace_first_runtime_call(maps:get(forms, Source)), ?TOOLCHAIN),
    {error, JsonDiagnostic} = alang_fidelity_backend_v2:compile_forms(
        replace_first_runtime_call(maps:get(forms, Json)), ?TOOLCHAIN),
    ?assertMatch(#{class := backend,
        location := #{frontend := alang_source, line := _, column := _, byte := _}},
        SourceDiagnostic),
    ?assertMatch(#{class := backend,
        location := #{frontend := typed_json, pointer := _, offset := _}},
        JsonDiagnostic),
    ?assertEqual(false, maps:is_key(detail, SourceDiagnostic)),
    ?assertEqual(false, maps:is_key(detail, JsonDiagnostic)).

metadata_decoder_rejects_noncanonical_or_trailing_etf_test() ->
    Product = compile_path(sample_source(), alang_source),
    Encoded = alang_fidelity_forms_v2:encode_metadata(maps:get(metadata, Product)),
    ?assertMatch({ok, _}, alang_fidelity_forms_v2:decode_metadata(Encoded)),
    ?assertEqual({error, trailing_backend_metadata},
        alang_fidelity_forms_v2:decode_metadata(<<Encoded/binary, 0>>)),
    Compressed = term_to_binary({alang_backend_metadata_v2,
        maps:get(metadata, Product)}, [compressed]),
    ?assertEqual({error, compressed_backend_metadata},
        alang_fidelity_forms_v2:decode_metadata(Compressed)).

compile_all() ->
    [compile_path(Path, Frontend) || {Path, Frontend} <- representation_paths()].

representation_paths() ->
    Sources = filelib:wildcard(
        "assets/effectful-source-fidelity/corpus/*/*.alang"),
    Json = [Path || Path <- filelib:wildcard(
        "assets/effectful-source-fidelity/corpus/*/*.json"),
        not lists:suffix(".answer.json", Path),
        not lists:suffix("corpus-manifest-v1.json", Path)],
    [{Path, alang_source} || Path <- lists:sort(Sources)] ++
        [{Path, typed_json} || Path <- lists:sort(Json)].

pairs() ->
    [{Source, filename:rootname(Source, ".alang") ++ ".json"} ||
        Source <- lists:sort(filelib:wildcard(
            "assets/effectful-source-fidelity/corpus/*/*.alang"))].

compile_path(Path, Frontend) ->
    {ok, Binary} = file:read_file(Path),
    Result = case Frontend of
        alang_source -> alang_fidelity_compiler:compile_source(Binary);
        typed_json -> alang_fidelity_compiler:compile_control(Binary)
    end,
    {ok, Lowered} = Result,
    {ok, Product} = alang_fidelity_backend_v2:compile(Lowered, ?TOOLCHAIN),
    Product.

replace_first_runtime_call(Forms) ->
    {Mutant, true} = replace_term(Forms, false),
    Mutant.

replace_term({call, Line, {remote, RemoteLine,
        {atom, ModuleLine, alang_fidelity_runtime_abi},
        {atom, FunctionLine, _Function}}, Arguments}, false) ->
    {{call, Line, {remote, RemoteLine,
        {atom, ModuleLine, erlang}, {atom, FunctionLine, spawn}}, Arguments}, true};
replace_term(Tuple, Replaced) when is_tuple(Tuple) ->
    {Values, Final} = replace_terms(tuple_to_list(Tuple), Replaced, []),
    {list_to_tuple(Values), Final};
replace_term(List, Replaced) when is_list(List) ->
    replace_terms(List, Replaced, []);
replace_term(Value, Replaced) -> {Value, Replaced}.

replace_terms([], Replaced, Acc) -> {lists:reverse(Acc), Replaced};
replace_terms([Value | Rest], Replaced, Acc) ->
    {Changed, Next} = replace_term(Value, Replaced),
    replace_terms(Rest, Next, [Changed | Acc]).

sample_source() ->
    "assets/effectful-source-fidelity/corpus/single-model-artifact/sma-simple.alang".

sample_json() ->
    "assets/effectful-source-fidelity/corpus/single-model-artifact/sma-simple.json".
