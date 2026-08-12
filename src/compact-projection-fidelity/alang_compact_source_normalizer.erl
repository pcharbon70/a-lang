-module(alang_compact_source_normalizer).

-export([normalize/1, restore/2]).

-spec normalize(binary()) -> {ok, binary(), map()} | {error, term()}.
normalize(Binary) when is_binary(Binary) ->
    State = #{resource_forward => #{}, resource_reverse => #{}, resource_count => 0,
        path_forward => #{}, path_reverse => #{}, path_count => 0},
    case normalize_bytes(Binary, State, []) of
        {ok, Parts, FinalState} ->
            {ok, iolist_to_binary(lists:reverse(Parts)), FinalState};
        {error, _} = Error -> Error
    end;
normalize(_) -> {error, expected_source_binary}.

-spec restore(map(), map()) -> map().
restore(Semantic, State) ->
    ResourceReverse = maps:get(resource_reverse, State),
    PathReverse = maps:get(path_reverse, State),
    Semantic#{
        <<"goal_facts">> := restore_paths(maps:get(<<"goal_facts">>, Semantic), PathReverse),
        <<"requirements">> := restore_requirements(maps:get(<<"requirements">>, Semantic), ResourceReverse),
        <<"scopes">> := restore_scopes(maps:get(<<"scopes">>, Semantic), ResourceReverse, PathReverse),
        <<"child_attenuation">> := restore_child(maps:get(<<"child_attenuation">>, Semantic), ResourceReverse, PathReverse),
        <<"completion_predicates">> := restore_predicates(
            maps:get(<<"completion_predicates">>, Semantic), PathReverse),
        <<"clarification_needs">> := restore_paths(
            maps:get(<<"clarification_needs">>, Semantic), PathReverse)
    }.

normalize_bytes(<<>>, State, Acc) -> {ok, Acc, State};
normalize_bytes(<<$", Rest/binary>>, State, Acc) ->
    case take_string(Rest, <<>>) of
        {ok, Value, Tail} ->
            case Value of
                <<"/", _/binary>> ->
                    {Alias, NextState} = alias(path, Value, State),
                    normalize_bytes(Tail, NextState, [[<<"\"">>, Alias, <<"\"">>] | Acc]);
                _ ->
                    normalize_bytes(Tail, State, [[<<"\"">>, quote_bytes(Value), <<"\"">>] | Acc])
            end;
        {error, _} = Error -> Error
    end;
normalize_bytes(<<C, _/binary>> = Binary, State, Acc) when
    (C >= $a andalso C =< $z) orelse (C >= $A andalso C =< $Z) orelse C =:= $_ ->
    {Word, Rest} = take_word(Binary, <<>>),
    case binary:match(Word, <<"/">>) of
        nomatch -> normalize_bytes(Rest, State, [Word | Acc]);
        _ ->
            {Alias, NextState} = alias(resource, Word, State),
            normalize_bytes(Rest, NextState, [Alias | Acc])
    end;
normalize_bytes(<<Codepoint/utf8, Rest/binary>>, State, Acc) ->
    normalize_bytes(Rest, State, [<<Codepoint/utf8>> | Acc]).

take_word(<<C, Rest/binary>>, Acc) when
    (C >= $a andalso C =< $z) orelse (C >= $A andalso C =< $Z) orelse
    (C >= $0 andalso C =< $9) orelse C =:= $_ orelse C =:= $- orelse C =:= $/ ->
    take_word(Rest, <<Acc/binary, C>>);
take_word(Rest, Acc) -> {Acc, Rest}.

take_string(<<>>, _Acc) -> {error, unterminated_source_string};
take_string(<<$", Rest/binary>>, Acc) -> {ok, Acc, Rest};
take_string(<<$\\, $", Rest/binary>>, Acc) -> take_string(Rest, <<Acc/binary, $">>);
take_string(<<$\\, $\\, Rest/binary>>, Acc) -> take_string(Rest, <<Acc/binary, $\\>>);
take_string(<<$\\, Escape, _/binary>>, _Acc) -> {error, {invalid_source_escape, Escape}};
take_string(<<Codepoint/utf8, Rest/binary>>, Acc) ->
    take_string(Rest, <<Acc/binary, Codepoint/utf8>>).

quote_bytes(<<>>) -> [];
quote_bytes(<<$", Rest/binary>>) -> [<<"\\\"">> | quote_bytes(Rest)];
quote_bytes(<<$\\, Rest/binary>>) -> [<<"\\\\">> | quote_bytes(Rest)];
quote_bytes(<<Codepoint/utf8, Rest/binary>>) -> [<<Codepoint/utf8>> | quote_bytes(Rest)].

alias(resource, Value, State) ->
    alias_value(Value, resource_forward, resource_reverse, resource_count,
        fun(Index) -> <<"compact-resource-", (integer_to_binary(Index))/binary>> end, State);
alias(path, Value, State) ->
    alias_value(Value, path_forward, path_reverse, path_count,
        fun(Index) -> <<"/workspace/__compact__/p", (integer_to_binary(Index))/binary>> end, State).

alias_value(Value, ForwardKey, ReverseKey, CountKey, Constructor, State) ->
    Forward = maps:get(ForwardKey, State),
    case maps:find(Value, Forward) of
        {ok, Existing} -> {Existing, State};
        error ->
            Index = maps:get(CountKey, State),
            Alias = Constructor(Index),
            Reverse = maps:get(ReverseKey, State),
            {Alias, State#{ForwardKey := Forward#{Value => Alias},
                ReverseKey := Reverse#{Alias => Value}, CountKey := Index + 1}}
    end.

restore_requirements(Requirements, Reverse) ->
    [Requirement#{<<"resource">> := restore_value(maps:get(<<"resource">>, Requirement), Reverse)}
        || Requirement <- Requirements].

restore_scopes(Scopes, ResourceReverse, PathReverse) ->
    Scopes#{
        <<"models">> := restore_values(maps:get(<<"models">>, Scopes), ResourceReverse),
        <<"workspaces">> := restore_values(maps:get(<<"workspaces">>, Scopes), ResourceReverse),
        <<"paths">> := restore_values(maps:get(<<"paths">>, Scopes), PathReverse)
    }.

restore_child(null, _ResourceReverse, _PathReverse) -> null;
restore_child(Child, ResourceReverse, PathReverse) ->
    Child#{
        <<"requirements">> := restore_requirements(maps:get(<<"requirements">>, Child), ResourceReverse),
        <<"scopes">> := restore_scopes(maps:get(<<"scopes">>, Child), ResourceReverse, PathReverse)
    }.

restore_predicates(Predicates, Reverse) ->
    [Predicate#{
        <<"target">> := restore_value(maps:get(<<"target">>, Predicate), Reverse),
        <<"expected">> := restore_maybe_path(maps:get(<<"expected">>, Predicate), Reverse)
    } || Predicate <- Predicates].

restore_maybe_path(Value, Reverse) when is_binary(Value) -> restore_value(Value, Reverse);
restore_maybe_path(Value, _Reverse) -> Value.

restore_paths(Values, Reverse) -> restore_values(Values, Reverse).
restore_values(Values, Reverse) -> [restore_value(Value, Reverse) || Value <- Values].
restore_value(Value, Reverse) -> maps:get(Value, Reverse, Value).
