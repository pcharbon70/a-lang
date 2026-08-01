-module(alang_phase1_compiler_tests).

-include_lib("eunit/include/eunit.hrl").

-define(CONFIG, "src/phase-01/toolchain.config").

toolchain_matches_test() ->
    ?assertMatch({ok, #{}}, alang_phase1_compiler:check_toolchain(?CONFIG)).

toolchain_mismatch_test() ->
    {ok, Config} = alang_phase1_compiler:load_toolchain_config(?CONFIG),
    Wrong = Config#{otp_version := <<"29.0.3">>},
    ?assertMatch(
        {error, {toolchain_mismatch, [{otp_version, <<"29.0.3">>, <<"29.0.4">>}]}},
        alang_phase1_compiler:check_toolchain_config(Wrong)
    ).

allowed_subset_compiles_deterministically_test() ->
    Forms = valid_probe_forms(),
    {ok, First} = alang_phase1_compiler:compile_forms(Forms, ?CONFIG),
    {ok, Second} = alang_phase1_compiler:compile_forms(Forms, ?CONFIG),
    FirstBeam = maps:get(beam, First),
    SecondBeam = maps:get(beam, Second),
    ?assertEqual(FirstBeam, SecondBeam),
    Inspection = maps:get(inspection, First),
    ?assertEqual(phase1_counter_v1, maps:get(module, Inspection)),
    ?assertEqual(
        [{module_info, 0}, {module_info, 1}, {start, 1}],
        maps:get(exports, Inspection)
    ),
    ?assertEqual([], maps:get(imports, Inspection) -- alang_phase1_compiler:allowed_beam_imports()).

unsupported_form_rejected_test() ->
    [Module, Export, Function] = valid_probe_forms(),
    Extra = {attribute, 1, behavior, gen_server},
    ?assertMatch(
        {error, {unsupported_module_shape, _}},
        alang_phase1_compiler:validate_allowed_forms([Module, Export, Extra, Function])
    ).

forbidden_import_rejected_test() ->
    [Module, Export, {function, Line, start, 1, [Clause]}] = valid_probe_forms(),
    {clause, ClauseLine, Patterns, Guards, _Body} = Clause,
    ForbiddenCall =
        {call, 4, {remote, 4, {atom, 4, os}, {atom, 4, cmd}}, [{string, 4, "id"}]},
    ForbiddenForms = [
        Module,
        Export,
        {function, Line, start, 1, [
            {clause, ClauseLine, Patterns, Guards, [ForbiddenCall]}
        ]}
    ],
    ?assertMatch(
        {error, {forbidden_remote_call, {os, cmd, 1}}},
        alang_phase1_compiler:validate_allowed_forms(ForbiddenForms)
    ).

valid_probe_forms() ->
    [
        {attribute, 1, module, phase1_counter_v1},
        {attribute, 1, export, [{start, 1}]},
        {function, 2, start, 1, [
            {clause, 2, [{var, 2, 'Parent'}], [], [
                {'receive', 3, [
                    {clause, 3, [
                        {tuple, 3, [
                            {atom, 3, alang_v1},
                            {atom, 3, run},
                            {var, 3, 'Correlation'},
                            {var, 3, 'Parent'},
                            {tuple, 3, [{atom, 3, input}, {var, 3, 'Value'}]}
                        ]}
                    ], [], [
                        {op, 4, '!', {var, 4, 'Parent'},
                            {tuple, 4, [
                                {atom, 4, alang_v1},
                                {atom, 4, result},
                                {var, 4, 'Correlation'},
                                {tuple, 4, [
                                    {atom, 4, ok},
                                    {op, 4, '+', {var, 4, 'Value'}, {integer, 4, 1}}
                                ]}
                            ]}}
                    ]}
                ]}
            ]}
        ]}
    ].
