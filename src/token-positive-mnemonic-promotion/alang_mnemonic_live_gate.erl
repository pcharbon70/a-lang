-module(alang_mnemonic_live_gate).

-export([authorize/4, decode_inventory/1, validate_inventory/2,
    validate_submission/6]).

-define(PROFILES, "assets/token-positive-mnemonic-promotion/campaign/provider-profiles-v1.json").
-define(POLICY, "assets/token-positive-mnemonic-promotion/campaign/campaign-policy-v1.json").

-spec decode_inventory(binary()) -> {ok, [map()]} | {error, term()}.
decode_inventory(Bytes) ->
    try
        {ok, Value} = checked(alang_fidelity_json:decode(Bytes)),
        Models = maps:get(<<"models">>, Value),
        ensure(is_list(Models), invalid_model_inventory),
        {ok, [inventory_entry(Model) || Model <- Models]}
    catch
        error:{badkey, Key} -> {error, {mnemonic_live_gate_error, {missing_field, Key}}};
        throw:{mnemonic_live_gate_error, Reason} -> {error, {mnemonic_live_gate_error, Reason}}
    end.

-spec authorize(map(), file:filename(), map(), [map()]) ->
    {ok, map()} | {error, term()}.
authorize(Evidence, Root, Environment, Inventory) ->
    try
        {ok, BaseToken} = checked(alang_mnemonic_authorization:authorize(
            Evidence, Root, Environment)),
        Profiles = decode(filename:join(Root, ?PROFILES)),
        Policy = decode(filename:join(Root, ?POLICY)),
        {ok, _} = checked(alang_mnemonic_registration:validate_profiles(Profiles)),
        {ok, _} = checked(alang_mnemonic_registration:validate_policy(Policy)),
        FullProfiles = [profile_identity(P) || P <- maps:get(<<"profiles">>, Profiles)],
        {ok, _} = checked(validate_inventory(Profiles, Inventory)),
        Body = #{
            <<"format">> => <<"alang-token-positive-phase-3-live-token-v1">>,
            <<"qualification_digest">> => maps:get(<<"qualification_digest">>, BaseToken),
            <<"profile_digest">> => alang_fidelity_json:digest(FullProfiles),
            <<"endpoint">> => maps:get(<<"endpoint">>, maps:get(<<"live_opt_in">>, Policy)),
            <<"request_ceilings">> => maps:get(<<"per_request_ceilings">>, Policy),
            <<"campaign_ceilings">> => maps:get(<<"campaign_ceilings">>, Policy),
            <<"profiles">> => FullProfiles,
            <<"authorized">> => true,
            <<"scope">> => <<"phase-3-exact-profile-submissions-only">>
        },
        {ok, Body#{<<"token_digest">> => alang_fidelity_json:digest(Body)}}
    catch
        error:{badkey, Key} -> {error, {mnemonic_live_gate_error, {missing_field, Key}}};
        throw:{mnemonic_live_gate_error, Reason} -> {error, {mnemonic_live_gate_error, Reason}}
    end.

-spec validate_inventory(map(), [map()]) -> {ok, [map()]} | {error, term()}.
validate_inventory(Profiles, Inventory) ->
    try
        FullProfiles = [profile_identity(P) || P <- maps:get(<<"profiles">>, Profiles)],
        Required = [maps:with([<<"model_id">>, <<"manifest_sha256">>], P)
            || P <- FullProfiles],
        Actual = [closed_inventory(I) || I <- Inventory],
        Ids = [maps:get(<<"model_id">>, I) || I <- Actual],
        ensure(length(Ids) =:= length(lists:usort(Ids)), duplicate_model_id),
        lists:foreach(fun(Expected) ->
            Id = maps:get(<<"model_id">>, Expected),
            case [I || I <- Actual, maps:get(<<"model_id">>, I) =:= Id] of
                [Observed] -> exact(Observed, Expected, {model_manifest, Id});
                [] -> fail({missing_model, Id})
            end
        end, Required),
        {ok, Required}
    catch
        error:{badkey, Key} -> {error, {mnemonic_live_gate_error, {missing_field, Key}}};
        throw:{mnemonic_live_gate_error, Reason} -> {error, {mnemonic_live_gate_error, Reason}}
    end.

-spec validate_submission(map(), map(), file:filename(), map(), [map()], binary()) ->
    {ok, map()} | {error, term()}.
validate_submission(Cell, Evidence, Root, Environment, Inventory, Prompt) ->
    try
        {ok, Token} = checked(authorize(Evidence, Root, Environment, Inventory)),
        ensure(is_binary(Prompt) andalso byte_size(Prompt) > 0, empty_prompt),
        Ceilings = maps:get(<<"request_ceilings">>, Token),
        ensure(byte_size(Prompt) =< maps:get(<<"accepted_input_bytes">>, Ceilings),
            input_byte_ceiling),
        Family = maps:get(<<"model_family">>, Cell),
        Profile = one(<<"family">>, Family, maps:get(<<"profiles">>, Token)),
        Request = #{
            <<"format">> => <<"alang-token-positive-provider-request-v1">>,
            <<"trial_id">> => maps:get(<<"trial_id">>, Cell),
            <<"cell_index">> => maps:get(<<"index">>, Cell),
            <<"model_family">> => Family,
            <<"model_id">> => maps:get(<<"model_id">>, Profile),
            <<"manifest_sha256">> => maps:get(<<"manifest_sha256">>, Profile),
            <<"parameters">> => maps:get(<<"request_parameters">>, Profile),
            <<"seed">> => seed(maps:get(<<"trial_id">>, Cell)),
            <<"prompt">> => Prompt,
            <<"prompt_sha256">> => hex(crypto:hash(sha256, Prompt)),
            <<"authorization_digest">> => maps:get(<<"token_digest">>, Token)
        },
        {ok, Request}
    catch
        error:{badkey, Key} -> {error, {mnemonic_live_gate_error, {missing_field, Key}}};
        throw:{mnemonic_live_gate_error, Reason} -> {error, {mnemonic_live_gate_error, Reason}}
    end.

