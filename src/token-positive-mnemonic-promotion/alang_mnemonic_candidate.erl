-module(alang_mnemonic_candidate).

-export([compare/2, decode/3, decode_versioned/4, load/2, render/3,
    validate/2]).

-define(CONTRACT, "assets/token-positive-mnemonic-promotion/phase-02/contracts/candidate-contract-v1.json").

-spec load(file:filename(), file:filename()) -> {ok, map()} | {error, term()}.
load(Path, RepoRoot) ->
    case alang_fidelity_json:decode_file(Path) of
        {ok, Contract} -> validate(Contract, RepoRoot);
        {error, Reason} -> {error, {mnemonic_candidate_error, contract_read, Reason}}
    end.

-spec validate(term(), file:filename()) -> {ok, map()} | {error, term()}.
validate(Contract, RepoRoot) ->
    try
        exact(maps:get(<<"format">>, Contract),
            <<"alang-token-positive-candidate-contract-v1">>, format),
        exact(maps:keys(Contract), lists:sort([<<"alias_groups">>, <<"conditions">>,
            <<"conformance">>, <<"format">>, <<"limits">>, <<"references">>,
            <<"source_maps">>]), fields),
        exact(maps:get(<<"conditions">>, Contract), expected_conditions(), conditions),
        References = maps:get(<<"references">>, Contract),
        exact([maps:get(<<"role">>, R) || R <- References],
            [<<"renderer">>, <<"vocabulary">>, <<"surface-registry">>,
                <<"source-map-implementation">>, <<"source-map-contract">>], references),
        lists:foreach(fun(Reference) -> validate_reference(Reference, RepoRoot) end, References),
        exact(maps:get(<<"alias_groups">>, Contract), expected_groups(), alias_groups),
        exact(maps:get(<<"limits">>, Contract), expected_limits(), limits),
        exact(maps:get(<<"conformance">>, Contract), expected_conformance(), conformance),
        exact(maps:get(<<"source_maps">>, Contract), expected_source_maps(), source_maps),
        validate_vocabulary(reference_path(<<"vocabulary">>, References, RepoRoot)),
        {ok, _} = checked(alang_compact_surface:load_registry(
            reference_path(<<"surface-registry">>, References, RepoRoot))),
        {ok, _} = checked(alang_compact_source_map:load_contract(
            reference_path(<<"source-map-contract">>, References, RepoRoot))),
        Phase1 = filename:join(RepoRoot,
            "assets/token-positive-mnemonic-promotion/contracts/campaign-contract-v1.json"),
        {ok, CampaignContract} = checked(alang_mnemonic_contract:load(Phase1)),
        {ok, _} = checked(alang_mnemonic_contract:validate_reference(CampaignContract, RepoRoot)),
        {ok, Contract}
    catch
        error:{badkey, Key} -> {error, {mnemonic_candidate_error, {missing_field, Key}}};
        throw:{mnemonic_candidate_error, Reason} -> {error, {mnemonic_candidate_error, Reason}}
    end.

-spec render(binary(), map(), file:filename()) -> {ok, map()} | {error, term()}.
render(Condition, Oracle, RepoRoot) ->
    case load(filename:join(RepoRoot, ?CONTRACT), RepoRoot) of
        {ok, Contract} ->
            case condition(Condition, Contract) of
                {ok, Entry} -> render_entry(Entry, Oracle, Contract, RepoRoot);
                error -> {error, {mnemonic_candidate_error, {unknown_condition, Condition}}}
            end;
        {error, _} = Error -> Error
    end.

render_entry(Entry, Oracle, Contract, RepoRoot) ->
    Registry = reference_path(<<"surface-registry">>, maps:get(<<"references">>, Contract), RepoRoot),
    SurfaceId = maps:get(<<"surface_id">>, Entry),
    Version = maps:get(<<"version">>, Entry),
    case alang_compact_surface:render(SurfaceId, Version, Oracle, Registry) of
        {ok, Surface} ->
            case alang_compact_source_map:build(Surface, Oracle) of
                {ok, SourceMap} ->
                    Result = Surface#{condition => maps:get(<<"id">>, Entry),
                        source_map => SourceMap},
                    verify_p1_bytes(Result, Entry, Oracle, Registry);
                {error, _} = Error -> Error
            end;
        {error, _} = Error -> Error
    end.

