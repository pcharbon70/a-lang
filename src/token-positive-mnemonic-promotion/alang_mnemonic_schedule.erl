-module(alang_mnemonic_schedule).

-export([materialize/1, schedule_digest/1, validate/3]).

-define(MODELS, [<<"mixtral">>, <<"ornith">>]).
-define(PROTOCOLS, [<<"action-completion">>, <<"comprehension">>,
    <<"diagnostic-repair">>, <<"generation">>]).
-define(CONDITIONS, [<<"P0">>, <<"P1">>]).

-spec materialize(file:filename()) -> {ok, map()} | {error, term()}.
materialize(Base) ->
    try
        {ok, Design} = alang_fidelity_json:decode_file(filename:join(Base, "case-design-v1.json")),
        {ok, Policy} = alang_fidelity_json:decode_file(filename:join(Base, "schedule-policy-v1.json")),
        Cases = validate_design(Design),
        ok = validate_policy(Policy),
        Ordered = spread(order(cells(Cases, Policy), maps:get(<<"seed">>, Policy)), undefined, []),
        Cells = indexed_cells(Ordered, maps:get(<<"seed">>, Policy)),
        Schedule = #{
            <<"format">> => <<"alang-token-positive-schedule-v1">>,
            <<"seed">> => maps:get(<<"seed">>, Policy),
            <<"schedule_digest">> => schedule_digest(Cells),
            <<"cells">> => Cells
        },
        ok = checked(validate(Schedule, Policy, Cases)),
        {ok, Schedule}
    catch
        error:{badmatch, Reason} -> {error, {mnemonic_schedule_error, {materialization_failed, Reason}}};
        throw:{mnemonic_schedule_error, Reason} -> {error, {mnemonic_schedule_error, Reason}}
    end.

-spec schedule_digest([map()]) -> binary().
schedule_digest(Cells) -> alang_fidelity_json:digest(Cells).

-spec validate(term(), map(), [map()]) -> ok | {error, term()}.
validate(Schedule, Policy, Cases) ->
    try
        ok = validate_policy(Policy),
        closed(Schedule, [<<"format">>, <<"seed">>, <<"schedule_digest">>, <<"cells">>], schedule),
        exact(maps:get(<<"format">>, Schedule), <<"alang-token-positive-schedule-v1">>, schedule_format),
        exact(maps:get(<<"seed">>, Schedule), maps:get(<<"seed">>, Policy), schedule_seed),
        Cells = maps:get(<<"cells">>, Schedule),
        exact(length(Cells), 1536, primary_cells),
        exact([maps:get(<<"index">>, C) || C <- Cells], lists:seq(0, 1535), indices),
        unique([maps:get(<<"trial_id">>, C) || C <- Cells], trial_ids),
        unique([identity(C) || C <- Cells], cell_identities),
        exact(maps:get(<<"schedule_digest">>, Schedule), schedule_digest(Cells), digest),
        exact(length(Cases), 48, selected_cases),
        validate_counts(Cells),
        validate_counterbalance(Cells, Cases),
        validate_adjacency(Cells),
        ok
    catch throw:{mnemonic_schedule_error, Reason} -> {error, {mnemonic_schedule_error, Reason}} end.

