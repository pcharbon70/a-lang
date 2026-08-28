-module(alang_mnemonic_power).

-export([audit/1, load/1]).

-spec load(file:filename()) -> {ok, map()} | {error, term()}.
load(Path) ->
    case alang_fidelity_json:decode_file(Path) of
        {ok, Design} -> audit(Design);
        {error, _} = Error -> Error
    end.

-spec audit(term()) -> {ok, map()} | {error, term()}.
audit(Design) when is_map(Design) ->
    try
        exact(maps:get(<<"format">>, Design), <<"alang-token-positive-power-design-v1">>, format),
        exact(maps:get(<<"seed">>, Design), 2026082504, seed),
        Old = Design#{<<"format">> := <<"alang-compact-power-design-v1">>},
        case alang_compact_power:audit(Old) of
            {ok, Audit} ->
                Selected = maps:get(<<"selected_cases">>, Audit),
                ensure(Selected >= 48, {selected_below_registered_minimum, Selected}),
                {ok, Audit#{
                    <<"format">> := <<"alang-token-positive-power-audit-v1">>,
                    <<"seed">> => 2026082504,
                    <<"minimum_confirmatory_cases">> => 48,
                    <<"expansion_only_before_observation">> => true
                }};
            {error, _} = Error -> Error
        end
    catch
        error:{badkey, Key} -> {error, {mnemonic_power_error, {missing_field, Key}}};
        throw:{mnemonic_power_error, Reason} -> {error, {mnemonic_power_error, Reason}}
    end;
audit(_) -> {error, {mnemonic_power_error, expected_object}}.

exact(Value, Expected, Field) -> ensure(Value =:= Expected, {expected, Field, Expected, Value}).
ensure(true, _Reason) -> ok;
ensure(false, Reason) -> throw({mnemonic_power_error, Reason}).