verify_p1_bytes(Result, #{<<"id">> := <<"P1">>}, Oracle, Registry) ->
    {ok, R2} = alang_compact_surface:render(<<"R2">>,
        <<"alang-source-v2-alias-v1">>, Oracle, Registry),
    exact(maps:get(bytes, Result), maps:get(bytes, R2), p1_r2_bytes),
    {ok, Result#{reference_surface => <<"R2">>, byte_equal_to_r2 => true}};
verify_p1_bytes(Result, _Entry, _Oracle, _Registry) -> {ok, Result}.

-spec decode(binary(), binary(), file:filename()) -> {ok, map()} | {error, term()}.
decode(Condition, Bytes, RepoRoot) ->
    case load(filename:join(RepoRoot, ?CONTRACT), RepoRoot) of
        {ok, Contract} ->
            case condition(Condition, Contract) of
                {ok, Entry} -> alang_compact_surface:decode(maps:get(<<"surface_id">>, Entry),
                    maps:get(<<"version">>, Entry), Bytes);
                error -> {error, {mnemonic_candidate_error, {unknown_condition, Condition}}}
            end;
        {error, _} = Error -> Error
    end.

-spec decode_versioned(binary(), binary(), binary(), file:filename()) ->
    {ok, map()} | {error, term()}.
decode_versioned(Condition, Version, Bytes, RepoRoot) ->
    case load(filename:join(RepoRoot, ?CONTRACT), RepoRoot) of
        {ok, Contract} ->
            case condition(Condition, Contract) of
                {ok, Entry} -> alang_compact_surface:decode(maps:get(<<"surface_id">>, Entry),
                    Version, Bytes);
                error -> {error, {mnemonic_candidate_error, {unknown_condition, Condition}}}
            end;
        {error, _} = Error -> Error
    end.

-spec compare(map(), file:filename()) -> {ok, map()} | {error, term()}.
compare(Oracle, RepoRoot) ->
    case {render(<<"P0">>, Oracle, RepoRoot), render(<<"P1">>, Oracle, RepoRoot)} of
        {{ok, P0}, {ok, P1}} ->
            {ok, D0} = decode(<<"P0">>, maps:get(bytes, P0), RepoRoot),
            {ok, D1} = decode(<<"P1">>, maps:get(bytes, P1), RepoRoot),
            Digest = alang_fidelity_contract:semantic_digest(Oracle),
            exact(maps:get(semantic_digest, P0), Digest, p0_render_digest),
            exact(maps:get(semantic_digest, P1), Digest, p1_render_digest),
            exact(maps:get(semantic_digest, D0), Digest, p0_decode_digest),
            exact(maps:get(semantic_digest, D1), Digest, p1_decode_digest),
            {ok, #{<<"format">> => <<"alang-token-positive-candidate-pair-v1">>,
                <<"semantic_digest">> => Digest,
                <<"p0">> => P0, <<"p1">> => P1,
                <<"p1_r2_byte_equal">> => true}};
        {Error = {error, _}, _} -> Error;
        {_, Error = {error, _}} -> Error
    end.

condition(Id, Contract) ->
    case [C || C <- maps:get(<<"conditions">>, Contract), maps:get(<<"id">>, C) =:= Id] of
        [Entry] -> {ok, Entry};
        _ -> error
    end.

validate_reference(Reference, RepoRoot) ->
    exact(maps:keys(Reference), [<<"path">>, <<"role">>, <<"sha256">>], reference_fields),
    Path = filename:join(RepoRoot, binary_to_list(maps:get(<<"path">>, Reference))),
    {ok, Bytes} = case file:read_file(Path) of
        {ok, Value} -> {ok, Value};
        {error, Reason} -> fail({reference_read_failed, Path, Reason})
    end,
    Actual = alang_fidelity_json:hex(crypto:hash(sha256, Bytes)),
    exact(Actual, maps:get(<<"sha256">>, Reference),
        {reference_digest, maps:get(<<"role">>, Reference)}).

reference_path(Role, References, RepoRoot) ->
    [Reference] = [R || R <- References, maps:get(<<"role">>, R) =:= Role],
    filename:join(RepoRoot, binary_to_list(maps:get(<<"path">>, Reference))).

validate_vocabulary(Path) ->
    {ok, Value} = checked(alang_fidelity_json:decode_file(Path)),
    Groups = maps:get(<<"alias_groups">>, Value),
    exact([maps:get(<<"group">>, G) || G <- Groups], expected_groups(), vocabulary_groups),
    lists:foreach(fun(Group) ->
        Aliases = maps:get(<<"aliases">>, Group),
        unique([maps:get(<<"readable">>, A) || A <- Aliases], duplicate_readable_alias),
        unique([maps:get(<<"compact">>, A) || A <- Aliases], duplicate_compact_alias)
    end, Groups).

expected_conditions() -> [
    #{<<"id">> => <<"P0">>, <<"surface_id">> => <<"R0">>,
        <<"representation">> => <<"alang-source-v2-readable">>,
        <<"version">> => <<"alang-source-v2">>, <<"role">> => <<"canonical-baseline">>},
    #{<<"id">> => <<"P1">>, <<"surface_id">> => <<"R2">>,
        <<"representation">> => <<"alang-source-v2-mnemonic-aliases">>,
        <<"version">> => <<"alang-source-v2-alias-v1">>,
        <<"role">> => <<"sole-promotion-candidate">>}
].
expected_groups() -> [<<"declaration">>, <<"scope-key">>, <<"budget-key">>,
    <<"operation">>, <<"predicate">>, <<"relation">>].
expected_limits() -> #{<<"max_representation_bytes">> => 32768,
    <<"unknown_version">> => <<"reject">>, <<"duplicate_fields">> => <<"reject">>,
    <<"invalid_utf8">> => <<"reject">>, <<"unknown_alias">> => <<"reject">>,
    <<"cross_group_alias">> => <<"reject">>}.
expected_conformance() -> #{<<"rendering">> => <<"byte-for-byte-r2">>,
    <<"acceptance">> => <<"same-as-r2">>,
    <<"decode">> => <<"same-checked-semantics-as-r2">>,
    <<"semantic_digest">> => <<"origin-free-canonical">>}.
expected_source_maps() -> #{<<"coverage">> => <<"contiguous-every-byte-exactly-once">>,
    <<"security_fields">> => <<"complete-with-witnesses">>,
    <<"map_order">> => <<"stable">>,
    <<"diagnostic_edit_target">> => <<"readable-source">>}.

checked({ok, _} = Result) -> Result;
checked({error, Reason}) -> fail(Reason).
unique(Values, Reason) -> exact(length(Values), length(lists:usort(Values)), Reason).
exact(Value, Expected, _Reason) when Value =:= Expected -> ok;
exact(Value, Expected, Reason) -> fail({expected, Reason, Expected, Value}).
fail(Reason) -> throw({mnemonic_candidate_error, Reason}).
