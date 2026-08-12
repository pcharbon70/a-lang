-module(alang_compact_surface).

-export([decode/3, load_registry/1, render/4, validate_registry/1]).

-define(MAX_REPRESENTATION_BYTES, 32768).

-spec load_registry(file:filename()) -> {ok, map()} | {error, term()}.
load_registry(Path) ->
    case alang_fidelity_json:decode_file(Path) of
        {ok, Value} -> validate_registry(Value);
        {error, Reason} -> {error, {surface_registry_read_failed, Reason}}
    end.

-spec validate_registry(term()) -> {ok, map()} | {error, term()}.
validate_registry(Value) when is_map(Value) ->
    Expected = expected_registry(),
    case Value =:= Expected of
        true -> {ok, Value};
        false -> {error, {surface_registry_mismatch,
            alang_fidelity_json:digest(Expected), alang_fidelity_json:digest(Value)}}
    end;
validate_registry(Value) ->
    {error, {invalid_surface_registry, Value}}.

-spec render(binary(), binary(), map(), file:filename()) -> {ok, map()} | {error, term()}.
render(SurfaceId, Version, Oracle, RegistryPath) ->
    case load_registry(RegistryPath) of
        {ok, Registry} -> render_registered(SurfaceId, Version, Oracle, Registry);
        {error, _} = Error -> Error
    end.

render_registered(SurfaceId, Version, Oracle, Registry) ->
    case find_surface(SurfaceId, maps:get(<<"surfaces">>, Registry)) of
        {ok, Surface} ->
            ExpectedVersion = maps:get(<<"version">>, Surface),
            case Version =:= ExpectedVersion of
                true -> render_checked(Surface, Oracle);
                false -> {error, {surface_version_mismatch, SurfaceId, ExpectedVersion, Version}}
            end;
        error ->
            {error, {unknown_surface, SurfaceId}}
    end.

render_checked(#{<<"implementation_section">> := Section} = Surface, Oracle)
  when Section =:= <<"2.1">> ->
    case alang_fidelity_contract:validate_comprehension(Oracle) of
        {ok, _} ->
            try render_implemented(maps:get(<<"id">>, Surface), Oracle) of
                {ok, Binary} -> result(Surface, Oracle, Binary);
                {error, _} = Error -> Error
            catch
                throw:{surface_render_error, Reason} -> {error, Reason}
            end;
        {error, Reason} ->
            {error, {invalid_checked_semantics, Reason}}
    end;
render_checked(Surface, _Oracle) ->
    {error, {surface_not_implemented,
        maps:get(<<"id">>, Surface), maps:get(<<"implementation_section">>, Surface)}}.

render_implemented(<<"R0">>, Oracle) ->
    {ok, render_source(Oracle, readable)};
render_implemented(<<"R1">>, Oracle) ->
    {ok, render_source(Oracle, minified)};
render_implemented(<<"R2">>, Oracle) ->
    {ok, render_source(Oracle, alias)};
render_implemented(<<"R5">>, Oracle) ->
    Control = #{
        <<"format">> => <<"alang-task-json-v1">>,
        <<"case_id">> => maps:get(<<"case_id">>, Oracle),
        <<"task">> => maps:without([<<"format">>, <<"case_id">>], Oracle)
    },
    alang_fidelity_json:encode_canonical(Control).

result(Surface, Oracle, Binary) when byte_size(Binary) =< ?MAX_REPRESENTATION_BYTES ->
    SemanticDigest = alang_fidelity_contract:semantic_digest(Oracle),
    {ok, #{
        surface_id => maps:get(<<"id">>, Surface),
        representation => maps:get(<<"representation">>, Surface),
        version => maps:get(<<"version">>, Surface),
        bytes => Binary,
        byte_count => byte_size(Binary),
        representation_sha256 => hex(crypto:hash(sha256, Binary)),
        semantic_digest => SemanticDigest,
        sections => semantic_sections(Oracle, Binary),
        lexemes => lexeme_sections(Oracle, Binary),
        provenance => #{
            input => checked_alang_task_comprehension_v1,
            canonical => true,
            renderer => ?MODULE,
            semantic_digest => SemanticDigest
        }
    }};
