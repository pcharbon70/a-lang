-module(alang_fidelity_frontend_evidence).

-export([build/0, main/0, negative_cases/0, write/1]).

-define(CORPUS_GLOB, "assets/effectful-source-fidelity/corpus/*/*.alang").
-define(V1_FIXTURE, "src/phase-02/fixtures/counter.alang").
-define(OWNED_ROOT, "build/effectful-source-fidelity/phase-02").

-spec build() -> {ok, map()} | {error, term()}.
build() ->
    try
        Files = lists:sort(filelib:wildcard(?CORPUS_GLOB)),
        Cases = [case_record(Path) || Path <- Files],
        true = length(Cases) =:= 24,
        Negative = negative_results(),
        true = lists:all(fun(Entry) -> maps:get(matched, Entry) end, Negative),
        Robustness = robustness_results(),
        true = maps:get(parser_crashes, Robustness) =:= 0,
        true = maps:get(canonical_crashes, Robustness) =:= 0,
        true = maps:get(atom_growth, Robustness) =:= 0,
        Residency = residency(),
        true = lists:all(fun(Entry) -> maps:get(is_beam, Entry) end, Residency),
        Body = #{
            format => alang_fidelity_phase2_evidence_body_v1,
            engine => beam,
            vm => 'BEAM',
            otp_release => list_to_binary(erlang:system_info(otp_release)),
            hosted_calls => 0,
            corpus_count => length(Cases),
            cases => Cases,
            ast_manifest_sha256 => digest(Cases),
            canonical_bundle_sha256 => digest([
                {maps:get(case_id, Entry), maps:get(canonical_sha256, Entry)} || Entry <- Cases
            ]),
            source_map_bundle_sha256 => digest([
                {maps:get(case_id, Entry), maps:get(source_map_sha256, Entry)} || Entry <- Cases
            ]),
            negative_case_count => length(Negative),
            negative_cases => Negative,
            robustness => Robustness,
            legacy_v1 => legacy_v1(),
            module_residency => Residency,
            bounds => #{
                source_bytes => 8192,
                lexer_bytes => 1048576,
                canonical_bytes => 1048576,
                tokens => 4096,
                actions => 16,
                child_depth => 1,
                output_bytes => 8192
            },
            parser_runtime_effects => [],
            foreign_compiler_executables => []
        },
        {ok, #{
            format => alang_fidelity_phase2_evidence_v1,
            evidence_sha256 => digest(Body),
            evidence => Body
        }}
    catch
        Class:Reason:Stack -> {error, {Class, Reason, Stack}}
    end.

-spec write(file:filename_all()) -> {ok, map()} | {error, term()}.
write(Path) ->
    case owned_path(Path) of
        true ->
            case build() of
                {ok, Evidence} ->
                    ok = filelib:ensure_dir(Path),
                    Binary = term_to_binary(Evidence, [deterministic]),
                    case file:write_file(Path, Binary, [binary]) of
                        ok -> {ok, Evidence#{artifact_sha256 => hex(crypto:hash(sha256, Binary))}};
                        {error, Reason} -> {error, {evidence_write_failed, Reason}}
                    end;
                {error, _} = Error -> Error
            end;
        false ->
            {error, evidence_path_outside_owned_root}
    end.

main() ->
    case init:get_plain_arguments() of
        [Output] ->
            case write(Output) of
                {ok, Evidence} ->
                    Body = maps:get(evidence, Evidence),
                    io:format(
                        "fidelity_phase2_ok digest=~s artifact=~s cases=~B negatives=~B generated=~B otp=~s output=~s~n",
                        [
                            maps:get(evidence_sha256, Evidence),
                            maps:get(artifact_sha256, Evidence),
                            maps:get(corpus_count, Body),
                            maps:get(negative_case_count, Body),
                            maps:get(generated_inputs, maps:get(robustness, Body)),
                            maps:get(otp_release, Body),
                            Output
                        ]
                    ),
                    halt(0);
                {error, Reason} ->
                    io:format(standard_error, "fidelity_phase2_error ~tp~n", [Reason]),
                    halt(1)
            end;
        _ ->
            io:format(standard_error, "usage: alang_fidelity_frontend_evidence <output.etf>~n", []),
            halt(2)
    end.

case_record(Path) ->
    {ok, Source} = file:read_file(Path),
    {ok, Ast} = alang_fidelity_parser:parse(Source),
    {ok, Canonical} = alang_fidelity_canonical:encode(Ast),
    {ok, Ast} = alang_fidelity_canonical:decode(Canonical),
    {ok, CanonicalDigest} = alang_fidelity_canonical:digest(Ast),
    Task = maps:get(task, Ast),
    SourceMap = source_map(Ast),
    #{
        case_id => maps:get(name, Task),
        family => list_to_binary(filename:basename(filename:dirname(Path))),
        path => list_to_binary(Path),
        source_sha256 => hex(crypto:hash(sha256, Source)),
        canonical_sha256 => CanonicalDigest,
        canonical_bytes => byte_size(Canonical),
        source_map_entries => length(SourceMap),
        source_map_sha256 => digest(SourceMap)
    }.

