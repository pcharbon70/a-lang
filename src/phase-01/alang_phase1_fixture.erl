-module(alang_phase1_fixture).

-export([forms/1, load/1, validate/1]).

-type error_reason() :: term().
-type fixture() :: map().
-type forms() :: [erl_parse:abstract_form()].

-spec load(file:filename()) -> {ok, fixture()} | {error, error_reason()}.
load(Path) ->
    case file:consult(Path) of
        {ok, [Fixture]} when is_map(Fixture) ->
            case validate(Fixture) of
                ok -> {ok, Fixture};
                {error, _} = Error -> Error
            end;
        {ok, Terms} ->
            {error, {invalid_semantic_fixture, {expected_one_map, Terms}}};
        {error, Reason} ->
            {error, {semantic_fixture_read_failed, Reason}}
    end.

-spec validate(term()) -> ok | {error, error_reason()}.
validate(Fixture) when is_map(Fixture) ->
    Expected = expected_fixture(),
    case Fixture =:= Expected of
        true -> ok;
        false -> {error, {invalid_semantic_fixture, changed_paths(Expected, Fixture)}}
    end;
validate(Other) ->
    {error, {invalid_semantic_fixture, {expected_map, Other}}}.

-spec forms(fixture()) -> {ok, forms()} | {error, error_reason()}.
forms(Fixture) ->
    case validate(Fixture) of
        ok -> {ok, generated_forms()};
        {error, _} = Error -> Error
    end.

expected_fixture() ->
    #{
        fixture_format => alang_semantic_fixture_v1,
        language => alang,
        semantic_version => <<"phase1-ir-v1">>,
        module => phase1_counter_v1,
        entrypoint => {start, 1},
        runtime_abi => alang_v1,
        types => #{
            input => {integer_range, 0, 1000000},
            state => {closed_sum, [waiting, completed]},
            result => {
                closed_sum,
                [
                    {ok, successor_integer},
                    {
                        error,
                        [
                            malformed_envelope,
                            unsupported_abi,
                            invalid_correlation,
                            invalid_reply_target,
                            invalid_payload,
                            payload_too_large,
                            unavailable_operation,
                            unexpected_process_exit
                        ]
                    }
                ]
            }
        },
        transition => #{
            from => waiting,
            input_binding => value,
            to => completed,
            result => {integer_add, value, 1}
        },
        runtime_operations => [
            initialize,
            receive_envelope,
            emit_trace,
            reply_result,
            terminate
        ],
        limits => #{correlation_bytes => {1, 64}, envelope_bytes => 1024}
    }.

changed_paths(Expected, Actual) ->
    lists:sort(changed_paths([], Expected, Actual)).

changed_paths(Path, Expected, Actual) when is_map(Expected), is_map(Actual) ->
    Keys = lists:usort(maps:keys(Expected) ++ maps:keys(Actual)),
    lists:append([
        case {maps:find(Key, Expected), maps:find(Key, Actual)} of
            {{ok, ExpectedValue}, {ok, ActualValue}} ->
                changed_paths(Path ++ [Key], ExpectedValue, ActualValue);
            {error, {ok, ActualValue}} ->
                [{unexpected, Path ++ [Key], ActualValue}];
            {{ok, ExpectedValue}, error} ->
                [{missing, Path ++ [Key], ExpectedValue}]
        end
     || Key <- Keys
    ]);
changed_paths(_Path, Value, Value) ->
    [];
changed_paths(Path, Expected, Actual) ->
    [{changed, Path, Expected, Actual}].

generated_forms() ->
    [
        {attribute, 1, module, phase1_counter_v1},
        {attribute, 2, export, [{start, 1}]},
        {function, 3, start, 1, [
            {clause, 3, [variable(3, 'Parent')], [valid_parent_guard(3)], [
                {'receive', 4, receive_clauses()}
            ]}
        ]}
    ].

receive_clauses() ->
    [
        success_clause(),
        unavailable_operation_clause(),
        invalid_payload_clause(),
        unsupported_abi_clause(),
        invalid_correlation_clause(),
        invalid_reply_target_clause(),
        malformed_envelope_clause()
    ].

success_clause() ->
    Line = 10,
    Correlation = variable(Line, 'Correlation'),
    Parent = variable(Line, 'Parent'),
    Value = variable(Line, 'Value'),
    Payload = tuple(Line, [atom(Line, input), Value]),
    Envelope = envelope(Line, atom(Line, alang_v1), Correlation, Parent, Payload),
    Guards = valid_correlation_guards(Line, Correlation) ++
        [
            remote_call(Line, is_integer, [Value]),
            operator(Line, '>=', Value, integer(Line, 0)),
            operator(Line, '=<', Value, integer(Line, 1000000))
        ],
    Successor = variable(12, 'Successor'),
    Body = [
        send(11, Parent, tuple(11, [
            atom(11, alang_v1),
            atom(11, trace),
            variable(11, 'Correlation'),
            atom(11, received)
        ])),
        {match, 12, Successor, operator(12, '+', variable(12, 'Value'), integer(12, 1))},
        send(13, Parent, tuple(13, [
            atom(13, alang_v1),
            atom(13, trace),
            variable(13, 'Correlation'),
            tuple(13, [atom(13, transition), atom(13, waiting), atom(13, completed)])
        ])),
        send(14, Parent, tuple(14, [
            atom(14, alang_v1),
            atom(14, result),
            variable(14, 'Correlation'),
            tuple(14, [atom(14, ok), variable(14, 'Successor')])
        ]))
    ],
    SizeCheckedBody = size_case(Line, Envelope, Body, [
        error_reply(Line, Correlation, payload_too_large)
    ]),
    receive_clause(Line, Envelope, Guards, [SizeCheckedBody]).

