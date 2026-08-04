-module(alang_phase6_repair).

-export([classify/2, new/2, plan/3, record_response/3, snapshot/1]).

-spec new(map(), non_neg_integer()) -> {ok, map()} | {error, atom()}.
new(Request, MaxAttempts) when is_integer(MaxAttempts), MaxAttempts >= 0, MaxAttempts =< 8 ->
    case alang_phase6_model_protocol:validate_request(Request) of
        ok ->
            {ok, OriginalDigest} = alang_phase6_model_protocol:request_digest(Request),
            {ok, #{
                format => alang_repair_state_v1,
                original_request => Request,
                original_request_digest => OriginalDigest,
                original_context_digest => digest(maps:get(context, Request)),
                max_attempts => MaxAttempts,
                attempts => 0,
                pending => none,
                history => []
            }};
        {error, _} -> {error, invalid_original_request}
    end;
new(_Request, _MaxAttempts) -> {error, invalid_repair_budget}.

-spec classify(map(), map()) -> repairable | {terminal, atom()} | {error, atom()}.
classify(Result, #{consequential_effects := Consequential, cancelled := Cancelled,
    authorized := Authorized} = Gate) when map_size(Gate) =:= 3,
    is_boolean(Consequential), is_boolean(Cancelled), is_boolean(Authorized) ->
    case {Cancelled, Authorized, Consequential, maps:get(status, Result, invalid)} of
        {true, _, _, _} -> {terminal, cancelled};
        {_, false, _, _} -> {terminal, authorization_failure};
        {_, _, true, _} -> {terminal, consequential_effect_retry_forbidden};
        {false, true, false, invalid_syntax} -> repairable;
        {false, true, false, schema_failure} -> repairable;
        {false, true, false, Status} when
            Status =:= content_policy_denial; Status =:= timeout;
            Status =:= provider_error; Status =:= budget_exhausted;
            Status =:= outcome_unknown
        -> {terminal, Status};
        _ -> {error, invalid_model_failure}
    end;
classify(_Result, _Gate) -> {error, invalid_repair_gate}.

-spec plan(map(), map(), map()) -> {ok, map(), map()} | {terminal, atom(), map()} |
    {error, atom()}.
plan(State, Failure, Gate) ->
    case validate_state(State) of
        false -> {error, invalid_repair_state};
        true -> plan_checked(State, Failure, Gate)
    end.

plan_checked(#{pending := Pending}, _Failure, _Gate) when Pending =/= none ->
    {error, repair_response_pending};
plan_checked(State, Failure, Gate) ->
    Original = maps:get(original_request, State),
    case alang_phase6_model_protocol:validate_result(Failure, Original) of
        {error, _} -> {error, invalid_original_failure};
        ok ->
            case classify(Failure, Gate) of
                repairable -> build_repair(State, Failure);
                {terminal, Reason} -> {terminal, Reason, State};
                {error, _} = Error -> Error
            end
    end.

build_repair(State, Failure) ->
    Attempts = maps:get(attempts, State),
    case Attempts < maps:get(max_attempts, State) of
        false -> {terminal, repair_budget_exhausted, State};
        true ->
            Attempt = Attempts + 1,
            Original = maps:get(original_request, State),
            Diagnostic = maps:get(diagnostic, Failure),
            RepairId = repair_id(Attempt, maps:get(original_request_digest, State)),
            RepairFragment = repair_fragment(Attempt, Diagnostic),
            Provenance0 = maps:get(provenance, Original),
            Request0 = Original#{
                operation_id := RepairId,
                context := [RepairFragment],
                instruction := <<"Repair only the supplied failing fragment. Return output matching the unchanged schema.">>,
                retry_class := none,
                provenance := Provenance0#{parent_call_id := maps:get(operation_id, Original)}
            },
            case alang_phase6_model_protocol:new_request(maps:remove(format, Request0)) of
                {error, Reason} -> {error, Reason};
                {ok, Request} ->
                    {ok, RequestDigest} = alang_phase6_model_protocol:request_digest(Request),
                    Entry = #{
                        attempt => Attempt,
                        original_call_id => maps:get(operation_id, Original),
                        original_request_digest => maps:get(original_request_digest, State),
                        original_context_digest => maps:get(original_context_digest, State),
                        repair_call_id => RepairId,
                        repair_request_digest => RequestDigest,
                        diagnostic_digest => digest(Diagnostic),
                        failing_fragment_digest => digest(maps:get(fragment, Diagnostic)),
                        response => pending
                    },
                    Updated = State#{attempts := Attempt, pending := RequestDigest,
                        history := maps:get(history, State) ++ [Entry]},
                    {ok, Request, Updated}
            end
    end.