result(_Surface, _Oracle, Binary) ->
    {error, {representation_too_large, byte_size(Binary), ?MAX_REPRESENTATION_BYTES}}.

-spec decode(binary(), binary(), binary()) -> {ok, map()} | {error, term()}.
decode(SurfaceId, Version, Binary) when is_binary(Binary), byte_size(Binary) =< ?MAX_REPRESENTATION_BYTES ->
    case exact_version(SurfaceId, Version) of
        ok -> decode_versioned(SurfaceId, Binary);
        {error, _} = Error -> Error
    end;
decode(_SurfaceId, _Version, Binary) when is_binary(Binary) ->
    {error, {representation_too_large, byte_size(Binary), ?MAX_REPRESENTATION_BYTES}};
decode(_SurfaceId, _Version, _Binary) ->
    {error, expected_representation_binary}.

decode_versioned(<<"R0">>, Binary) -> decode_source(Binary, <<"alang-source-v2">>);
decode_versioned(<<"R1">>, Binary) -> decode_source(Binary, <<"alang-source-v2">>);
decode_versioned(<<"R2">>, Binary) ->
    case expand_alias_source(Binary) of
        {ok, Source} -> decode_source(Source, <<"alang-source-v2-alias-v1">>);
        {error, _} = Error -> Error
    end;
decode_versioned(<<"R5">>, Binary) ->
    case alang_fidelity_representation:decode_control(Binary) of
        {ok, Decoded} ->
            {ok, #{
                source_format => <<"alang-task-json-v1">>,
                semantic => maps:get(<<"semantic">>, Decoded),
                semantic_digest => maps:get(<<"semantic_digest">>, Decoded),
                origins => maps:get(<<"origins">>, Decoded)
            }};
        {error, Reason} -> {error, {surface_decode_failed, <<"R5">>, Reason}}
    end;
decode_versioned(SurfaceId, _Binary) ->
    {error, {surface_not_implemented, SurfaceId}}.

decode_source(Binary, SourceFormat) ->
    case alang_compact_source_normalizer:normalize(Binary) of
        {ok, NormalizedSource, State} ->
            case alang_fidelity_source:decode(NormalizedSource) of
                {ok, Decoded} ->
                    Semantic = alang_compact_source_normalizer:restore(maps:get(semantic, Decoded), State),
                    Comprehension = Semantic#{
                        <<"format">> => <<"alang_task_comprehension_v1">>,
                        <<"case_id">> => maps:get(case_id, Decoded)
                    },
                    case alang_fidelity_contract:validate_comprehension(Comprehension) of
                        {ok, _} -> {ok, #{
                            source_format => SourceFormat,
                            semantic => alang_fidelity_contract:normalize(Comprehension),
                            semantic_digest => alang_fidelity_contract:semantic_digest(Comprehension),
                            origins => maps:get(origins, Decoded),
                            normalization => reversible_source_domain_aliases
                        }};
                        {error, Reason} -> {error, {surface_decode_failed, SourceFormat, Reason}}
                    end;
                {error, Reason} -> {error, {surface_decode_failed, SourceFormat, Reason}}
            end;
        {error, Reason} -> {error, {surface_decode_failed, SourceFormat, Reason}}
    end.

exact_version(SurfaceId, Version) ->
    case find_surface(SurfaceId, maps:get(<<"surfaces">>, expected_registry())) of
        {ok, Surface} ->
            Expected = maps:get(<<"version">>, Surface),
            case Version =:= Expected of
                true -> ok;
                false -> {error, {surface_version_mismatch, SurfaceId, Expected, Version}}
            end;
        error -> {error, {unknown_surface, SurfaceId}}
    end.

