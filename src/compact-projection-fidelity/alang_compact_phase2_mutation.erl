-module(alang_compact_phase2_mutation).

-export([run/0]).

-define(SEED, <<"compact-phase-2-mutation-v1">>).

-spec run() -> {ok, map()} | {error, term()}.
run() ->
    Oracle = delegated_oracle(),
    Digest = alang_fidelity_contract:semantic_digest(Oracle),
    {ok, Surface} = alang_compact_surface:render(
        <<"R3">>, <<"alang-model-v1">>, Oracle, registry_path()),
    Compact = compact_value(maps:get(bytes, Surface)),
    Mutants = [
        result(<<"decoder-unknown-field">>, decoder_mutant(Compact)),
        result(<<"derivation-witness-removal">>, derivation_mutant(Compact)),
        result(<<"alias-reverse-entry-removal">>, alias_mutant(Compact)),
        result(<<"token-attribution-category-removal">>, attribution_mutant(Surface)),
        result(<<"source-map-range-shift">>, source_map_mutant(Surface, Oracle)),
        result(<<"representation-version-change">>, version_mutant(Surface)),
        result(<<"authority-budget-widening">>, authority_mutant(Compact, Digest))
    ],
    case lists:all(fun(#{<<"detected">> := Detected}) -> Detected end, Mutants) of
        true -> {ok, #{
            <<"format">> => <<"alang-compact-phase-2-mutation-v1">>,
            <<"seed">> => ?SEED,
            <<"seed_sha256">> => hex(crypto:hash(sha256, ?SEED)),
            <<"mutants">> => Mutants,
            <<"seeded">> => length(Mutants),
            <<"detected">> => length(Mutants),
            <<"mutation_score_basis_points">> => 10000
        }};
        false -> {error, {surviving_phase2_mutants,
            [maps:get(<<"name">>, M) || M <- Mutants,
                maps:get(<<"detected">>, M) =:= false]}}
    end.

decoder_mutant(Compact) ->
    is_error(alang_compact_model:decode(compact_binary(Compact#{<<"unknown">> => true}))).

derivation_mutant(Compact) ->
    Derived = maps:get(<<"derived">>, Compact),
    is_error(alang_compact_model:decode(compact_binary(Compact#{<<"derived">> :=
        lists:delete(<<"effects">>, Derived)}))).

alias_mutant(Compact) ->
    Aliases = maps:get(<<"aliases">>, Compact),
    [First | _] = lists:sort(maps:keys(Aliases)),
    is_error(alang_compact_model:decode(compact_binary(Compact#{<<"aliases">> :=
        maps:remove(First, Aliases)}))).

attribution_mutant(Surface) ->
    Sections = maps:remove(authority, maps:get(sections, Surface)),
    Request = #{common_instructions => <<"common">>, legend => <<"legend">>,
        output_scaffolding => <<"output">>},
    is_error(alang_compact_token_audit:audit(
        <<"tiktoken-0.12.0-cl100k-base">>, Surface#{sections := Sections}, Request,
        unavailable, tokenizer_dir(), audit_contract_path())).

source_map_mutant(Surface, Oracle) ->
    {ok, Map} = alang_compact_source_map:build(Surface, Oracle),
    [First | Rest] = maps:get(<<"tokens">>, Map),
    Broken = Map#{<<"tokens">> := [First#{<<"from">> := 1} | Rest]},
    is_error(alang_compact_source_map:validate(Broken, Surface, Oracle)).

version_mutant(Surface) ->
    is_error(alang_compact_surface:decode(
        <<"R3">>, <<"alang-model-v2">>, maps:get(bytes, Surface))).

authority_mutant(Compact, Digest) ->
    Cap = maps:get(<<"cap">>, Compact),
    Mutant = Compact#{<<"cap">> := Cap#{<<"t">> := maps:get(<<"t">>, Cap) + 1}},
    case alang_compact_model:decode(compact_binary(Mutant)) of
        {error, _} -> true;
        {ok, Decoded} -> maps:get(semantic_digest, Decoded) =/= Digest
    end.

result(Name, Detected) -> #{<<"name">> => Name, <<"detected">> => Detected}.
is_error({error, _}) -> true;
is_error(_) -> false.

compact_value(<<"#!alang-model-v1\n", Json/binary>>) ->
    {ok, Value} = alang_fidelity_json:decode(Json),
    Value.

compact_binary(Value) ->
    {ok, Json} = alang_fidelity_json:encode_canonical(Value),
    <<"#!alang-model-v1\n", Json/binary>>.

delegated_oracle() ->
    {ok, Corpus} = alang_fidelity_json:decode_file(corpus_path()),
    hd([Oracle || Case <- maps:get(<<"cases">>, Corpus),
        Oracle <- [alang_compact_corpus:oracle(Case)],
        is_map(maps:get(<<"child_attenuation">>, Oracle))]).

registry_path() -> filename:join([phase2_dir(), "contracts", "surface-registry-v1.json"]).
audit_contract_path() -> filename:join([phase2_dir(), "contracts", "token-audit-contract-v1.json"]).
tokenizer_dir() -> filename:join([phase2_dir(), "tokenizers"]).
phase2_dir() -> filename:join(["assets", "compact-projection-fidelity", "phase-02"]).
corpus_path() -> filename:join(["assets", "compact-projection-fidelity", "corpus",
    "confirmatory-corpus-v1.json"]).

hex(Binary) ->
    iolist_to_binary([io_lib:format("~2.16.0b", [Byte]) || <<Byte>> <= Binary]).
