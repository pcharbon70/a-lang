-module(alang_mnemonic_protocol).

-export([load/2, materialize/5, oracle_response/3, score/5, validate/2]).

-define(CONTRACT, "assets/token-positive-mnemonic-promotion/phase-02/contracts/protocol-contract-v1.json").
-define(PROTOCOLS, [<<"action-completion">>, <<"comprehension">>,
    <<"diagnostic-repair">>, <<"generation">>]).

-spec load(file:filename(), file:filename()) -> {ok, map()} | {error, term()}.
load(Path, RepoRoot) ->
    case alang_fidelity_json:decode_file(Path) of
        {ok, Contract} -> validate(Contract, RepoRoot);
        {error, Reason} -> {error, {mnemonic_protocol_error, contract_read, Reason}}
    end.

-spec validate(term(), file:filename()) -> {ok, map()} | {error, term()}.
validate(Contract, RepoRoot) ->
    try
        Keys = [<<"conditions">>, <<"format">>, <<"judge">>,
            <<"model_visible_excluded">>, <<"mutation_fields">>,
            <<"prompt_policy_path">>, <<"prompt_policy_sha256">>,
            <<"protocols">>, <<"request_order">>],
        exact(maps:keys(Contract), Keys, fields),
        exact(maps:get(<<"format">>, Contract),
            <<"alang-token-positive-protocol-contract-v1">>, format),
        exact(maps:get(<<"conditions">>, Contract), [<<"P0">>, <<"P1">>], conditions),
        Protocols = maps:get(<<"protocols">>, Contract),
        exact([maps:get(<<"id">>, P) || P <- Protocols], ?PROTOCOLS, protocols),
        exact(maps:get(<<"request_order">>, Contract), [<<"opaque-trial-id">>,
            <<"common-instruction">>, <<"protocol-instruction">>,
            <<"condition-legend">>, <<"case-material">>, <<"output-contract">>], request_order),
        exact(maps:get(<<"judge">>, Contract), <<"deterministic-beam-only">>, judge),
        exact(length(maps:get(<<"mutation_fields">>, Contract)), 17, mutation_fields),
        PromptPath = filename:join(RepoRoot,
            binary_to_list(maps:get(<<"prompt_policy_path">>, Contract))),
        verify_sha(PromptPath, maps:get(<<"prompt_policy_sha256">>, Contract)),
        {ok, PromptPolicy} = checked(alang_fidelity_json:decode_file(PromptPath)),
        {ok, _} = checked(alang_mnemonic_registration:validate_prompts(PromptPolicy)),
        {ok, Contract}
    catch
        error:{badkey, Key} -> {error, {mnemonic_protocol_error, {missing_field, Key}}};
        throw:{mnemonic_protocol_error, Reason} -> {error, {mnemonic_protocol_error, Reason}}
    end.

-spec materialize(map(), map(), binary(), binary(), file:filename()) ->
    {ok, map()} | {error, term()}.
materialize(Case, Oracle, Condition, Protocol, RepoRoot) ->
    try
        ensure(lists:member(Condition, [<<"P0">>, <<"P1">>]), {unknown_condition, Condition}),
        ensure(lists:member(Protocol, ?PROTOCOLS), {unknown_protocol, Protocol}),
        {ok, _} = checked(load(filename:join(RepoRoot, ?CONTRACT), RepoRoot)),
        {ok, Surface} = checked(alang_mnemonic_candidate:render(Condition, Oracle, RepoRoot)),
        PromptPolicy = decode(filename:join(RepoRoot,
            "assets/token-positive-mnemonic-promotion/campaign/prompt-policy-v1.json")),
        ProtocolEntry = one(<<"id">>, Protocol, maps:get(<<"protocols">>, PromptPolicy)),
        Legend = one(<<"condition">>, Condition, maps:get(<<"legends">>, PromptPolicy)),
        TrialId = trial_id(maps:get(<<"id">>, Case), Protocol, Condition),
        Sections = #{
            <<"opaque_trial_id">> => <<"trial ", TrialId/binary>>,
            <<"common_instruction">> => maps:get(<<"common_instruction">>, PromptPolicy),
            <<"protocol_instruction">> => maps:get(<<"instruction">>, ProtocolEntry),
            <<"condition_legend">> => maps:get(<<"content">>, Legend),
            <<"case_material">> => case_material(Protocol, Case, Surface),
            <<"output_contract">> => maps:get(<<"output_contract">>, ProtocolEntry)
        },
        Bytes = ordered_bytes(Sections),
        ensure(no_hidden_markers(Bytes), model_visible_leak),
        {ok, #{
            <<"format">> => <<"alang-token-positive-prompt-v1">>,
            <<"trial_id">> => TrialId, <<"protocol">> => Protocol,
            <<"condition">> => Condition, <<"sections">> => Sections,
            <<"bytes">> => Bytes,
            <<"sha256">> => hex(crypto:hash(sha256, Bytes)),
            <<"oracle">> => oracle_record(Protocol, Oracle)
        }}
    catch
        error:{badkey, Key} -> {error, {mnemonic_protocol_error, {missing_field, Key}}};
        throw:{mnemonic_protocol_error, Reason} -> {error, {mnemonic_protocol_error, Reason}}
    end.