inventory_entry(Model) when is_map(Model) ->
    Name = maps:get(<<"name">>, Model, maps:get(<<"model">>, Model, undefined)),
    Digest0 = maps:get(<<"digest">>, Model, undefined),
    ensure(is_binary(Name) andalso is_binary(Digest0), invalid_model_inventory_entry),
    Digest = case Digest0 of
        <<"sha256:", Rest/binary>> -> Rest;
        _ -> Digest0
    end,
    #{<<"model_id">> => Name, <<"manifest_sha256">> => Digest};
inventory_entry(_) -> fail(invalid_model_inventory_entry).

closed_inventory(I) ->
    exact(lists:sort(maps:keys(I)), [<<"manifest_sha256">>, <<"model_id">>],
        inventory_fields),
    Id = maps:get(<<"model_id">>, I), Digest = maps:get(<<"manifest_sha256">>, I),
    ensure(is_binary(Id) andalso byte_size(Id) > 0, invalid_model_id),
    ensure(valid_digest(Digest), invalid_manifest_digest), I.

profile_identity(P) ->
    #{<<"family">> => maps:get(<<"family">>, P),
      <<"model_id">> => maps:get(<<"model_id">>, P),
      <<"manifest_sha256">> => maps:get(<<"manifest_sha256">>, P),
      <<"request_parameters">> => maps:get(<<"request_parameters">>, P),
      <<"accepted_output_bytes">> => maps:get(<<"accepted_output_bytes">>, P)}.

seed(TrialId) ->
    <<First:8/binary, _/binary>> = TrialId,
    binary_to_integer(First, 16) band 16#7fffffff.

one(Key, Value, Entries) ->
    case [E || E <- Entries, maps:get(Key, E) =:= Value] of
        [Entry] -> Entry;
        _ -> fail({unknown_model_family, Value})
    end.

decode(Path) -> {ok, Value} = checked(alang_fidelity_json:decode_file(Path)), Value.
checked({ok, _} = Result) -> Result;
checked({error, Reason}) -> fail(Reason).
valid_digest(Value) when is_binary(Value), byte_size(Value) =:= 64 ->
    re:run(Value, <<"^[0-9a-f]{64}$">>, [{capture, none}]) =:= match;
valid_digest(_) -> false.
exact(Value, Expected, _Reason) when Value =:= Expected -> ok;
exact(Value, Expected, Reason) -> fail({expected, Reason, Expected, Value}).
ensure(true, _Reason) -> ok;
ensure(false, Reason) -> fail(Reason).
fail(Reason) -> throw({mnemonic_live_gate_error, Reason}).
hex(Bytes) -> alang_fidelity_json:hex(Bytes).
