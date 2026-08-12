-module(alang_compact_schedule).

-export([materialize/1, schedule_digest/1, validate/3]).

-define(MODELS, [<<"mixtral">>, <<"ornith">>]).
-define(PROTOCOLS, [<<"action-completion">>, <<"comprehension">>, <<"diagnostic-repair">>, <<"generation">>]).

-spec materialize(file:filename()) -> {ok, map()} | {error, term()}.
materialize(Base) ->
    try
        {ok, Design} = alang_fidelity_json:decode_file(filename:join(Base, "case-design-v1.json")),
        {ok, Policy} = alang_fidelity_json:decode_file(filename:join(Base, "schedule-policy-v1.json")),
        Cases = validate_design(Design),
        ok = validate_policy(Policy),
        Cells0 = cells(Cases, Policy),
        Ordered = spread(order(Cells0, maps:get(<<"seed">>, Policy)), undefined, []),
        Cells = indexed_cells(Ordered, maps:get(<<"seed">>, Policy)),
        Schedule = #{
            <<"format">> => <<"alang-compact-schedule-v1">>,
            <<"seed">> => maps:get(<<"seed">>, Policy),
            <<"schedule_digest">> => schedule_digest(Cells),
            <<"cells">> => Cells
        },
        ok = validate(Schedule, Policy, Cases),
        {ok, Schedule}
    catch
        error:{badmatch, Reason} -> {error, {schedule_materialization_failed, Reason}};
        throw:{schedule_error, Reason} -> {error, Reason}
    end.

-spec schedule_digest([map()]) -> binary().
schedule_digest(Cells) -> alang_fidelity_json:digest(Cells).

-spec validate(term(), map(), [map()]) -> ok | {error, term()}.
validate(Schedule, Policy, Cases) ->
    try
        Keys = [<<"format">>, <<"seed">>, <<"schedule_digest">>, <<"cells">>],
        closed(Schedule, Keys, schedule),
        exact(maps:get(<<"format">>, Schedule), <<"alang-compact-schedule-v1">>, schedule_format),
        exact(maps:get(<<"seed">>, Schedule), maps:get(<<"seed">>, Policy), schedule_seed),
        Cells = maps:get(<<"cells">>, Schedule),
        exact(length(Cells), maps:get(<<"primary_cells">>, Policy), primary_cell_count),
        exact([maps:get(<<"index">>, C) || C <- Cells], lists:seq(0, length(Cells) - 1), cell_indices),
        unique([maps:get(<<"trial_id">>, C) || C <- Cells], trial_ids),
        unique([cell_identity(C) || C <- Cells], cell_identities),
        exact(maps:get(<<"schedule_digest">>, Schedule), schedule_digest(Cells), schedule_digest),
        exact(length(Cases), maps:get(<<"selected_cases">>, Policy), selected_case_count),
        validate_factor_counts(Cells, Policy, Cases),
        validate_adjacency(Cells),
        ok
    catch throw:{schedule_error, Reason} -> {error, Reason} end.

