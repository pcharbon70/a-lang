-module(alang_phase8_release).

-export([archive_check/0, main/0, run/1]).

-define(TOOLCHAIN, "src/phase-01/toolchain.config").

-spec main() -> no_return().
main() ->
    Output = case init:get_plain_arguments() of
        [Path] -> Path;
        [] -> "build/phase-08/release-candidate";
        Arguments -> fail_main({invalid_arguments, Arguments})
    end,
    case run(Output) of
        {ok, Evidence} ->
            io:format("phase8_release_ok status=~p roadmap=~p demo=~s output=~s~n",
                [maps:get(status, Evidence), maps:get(roadmap_status, Evidence),
                    maps:get(demo_evidence_digest, Evidence), Output]),
            halt(0);
        {error, Reason} -> fail_main(Reason)
    end.

-spec run(file:filename()) -> {ok, map()} | {error, term()}.
run(Output0) ->
    try
        Output = prepare_output(Output0),
        {ok, Toolchain} = alang_phase1_compiler:check_toolchain(?TOOLCHAIN),
        {ok, Residency} = alang_phase3_residency:verify(),
        {ok, Demo} = alang_phase8_demo:run(filename:join(Output, "demonstration")),
        {ok, Comparison} = alang_phase8_comparison:run(
            filename:join(Output, "comparison")),
        Decision = alang_phase8_decision:decision(),
        ok = alang_phase8_decision:validate(Decision),
        Campaign = alang_phase7_campaign:run(),
        true = maps:get(passed, Campaign),
        {ok, Archive} = archive_check(),
        Evidence0 = #{format => alang_phase8_release_evidence_v1,
            status => accepted_with_revised_roadmap,
            roadmap_status => revised_not_complete,
            supported_environment => supported_environment(Toolchain),
            compiler_residency => residency_summary(Residency),
            demo_evidence_digest => maps:get(evidence_digest, Demo),
            demo_artifacts => maps:map(fun(_Name, Artifact) ->
                maps:with([beam_sha256, bytes, policy], Artifact)
            end, maps:get(artifacts, Demo)),
            comparison => maps:get(summary, Comparison),
            validation => #{counts => maps:get(counts, Campaign),
                passed => maps:get(passed, Campaign),
                environment => maps:get(environment, Campaign)},
            architecture_decision => decision_summary(Decision),
            archive => Archive,
            commands => [<<"make demo">>, <<"make compare">>, <<"make decide">>,
                <<"make test-section-8-4">>, <<"make test">>],
            unmet_roadmap_items => [
                all_model_tool_storage_and_workspace_boundaries_are_os_bounded
            ],
            production_status => not_approved,
            network => disabled,
            secrets => none},
        Evidence = Evidence0#{evidence_digest => digest(Evidence0)},
        ok = write_term(filename:join(Output, "release-evidence.config"), Evidence),
        {ok, Evidence}
    catch
        Class:Reason:Stack -> {error, #{class => Class, reason => Reason,
            stack_digest => digest(Stack)}}
    end.

prepare_output(Output0) ->
    Output = filename:absname(Output0),
    Root = filename:absname("build/phase-08"),
    true = lists:prefix(Root ++ "/", Output),
    _ = file:del_dir_r(Output),
    ok = filelib:ensure_dir(filename:join(Output, ".keep")),
    Output.

supported_environment(Toolchain) -> #{otp_version => maps:get(otp_version, Toolchain),
    otp_release => maps:get(otp_release, Toolchain),
    erts_version => maps:get(erts_version, Toolchain),
    system_architecture => maps:get(system_architecture, Toolchain),
    operating_system => os:type(), word_size => erlang:system_info(wordsize),
    schedulers_online => erlang:system_info(schedulers_online)}.

