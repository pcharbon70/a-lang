-module(alang_fidelity_preregister).

-export([
    build/1,
    main/0,
    registration_files/1,
    scope_audit/1,
    validate_all/1,
    write/2
]).

-define(DEFAULT_BASE, "assets/effectful-source-fidelity").
-define(DEFAULT_OUTPUT, "build/effectful-source-fidelity/phase-01/evidence/pre-registration-evidence.json").

-spec main() -> no_return().
main() ->
    {Base, Output} = case init:get_plain_arguments() of
        [] -> {?DEFAULT_BASE, ?DEFAULT_OUTPUT};
        [OutputArgument] -> {?DEFAULT_BASE, OutputArgument};
        [BaseArgument, OutputArgument] -> {BaseArgument, OutputArgument};
        Arguments -> fail_main({invalid_arguments, Arguments})
    end,
    case write(Base, Output) of
        {ok, Evidence} ->
            io:format(
                "fidelity_preregistration_ok digest=~s files=~B cases=~B hosted_calls=0 output=~s~n",
                [
                    maps:get(<<"registration_digest">>, Evidence),
                    maps:get(<<"registration_file_count">>, Evidence),
                    maps:get(<<"semantic_case_count">>, Evidence),
                    Output
                ]
            ),
            halt(0);
        {error, Reason} -> fail_main(Reason)
    end.

-spec build(file:filename()) -> {ok, map()} | {error, term()}.
build(Base) ->
    case validate_all(Base) of
        {ok, Validation} ->
            Files = registration_files(Base),
            Entries = [file_entry(Path) || Path <- Files],
            RegistrationDigest = alang_fidelity_json:digest([
                {maps:get(<<"path">>, Entry), maps:get(<<"sha256">>, Entry), maps:get(<<"bytes">>, Entry)}
                || Entry <- Entries
            ]),
            Corpus = maps:get(<<"corpus">>, Validation),
            Campaign = maps:get(<<"campaign">>, Validation),
            Evidence0 = #{
                <<"format">> => <<"alang-fidelity-preregistration-evidence-v1">>,
                <<"digest_algorithm">> => <<"sha-256-canonical-etf-v1">>,
                <<"registration_digest">> => RegistrationDigest,
                <<"registration_file_count">> => length(Entries),
                <<"registration_files">> => Entries,
                <<"semantic_case_count">> => maps:get(<<"semantic_cases">>, Corpus),
                <<"candidate_document_count">> => maps:get(<<"candidate_documents">>, Corpus),
                <<"control_document_count">> => maps:get(<<"control_documents">>, Corpus),
                <<"answer_key_count">> => maps:get(<<"answer_keys">>, Corpus),
                <<"model_profile_count">> => maps:get(<<"model_profiles">>, Campaign),
                <<"primary_call_ceiling">> => maps:get(<<"primary_call_ceiling">>, Campaign),
                <<"all_call_ceiling">> => maps:get(<<"all_call_ceiling">>, Campaign),
                <<"cost_ceiling_usd">> => maps:get(<<"cost_ceiling_usd">>, Campaign),
                <<"network_default">> => maps:get(<<"network_default">>, Campaign),
                <<"hosted_calls_observed">> => 0,
                <<"schemas_validated">> => maps:get(<<"schemas_validated">>, Validation),
                <<"scope_audit">> => maps:get(<<"scope_audit">>, Validation),
                <<"commands">> => [
                    <<"make test-fidelity-section-1-4">>,
                    <<"make build-fidelity-phase-1-evidence">>,
                    <<"make test-fidelity-phase-1">>
                ]
            },
            {ok, Evidence0#{<<"evidence_digest">> => alang_fidelity_json:digest(Evidence0)}};
        {error, _} = Error -> Error
    end.

-spec write(file:filename(), file:filename()) -> {ok, map()} | {error, term()}.
write(Base, Output0) ->
    try
        Output = safe_output(Output0),
        case build(Base) of
            {ok, Evidence} ->
                ok = filelib:ensure_dir(Output),
                Bytes = [json:format(Evidence), <<"\n">>],
                ok = file:write_file(Output, Bytes),
                {ok, Evidence};
            {error, _} = Error -> Error
        end
    catch
        Class:Reason -> {error, {evidence_write_failed, Class, Reason}}
    end.

-spec validate_all(file:filename()) -> {ok, map()} | {error, term()}.
validate_all(Base) ->
    Contracts = filename:join(Base, "contracts"),
    SourceContract = filename:join(Contracts, "alang-source-v2-contract.json"),
    PairingContract = filename:join(Contracts, "pairing-and-materialization-v1.json"),
    DecisionContract = filename:join(Contracts, "metrics-and-decision-v1.json"),
    case validate_schemas(Contracts) of
        {ok, SchemaEvidence} ->
            case alang_fidelity_representation:load_source_contract(SourceContract) of
                {ok, _} ->
                    case alang_fidelity_representation:load_pairing_contract(PairingContract) of
                        {ok, _} ->
                            case alang_fidelity_decision:load_contract(DecisionContract) of
                                {ok, _} -> validate_corpus_and_scope(Base, SchemaEvidence);
                                {error, Reason} -> {error, {preregistration_error, decision_contract, Reason}}
                            end;
                        {error, Reason} -> {error, {preregistration_error, pairing_contract, Reason}}
                    end;
                {error, Reason} -> {error, {preregistration_error, source_contract, Reason}}
            end;
        {error, _} = Error -> Error
    end.

validate_corpus_and_scope(Base, SchemaEvidence) ->
    case alang_fidelity_corpus:validate(Base) of
        {ok, Registration} ->
            case scope_audit(Base) of
                {ok, Scope} ->
                    {ok, #{
                        <<"format">> => <<"alang-fidelity-registration-validation-v1">>,
                        <<"schemas_validated">> => maps:get(<<"schema_count">>, SchemaEvidence),
                        <<"corpus">> => maps:get(<<"corpus">>, Registration),
                        <<"campaign">> => maps:get(<<"campaign">>, Registration),
                        <<"scope_audit">> => Scope,
                        <<"hosted_calls_observed">> => maps:get(<<"hosted_calls_observed">>, Registration)
                    }};
                {error, _} = Error -> Error
            end;
        {error, _} = Error -> Error
    end.