find_surface(_SurfaceId, []) -> error;
find_surface(SurfaceId, [#{<<"id">> := SurfaceId} = Surface | _]) -> {ok, Surface};
find_surface(SurfaceId, [_ | Rest]) -> find_surface(SurfaceId, Rest).

render_source(Oracle, Mode) ->
    Header = case Mode of alias -> <<"#!alang-source-v2-alias-v1\n">>; _ -> <<"#!alang-source-v2\n">> end,
    Open = [word(Mode, task), <<" ">>, maps:get(<<"case_id">>, Oracle), <<"{">>, line_break(Mode)],
    Clauses = [
        clause(Mode, facts, string_list(maps:get(<<"goal_facts">>, Oracle)), 1),
        [input_clause(Mode, Input) || Input <- maps:get(<<"inputs">>, Oracle)],
        clause(Mode, effects, effect_list(maps:get(<<"effects">>, Oracle), Mode), 1),
        clause(Mode, requirements, requirement_list(maps:get(<<"requirements">>, Oracle), Mode), 1),
        scopes_clause(Mode, maps:get(<<"scopes">>, Oracle), 1),
        limits_clause(Mode, maps:get(<<"budgets">>, Oracle), 1),
        [action_clause(Mode, Action) || Action <- maps:get(<<"actions">>, Oracle)],
        error_clause(Mode, maps:get(<<"error_branches">>, Oracle)),
        child_clause(Mode, maps:get(<<"child_attenuation">>, Oracle)),
        completion_clause(Mode, maps:get(<<"completion_predicates">>, Oracle)),
        clause(Mode, clarify, string_list(maps:get(<<"clarification_needs">>, Oracle)), 1),
        [indent(Mode, 1), word(Mode, terminal), <<" ">>,
            maps:get(<<"terminal_class">>, Oracle), <<";">>, line_break(Mode)]
    ],
    iolist_to_binary([Header, Open, Clauses, <<"}\n">>]).

clause(Mode, Name, Value, Depth) ->
    [indent(Mode, Depth), word(Mode, Name), optional_space(Mode), Value, <<";">>, line_break(Mode)].

input_clause(Mode, Input) ->
    Required = case maps:get(<<"required">>, Input) of true -> <<"required">>; false -> <<"optional">> end,
    [indent(Mode, 1), word(Mode, input), <<" ">>, maps:get(<<"name">>, Input), <<":">>,
        maps:get(<<"type">>, Input), <<" ">>, Required, <<";">>, line_break(Mode)].

action_clause(alias, Action) ->
    [word(alias, step), <<" ">>, maps:get(<<"id">>, Action), <<":">>,
        operation_alias(maps:get(<<"operation">>, Action)), <<"<-">>,
        identifier_list(maps:get(<<"depends_on">>, Action)), <<";">>];
action_clause(Mode, Action) ->
    [indent(Mode, 1), word(Mode, step), <<" ">>, maps:get(<<"id">>, Action), <<":">>,
        maps:get(<<"operation">>, Action), <<" depends">>, optional_space(Mode),
        identifier_list(maps:get(<<"depends_on">>, Action)), <<";">>, line_break(Mode)].

error_clause(Mode, Branches) ->
    Values = join([error_branch(Branch) || Branch <- Branches], <<",">>, Mode),
    clause(Mode, on_error, [<<"[">>, Values, <<"]">>], 1).

error_branch(Branch) ->
    [maps:get(<<"action">>, Branch), <<" ">>, maps:get(<<"on">>, Branch), <<"=>">>,
        maps:get(<<"terminal_class">>, Branch)].

child_clause(Mode, null) ->
    [indent(Mode, 1), word(Mode, child), <<" none;">>, line_break(Mode)];
child_clause(Mode, Child) ->
    [indent(Mode, 1), word(Mode, child), optional_space(Mode), <<"{">>,
        clause(Mode, effects, effect_list(maps:get(<<"effects">>, Child), Mode), 0),
        clause(Mode, requirements, requirement_list(maps:get(<<"requirements">>, Child), Mode), 0),
        scopes_clause(Mode, maps:get(<<"scopes">>, Child), 0),
        limits_clause(Mode, maps:get(<<"budgets">>, Child), 0),
        <<"}">>, line_break(Mode)].

completion_clause(Mode, Predicates) ->
    Values = join([completion_predicate(Predicate, Mode) || Predicate <- Predicates], <<",">>, Mode),
    clause(Mode, completion, [<<"[">>, Values, <<"]">>], 1).

completion_predicate(Predicate, Mode) ->
    Kind = case Mode of
        alias -> <<"~", (predicate_alias(maps:get(<<"kind">>, Predicate)))/binary>>;
        _ -> maps:get(<<"kind">>, Predicate)
    end,
    [Kind, <<" ">>, quote(maps:get(<<"target">>, Predicate)), <<":">>,
        scalar(maps:get(<<"expected">>, Predicate))].

scopes_clause(Mode, Scopes, Depth) ->
    Fields = [scope_field(Mode, models, maps:get(<<"models">>, Scopes)),
        scope_field(Mode, workspaces, maps:get(<<"workspaces">>, Scopes)),
        scope_field(Mode, paths, maps:get(<<"paths">>, Scopes))],
    [indent(Mode, Depth), word(Mode, scopes), optional_space(Mode), <<"{">>, Fields, <<"}">>, line_break(Mode)].

scope_field(alias, Name, Values) ->
    [scope_alias(Name), <<"=">>, scope_values(Name, Values), <<";">>];
scope_field(Mode, Name, Values) ->
    [word(Mode, Name), optional_space(Mode), scope_values(Name, Values), <<";">>].

scope_values(paths, Values) -> string_list(Values);
scope_values(_Name, Values) -> identifier_list(Values).

limits_clause(Mode, Budgets, Depth) ->
    Values = [limit_field(Mode, Name, maps:get(budget_key(Name), Budgets)) || Name <- budget_names()],
    [indent(Mode, Depth), word(Mode, limits), optional_space(Mode), <<"{">>, Values, <<"}">>, line_break(Mode)].

limit_field(alias, Name, Value) -> [<<"~">>, budget_alias(Name), <<"=">>, integer_to_binary(Value), <<";">>];
limit_field(Mode, Name, Value) -> [word(Mode, Name), <<" ">>, integer_to_binary(Value), <<";">>].

string_list(Values) -> [<<"[">>, join([quote(Value) || Value <- Values], <<",">>, minified), <<"]">>].
identifier_list(Values) -> [<<"[">>, join(Values, <<",">>, minified), <<"]">>].
effect_list(Values, _Mode) -> identifier_list(Values).
requirement_list(Values, Mode) ->
    [<<"[">>, join([[maps:get(<<"kind">>, Value), <<" ">>, maps:get(<<"resource">>, Value)] || Value <- Values], <<",">>, Mode), <<"]">>].

join([], _Separator, _Mode) -> [];
join([Only], _Separator, _Mode) -> Only;
join([Head | Rest], Separator, readable) -> [Head, Separator, <<" ">>, join(Rest, Separator, readable)];
join([Head | Rest], Separator, Mode) -> [Head, Separator, join(Rest, Separator, Mode)].

quote(Binary) -> [<<"\"">>, quote_bytes(Binary), <<"\"">>].
quote_bytes(<<>>) -> [];
quote_bytes(<<$", Rest/binary>>) -> [<<"\\\"">> | quote_bytes(Rest)];
quote_bytes(<<$\\, Rest/binary>>) -> [<<"\\\\">> | quote_bytes(Rest)];
quote_bytes(<<Byte, _/binary>>) when Byte < 32 -> throw({surface_render_error, {unsupported_string_character, Byte}});
quote_bytes(<<Codepoint/utf8, Rest/binary>>) -> [<<Codepoint/utf8>> | quote_bytes(Rest)].

scalar(true) -> <<"true">>;
scalar(false) -> <<"false">>;
scalar(Value) when is_integer(Value) -> integer_to_binary(Value);
scalar(Value) when is_binary(Value) -> quote(Value).

optional_space(readable) -> <<" ">>;
optional_space(_) -> <<>>.
line_break(readable) -> <<"\n">>;
line_break(_) -> <<>>.
indent(readable, 1) -> <<"  ">>;
indent(_, _) -> <<>>.

word(alias, facts) -> <<"f">>;
word(alias, input) -> <<"i">>;
word(alias, requirements) -> <<"use">>;
word(alias, scopes) -> <<"at">>;
word(alias, limits) -> <<"cap">>;
word(alias, on_error) -> <<"err">>;
word(alias, child) -> <<"kid">>;
word(alias, completion) -> <<"ok">>;
word(alias, clarify) -> <<"ask">>;
word(alias, terminal) -> <<"end">>;
word(_Mode, on_error) -> <<"on-error">>;
word(_Mode, completion) -> <<"complete">>;
word(_Mode, model_calls) -> <<"model-calls">>;
word(_Mode, repair_calls) -> <<"repair-calls">>;
word(_Mode, child_calls) -> <<"child-calls">>;
word(_Mode, workspace_writes) -> <<"workspace-writes">>;
word(_Mode, output_bytes) -> <<"output-bytes">>;
word(_Mode, timeout_ms) -> <<"timeout-ms">>;
word(_Mode, Name) -> atom_to_binary(Name).

scope_alias(models) -> <<"m">>;
scope_alias(workspaces) -> <<"w">>;
scope_alias(paths) -> <<"p">>.

budget_names() -> [steps, model_calls, repair_calls, child_calls, workspace_writes, output_bytes, timeout_ms].
budget_key(steps) -> <<"steps">>;
budget_key(model_calls) -> <<"model_calls">>;
budget_key(repair_calls) -> <<"repair_calls">>;
budget_key(child_calls) -> <<"child_calls">>;
budget_key(workspace_writes) -> <<"workspace_writes">>;
budget_key(output_bytes) -> <<"output_bytes">>;
budget_key(timeout_ms) -> <<"timeout_ms">>.

budget_alias(steps) -> <<"s">>;
budget_alias(model_calls) -> <<"m">>;
budget_alias(repair_calls) -> <<"r">>;
budget_alias(child_calls) -> <<"c">>;
budget_alias(workspace_writes) -> <<"w">>;
budget_alias(output_bytes) -> <<"b">>;
budget_alias(timeout_ms) -> <<"t">>.

operation_alias(<<"model.generate">>) -> <<"gen">>;
operation_alias(<<"model.repair">>) -> <<"fix">>;
operation_alias(<<"workspace.write">>) -> <<"put">>;
operation_alias(<<"child.run">>) -> <<"sub">>;
operation_alias(<<"complete">>) -> <<"done">>.

predicate_alias(<<"artifact-exists">>) -> <<"exists">>;
predicate_alias(<<"journal-succeeded">>) -> <<"journal">>;
predicate_alias(<<"max-bytes">>) -> <<"maxb">>;
predicate_alias(<<"utf8">>) -> <<"u8">>;
predicate_alias(<<"clarification-recorded">>) -> <<"asked">>;
predicate_alias(Other) -> Other.

expand_alias_source(<<"#!alang-source-v2-alias-v1", Rest/binary>>) ->
    case transform_outside_strings(Rest, false, []) of
        {ok, Expanded} -> {ok, <<"#!alang-source-v2", Expanded/binary>>};
        {error, _} = Error -> Error
    end;
expand_alias_source(<<"#!alang-source-", _/binary>>) -> {error, unsupported_alias_version};
expand_alias_source(_) -> {error, missing_alias_version}.

transform_outside_strings(<<>>, false, Acc) ->
    {ok, iolist_to_binary(lists:reverse(Acc))};
transform_outside_strings(<<>>, true, _Acc) ->
    {error, unterminated_alias_string};
transform_outside_strings(<<$", Rest/binary>>, false, Acc) ->
    transform_outside_strings(Rest, true, [<<$">> | Acc]);
transform_outside_strings(<<$", Rest/binary>>, true, Acc) ->
    transform_outside_strings(Rest, false, [<<$">> | Acc]);
transform_outside_strings(<<$\\, Escaped, Rest/binary>>, true, Acc) ->
    transform_outside_strings(Rest, true, [<<$\\, Escaped>> | Acc]);
transform_outside_strings(Binary, false, Acc) ->
    {Plain, Rest} = take_plain(Binary, <<>>),
    transform_outside_strings(Rest, false, [expand_plain(Plain) | Acc]);
transform_outside_strings(<<Codepoint/utf8, Rest/binary>>, true, Acc) ->
    transform_outside_strings(Rest, true, [<<Codepoint/utf8>> | Acc]).

take_plain(<<$", _/binary>> = Rest, Acc) -> {Acc, Rest};
take_plain(<<Codepoint/utf8, Rest/binary>>, Acc) -> take_plain(Rest, <<Acc/binary, Codepoint/utf8>>);
take_plain(<<>>, Acc) -> {Acc, <<>>}.

expand_plain(Binary) ->
    replace_all(Binary, [
        {<<"{f[">>, <<"{facts[">>}, {<<";i ">>, <<";input ">>},
        {<<"use[">>, <<"requirements[">>}, {<<"at{">>, <<"scopes{">>},
        {<<"cap{">>, <<"limits{">>}, {<<"err[">>, <<"on-error[">>},
        {<<"kid{">>, <<"child{">>}, {<<"kid none">>, <<"child none">>},
        {<<"ok[">>, <<"complete[">>}, {<<"ask[">>, <<"clarify[">>},
        {<<"end ">>, <<"terminal ">>},
        {<<"m=[">>, <<"models[">>}, {<<"w=[">>, <<"workspaces[">>},
        {<<"p=[">>, <<"paths[">>},
        {<<"~s=">>, <<"steps ">>}, {<<"~m=">>, <<"model-calls ">>},
        {<<"~r=">>, <<"repair-calls ">>}, {<<"~c=">>, <<"child-calls ">>},
        {<<"~w=">>, <<"workspace-writes ">>}, {<<"~b=">>, <<"output-bytes ">>},
        {<<"~t=">>, <<"timeout-ms ">>},
        {<<":gen<-">>, <<":model.generate depends">>},
        {<<":fix<-">>, <<":model.repair depends">>},
        {<<":put<-">>, <<":workspace.write depends">>},
        {<<":sub<-">>, <<":child.run depends">>},
        {<<":done<-">>, <<":complete depends">>},
        {<<"~exists">>, <<"artifact-exists">>},
        {<<"~journal">>, <<"journal-succeeded">>},
        {<<"~maxb">>, <<"max-bytes">>}, {<<"~u8">>, <<"utf8">>},
        {<<"~asked">>, <<"clarification-recorded">>}
    ]).

replace_all(Binary, []) -> Binary;
replace_all(Binary, [{From, To} | Rest]) ->
    replace_all(binary:replace(Binary, From, To, [global]), Rest).

semantic_sections(Oracle, Binary) ->
    Empty = <<>>,
    #{layout => layout_bytes(Binary),
        keywords => keyword_bytes(),
        identifiers => canonical_bytes(identifier_values(Oracle)),
        facts => canonical_bytes(maps:get(<<"goal_facts">>, Oracle)),
        paths => canonical_bytes(path_values(Oracle)),
        budgets => canonical_bytes(budget_values(Oracle)),
        authority => canonical_bytes(authority_values(Oracle)),
        completion => canonical_bytes(completion_values(Oracle)),
        legends => Empty,
        common_instructions => Empty,
        output_scaffolding => Empty}.

lexeme_sections(Oracle, Binary) ->
    #{layout => whitespace_bytes(Binary), keywords => keyword_bytes(),
        identifiers => canonical_bytes(identifier_values(Oracle)),
        literals => canonical_bytes(literal_values(Oracle)),
        punctuation => punctuation_bytes(Binary)}.

identifier_values(Oracle) ->
    [maps:get(<<"case_id">>, Oracle)] ++
    [maps:get(<<"name">>, Input) || Input <- maps:get(<<"inputs">>, Oracle)] ++
    lists:append([[maps:get(<<"id">>, Action) | maps:get(<<"depends_on">>, Action)]
        || Action <- maps:get(<<"actions">>, Oracle)]) ++
    [maps:get(<<"resource">>, Requirement) || Requirement <- maps:get(<<"requirements">>, Oracle)].

path_values(Oracle) ->
    maps:get(<<"paths">>, maps:get(<<"scopes">>, Oracle)) ++
    [maps:get(<<"target">>, Predicate) || Predicate <- maps:get(<<"completion_predicates">>, Oracle),
        binary:match(maps:get(<<"target">>, Predicate), <<"/">>) =:= {0, 1}].

budget_values(Oracle) ->
    case maps:get(<<"child_attenuation">>, Oracle) of
        null -> maps:get(<<"budgets">>, Oracle);
        Child -> #{<<"task">> => maps:get(<<"budgets">>, Oracle), <<"child">> => maps:get(<<"budgets">>, Child)}
    end.

authority_values(Oracle) ->
    maps:with([<<"effects">>, <<"requirements">>, <<"scopes">>, <<"error_branches">>,
        <<"child_attenuation">>], Oracle).

completion_values(Oracle) ->
    maps:with([<<"completion_predicates">>, <<"clarification_needs">>, <<"terminal_class">>], Oracle).

literal_values(Oracle) ->
    maps:with([<<"goal_facts">>, <<"budgets">>, <<"completion_predicates">>,
        <<"clarification_needs">>, <<"terminal_class">>], Oracle).

canonical_bytes(Value) ->
    {ok, Binary} = alang_fidelity_json:encode_canonical(Value),
    Binary.

layout_bytes(Binary) -> filter_outside_strings(Binary, fun is_layout_or_punctuation/1).
whitespace_bytes(Binary) -> filter_outside_strings(Binary, fun is_whitespace/1).
punctuation_bytes(Binary) -> filter_outside_strings(Binary, fun is_punctuation/1).

filter_outside_strings(Binary, Predicate) ->
    iolist_to_binary(lists:reverse(filter_bytes(Binary, false, Predicate, []))).

filter_bytes(<<>>, _Quoted, _Predicate, Acc) -> Acc;
filter_bytes(<<$", Rest/binary>>, Quoted, Predicate, Acc) ->
    filter_bytes(Rest, not Quoted, Predicate, Acc);
filter_bytes(<<$\\, _Escaped, Rest/binary>>, true, Predicate, Acc) ->
    filter_bytes(Rest, true, Predicate, Acc);
filter_bytes(<<Byte, Rest/binary>>, false, Predicate, Acc) ->
    Next = case Predicate(Byte) of true -> [<<Byte>> | Acc]; false -> Acc end,
    filter_bytes(Rest, false, Predicate, Next);
filter_bytes(<<_Codepoint/utf8, Rest/binary>>, true, Predicate, Acc) ->
    filter_bytes(Rest, true, Predicate, Acc).

is_layout_or_punctuation(Byte) -> is_whitespace(Byte) orelse is_punctuation(Byte).
is_whitespace(Byte) -> Byte =:= $\s orelse Byte =:= $\t orelse Byte =:= $\n orelse Byte =:= $\r.
is_punctuation(Byte) -> lists:member(Byte, "#!-{}[]:;,.=<>\\").

keyword_bytes() ->
    <<"task facts input effects requirements scopes limits step depends on-error child complete clarify terminal required optional model workspace models workspaces paths steps model-calls repair-calls child-calls workspace-writes output-bytes timeout-ms">>.

expected_registry() ->
    #{
        <<"format">> => <<"alang-compact-surface-registry-v1">>,
        <<"canonical_input">> => <<"checked-alang-task-comprehension-v1">>,
        <<"max_representation_bytes">> => 32768,
        <<"surfaces">> => [
            surface(<<"R0">>, <<"alang-source-v2-readable">>, <<"alang-source-v2">>, <<"canonical-baseline">>, false, <<"2.1">>),
            surface(<<"R1">>, <<"alang-source-v2-layout-minified">>, <<"alang-source-v2">>, <<"layout-ablation">>, false, <<"2.1">>),
            surface(<<"R2">>, <<"alang-source-v2-mnemonic-aliases">>, <<"alang-source-v2-alias-v1">>, <<"closed-vocabulary-ablation">>, false, <<"2.1">>),
            surface(<<"R3">>, <<"alang-model-v1">>, <<"alang-model-v1">>, <<"promotion-candidate">>, true, <<"2.2">>),
            surface(<<"R4">>, <<"alang-model-v1-opaque-identifiers">>, <<"alang-model-v1-opaque-control">>, <<"identifier-negative-control">>, false, <<"2.3">>),
            surface(<<"R5">>, <<"alang-task-json-v1">>, <<"alang-task-json-v1">>, <<"external-control">>, false, <<"2.1">>)
        ],
        <<"unknown_surface">> => <<"reject">>,
        <<"unknown_version">> => <<"reject">>,
        <<"unregistered_flags">> => <<"reject">>
    }.

surface(Id, Representation, Version, Role, Promotable, Section) ->
    #{<<"id">> => Id, <<"representation">> => Representation, <<"version">> => Version,
        <<"role">> => Role, <<"promotable">> => Promotable, <<"implementation_section">> => Section}.

hex(Binary) ->
    << <<(hex_digit(Byte bsr 4)), (hex_digit(Byte band 16#0f))>> || <<Byte>> <= Binary >>.
hex_digit(Value) when Value < 10 -> $0 + Value;
hex_digit(Value) -> $a + Value - 10.
