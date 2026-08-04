-module(alang_phase7_adversarial).

-export([contains/2, mutate_binary/2, safe/1, surface_clean/2]).

-spec safe(fun(() -> term())) -> {returned, term()} | {exception, atom(), term()}.
safe(Function) when is_function(Function, 0) ->
    try Function() of Result -> {returned, Result}
    catch Class:Reason -> {exception, Class, Reason}
    end.

-spec mutate_binary(binary(), non_neg_integer()) -> [binary()].
mutate_binary(Binary, Seed) when is_binary(Binary), is_integer(Seed), Seed >= 0 ->
    Size = byte_size(Binary),
    Position = case Size of 0 -> 0; _ -> Seed rem Size end,
    Flipped = case Size of
        0 -> <<255>>;
        _ ->
            <<Before:Position/binary, Byte, After/binary>> = Binary,
            <<Before/binary, (Byte bxor 16#ff), After/binary>>
    end,
    Truncated = case Size of 0 -> <<>>; _ -> binary:part(Binary, 0, Position) end,
    lists:usort([Flipped, Truncated, <<Binary/binary, 0>>, <<0, Binary/binary>>]).

-spec surface_clean([term()], [binary()]) -> boolean().
surface_clean(Surfaces, Secrets) ->
    not lists:any(fun contains_runtime_identity/1, Surfaces) andalso
        not lists:any(fun(Secret) -> contains(Surfaces, Secret) end, Secrets).

-spec contains(term(), term()) -> boolean().
contains(Term, Term) -> true;
contains(Map, Needle) when is_map(Map) ->
    lists:any(fun(Item) -> contains(Item, Needle) end, maps:keys(Map) ++ maps:values(Map));
contains(Tuple, Needle) when is_tuple(Tuple) -> contains(tuple_to_list(Tuple), Needle);
contains(List, Needle) when is_list(List) ->
    lists:any(fun(Item) -> contains(Item, Needle) end, List);
contains(_Term, _Needle) -> false.

contains_runtime_identity(Term) when is_pid(Term); is_reference(Term); is_port(Term) -> true;
contains_runtime_identity(Map) when is_map(Map) ->
    lists:any(fun contains_runtime_identity/1, maps:keys(Map) ++ maps:values(Map));
contains_runtime_identity(Tuple) when is_tuple(Tuple) -> contains_runtime_identity(tuple_to_list(Tuple));
contains_runtime_identity(List) when is_list(List) -> lists:any(fun contains_runtime_identity/1, List);
contains_runtime_identity(_Term) -> false.