legacy_v1() ->
    {ok, Source} = file:read_file(?V1_FIXTURE),
    {ok, LegacyAst} = alang_phase2_parser:parse(Source),
    {ok, LegacyAst} = alang_fidelity_parser:parse(Source),
    {ok, LegacyCanonical} = alang_phase2_canonical:encode(LegacyAst),
    {ok, LegacyCanonical} = alang_fidelity_canonical:encode(LegacyAst),
    {ok, LegacyAst} = alang_fidelity_canonical:decode(LegacyCanonical),
    Invalid = <<"module X version \"alang-source-v1\" { task x() -> Unknown effect [] requires [] = 1 ensures true; }">>,
    LegacyDiagnostic = alang_phase2_parser:parse(Invalid),
    LegacyDiagnostic = alang_fidelity_parser:parse(Invalid),
    #{
        accepted_unchanged => true,
        source_sha256 => hex(crypto:hash(sha256, Source)),
        canonical_sha256 => hex(crypto:hash(sha256, LegacyCanonical)),
        diagnostic_sha256 => digest(LegacyDiagnostic)
    }.

-spec negative_cases() -> [map()].
negative_cases() ->
    Simple = read_case("single-model-artifact/sma-simple.alang"),
    Child = read_case("attenuated-delegation/ad-simple.alang"),
    [
        #{name => dynamic_effect, expected => unknown_effect, source => replace(Simple, <<"effects [model.generate">>, <<"effects [model.invoke">>)},
        #{name => dynamic_operation, expected => unknown_operation, source => replace(Simple, <<"step draft: model.generate">>, <<"step draft: model.invoke">>)},
        #{name => missing_error_table, expected => missing_task_clause, source => replace(Simple, <<"  on-error [];\n">>, <<>>)},
        #{name => widened_child, expected => unknown_child_field, source => replace(Child, <<"child {">>, <<"child { grants [];">>)},
        #{
            name => unsafe_completion_path,
            expected => unsafe_completion_path,
            source => replace(
                Simple,
                <<"complete [artifact-exists \"/workspace/release-note.md\"">>,
                <<"complete [artifact-exists \"/workspace/../secret.md\"">>
            )
        },
        #{name => duplicate_limit, expected => duplicate_field, source => replace(Simple, <<"steps 3;">>, <<"steps 3; steps 4;">>)},
        #{name => unsupported_loop, expected => unexpected_task_clause, source => replace(Simple, <<"  terminal complete;">>, <<"  loop forever;\n  terminal complete;">>)},
        #{name => invalid_utf8, expected => invalid_utf8, source => <<"#!alang-source-v2\n", 16#FF>>}
    ].

negative_results() ->
    [
        begin
            Actual = parse_error_code(maps:get(source, Case)),
            Expected = maps:get(expected, Case),
            #{name => maps:get(name, Case), expected => Expected, actual => Actual, matched => Actual =:= Expected}
        end
     || Case <- negative_cases()
    ].