-spec registration_files(file:filename()) -> [file:filename()].
registration_files(Base) ->
    Contracts = filelib:wildcard(filename:join([Base, "contracts", "*.json"])),
    CampaignJson = filelib:wildcard(filename:join([Base, "campaign", "*.json"])),
    CampaignText = filelib:wildcard(filename:join([Base, "campaign", "*.txt"])),
    CorpusRoot = filelib:wildcard(filename:join([Base, "corpus", "*.json"])),
    CorpusAlang = filelib:wildcard(filename:join([Base, "corpus", "*", "*.alang"])),
    CorpusJson = filelib:wildcard(filename:join([Base, "corpus", "*", "*.json"])),
    lists:sort(Contracts ++ CampaignJson ++ CampaignText ++ CorpusRoot ++ CorpusAlang ++ CorpusJson).

-spec scope_audit(file:filename()) -> {ok, map()} | {error, term()}.
scope_audit(Base) ->
    try
        CandidateFiles = filelib:wildcard(filename:join([Base, "corpus", "*", "*.alang"])),
        ensure(length(CandidateFiles) =:= 24, {expected_candidate_count, 24, length(CandidateFiles)}),
        Pattern = <<"(^|\\n)[\\t ]*(recurse|recursion|polymorph|forall|parallel|spawn|distribut|portable-delegation|delegation-protocol|protocol|package|self[-_]?host|categor)[a-z_-]*[\\t (]">>,
        lists:foreach(
            fun(Path) ->
                {ok, Binary} = file:read_file(Path),
                [_, Visible] = binary:split(Binary, <<"// model-visible-begin\n">>),
                ensure(re:run(Visible, Pattern, [multiline, {capture, none}]) =:= nomatch, {frozen_surface_construct, Path}),
                audit_surface_vocabulary(Visible, Path)
            end,
            CandidateFiles
        ),
        RepoRoot = filename:dirname(filename:dirname(Base)),
        SourceFiles = filelib:wildcard(filename:join([RepoRoot, "src", "effectful-source-fidelity", "*"])),
        Foreign = [Path || Path <- SourceFiles,
            filelib:is_regular(Path),
            not lists:member(filename:extension(Path), [".erl", ".md"])],
        ensure(Foreign =:= [], {foreign_trusted_source, Foreign}),
        {ok, #{
            <<"format">> => <<"alang-fidelity-scope-audit-v1">>,
            <<"candidate_documents_scanned">> => length(CandidateFiles),
            <<"foreign_trusted_sources">> => 0,
            <<"allowed_effects">> => [<<"child.run">>, <<"model.generate">>, <<"workspace.write">>],
            <<"frozen_features_absent">> => [
                <<"arbitrary-calls">>,
                <<"categorical-surface-syntax">>,
                <<"distribution">>,
                <<"dynamic-operations">>,
                <<"package-management">>,
                <<"parallelism">>,
                <<"polymorphism">>,
                <<"portable-delegation-protocols">>,
                <<"recursion">>,
                <<"self-hosting">>
            ],
            <<"passed">> => true
        }}
    catch
        error:{badmatch, Reason} -> {error, {scope_audit_failed, Reason}};
        throw:{scope_audit_failed, Reason} -> {error, {scope_audit_failed, Reason}}
    end.