-spec record_response(map(), map(), map()) -> {ok, map()} | {error, atom()}.
record_response(State, RepairRequest, Result) ->
    case validate_state(State) of
        false -> {error, invalid_repair_state};
        true -> record_response_checked(State, RepairRequest, Result)
    end.

record_response_checked(#{pending := none}, _RepairRequest, _Result) ->
    {error, no_repair_response_pending};
record_response_checked(#{pending := Expected} = State, RepairRequest, Result) ->
    case {alang_phase6_model_protocol:request_digest(RepairRequest),
        alang_phase6_model_protocol:validate_result(Result, RepairRequest)} of
        {{ok, Expected}, ok} ->
            Status = maps:get(status, Result),
            {Disposition, FragmentDigest} = response_disposition(Status, Result),
            Response = #{status => Status, disposition => Disposition,
                result_digest => digest(Result), fragment_digest => FragmentDigest},
            History = maps:get(history, State),
            Last = lists:last(History),
            UpdatedHistory = lists:droplast(History) ++ [Last#{response := Response}],
            {ok, State#{pending := none, history := UpdatedHistory}};
        {{ok, _}, ok} -> {error, wrong_repair_response};
        _ -> {error, invalid_repair_response}
    end.

-spec snapshot(map()) -> map().
snapshot(State) -> maps:without([original_request], State).

response_disposition(success, Result) -> {accepted, digest(maps:get(output, Result))};
response_disposition(_Status, Result) ->
    {rejected, digest(maps:get(fragment, maps:get(diagnostic, Result)))}.

repair_fragment(Attempt, #{code := Code, fragment := Fragment, offset := Offset} = Diagnostic) ->
    Content = iolist_to_binary([
        <<"attempt=">>, integer_to_binary(Attempt),
        <<"; code=">>, Code,
        <<"; offset=">>, offset_binary(Offset),
        <<"\n">>, Fragment
    ]),
    #{
        format => alang_context_fragment_v1,
        id => <<"repair-fragment-", (integer_to_binary(Attempt))/binary>>,
        visibility => task_local,
        provenance => digest(Diagnostic),
        trust => data_only,
        content => Content
    }.

repair_id(Attempt, OriginalDigest) ->
    Prefix = binary:part(OriginalDigest, 0, 24),
    <<"repair-", (integer_to_binary(Attempt))/binary, "-", Prefix/binary>>.

offset_binary(none) -> <<"none">>;
offset_binary(Offset) -> integer_to_binary(Offset).

validate_state(#{
    format := alang_repair_state_v1,
    original_request := Request,
    original_request_digest := RequestDigest,
    original_context_digest := ContextDigest,
    max_attempts := MaxAttempts,
    attempts := Attempts,
    pending := Pending,
    history := History
} = State) when map_size(State) =:= 8 ->
    alang_phase6_model_protocol:validate_request(Request) =:= ok andalso
        digest_request(Request) =:= RequestDigest andalso
        digest(maps:get(context, Request)) =:= ContextDigest andalso
        is_integer(MaxAttempts) andalso MaxAttempts >= 0 andalso MaxAttempts =< 8 andalso
        is_integer(Attempts) andalso Attempts >= 0 andalso Attempts =< MaxAttempts andalso
        (Pending =:= none orelse valid_digest(Pending)) andalso
        is_list(History) andalso length(History) =:= Attempts;
validate_state(_State) -> false.

digest_request(Request) ->
    {ok, Digest} = alang_phase6_model_protocol:request_digest(Request),
    Digest.

valid_digest(Value) when is_binary(Value), byte_size(Value) =:= 64 ->
    lists:all(fun is_hex/1, binary_to_list(Value));
valid_digest(_Value) -> false.

digest(Term) -> hex(crypto:hash(sha256, term_to_binary(Term, [deterministic]))).
is_hex(Character) when Character >= $0, Character =< $9 -> true;
is_hex(Character) when Character >= $a, Character =< $f -> true;
is_hex(_Character) -> false.
hex(Binary) -> << <<(hex_digit(Nibble))>> || <<Nibble:4>> <= Binary >>.
hex_digit(Nibble) when Nibble < 10 -> $0 + Nibble;
hex_digit(Nibble) -> $a + Nibble - 10.