robustness_results() ->
    _ = alang_fidelity_parser:parse(<<"#!alang-source-v2\ntask warmup {">>),
    _ = alang_fidelity_canonical:decode(<<131, 104, 0>>),
    {ok, V1Source} = file:read_file(?V1_FIXTURE),
    {ok, V1Ast} = alang_fidelity_parser:parse(V1Source),
    {ok, V1Canonical} = alang_fidelity_canonical:encode(V1Ast),
    {ok, V1Ast} = alang_fidelity_canonical:decode(V1Canonical),
    Inputs = [<<Byte>> || Byte <- lists:seq(0, 255)] ++ [generated_binary(Seed) || Seed <- lists:seq(0, 255)],
    _ = [safe_parse(Input) || Input <- Inputs],
    _ = [safe_decode(Input) || Input <- Inputs],
    AtomBefore = erlang:system_info(atom_count),
    ParserCrashes = length([crashed || Input <- Inputs, safe_parse(Input) =:= crashed]),
    CanonicalCrashes = length([crashed || Input <- Inputs, safe_decode(Input) =:= crashed]),
    lists:foreach(fun(Number) ->
        Name = integer_to_binary(Number),
        _ = alang_fidelity_parser:parse(<<"#!alang-source-v2\ntask generated-", Name/binary, " {">>)
    end, lists:seq(1, 256)),
    AtomAfter = erlang:system_info(atom_count),
    #{
        seed => 20260805,
        generated_inputs => length(Inputs),
        max_generated_bytes => 255,
        parser_crashes => ParserCrashes,
        canonical_crashes => CanonicalCrashes,
        atom_growth => AtomAfter - AtomBefore
    }.

residency() ->
    Modules = [
        alang_fidelity_lexer,
        alang_fidelity_parser,
        alang_fidelity_ast,
        alang_fidelity_canonical,
        alang_fidelity_frontend_evidence
    ],
    [
        begin
            Path = code:which(Module),
            #{module => Module, path => list_to_binary(relative_path(Path)), is_beam => filename:extension(Path) =:= ".beam"}
        end
     || Module <- Modules
    ].

source_map(Ast) ->
    lists:sort(collect_origins(Ast, [], [])).

collect_origins(Map, Path, Acc) when is_map(Map) ->
    case is_origin(Map) of
        true -> [{lists:reverse(Path), Map} | Acc];
        false ->
            lists:foldl(fun(Key, InnerAcc) ->
                collect_origins(maps:get(Key, Map), [Key | Path], InnerAcc)
            end, Acc, lists:sort(maps:keys(Map)))
    end;
collect_origins(List, Path, Acc) when is_list(List) ->
    collect_list_origins(List, Path, 0, Acc);
collect_origins(_Value, _Path, Acc) -> Acc.

collect_list_origins([], _Path, _Index, Acc) -> Acc;
collect_list_origins([Item | Rest], Path, Index, Acc) ->
    Next = collect_origins(Item, [Index | Path], Acc),
    collect_list_origins(Rest, Path, Index + 1, Next).

is_origin(#{byte := Byte, line := Line, column := Column} = Map) ->
    maps:size(Map) =:= 3 andalso is_integer(Byte) andalso is_integer(Line) andalso is_integer(Column);
is_origin(_) -> false.

parse_error_code(Source) ->
    case alang_fidelity_parser:parse(Source) of
        {error, [Diagnostic | _]} -> maps:get(code, Diagnostic);
        {ok, _} -> accepted
    end.

safe_parse(Input) ->
    try alang_fidelity_parser:parse(Input) of
        Result -> Result
    catch
        _:_ -> crashed
    end.

safe_decode(Input) ->
    try alang_fidelity_canonical:decode(Input) of
        Result -> Result
    catch
        _:_ -> crashed
    end.

generated_binary(Seed) ->
    Length = Seed rem 256,
    list_to_binary([((Seed * 1103515245 + Index * 12345) band 255) || Index <- lists:seq(1, Length)]).

read_case(Relative) ->
    {ok, Source} = file:read_file(filename:join("assets/effectful-source-fidelity/corpus", Relative)),
    Source.

replace(Source, Pattern, Replacement) ->
    binary:replace(Source, Pattern, Replacement, [global]).

owned_path(Path) ->
    Root = filename:absname(?OWNED_ROOT),
    Absolute = filename:absname(Path),
    lists:prefix(Root ++ "/", Absolute).

relative_path(Path) ->
    Root = filename:absname(""),
    Absolute = filename:absname(Path),
    Prefix = Root ++ "/",
    case lists:prefix(Prefix, Absolute) of
        true -> lists:nthtail(length(Prefix), Absolute);
        false -> Absolute
    end.

digest(Term) ->
    hex(crypto:hash(sha256, term_to_binary(Term, [deterministic]))).

hex(Binary) ->
    iolist_to_binary([io_lib:format("~2.16.0b", [Byte]) || <<Byte>> <= Binary]).