validate_design(Design) ->
    closed(Design, [<<"format">>, <<"boundary">>, <<"cases">>], design),
    exact(maps:get(<<"format">>, Design), <<"alang-token-positive-case-design-v1">>, design_format),
    exact(maps:get(<<"boundary">>, Design), <<"prospective-confirmatory-held-out">>, boundary),
    Cases = maps:get(<<"cases">>, Design),
    exact(length(Cases), 48, case_count),
    Families = families(), Strata = strata(),
    lists:foreach(fun(Case) ->
        closed(Case, [<<"id">>, <<"runtime_family">>, <<"stratum">>, <<"replicate">>], case_entry),
        ensure(lists:member(maps:get(<<"runtime_family">>, Case), Families), invalid_family),
        ensure(lists:member(maps:get(<<"stratum">>, Case), Strata), invalid_stratum),
        ensure(lists:member(maps:get(<<"replicate">>, Case), [<<"a">>, <<"b">>]), invalid_replicate)
    end, Cases),
    unique([maps:get(<<"id">>, C) || C <- Cases], case_ids),
    Expected = lists:sort([{F, S, R} || F <- Families, S <- Strata, R <- [<<"a">>, <<"b">>]]),
    Actual = lists:sort([{maps:get(<<"runtime_family">>, C), maps:get(<<"stratum">>, C),
        maps:get(<<"replicate">>, C)} || C <- Cases]),
    exact(Actual, Expected, balance),
    Cases.

validate_policy(Policy) ->
    Keys = [<<"format">>, <<"seed">>, <<"selected_cases">>, <<"model_families">>,
        <<"repetitions">>, <<"protocol_conditions">>, <<"counterbalance_by">>,
        <<"primary_cells">>, <<"max_replacements_per_cell">>, <<"hard_request_ceiling">>,
        <<"definitive_response_retriable">>, <<"opaque_trial_id_bytes">>],
    closed(Policy, Keys, policy),
    exact(maps:get(<<"format">>, Policy), <<"alang-token-positive-schedule-policy-v1">>, policy_format),
    exact(maps:get(<<"seed">>, Policy), 2026082504, seed),
    exact(maps:get(<<"selected_cases">>, Policy), 48, selected_cases),
    exact(maps:get(<<"model_families">>, Policy), ?MODELS, models),
    exact(maps:get(<<"repetitions">>, Policy), 2, repetitions),
    ProtocolConditions = maps:get(<<"protocol_conditions">>, Policy),
    closed(ProtocolConditions, ?PROTOCOLS, protocol_conditions),
    lists:foreach(fun(P) -> exact(maps:get(P, ProtocolConditions), ?CONDITIONS, {conditions, P}) end, ?PROTOCOLS),
    exact(maps:get(<<"counterbalance_by">>, Policy),
        [<<"model-family">>, <<"protocol">>, <<"runtime-family">>, <<"stratum">>, <<"repetition">>], counterbalance),
    exact(maps:get(<<"primary_cells">>, Policy), 1536, primary_cells),
    exact(maps:get(<<"max_replacements_per_cell">>, Policy), 1, replacements),
    exact(maps:get(<<"hard_request_ceiling">>, Policy), 3072, ceiling),
    exact(maps:get(<<"definitive_response_retriable">>, Policy), false, retriable),
    exact(maps:get(<<"opaque_trial_id_bytes">>, Policy), 12, trial_id_bytes),
    ok.

cells(Cases, Policy) -> [#{
    <<"case_id">> => maps:get(<<"id">>, Case),
    <<"runtime_family">> => maps:get(<<"runtime_family">>, Case),
    <<"stratum">> => maps:get(<<"stratum">>, Case),
    <<"model_family">> => Model, <<"protocol">> => Protocol,
    <<"condition">> => Condition, <<"repetition">> => Repetition
} || Model <- ?MODELS, Repetition <- lists:seq(1, maps:get(<<"repetitions">>, Policy)),
     Protocol <- ?PROTOCOLS, Condition <- ?CONDITIONS, Case <- Cases].

order(Cells, Seed) ->
    Keyed = [{crypto:hash(sha256, term_to_binary({Seed, C}, [deterministic])), C} || C <- Cells],
    [C || {_K, C} <- lists:sort(Keyed)].

spread([], _Previous, Acc) -> lists:reverse(Acc);
spread(Cells, Previous, Acc) ->
    case take_different(Cells, Previous, []) of
        {Cell, Rest} -> spread(Rest, maps:get(<<"case_id">>, Cell), [Cell | Acc]);
        none -> fail(unable_to_separate_semantic_cases)
    end.