unavailable_operation_clause() ->
    Line = 30,
    Correlation = variable(Line, 'Correlation'),
    Parent = variable(Line, 'Parent'),
    Payload = tuple(Line, [atom(Line, operation), variable(Line, 'Other')]),
    Envelope = envelope(Line, atom(Line, alang_v1), Correlation, Parent, Payload),
    Guards = valid_correlation_guards(Line, Correlation),
    receive_clause(
        Line,
        Envelope,
        Guards,
        [size_case(
            Line,
            Envelope,
            [error_reply(Line, Correlation, unavailable_operation)],
            [error_reply(Line, Correlation, payload_too_large)]
        )]
    ).

invalid_payload_clause() ->
    Line = 40,
    Correlation = variable(Line, 'Correlation'),
    Parent = variable(Line, 'Parent'),
    Payload = variable(Line, 'Payload'),
    Envelope = envelope(Line, atom(Line, alang_v1), Correlation, Parent, Payload),
    Guards = valid_correlation_guards(Line, Correlation),
    receive_clause(Line, Envelope, Guards, [size_case(
        Line,
        Envelope,
        [error_reply(Line, Correlation, invalid_payload)],
        [error_reply(Line, Correlation, payload_too_large)]
    )]).

unsupported_abi_clause() ->
    Line = 50,
    Abi = variable(Line, 'Abi'),
    Correlation = variable(Line, 'Correlation'),
    Parent = variable(Line, 'Parent'),
    Payload = variable(Line, 'Payload'),
    Envelope = envelope(Line, Abi, Correlation, Parent, Payload),
    Guards = [operator(Line, '=/=', Abi, atom(Line, alang_v1))] ++
        valid_correlation_guards(Line, Correlation),
    receive_clause(Line, Envelope, Guards, [size_case(
        Line,
        Envelope,
        [error_reply(Line, Correlation, unsupported_abi)],
        [error_reply(Line, Correlation, payload_too_large)]
    )]).

invalid_correlation_clause() ->
    Line = 60,
    Pattern = envelope(
        Line,
        atom(Line, alang_v1),
        variable(Line, '_Correlation'),
        variable(Line, 'Parent'),
        variable(Line, '_Payload')
    ),
    receive_clause(Line, Pattern, [], [classified_exit(Line, invalid_correlation)]).

invalid_reply_target_clause() ->
    Line = 70,
    Correlation = variable(Line, 'Correlation'),
    ReplyTo = variable(Line, '_ReplyTo'),
    Pattern = envelope(
        Line,
        atom(Line, alang_v1),
        Correlation,
        ReplyTo,
        variable(Line, '_Payload')
    ),
    Guards = valid_correlation_guards(Line, Correlation) ++ [
        operator(Line, '=/=', ReplyTo, variable(Line, 'Parent'))
    ],
    receive_clause(Line, Pattern, Guards, [classified_exit(Line, invalid_reply_target)]).

malformed_envelope_clause() ->
    Line = 80,
    receive_clause(
        Line,
        variable(Line, '_'),
        [],
        [classified_exit(Line, malformed_envelope)]
    ).

valid_parent_guard(Line) ->
    [
        remote_call(Line, is_pid, [variable(Line, 'Parent')]),
        operator(
            Line,
            '=:=',
            remote_call(Line, node, [variable(Line, 'Parent')]),
            remote_call(Line, node, [])
        )
    ].

valid_correlation_guards(Line, Correlation) ->
    [
        remote_call(Line, is_binary, [Correlation]),
        operator(Line, '>', remote_call(Line, byte_size, [Correlation]), integer(Line, 0)),
        operator(Line, '=<', remote_call(Line, byte_size, [Correlation]), integer(Line, 64))
    ].

size_case(Line, Envelope, WithinLimitBody, OversizedBody) ->
    {'case', Line,
        operator(
            Line,
            '=<',
            remote_call(Line, external_size, [Envelope]),
            integer(Line, 1024)
        ),
        [
            receive_clause(Line, atom(Line, true), [], WithinLimitBody),
            receive_clause(Line, atom(Line, false), [], OversizedBody)
        ]}.

error_reply(Line, Correlation, Failure) ->
    send(Line, variable(Line, 'Parent'), tuple(Line, [
        atom(Line, alang_v1),
        atom(Line, result),
        Correlation,
        tuple(Line, [atom(Line, error), atom(Line, Failure)])
    ])).

classified_exit(Line, Failure) ->
    remote_call(Line, exit, [tuple(Line, [atom(Line, rejected), atom(Line, Failure)])]).

receive_clause(Line, Pattern, Guards, Body) ->
    GuardSequences =
        case Guards of
            [] -> [];
            [_ | _] -> [Guards]
        end,
    {clause, Line, [Pattern], GuardSequences, Body}.

envelope(Line, Abi, Correlation, ReplyTo, Payload) ->
    tuple(Line, [Abi, atom(Line, run), Correlation, ReplyTo, Payload]).

send(Line, Recipient, Message) ->
    operator(Line, '!', Recipient, Message).

remote_call(Line, Name, Arguments) ->
    {call, Line, {remote, Line, atom(Line, erlang), atom(Line, Name)}, Arguments}.

operator(Line, Operator, Left, Right) ->
    {op, Line, Operator, Left, Right}.

tuple(Line, Elements) ->
    {tuple, Line, Elements}.

variable(Line, Name) ->
    {var, Line, Name}.

atom(Line, Value) ->
    {atom, Line, Value}.

integer(Line, Value) ->
    {integer, Line, Value}.