case_material(<<"comprehension">>, _Case, Surface) -> maps:get(bytes, Surface);
case_material(<<"action-completion">>, Case, Surface) ->
    iolist_to_binary([maps:get(bytes, Surface), <<"\nNeutral request: ">>,
        maps:get(<<"request">>, Case), context(Case)]);
case_material(<<"diagnostic-repair">>, _Case, Surface) ->
    Bytes = maps:get(bytes, Surface),
    Mutant = case maps:get(condition, Surface) of
        <<"P0">> -> binary:replace(Bytes, <<"#!alang-source-v2">>, <<"#!alang-source-v3">>);
        <<"P1">> -> binary:replace(Bytes, <<"#!alang-source-v2-alias-v1">>,
            <<"#!alang-source-v2-alias-v2">>)
    end,
    <<Mutant/binary, "\nReadable-source diagnostic: unregistered representation version; edit canonical readable source and regenerate the model view.">>;
case_material(<<"generation">>, Case, _Surface) ->
    iolist_to_binary([<<"Natural-language requirements: ">>,
        maps:get(<<"request">>, Case), context(Case)]).

context(Case) ->
    case maps:get(<<"untrusted_context">>, Case) of
        [] -> <<>>;
        Values -> iolist_to_binary([<<"\nQuoted untrusted context:\n">>,
            join(Values, <<"\n">>)])
    end.

ordered_bytes(S) -> iolist_to_binary([
    maps:get(<<"opaque_trial_id">>, S), <<"\n">>,
    maps:get(<<"common_instruction">>, S), <<"\n">>,
    maps:get(<<"protocol_instruction">>, S), <<"\n">>,
    maps:get(<<"condition_legend">>, S), <<"\n">>,
    maps:get(<<"case_material">>, S), <<"\n">>,
    maps:get(<<"output_contract">>, S)
]).

oracle_record(<<"action-completion">>, Oracle) -> action_record(Oracle);
oracle_record(_Protocol, Oracle) -> #{
    <<"semantic_digest">> => alang_fidelity_contract:semantic_digest(Oracle),
    <<"case_id">> => maps:get(<<"case_id">>, Oracle)}.

action_record(Oracle) ->
    Clarifications = maps:get(<<"clarification_needs">>, Oracle),
    Actions = maps:get(<<"actions">>, Oracle),
    Next = case {Clarifications, [A || A <- Actions,
            maps:get(<<"depends_on">>, A) =:= []]} of
        {[Need | _], _} -> #{<<"kind">> => <<"clarify">>, <<"value">> => Need};
        {[], [Action | _]} -> #{<<"kind">> => <<"action">>,
            <<"value">> => maps:get(<<"id">>, Action)};
        {[], []} -> #{<<"kind">> => <<"blocked">>, <<"value">> => null}
    end,
    #{<<"format">> => <<"alang-action-completion-response-v1">>,
        <<"next">> => Next,
        <<"terminal_class">> => maps:get(<<"terminal_class">>, Oracle),
        <<"completion_predicates">> => maps:get(<<"completion_predicates">>, Oracle)}.

