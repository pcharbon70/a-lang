-module(alang_phase2_semantics).

-export([check/1]).

-define(MAX_INTEGER, 9223372036854775807).

-spec check(map()) -> {ok, map()} | {error, [map()]}.
check(#{
    format := alang_source_ast_v1,
    kind := module,
    name := ModuleName,
    version := <<"alang-source-v1">>,
    tasks := Tasks,
    origin := Origin
} = Ast) when is_binary(ModuleName), is_list(Tasks) ->
    case unique_names(Tasks, task) of
        ok ->
            case check_tasks(ModuleName, Tasks, []) of
                {ok, CheckedTasks} ->
                    {ok, #{
                        format => alang_checked_program_v1,
                        module => ModuleName,
                        tasks => CheckedTasks,
                        source => Ast,
                        origin => Origin
                    }};
                {error, _} = Error -> Error
            end;
        {error, _} = Error -> Error
    end;
check(#{version := Version, origin := Origin}) when Version =/= <<"alang-source-v1">> ->
    {error, [diagnostic(unsupported_source_version, Origin, <<"expected alang-source-v1">>)]};
check(Ast) when is_map(Ast) ->
    {error, [diagnostic(invalid_ast, maps:get(origin, Ast, default_origin()), <<"invalid source AST">>)]};
check(_) ->
    {error, [diagnostic(invalid_ast, default_origin(), <<"source AST must be a map">>)]}.

check_tasks(_ModuleName, [], Acc) ->
    {ok, lists:reverse(Acc)};
check_tasks(ModuleName, [Task | Rest], Acc) ->
    case check_task(ModuleName, Task) of
        {ok, Checked} -> check_tasks(ModuleName, Rest, [Checked | Acc]);
        {error, _} = Error -> Error
    end.

check_task(ModuleName, #{
    kind := task,
    name := Name,
    parameters := Parameters,
    result_type := ResultType,
    effects := Effects,
    requirements := Requirements,
    body := Body,
    ensures := Ensures,
    origin := Origin
}) when is_binary(Name), is_list(Parameters) ->
    case {Effects, Requirements, unique_names(Parameters, parameter)} of
        {[], [], ok} ->
            Environment = maps:from_list([{maps:get(name, Parameter), maps:get(type, Parameter)} || Parameter <- Parameters]),
            case type_expression(Body, Environment) of
                {ok, ResultType} ->
                    EnsureEnvironment = Environment#{<<"result">> => ResultType},
                    case type_expression(Ensures, EnsureEnvironment) of
                        {ok, bool} ->
                            Arity = length(Parameters),
                            TaskId = iolist_to_binary([
                                <<"task:">>, ModuleName, <<".">>, Name, <<"/">>, integer_to_binary(Arity)
                            ]),
                            {ok, #{
                                id => TaskId,
                                name => Name,
                                parameters => Parameters,
                                result_type => ResultType,
                                effects => [],
                                requirements => [],
                                body => Body,
                                ensures => Ensures,
                                origin => Origin
                            }};
                        {ok, ActualEnsureType} ->
                            {error, [type_mismatch(Ensures, bool, ActualEnsureType)]};
                        {error, _} = Error -> Error
                    end;
                {ok, ActualType} ->
                    {error, [type_mismatch(Body, ResultType, ActualType)]};
                {error, _} = Error -> Error
            end;
        {[_ | _], _, _} ->
            {error, [diagnostic(nonempty_effect_set, Origin, <<"the minimal vertical slice is pure">>)]};
        {_, [_ | _], _} ->
            {error, [diagnostic(nonempty_requirement_set, Origin, <<"the minimal vertical slice requires no authority">>)]};
        {_, _, {error, _} = Error} -> Error
    end;
check_task(_ModuleName, Task) ->
    {error, [diagnostic(invalid_task, maps:get(origin, Task, default_origin()), <<"invalid task declaration">>)]}.

type_expression(#{kind := integer, value := Value}, _Environment) when
    is_integer(Value), Value >= 0, Value =< ?MAX_INTEGER
->
    {ok, int};
type_expression(#{kind := integer, origin := Origin}, _Environment) ->
    {error, [diagnostic(integer_out_of_range, Origin, <<"integer literal exceeds signed 64-bit range">>)]};
type_expression(#{kind := boolean, value := Value}, _Environment) when is_boolean(Value) ->
    {ok, bool};
type_expression(#{kind := variable, name := Name, origin := Origin}, Environment) ->
    case maps:find(Name, Environment) of
        {ok, Type} -> {ok, Type};
        error -> {error, [diagnostic(unresolved_name, Origin, <<"unresolved name: ", Name/binary>>)]}
    end;
type_expression(#{kind := add, left := Left, right := Right} = Expression, Environment) ->
    case {type_expression(Left, Environment), type_expression(Right, Environment)} of
        {{ok, int}, {ok, int}} -> {ok, int};
        {{error, _} = Error, _} -> Error;
        {_, {error, _} = Error} -> Error;
        {{ok, LeftType}, {ok, RightType}} ->
            {error, [diagnostic(
                invalid_addition,
                maps:get(origin, Expression),
                iolist_to_binary(io_lib:format("addition requires Int operands, got ~p and ~p", [LeftType, RightType]))
            )]}
    end;
type_expression(#{kind := equal, left := Left, right := Right} = Expression, Environment) ->
    case {type_expression(Left, Environment), type_expression(Right, Environment)} of
        {{ok, Type}, {ok, Type}} -> {ok, bool};
        {{error, _} = Error, _} -> Error;
        {_, {error, _} = Error} -> Error;
        {{ok, LeftType}, {ok, RightType}} ->
            {error, [diagnostic(
                incomparable_types,
                maps:get(origin, Expression),
                iolist_to_binary(io_lib:format("equality operands differ: ~p and ~p", [LeftType, RightType]))
            )]}
    end;
type_expression(Expression, _Environment) when is_map(Expression) ->
    {error, [diagnostic(unknown_expression, maps:get(origin, Expression, default_origin()), <<"unknown expression">>)]};
type_expression(_, _Environment) ->
    {error, [diagnostic(unknown_expression, default_origin(), <<"expression must be a map">>)]}.

unique_names(Declarations, Kind) ->
    unique_names(Declarations, Kind, #{}).

unique_names([], _Kind, _Seen) ->
    ok;
unique_names([Declaration | Rest], Kind, Seen) ->
    Name = maps:get(name, Declaration, <<>>),
    case maps:is_key(Name, Seen) of
        true ->
            Origin = maps:get(origin, Declaration, default_origin()),
            {error, [diagnostic(duplicate_name, Origin, iolist_to_binary(io_lib:format("duplicate ~p name: ~ts", [Kind, Name])))]};
        false ->
            unique_names(Rest, Kind, Seen#{Name => true})
    end.

type_mismatch(Expression, Expected, Actual) ->
    diagnostic(
        type_mismatch,
        maps:get(origin, Expression, default_origin()),
        iolist_to_binary(io_lib:format("expected ~p, got ~p", [Expected, Actual]))
    ).

diagnostic(Code, Origin, Message) ->
    #{code => Code, severity => error, origin => Origin, message => Message}.

default_origin() ->
    #{byte => 0, line => 1, column => 1}.