validate_design(Design) ->
    closed(Design, [<<"format">>, <<"boundary">>, <<"cases">>], case_design),
    exact(maps:get(<<"format">>, Design), <<"alang-compact-case-design-v1">>, case_design_format),
    exact(maps:get(<<"boundary">>, Design), <<"confirmatory-held-out">>, case_boundary),
    Cases = maps:get(<<"cases">>, Design),
    exact(length(Cases), 48, case_count),
    Families = [<<"single-model-artifact">>, <<"repair-and-publish">>, <<"attenuated-delegation">>],
    Strata = [<<"simple">>, <<"constraint-heavy">>, <<"scope-budget">>, <<"error-branch">>,
        <<"missing-information">>, <<"irrelevant-context">>, <<"prompt-injection">>, <<"lexical-value-perturbation">>],
    lists:foreach(fun(Case) ->
        closed(Case, [<<"id">>, <<"runtime_family">>, <<"stratum">>, <<"replicate">>], case_entry),
        ensure(lists:member(maps:get(<<"runtime_family">>, Case), Families), invalid_runtime_family),
        ensure(lists:member(maps:get(<<"stratum">>, Case), Strata), invalid_stratum),
        ensure(lists:member(maps:get(<<"replicate">>, Case), [<<"a">>, <<"b">>]), invalid_replicate)
    end, Cases),
    unique([maps:get(<<"id">>, C) || C <- Cases], case_ids),
    ExpectedCells = lists:sort([{Family, Stratum, Replicate} || Family <- Families, Stratum <- Strata, Replicate <- [<<"a">>, <<"b">>]]),
    ActualCells = lists:sort([{maps:get(<<"runtime_family">>, C), maps:get(<<"stratum">>, C), maps:get(<<"replicate">>, C)} || C <- Cases]),
    exact(ActualCells, ExpectedCells, family_stratum_balance),
    Cases.

validate_policy(Policy) ->
    Keys = [<<"format">>, <<"seed">>, <<"selected_cases">>, <<"model_families">>, <<"repetitions">>,
        <<"protocol_conditions">>, <<"primary_cells">>, <<"max_replacements_per_cell">>,
        <<"hard_request_ceiling">>, <<"definitive_response_retriable">>, <<"opaque_trial_id_bytes">>],
    closed(Policy, Keys, schedule_policy),
    exact(maps:get(<<"format">>, Policy), <<"alang-compact-schedule-policy-v1">>, schedule_policy_format),
    exact(maps:get(<<"seed">>, Policy), 2026081103, schedule_seed),
    exact(maps:get(<<"selected_cases">>, Policy), 48, selected_cases),
    exact(lists:sort(maps:get(<<"model_families">>, Policy)), ?MODELS, model_families),
    exact(maps:get(<<"repetitions">>, Policy), 2, repetitions),
    Conditions = maps:get(<<"protocol_conditions">>, Policy),
    closed(Conditions, ?PROTOCOLS, protocol_conditions),
    exact(maps:get(<<"comprehension">>, Conditions), [<<"R0">>, <<"R1">>, <<"R2">>, <<"R3">>, <<"R4">>, <<"R5">>], comprehension_conditions),
    lists:foreach(fun(Protocol) -> exact(maps:get(Protocol, Conditions), [<<"R0">>, <<"R3">>], {core_conditions, Protocol}) end,
        [<<"action-completion">>, <<"diagnostic-repair">>, <<"generation">>]),
    exact(maps:get(<<"primary_cells">>, Policy), 2304, primary_cells),
    exact(maps:get(<<"max_replacements_per_cell">>, Policy), 1, max_replacements),
    exact(maps:get(<<"hard_request_ceiling">>, Policy), 4608, hard_request_ceiling),
    exact(maps:get(<<"definitive_response_retriable">>, Policy), false, definitive_retry),
    exact(maps:get(<<"opaque_trial_id_bytes">>, Policy), 12, trial_id_bytes),
    ok.

cells(Cases, Policy) ->
    Conditions = maps:get(<<"protocol_conditions">>, Policy),
    [#{
        <<"case_id">> => maps:get(<<"id">>, Case),
        <<"runtime_family">> => maps:get(<<"runtime_family">>, Case),
        <<"stratum">> => maps:get(<<"stratum">>, Case),
        <<"model_family">> => Model,
        <<"protocol">> => Protocol,
        <<"condition">> => Condition,
        <<"repetition">> => Repetition
    } || Model <- ?MODELS,
         Repetition <- lists:seq(1, maps:get(<<"repetitions">>, Policy)),
         Protocol <- ?PROTOCOLS,
         Condition <- maps:get(Protocol, Conditions),
         Case <- Cases].