residency_summary(Evidence) -> #{engine => maps:get(engine, Evidence),
    all_modules_are_beam => maps:get(all_modules_are_beam, Evidence),
    no_foreign_imports => maps:get(no_foreign_imports, Evidence),
    production_boundary => maps:get(production_boundary, Evidence),
    erlang_source_emitted => maps:get(erlang_source_emitted, Evidence),
    core_erlang_used => maps:get(core_erlang_used, Evidence),
    raw_beam_assembly_used => maps:get(raw_beam_assembly_used, Evidence),
    foreign_compiler_executables => maps:get(foreign_compiler_executables, Evidence),
    test_reference_is_deployable => maps:get(test_reference_is_deployable, Evidence)}.

decision_summary(Decision) -> #{dispositions => maps:from_list([
        {maps:get(hypothesis, Entry), maps:get(outcome, Entry)}
        || Entry <- maps:get(dispositions, Decision)]),
    next_decision_boundary => maps:get(id, maps:get(next_decision_boundary, Decision)),
    production_status => maps:get(production_status, Decision),
    continuation_status => maps:get(continuation_status, Decision)}.

-spec archive_check() -> {ok, map()} | {error, term()}.
archive_check() ->
    try
        {Directories, Files} = repository_entries("."),
        Markdown = [Path || Path <- Files, filename:extension(Path) =:= ".md"],
        Knowledge = [Path || Path <- Markdown, requires_frontmatter(Path)],
        FrontmatterErrors = [Path || Path <- Knowledge,
            not valid_frontmatter_shape(Path)],
        LinkErrors = lists:append([broken_links(Path) || Path <- Markdown]),
        ReadmeErrors = [Directory || Directory <- Directories,
            not filelib:is_regular(filename:join(Directory, "README.md"))],
        IndexErrors = lists:append([missing_index_entries(Directory)
            || Directory <- Directories]),
        {ok, SchemaBinary} = file:read_file("frontmatter.schema.json"),
        _ = json:decode(SchemaBinary),
        Errors = #{frontmatter => FrontmatterErrors, links => LinkErrors,
            readmes => ReadmeErrors, indexes => IndexErrors},
        case lists:all(fun(List) -> List =:= [] end, maps:values(Errors)) of
            true -> {ok, #{format => alang_phase8_archive_check_v1,
                schema_json => valid, markdown_documents => length(Markdown),
                frontmatter_documents => length(Knowledge),
                directories => length(Directories), local_links => count_links(Markdown),
                readme_indexes => length(Directories), passed => true}};
            false -> {error, {archive_check_failed, Errors}}
        end
    catch Class:Reason -> {error, {archive_check_exception, Class, Reason}} end.

repository_entries(Root) -> repository_entries(Root, [], []).
repository_entries(Path, Directories, Files) ->
    case file:list_dir(Path) of
        {ok, Names} ->
            lists:foldl(fun(Name, {Dirs, AccFiles}) ->
                Child = filename:join(Path, Name),
                case {skip_entry(Name), filelib:is_dir(Child)} of
                    {true, _} -> {Dirs, AccFiles};
                    {false, true} -> repository_entries(Child, [Child | Dirs], AccFiles);
                    {false, false} -> {Dirs, [Child | AccFiles]}
                end
            end, {[Path | Directories], Files}, Names);
        {error, Reason} -> error({repository_walk_failed, Path, Reason})
    end.

skip_entry(".git") -> true;
skip_entry("build") -> true;
skip_entry("_build") -> true;
skip_entry(_) -> false.

requires_frontmatter("./README.md") -> false;
requires_frontmatter("./AGENTS.md") -> false;
requires_frontmatter(Path) ->
    not (lists:prefix("./templates/", Path) andalso
        filename:basename(Path) =/= "README.md").

valid_frontmatter_shape(Path) ->
    {ok, Binary} = file:read_file(Path),
    starts_with(Binary, <<"---\n">>) andalso
        contains_all(Binary, [<<"\ntitle:">>, <<"\nkind:">>, <<"\ncreated:">>,
            <<"\ntags:">>, <<"\naliases:">>]) andalso
        kind_specific_fields(Binary).

