-module(alang_mnemonic_phase3_residency).

-export([audit/1, validate_network_imports/1]).

-spec audit(file:filename()) -> {ok, map()} | {error, term()}.
audit(Root) ->
    try
        Records = [module_record(Module, filename:join(Root, Path))
            || {Module, Path} <- module_sources()],
        ok = alang_mnemonic_phase2_residency:validate_sources(Records),
        ok = alang_mnemonic_phase2_residency:validate_imports(Records),
        ok = validate_network_imports(Records),
        {ok, #{<<"format">> => <<"alang-token-positive-phase-3-residency-v1">>,
            <<"engine">> => <<"ERTS">>, <<"module_count">> => length(Records),
            <<"modules">> => Records, <<"foreign_source_count">> => 0,
            <<"forbidden_import_count">> => 0, <<"network_modules">> =>
                [<<"alang_mnemonic_ollama">>], <<"ports">> => false,
            <<"nifs">> => false, <<"shell_commands">> => false,
            <<"interpreted_forms">> => false}}
    catch
        throw:{mnemonic_phase3_residency_error, Reason} ->
            {error, {mnemonic_phase3_residency_error, Reason}};
        Class:Reason -> {error, {mnemonic_phase3_residency_error, Class, Reason}}
    end.

-spec validate_network_imports([map()]) -> ok | no_return().
validate_network_imports(Records) ->
    Network = [R || R <- Records, lists:any(fun(I) ->
        binary:match(I, <<"httpc:">>) =:= {0, 6} orelse
            binary:match(I, <<"http:">>) =:= {0, 5}
    end, maps:get(<<"imports">>, R))],
    exact([maps:get(<<"module">>, R) || R <- Network],
        [<<"alang_mnemonic_ollama">>], network_module_scope), ok.

module_record(Module, Source) ->
    Beam = code:which(Module),
    ensure(is_list(Beam) andalso filename:extension(Beam) =:= ".beam",
        {not_beam_resident, Module}),
    {ok, BeamBytes} = file:read_file(Beam), {ok, SourceBytes} = file:read_file(Source),
    {ok, {Module, [{imports, Imports}]}} = beam_lib:chunks(Beam, [imports]),
    #{<<"module">> => atom_to_binary(Module), <<"source_path">> => list_to_binary(Source),
      <<"source_sha256">> => hex(crypto:hash(sha256, SourceBytes)),
      <<"beam_sha256">> => hex(crypto:hash(sha256, BeamBytes)),
      <<"imports">> => [import_name(M, F, A) || {M, F, A} <- lists:sort(Imports)]}.

module_sources() -> [
    {alang_mnemonic_live_gate, "src/token-positive-mnemonic-promotion/alang_mnemonic_live_gate.erl"},
    {alang_mnemonic_journal, "src/token-positive-mnemonic-promotion/alang_mnemonic_journal.erl"},
    {alang_mnemonic_runner, "src/token-positive-mnemonic-promotion/alang_mnemonic_runner.erl"},
    {alang_mnemonic_ollama, "src/token-positive-mnemonic-promotion/alang_mnemonic_ollama.erl"},
    {alang_mnemonic_observation, "src/token-positive-mnemonic-promotion/alang_mnemonic_observation.erl"},
    {alang_mnemonic_replay, "src/token-positive-mnemonic-promotion/alang_mnemonic_replay.erl"},
    {alang_mnemonic_limits, "src/token-positive-mnemonic-promotion/alang_mnemonic_limits.erl"},
    {alang_mnemonic_phase3_mutation, "src/token-positive-mnemonic-promotion/alang_mnemonic_phase3_mutation.erl"},
    {alang_mnemonic_phase3_residency, "src/token-positive-mnemonic-promotion/alang_mnemonic_phase3_residency.erl"}].
import_name(M, F, A) -> <<(atom_to_binary(M))/binary, ":", (atom_to_binary(F))/binary,
    "/", (integer_to_binary(A))/binary>>.
exact(Value, Expected, _Reason) when Value =:= Expected -> ok;
exact(Value, Expected, Reason) -> fail({expected, Reason, Expected, Value}).
ensure(true, _Reason) -> ok;
ensure(false, Reason) -> fail(Reason).
fail(Reason) -> throw({mnemonic_phase3_residency_error, Reason}).
hex(Bytes) -> alang_fidelity_json:hex(Bytes).