take_different([], _Previous, _Prefix) -> none;
take_different([Cell | Rest], Previous, Prefix) ->
    case maps:get(<<"case_id">>, Cell) =/= Previous of
        true -> {Cell, lists:reverse(Prefix) ++ Rest};
        false -> take_different(Rest, Previous, [Cell | Prefix])
    end.

indexed_cells(Cells, Seed) -> [C#{<<"index">> => I, <<"trial_id">> => trial_id(Seed, C)}
    || {C, I} <- lists:zip(Cells, lists:seq(0, length(Cells) - 1))].
trial_id(Seed, Cell) ->
    Hex = alang_fidelity_json:hex(crypto:hash(sha256,
        term_to_binary({token_positive_trial, Seed, Cell}, [deterministic]))),
    binary:part(Hex, 0, 24).

validate_counts(Cells) ->
    lists:foreach(fun(M) -> exact(count(<<"model_family">>, M, Cells), 768, {model, M}) end, ?MODELS),
    lists:foreach(fun(P) -> exact(count(<<"protocol">>, P, Cells), 384, {protocol, P}) end, ?PROTOCOLS),
    lists:foreach(fun(C) -> exact(count(<<"condition">>, C, Cells), 768, {condition, C}) end, ?CONDITIONS).

validate_counterbalance(Cells, _Cases) ->
    Keys = [{M, P, F, S, R} || M <- ?MODELS, P <- ?PROTOCOLS,
        F <- families(), S <- strata(), R <- [1, 2]],
    lists:foreach(fun({M, P, F, S, R}) ->
        Group = [C || C <- Cells, maps:get(<<"model_family">>, C) =:= M,
            maps:get(<<"protocol">>, C) =:= P, maps:get(<<"runtime_family">>, C) =:= F,
            maps:get(<<"stratum">>, C) =:= S, maps:get(<<"repetition">>, C) =:= R],
        exact(count(<<"condition">>, <<"P0">>, Group), 2, {counterbalance, M, P, F, S, R, p0}),
        exact(count(<<"condition">>, <<"P1">>, Group), 2, {counterbalance, M, P, F, S, R, p1})
    end, Keys).

validate_adjacency([A, B | Rest]) ->
    ensure(maps:get(<<"case_id">>, A) =/= maps:get(<<"case_id">>, B), adjacent_case),
    validate_adjacency([B | Rest]);
validate_adjacency(_) -> ok.

identity(C) -> maps:with([<<"case_id">>, <<"model_family">>, <<"protocol">>,
    <<"condition">>, <<"repetition">>], C).
count(Key, Value, Cells) -> length([C || C <- Cells, maps:get(Key, C) =:= Value]).
families() -> [<<"single-model-artifact">>, <<"repair-and-publish">>, <<"attenuated-delegation">>].
strata() -> [<<"simple">>, <<"constraint-heavy">>, <<"scope-budget">>, <<"error-branch">>,
    <<"missing-information">>, <<"irrelevant-context">>, <<"prompt-injection">>,
    <<"lexical-value-perturbation">>].
closed(Value, Keys, Reason) ->
    ensure(is_map(Value), {Reason, expected_object}), Actual = maps:keys(Value),
    ensure(Actual -- Keys =:= [], {Reason, unknown_fields, lists:sort(Actual -- Keys)}),
    ensure(Keys -- Actual =:= [], {Reason, missing_fields, lists:sort(Keys -- Actual)}).
unique(Values, Reason) -> ensure(length(Values) =:= length(lists:usort(Values)), {duplicate, Reason}).
exact(Value, Expected, Reason) -> ensure(Value =:= Expected, {expected, Reason, Expected, Value}).
checked(ok) -> ok;
checked({error, Reason}) -> fail(Reason).
ensure(true, _Reason) -> ok;
ensure(false, Reason) -> fail(Reason).
fail(Reason) -> throw({mnemonic_schedule_error, Reason}).
