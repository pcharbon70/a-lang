-module(alang_compact_token_audit).

-export([audit/6, load_contract/1, validate_contract/1]).

-define(SEMANTIC_SECTIONS, [layout, keywords, identifiers, facts, paths, budgets,
    authority, completion, legends, common_instructions, output_scaffolding]).
-define(LEXEME_CLASSES, [layout, keywords, identifiers, literals, punctuation]).

-spec load_contract(file:filename()) -> {ok, map()} | {error, term()}.
load_contract(Path) ->
    case alang_fidelity_json:decode_file(Path) of
        {ok, Value} -> validate_contract(Value);
        {error, Reason} -> {error, {token_audit_contract_read_failed, Reason}}
    end.

-spec validate_contract(term()) -> {ok, map()} | {error, term()}.
validate_contract(Value) when is_map(Value) ->
    Expected = expected_contract(),
    case Value =:= Expected of
        true -> {ok, Value};
        false -> {error, {token_audit_contract_mismatch,
            alang_fidelity_json:digest(Expected), alang_fidelity_json:digest(Value)}}
    end;
validate_contract(Value) ->
    {error, {invalid_token_audit_contract, Value}}.

-spec audit(binary(), map(), map(), term(), file:filename(), file:filename()) ->
    {ok, map()} | {error, term()}.
audit(ProfileId, Surface, RequestParts, ProviderUsage, TokenizerDirectory, ContractPath) ->
    case load_contract(ContractPath) of
        {ok, _} -> audit_registered(ProfileId, Surface, RequestParts, ProviderUsage, TokenizerDirectory);
        {error, _} = Error -> Error
    end.

audit_registered(ProfileId, Surface, RequestParts, ProviderUsage, TokenizerDirectory) ->
    case validate_inputs(Surface, RequestParts, ProviderUsage) of
        {ok, Sections, Lexemes, NormalizedUsage, FullRequest} ->
            Document = maps:get(bytes, Surface),
            case {count(ProfileId, Document, TokenizerDirectory),
                    count(ProfileId, FullRequest, TokenizerDirectory),
                    count_attribution(ProfileId, Sections, TokenizerDirectory),
                    count_attribution(ProfileId, Lexemes, TokenizerDirectory)} of
                {{ok, DocumentCount}, {ok, RequestCount}, {ok, SectionCounts}, {ok, LexemeCounts}} ->
                    {ok, #{
                        <<"format">> => <<"alang-compact-token-audit-v1">>,
                        <<"surface_id">> => maps:get(surface_id, Surface),
                        <<"representation">> => maps:get(representation, Surface),
                        <<"version">> => maps:get(version, Surface),
                        <<"representation_bytes">> => byte_size(Document),
                        <<"representation_sha256">> => maps:get(representation_sha256, Surface),
                        <<"tokenizer">> => #{
                            <<"profile_id">> => ProfileId,
                            <<"implementation">> => <<"beam-byte-pair-encoding-v1">>,
                            <<"provenance">> => <<"exact-registered-tokenizer">>
                        },
                        <<"counts">> => #{
                            <<"document">> => DocumentCount,
                            <<"full_request">> => RequestCount
                        },
                        <<"semantic_sections">> => SectionCounts,
                        <<"lexeme_classes">> => LexemeCounts,
                        <<"attribution">> => <<"standalone-nonadditive-bpe-components">>,
                        <<"provider_usage">> => NormalizedUsage
                    }};
                Results -> first_error(tuple_to_list(Results))
            end;
        {error, _} = Error -> Error
    end.

validate_inputs(Surface, RequestParts, ProviderUsage) ->
    RequiredSurface = [surface_id, representation, version, bytes, representation_sha256,
        semantic_digest, sections, lexemes, provenance, byte_count],
    case closed_atom_map(Surface, RequiredSurface, surface) of
        ok ->
            RequiredRequest = [common_instructions, legend, output_scaffolding],
            case closed_atom_map(RequestParts, RequiredRequest, request_parts) of
                ok -> validate_maps_and_usage(Surface, RequestParts, ProviderUsage);
                {error, _} = Error -> Error
            end;
        {error, _} = Error -> Error
    end.

validate_maps_and_usage(Surface, RequestParts, ProviderUsage) ->
    Sections0 = maps:get(sections, Surface),
    Lexemes = maps:get(lexemes, Surface),
    case {closed_binary_components(Sections0, ?SEMANTIC_SECTIONS, semantic_sections),
            closed_binary_components(Lexemes, ?LEXEME_CLASSES, lexeme_classes),
            binary_request_parts(RequestParts), normalize_provider_usage(ProviderUsage)} of
        {ok, ok, ok, {ok, NormalizedUsage}} ->
            Sections = Sections0#{
                legends := maps:get(legend, RequestParts),
                common_instructions := maps:get(common_instructions, RequestParts),
                output_scaffolding := maps:get(output_scaffolding, RequestParts)
            },
            FullRequest = iolist_to_binary([
                maps:get(common_instructions, RequestParts), <<"\n">>,
                maps:get(legend, RequestParts), <<"\n">>,
                maps:get(bytes, Surface), <<"\n">>,
                maps:get(output_scaffolding, RequestParts)
            ]),
            {ok, Sections, Lexemes, NormalizedUsage, FullRequest};
        {{error, _} = Error, _, _, _} -> Error;
        {_, {error, _} = Error, _, _} -> Error;
        {_, _, {error, _} = Error, _} -> Error;
        {_, _, _, {error, _} = Error} -> Error
    end.