order(Cells, Seed) ->
    Keyed = [{crypto:hash(sha256, term_to_binary({Seed, Cell}, [deterministic])), Cell} || Cell <- Cells],
    [Cell || {_Key, Cell} <- lists:sort(Keyed)].

spread([], _PreviousCase, Acc) -> lists:reverse(Acc);
spread(Cells, PreviousCase, Acc) ->
    case take_different(Cells, PreviousCase, []) of
        {Cell, Rest} -> spread(Rest, maps:get(<<"case_id">>, Cell), [Cell | Acc]);
        none -> throw({schedule_error, unable_to_separate_semantic_cases})
    end.

take_different([], _PreviousCase, _Prefix) -> none;
take_different([Cell | Rest], PreviousCase, Prefix) ->
    case maps:get(<<"case_id">>, Cell) =/= PreviousCase of
        true -> {Cell, lists:reverse(Prefix) ++ Rest};
        false -> take_different(Rest, PreviousCase, [Cell | Prefix])
    end.

indexed_cells(Cells, Seed) ->
    [Cell#{
        <<"index">> => Index,
        <<"trial_id">> => trial_id(Seed, Cell)
    } || {Cell, Index} <- lists:zip(Cells, lists:seq(0, length(Cells) - 1))].

trial_id(Seed, Cell) ->
    Hex = alang_fidelity_json:hex(crypto:hash(sha256, term_to_binary({compact_trial, Seed, Cell}, [deterministic]))),
    binary:part(Hex, 0, 24).

validate_factor_counts(Cells, Policy, Cases) ->
    CaseCount = length(Cases),
    Repetitions = maps:get(<<"repetitions">>, Policy),
    ModelCount = length(?MODELS),
    lists:foreach(fun(Protocol) ->
        Conditions = maps:get(Protocol, maps:get(<<"protocol_conditions">>, Policy)),
        Expected = CaseCount * Repetitions * ModelCount * length(Conditions),
        exact(length([C || C <- Cells, maps:get(<<"protocol">>, C) =:= Protocol]), Expected, {protocol_count, Protocol})
    end, ?PROTOCOLS),
    lists:foreach(fun(Model) -> exact(length([C || C <- Cells, maps:get(<<"model_family">>, C) =:= Model]), 1152, {model_count, Model}) end, ?MODELS),
    lists:foreach(fun(Condition) ->
        ProtocolCount = case Condition of <<"R0">> -> 4; <<"R3">> -> 4; _ -> 1 end,
        exact(length([C || C <- Cells, maps:get(<<"condition">>, C) =:= Condition]), CaseCount * Repetitions * ModelCount * ProtocolCount, {condition_count, Condition})
    end, [<<"R0">>, <<"R1">>, <<"R2">>, <<"R3">>, <<"R4">>, <<"R5">>]).

validate_adjacency([_]) -> ok;
validate_adjacency([First, Second | Rest]) ->
    ensure(maps:get(<<"case_id">>, First) =/= maps:get(<<"case_id">>, Second), adjacent_semantic_case),
    validate_adjacency([Second | Rest]);
validate_adjacency([]) -> ok.

cell_identity(Cell) -> maps:with([<<"case_id">>, <<"model_family">>, <<"protocol">>, <<"condition">>, <<"repetition">>], Cell).
closed(Value, Keys, Reason) ->
    ensure(is_map(Value), {Reason, expected_object}),
    Actual = maps:keys(Value),
    ensure(Actual -- Keys =:= [], {Reason, unknown_fields, lists:sort(Actual -- Keys)}),
    ensure(Keys -- Actual =:= [], {Reason, missing_fields, lists:sort(Keys -- Actual)}).
unique(Values, Reason) -> ensure(length(Values) =:= length(lists:usort(Values)), {duplicate, Reason}).
exact(Value, Expected, Reason) -> ensure(Value =:= Expected, {expected, Reason, Expected, Value}).
ensure(true, _Reason) -> ok;
ensure(false, Reason) -> throw({schedule_error, Reason}).