kind_specific_fields(Binary) ->
    case {binary:match(Binary, <<"\nkind: note\n">>),
        binary:match(Binary, <<"\nkind: inquiry\n">>)} of
        {{_, _}, _} -> binary:match(Binary, <<"\nmaturity:">>) =/= nomatch;
        {_, {_, _}} -> binary:match(Binary, <<"\nstatus:">>) =/= nomatch;
        _ -> true
    end.

contains_all(Binary, Needles) -> lists:all(fun(Needle) ->
    binary:match(Binary, Needle) =/= nomatch
end, Needles).

starts_with(Binary, Prefix) when byte_size(Binary) >= byte_size(Prefix) ->
    binary:part(Binary, 0, byte_size(Prefix)) =:= Prefix;
starts_with(_Binary, _Prefix) -> false.

broken_links(Path) ->
    {ok, Binary} = file:read_file(Path),
    [#{document => list_to_binary(Path), target => Target} || Target <- links(Binary),
        local_link(Target), not target_exists(Path, Target)].

links(Binary) ->
    case re:run(Binary, "\\]\\(([^)]+)\\)", [global, {capture, [1], binary}]) of
        {match, Matches} -> [Target || [Target] <- Matches];
        nomatch -> []
    end.

local_link(<<>>) -> false;
local_link(<<"#", _/binary>>) -> false;
local_link(<<"mailto:", _/binary>>) -> false;
local_link(Target) -> binary:match(Target, <<"://">>) =:= nomatch.

target_exists(Document, Target0) ->
    Target1 = hd(binary:split(Target0, <<"#">>)),
    Target2 = trim_angles(Target1),
    Path = filename:join(filename:dirname(Document), binary_to_list(Target2)),
    filelib:is_regular(Path) orelse filelib:is_dir(Path).

trim_angles(<<"<", Rest/binary>>) when byte_size(Rest) > 0 ->
    case binary:last(Rest) of
        $> -> binary:part(Rest, 0, byte_size(Rest) - 1);
        _ -> <<"<", Rest/binary>>
    end;
trim_angles(Binary) -> Binary.

missing_index_entries(Directory) ->
    Readme = filename:join(Directory, "README.md"),
    case file:read_file(Readme) of
        {ok, Binary} -> [#{readme => list_to_binary(Readme), child => list_to_binary(Name)}
            || Name <- direct_children(Directory), not indexed(Binary, Directory, Name)];
        {error, _} -> []
    end.

direct_children(Directory) ->
    {ok, Names} = file:list_dir(Directory),
    [Name || Name <- Names, Name =/= "README.md", not skip_direct(Name, Directory)].

skip_direct(Name, ".") -> skip_entry(Name);
skip_direct([$. | _], _Directory) -> true;
skip_direct(_Name, _Directory) -> false.

indexed(Binary, Directory, Name) ->
    Path = filename:join(Directory, Name),
    Needle = case filelib:is_dir(Path) of
        true -> list_to_binary(filename:join(Name, "README.md"));
        false -> list_to_binary(Name)
    end,
    binary:match(Binary, Needle) =/= nomatch.

count_links(Paths) -> lists:sum([begin {ok, Binary} = file:read_file(Path),
    length([Link || Link <- links(Binary), local_link(Link)]) end || Path <- Paths]).

write_term(Path, Term) -> file:write_file(Path, io_lib:format("~tp.~n", [Term])).
digest(Term) -> hex(crypto:hash(sha256, term_to_binary(Term, [deterministic]))).
hex(Binary) -> << <<(hex_digit(Nibble))>> || <<Nibble:4>> <= Binary >>.
hex_digit(Nibble) when Nibble < 10 -> $0 + Nibble;
hex_digit(Nibble) -> $a + Nibble - 10.

fail_main(Reason) ->
    io:format(standard_error, "phase8_release_error ~tp~n", [Reason]),
    halt(1).
