-module(alang_mnemonic_phase2_residency).

-export([audit/1, validate_imports/1, validate_sources/1]).

-spec audit(file:filename()) -> {ok, map()} | {error, term()}.
audit(RepoRoot) ->
    try
        Pairs = module_sources(RepoRoot),
        Records = [module_record(Module, Source) || {Module, Source} <- Pairs],
        ok = validate_sources(Records),
        ok = validate_imports(Records),
        {ok, #{<<"format">> => <<"alang-token-positive-phase-2-residency-v1">>,
            <<"engine">> => <<"ERTS">>, <<"module_count">> => length(Records),
            <<"modules">> => Records, <<"foreign_source_count">> => 0,
            <<"forbidden_import_count">> => 0,
            <<"ports">> => false, <<"nifs">> => false,
            <<"shell_commands">> => false, <<"interpreted_forms">> => false}}
    catch
        throw:{mnemonic_residency_error, Reason} ->
            {error, {mnemonic_residency_error, Reason}};
        error:Reason -> {error, {mnemonic_residency_error, Reason}}
    end.

module_record(Module, Source) ->
    Beam = code:which(Module),
    ensure(is_list(Beam) andalso filename:extension(Beam) =:= ".beam",
        {not_beam_resident, Module, Beam}),
    {ok, BeamBytes} = file:read_file(Beam), {ok, SourceBytes} = file:read_file(Source),
    {ok, {Module, [{imports, Imports}]}} = beam_lib:chunks(Beam, [imports]),
    #{<<"module">> => atom_to_binary(Module),
        <<"source_path">> => list_to_binary(Source),
        <<"source_sha256">> => hex(crypto:hash(sha256, SourceBytes)),
        <<"beam_sha256">> => hex(crypto:hash(sha256, BeamBytes)),
        <<"imports">> => [import_name(M, F, A) ||
            {M, F, A} <- lists:sort(Imports)]}.

import_name(Module, Function, Arity) ->
    M = atom_to_binary(Module), F = atom_to_binary(Function), A = integer_to_binary(Arity),
    <<M/binary, ":", F/binary, "/", A/binary>>.

-spec validate_sources([map()]) -> ok | no_return().
validate_sources(Records) ->
    lists:foreach(fun(Record) ->
        Source = binary_to_list(maps:get(<<"source_path">>, Record)),
        ensure(filename:extension(Source) =:= ".erl", {foreign_trusted_source, Source}),
        ensure(filelib:is_regular(Source), {missing_trusted_source, Source})
    end, Records), ok.

-spec validate_imports([map()]) -> ok | no_return().
validate_imports(Records) ->
    Forbidden = [<<"erlang:open_port/2">>, <<"erlang:load_nif/2">>,
        <<"os:cmd/1">>, <<"os:cmd/2">>, <<"erl_eval:expr/2">>,
        <<"erl_eval:exprs/2">>, <<"shell:start/0">>],
    lists:foreach(fun(Record) ->
        Imports = maps:get(<<"imports">>, Record),
        lists:foreach(fun(Import) ->
            ensure(not lists:member(Import, Forbidden),
                {forbidden_import, maps:get(<<"module">>, Record), Import})
        end, Imports)
    end, Records), ok.

module_sources(Root) -> [{Module, filename:join(Root, Path)} || {Module, Path} <- [
    {alang_fidelity_json, "src/effectful-source-fidelity/alang_fidelity_json.erl"},
    {alang_fidelity_contract, "src/effectful-source-fidelity/alang_fidelity_contract.erl"},
    {alang_fidelity_representation, "src/effectful-source-fidelity/alang_fidelity_representation.erl"},
    {alang_fidelity_lexer, "src/effectful-source-fidelity/alang_fidelity_lexer.erl"},
    {alang_fidelity_parser, "src/effectful-source-fidelity/alang_fidelity_parser.erl"},
    {alang_fidelity_ast, "src/effectful-source-fidelity/alang_fidelity_ast.erl"},
    {alang_fidelity_source, "src/effectful-source-fidelity/alang_fidelity_source.erl"},
    {alang_compact_source_normalizer, "src/compact-projection-fidelity/alang_compact_source_normalizer.erl"},
    {alang_compact_surface, "src/compact-projection-fidelity/alang_compact_surface.erl"},
    {alang_compact_source_map, "src/compact-projection-fidelity/alang_compact_source_map.erl"},
    {alang_compact_tokenizer, "src/compact-projection-fidelity/alang_compact_tokenizer.erl"},
    {alang_mnemonic_contract, "src/token-positive-mnemonic-promotion/alang_mnemonic_contract.erl"},
    {alang_mnemonic_candidate, "src/token-positive-mnemonic-promotion/alang_mnemonic_candidate.erl"},
    {alang_mnemonic_protocol, "src/token-positive-mnemonic-promotion/alang_mnemonic_protocol.erl"},
    {alang_mnemonic_qualification, "src/token-positive-mnemonic-promotion/alang_mnemonic_qualification.erl"},
    {alang_mnemonic_authorization, "src/token-positive-mnemonic-promotion/alang_mnemonic_authorization.erl"}
]].

ensure(true, _Reason) -> ok;
ensure(false, Reason) -> throw({mnemonic_residency_error, Reason}).
hex(Binary) -> alang_fidelity_json:hex(Binary).