-spec oracle_response(binary(), binary(), map()) -> binary().
oracle_response(<<"comprehension">>, _Condition, Oracle) ->
    {ok, Bytes} = alang_fidelity_json:encode_canonical(Oracle), Bytes;
oracle_response(<<"action-completion">>, _Condition, Oracle) ->
    {ok, Bytes} = alang_fidelity_json:encode_canonical(action_record(Oracle)), Bytes;
oracle_response(Protocol, Condition, Oracle)
  when Protocol =:= <<"generation">>; Protocol =:= <<"diagnostic-repair">> ->
    {ok, Surface} = alang_mnemonic_candidate:render(Condition, Oracle, "."),
    maps:get(bytes, Surface).

-spec score(binary(), binary(), binary(), map(), file:filename()) -> {ok, map()}.
score(Protocol, Condition, Response, Oracle, RepoRoot) ->
    ExpectedDigest = alang_fidelity_contract:semantic_digest(Oracle),
    {Valid, Exact} = case Protocol of
        <<"comprehension">> -> score_comprehension(Response, ExpectedDigest);
        <<"generation">> -> score_surface(Condition, Response, ExpectedDigest, RepoRoot);
        <<"diagnostic-repair">> -> score_surface(Condition, Response, ExpectedDigest, RepoRoot);
        <<"action-completion">> -> score_action(Response, action_record(Oracle));
        _ -> {false, false}
    end,
    {ok, #{<<"format">> => <<"alang-token-positive-protocol-score-v1">>,
        <<"protocol">> => Protocol, <<"condition">> => Condition,
        <<"valid">> => Valid, <<"exact">> => Exact,
        <<"judge">> => <<"deterministic-beam-only">>}}.

score_comprehension(Response, Digest) ->
    case alang_fidelity_contract:decode_comprehension(Response) of
        {ok, Value} -> {true, alang_fidelity_contract:semantic_digest(Value) =:= Digest};
        {error, _} -> {false, false}
    end.
score_surface(Condition, Response, Digest, RepoRoot) ->
    case alang_mnemonic_candidate:decode(Condition, Response, RepoRoot) of
        {ok, Value} -> {true, maps:get(semantic_digest, Value) =:= Digest};
        {error, _} -> {false, false}
    end.
score_action(Response, Expected) ->
    case alang_fidelity_json:decode(Response) of
        {ok, Value} when is_map(Value) -> {true, Value =:= Expected};
        _ -> {false, false}
    end.

trial_id(CaseId, Protocol, Condition) ->
    Digest = hex(crypto:hash(sha256,
        term_to_binary({2026082504, CaseId, Protocol, Condition}, [deterministic]))),
    binary:part(Digest, 0, 24).

no_hidden_markers(Bytes) -> lists:all(fun(Marker) ->
    binary:match(Bytes, Marker) =:= nomatch
end, [<<"answer-key">>, <<"semantic-digest">>, <<"condition-role">>,
    <<"hidden-example">>, <<"cross-trial-state">>, <<" P0 ">>, <<" P1 ">>]).

one(Key, Value, Entries) -> [Entry] = [E || E <- Entries, maps:get(Key, E) =:= Value], Entry.
decode(Path) -> {ok, Value} = checked(alang_fidelity_json:decode_file(Path)), Value.
verify_sha(Path, Expected) ->
    {ok, Bytes} = case file:read_file(Path) of
        {ok, Value} -> {ok, Value};
        {error, Reason} -> fail({read_failed, Path, Reason})
    end,
    exact(hex(crypto:hash(sha256, Bytes)), Expected, {digest, Path}).
checked({ok, _} = Result) -> Result;
checked({error, Reason}) -> fail(Reason).
exact(Value, Expected, _Reason) when Value =:= Expected -> ok;
exact(Value, Expected, Reason) -> fail({expected, Reason, Expected, Value}).
ensure(true, _Reason) -> ok;
ensure(false, Reason) -> fail(Reason).
fail(Reason) -> throw({mnemonic_protocol_error, Reason}).
join([], _Sep) -> [];
join([Only], _Sep) -> Only;
join([First | Rest], Sep) -> [First, Sep, join(Rest, Sep)].
hex(Binary) -> alang_fidelity_json:hex(Binary).