audit_surface_vocabulary(Visible, Path) ->
    EffectLists = captures(Visible, <<"effects[ \\t]*\\[([^\\]]*)\\]">>),
    ensure(EffectLists =/= [], {missing_effect_declaration, Path}),
    AllowedEffects = [<<"child.run">>, <<"model.generate">>, <<"workspace.write">>],
    lists:foreach(
        fun(EffectList) ->
            Effects = csv(EffectList),
            ensure(lists:all(fun(Effect) -> lists:member(Effect, AllowedEffects) end, Effects), {extra_effect_family, Path, Effects})
        end,
        EffectLists
    ),
    Operations = captures(Visible, <<"step[ \\t]+[a-z][a-z0-9-]*[ \\t]*:[ \\t]*([a-z.]+)">>),
    AllowedOperations = [<<"child.run">>, <<"complete">>, <<"model.generate">>, <<"model.repair">>, <<"workspace.write">>],
    ensure(Operations =/= [], {missing_step_operation, Path}),
    ensure(lists:all(fun(Operation) -> lists:member(Operation, AllowedOperations) end, Operations), {dynamic_or_arbitrary_operation, Path, Operations}).

captures(Binary, Pattern) ->
    case re:run(Binary, Pattern, [global, {capture, [1], binary}]) of
        {match, Matches} -> [Value || [Value] <- Matches];
        nomatch -> []
    end.

csv(Binary) ->
    Trimmed = string:trim(Binary),
    case Trimmed of
        <<>> -> [];
        _ -> [string:trim(Item) || Item <- binary:split(Trimmed, <<",">>, [global])]
    end.

validate_schemas(Contracts) ->
    try
        Paths = lists:sort(filelib:wildcard(filename:join(Contracts, "*.schema.json"))),
        ensure(length(Paths) =:= 7, {expected_schema_count, 7, length(Paths)}),
        Schemas = [begin
            {ok, Schema} = alang_fidelity_json:decode_file(Path),
            exact(maps:get(<<"$schema">>, Schema, undefined), <<"https://json-schema.org/draft/2020-12/schema">>, {schema_dialect, Path}),
            ensure(maps:is_key(<<"$id">>, Schema), {missing_schema_id, Path}),
            exact(maps:get(<<"type">>, Schema, undefined), <<"object">>, {root_schema_type, Path}),
            exact(maps:get(<<"additionalProperties">>, Schema, undefined), false, {root_schema_open, Path}),
            validate_closed_objects(Schema, [list_to_binary(Path)]),
            Schema
        end || Path <- Paths],
        Ids = [maps:get(<<"$id">>, Schema) || Schema <- Schemas],
        ensure(length(Ids) =:= length(lists:usort(Ids)), duplicate_schema_id),
        {ok, #{<<"format">> => <<"alang-fidelity-schema-evidence-v1">>, <<"schema_count">> => length(Paths), <<"schema_ids">> => lists:sort(Ids)}}
    catch
        error:{badmatch, Reason} -> {error, {schema_validation_failed, Reason}};
        throw:{scope_audit_failed, Reason} -> {error, {schema_validation_failed, Reason}}
    end.

validate_closed_objects(Value, Path) when is_map(Value) ->
    case maps:get(<<"type">>, Value, undefined) of
        <<"object">> -> exact(maps:get(<<"additionalProperties">>, Value, undefined), false, {open_object_schema, Path});
        _ -> ok
    end,
    lists:foreach(fun({Key, Child}) -> validate_closed_objects(Child, Path ++ [Key]) end, maps:to_list(Value));
validate_closed_objects(Value, Path) when is_list(Value) ->
    lists:foreach(fun({Child, Index}) -> validate_closed_objects(Child, Path ++ [Index]) end, indexed(Value));
validate_closed_objects(_Value, _Path) ->
    ok.

file_entry(Path) ->
    {ok, Binary} = file:read_file(Path),
    #{
        <<"path">> => list_to_binary(Path),
        <<"sha256">> => alang_fidelity_json:hex(crypto:hash(sha256, Binary)),
        <<"bytes">> => byte_size(Binary)
    }.

safe_output(Output0) ->
    Output = filename:absname(Output0),
    Root = filename:absname("build/effectful-source-fidelity"),
    true = lists:prefix(Root ++ "/", Output),
    Output.

indexed(List) ->
    lists:zip(List, lists:seq(0, length(List) - 1)).

exact(Value, Expected, Reason) ->
    ensure(Value =:= Expected, {Reason, expected, Expected, actual, Value}).

ensure(true, _Reason) -> ok;
ensure(false, Reason) -> throw({scope_audit_failed, Reason}).

fail_main(Reason) ->
    io:format(standard_error, "fidelity_preregistration_error ~tp~n", [Reason]),
    halt(1).