normalize_provider_usage(unavailable) ->
    {ok, #{<<"status">> => <<"unavailable">>, <<"provenance">> => <<"not-reported">>}};
normalize_provider_usage(Usage) when is_map(Usage) ->
    Required = [source, input_tokens, output_tokens, total_tokens, estimated],
    case closed_atom_map(Usage, Required, provider_usage) of
        ok ->
            Input = maps:get(input_tokens, Usage),
            Output = maps:get(output_tokens, Usage),
            Total = maps:get(total_tokens, Usage),
            case maps:get(source, Usage) =:= provider_reported andalso
                    maps:get(estimated, Usage) =:= false andalso
                    valid_count(Input) andalso valid_count(Output) andalso
                    Total =:= Input + Output of
                true -> {ok, #{
                    <<"status">> => <<"reported">>,
                    <<"provenance">> => <<"provider-reported-authoritative">>,
                    <<"input_tokens">> => Input,
                    <<"output_tokens">> => Output,
                    <<"total_tokens">> => Total
                }};
                false -> {error, invalid_or_estimated_provider_usage}
            end;
        {error, _} = Error -> Error
    end;
normalize_provider_usage(_) -> {error, invalid_provider_usage}.

valid_count(Value) -> is_integer(Value) andalso Value >= 0.

count(ProfileId, Binary, Directory) ->
    case alang_compact_tokenizer:encode(ProfileId, Binary, Directory) of
        {ok, Encoded} -> {ok, maps:get(token_count, Encoded)};
        {error, _} = Error -> Error
    end.

count_attribution(ProfileId, Components, Directory) ->
    count_pairs(ProfileId, lists:sort(maps:to_list(Components)), Directory, #{}).

count_pairs(_ProfileId, [], _Directory, Acc) -> {ok, Acc};
count_pairs(ProfileId, [{Name, Binary} | Rest], Directory, Acc) ->
    case count(ProfileId, Binary, Directory) of
        {ok, TokenCount} ->
            Key = atom_to_binary(Name),
            count_pairs(ProfileId, Rest, Directory,
                Acc#{Key => #{<<"bytes">> => byte_size(Binary), <<"tokens">> => TokenCount}});
        {error, _} = Error -> Error
    end.

closed_atom_map(Value, Required, Name) when is_map(Value) ->
    Keys = maps:keys(Value),
    case {Keys -- Required, Required -- Keys} of
        {[], []} -> ok;
        {Unknown, Missing} -> {error, {invalid_closed_record, Name, lists:sort(Unknown), lists:sort(Missing)}}
    end;
closed_atom_map(_Value, _Required, Name) -> {error, {expected_map, Name}}.

closed_binary_components(Value, Required, Name) when is_map(Value) ->
    case closed_atom_map(Value, Required, Name) of
        ok ->
            case lists:all(fun is_binary/1, maps:values(Value)) of
                true -> ok;
                false -> {error, {nonbinary_component, Name}}
            end;
        {error, _} = Error -> Error
    end;
closed_binary_components(_Value, _Required, Name) -> {error, {expected_map, Name}}.

binary_request_parts(Value) ->
    case lists:all(fun is_binary/1, maps:values(Value)) of
        true -> ok;
        false -> {error, nonbinary_request_part}
    end.

first_error([{error, _} = Error | _]) -> Error;
first_error([_ | Rest]) -> first_error(Rest).

expected_contract() ->
    #{
        <<"format">> => <<"alang-compact-token-audit-contract-v1">>,
        <<"report_format">> => <<"alang-compact-token-audit-v1">>,
        <<"representation_digest">> => <<"sha-256-bytes">>,
        <<"offline_counts">> => <<"exact-registered-tokenizer">>,
        <<"provider_usage">> => <<"authoritative-when-present-otherwise-unavailable">>,
        <<"attribution_mode">> => <<"standalone-nonadditive-bpe-components">>,
        <<"semantic_sections">> => [atom_to_binary(Name) || Name <- ?SEMANTIC_SECTIONS],
        <<"lexeme_classes">> => [atom_to_binary(Name) || Name <- ?LEXEME_CLASSES],
        <<"required_count_scopes">> => [<<"document">>, <<"full_request">>],
        <<"estimated_provider_usage">> => <<"reject">>
    }.
