-module(alang_phase6_model_protocol).

-export([
    canonical_request/1,
    failure/5,
    new_request/1,
    request_digest/1,
    success/5,
    validate_profile/1,
    validate_request/1,
    validate_result/2
]).

-define(MAX_REQUEST_BYTES, 131072).
-define(MAX_CONTEXT_FRAGMENTS, 32).
-define(MAX_ID_BYTES, 128).
-define(MAX_INSTRUCTION_BYTES, 32768).
-define(MAX_METADATA_BYTES, 4096).
-define(MAX_DIAGNOSTIC_BYTES, 8192).
-define(MAX_TOKENS, 131072).
-define(MAX_TIMEOUT_MS, 120000).

-spec new_request(map()) -> {ok, map()} | {error, atom()}.
new_request(Spec) when is_map(Spec) ->
    Request = Spec#{format => alang_model_request_v1},
    case validate_request(Request) of
        ok -> {ok, Request};
        {error, _} = Error -> Error
    end;
new_request(_Spec) -> {error, invalid_model_request}.

-spec validate_profile(term()) -> ok | {error, atom()}.
validate_profile(#{
    format := alang_model_profile_v1,
    id := Id,
    provider_class := ProviderClass,
    model := Model,
    sampling := #{temperature_milli := Temperature, top_p_milli := TopP} = Sampling,
    max_input_bytes := MaxInput,
    max_output_bytes := MaxOutput,
    max_tokens := MaxTokens,
    timeout_ms := Timeout
} = Profile) when map_size(Profile) =:= 9, map_size(Sampling) =:= 2 ->
    case valid_id(Id) andalso
        lists:member(ProviderClass, [mock, live_feature_gated]) andalso
        valid_id(Model) andalso
        is_integer(Temperature) andalso Temperature >= 0 andalso Temperature =< 2000 andalso
        is_integer(TopP) andalso TopP > 0 andalso TopP =< 1000 andalso
        valid_size(MaxInput, 1024, 65536) andalso
        valid_size(MaxOutput, 64, 65536) andalso
        is_integer(MaxTokens) andalso MaxTokens > 0 andalso MaxTokens =< ?MAX_TOKENS andalso
        is_integer(Timeout) andalso Timeout > 0 andalso Timeout =< ?MAX_TIMEOUT_MS
    of
        true -> ok;
        false -> {error, invalid_model_profile}
    end;
validate_profile(_Profile) -> {error, invalid_model_profile}.

-spec validate_request(term()) -> ok | {error, atom()}.
validate_request(#{
    format := alang_model_request_v1,
    operation_id := OperationId,
    profile := Profile,
    context := Context,
    instruction := Instruction,
    output_schema := OutputSchema,
    deadline := Deadline,
    retry_class := RetryClass,
    redaction_policy := RedactionPolicy,
    provenance := Provenance
} = Request) when map_size(Request) =:= 10 ->
    case {
        validate_profile(Profile),
        validate_context(Context),
        validate_output_schema(OutputSchema, Profile),
        validate_redaction_policy(RedactionPolicy),
        validate_provenance(Provenance),
        valid_id(OperationId),
        valid_binary(Instruction, 1, ?MAX_INSTRUCTION_BYTES),
        is_integer(Deadline),
        lists:member(RetryClass, [none, repair_only, transient_before_acceptance]),
        request_within_profile(Request, Profile),
        external_size(Request) =< ?MAX_REQUEST_BYTES
    } of
        {ok, ok, ok, ok, ok, true, true, true, true, true, true} -> ok;
        {{error, Reason}, _, _, _, _, _, _, _, _, _, _} -> {error, Reason};
        {_, {error, Reason}, _, _, _, _, _, _, _, _, _} -> {error, Reason};
        {_, _, {error, Reason}, _, _, _, _, _, _, _, _} -> {error, Reason};
        {_, _, _, {error, Reason}, _, _, _, _, _, _, _} -> {error, Reason};
        {_, _, _, _, {error, Reason}, _, _, _, _, _, _} -> {error, Reason};
        {_, _, _, _, _, false, _, _, _, _, _} -> {error, invalid_operation_id};
        {_, _, _, _, _, _, false, _, _, _, _} -> {error, invalid_instruction};
        {_, _, _, _, _, _, _, false, _, _, _} -> {error, invalid_deadline};
        {_, _, _, _, _, _, _, _, false, _, _} -> {error, invalid_retry_class};
        {_, _, _, _, _, _, _, _, _, false, _} -> {error, model_request_too_large};
        _ -> {error, model_request_too_large}
    end;
validate_request(_Request) -> {error, invalid_model_request}.

-spec canonical_request(map()) -> {ok, binary()} | {error, atom()}.
canonical_request(Request) ->
    case validate_request(Request) of
        ok -> {ok, term_to_binary(Request, [deterministic])};
        {error, _} = Error -> Error
    end.

-spec request_digest(map()) -> {ok, binary()} | {error, atom()}.
request_digest(Request) ->
    case canonical_request(Request) of
        {ok, Binary} -> {ok, hex(crypto:hash(sha256, Binary))};
        {error, _} = Error -> Error
    end.

-spec success(map(), binary(), map(), map(), map()) -> {ok, map()} | {error, atom()}.
success(Request, Output, Parsed, Usage, Metadata) ->
    with_request_digest(Request, fun(Digest) ->
        Result = #{
            format => alang_model_result_v1,
            status => success,
            operation_id => maps:get(operation_id, Request),
            request_digest => Digest,
            output => Output,
            parsed => Parsed,
            usage => Usage,
            provider_metadata => Metadata
        },
        checked_result(Result, Request)
    end).

-spec failure(map(), atom(), map(), map(), map()) -> {ok, map()} | {error, atom()}.
failure(Request, Status, Diagnostic, Usage, Metadata) ->
    with_request_digest(Request, fun(Digest) ->
        Result = #{
            format => alang_model_result_v1,
            status => Status,
            operation_id => maps:get(operation_id, Request),
            request_digest => Digest,
            diagnostic => Diagnostic,
            usage => Usage,
            provider_metadata => Metadata,
            retryable => retryable(Status, Diagnostic),
            outcome => outcome(Status)
        },
        checked_result(Result, Request)
    end).

-spec validate_result(term(), map()) -> ok | {error, atom()}.
validate_result(Result, Request) when is_map(Result), is_map(Request) ->
    case request_digest(Request) of
        {ok, Digest} -> validate_result_shape(Result, Request, Digest);
        {error, _} -> {error, invalid_result_request}
    end;
validate_result(_Result, _Request) -> {error, invalid_model_result}.

validate_result_shape(#{
    format := alang_model_result_v1,
    status := success,
    operation_id := OperationId,
    request_digest := Digest,
    output := Output,
    parsed := Parsed,
    usage := Usage,
    provider_metadata := Metadata
} = Result, Request, Digest) when map_size(Result) =:= 8 ->
    Profile = maps:get(profile, Request),
    Schema = maps:get(output_schema, Request),
    case OperationId =:= maps:get(operation_id, Request) andalso
        valid_binary(Output, 1, maps:get(max_output_bytes, Profile)) andalso
        valid_parsed(Parsed, Output, Schema) andalso
        valid_usage(Usage, Profile) andalso
        valid_metadata(Metadata) andalso
        metadata_allowed(Metadata, maps:get(redaction_policy, Request))
    of
        true -> ok;
        false -> {error, invalid_model_result}
    end;
validate_result_shape(#{
    format := alang_model_result_v1,
    status := Status,
    operation_id := OperationId,
    request_digest := Digest,
    diagnostic := Diagnostic,
    usage := Usage,
    provider_metadata := Metadata,
    retryable := Retryable,
    outcome := Outcome
} = Result, Request, Digest) when map_size(Result) =:= 9 ->
    Profile = maps:get(profile, Request),
    case valid_failure_status(Status) andalso
        OperationId =:= maps:get(operation_id, Request) andalso
        valid_diagnostic(Diagnostic) andalso
        valid_usage(Usage, Profile) andalso
        valid_metadata(Metadata) andalso
        metadata_allowed(Metadata, maps:get(redaction_policy, Request)) andalso
        Retryable =:= retryable(Status, Diagnostic) andalso Outcome =:= outcome(Status)
    of
        true -> ok;
        false -> {error, invalid_model_result}
    end;
validate_result_shape(_Result, _Request, _Digest) -> {error, invalid_model_result}.

checked_result(Result, Request) ->
    case validate_result(Result, Request) of
        ok -> {ok, Result};
        {error, _} = Error -> Error
    end.

with_request_digest(Request, Fun) ->
    case request_digest(Request) of
        {ok, Digest} -> Fun(Digest);
        {error, _} = Error -> Error
    end.

validate_context(Context) when is_list(Context), length(Context) =< ?MAX_CONTEXT_FRAGMENTS ->
    case lists:all(fun valid_fragment/1, Context) andalso unique_fragment_ids(Context) of
        true -> ok;
        false -> {error, invalid_model_context}
    end;
validate_context(_Context) -> {error, invalid_model_context}.

valid_fragment(#{
    format := alang_context_fragment_v1,
    id := Id,
    visibility := Visibility,
    provenance := Provenance,
    trust := Trust,
    content := Content
} = Fragment) when map_size(Fragment) =:= 6 ->
    valid_id(Id) andalso
        lists:member(Visibility, [public, task_local]) andalso
        valid_digest(Provenance) andalso
        lists:member(Trust, [instruction, data_only]) andalso
        valid_binary(Content, 0, 32768);
valid_fragment(_Fragment) -> false.

unique_fragment_ids(Context) ->
    Ids = [maps:get(id, Fragment) || Fragment <- Context],
    length(Ids) =:= length(lists:usort(Ids)).

validate_output_schema(#{
    format := alang_output_schema_v1,
    id := markdown_draft_v1,
    max_bytes := MaxBytes,
    required_sections := Sections
} = Schema, Profile) when map_size(Schema) =:= 4, is_list(Sections), length(Sections) =< 16 ->
    case valid_size(MaxBytes, 1, maps:get(max_output_bytes, Profile, 0)) andalso
        lists:all(fun valid_id/1, Sections) andalso length(Sections) =:= length(lists:usort(Sections))
    of
        true -> ok;
        false -> {error, invalid_output_schema}
    end;
validate_output_schema(_Schema, _Profile) -> {error, invalid_output_schema}.

validate_redaction_policy(#{
    format := alang_redaction_policy_v1,
    trace_content := digest_only,
    retain_provider_fields := Fields
} = Policy) when map_size(Policy) =:= 3, is_list(Fields) ->
    Allowed = [<<"finish_reason">>, <<"model">>, <<"provider">>, <<"request_id">>],
    case length(Fields) =< length(Allowed) andalso
        lists:all(fun(Field) -> lists:member(Field, Allowed) end, Fields) andalso
        length(Fields) =:= length(lists:usort(Fields))
    of
        true -> ok;
        false -> {error, invalid_redaction_policy}
    end;
validate_redaction_policy(_Policy) -> {error, invalid_redaction_policy}.

validate_provenance(#{
    format := alang_model_provenance_v1,
    task_id := TaskId,
    goal_digest := GoalDigest,
    parent_call_id := ParentCallId
} = Provenance) when map_size(Provenance) =:= 4 ->
    case valid_id(TaskId) andalso valid_digest(GoalDigest) andalso
        (ParentCallId =:= none orelse valid_id(ParentCallId))
    of
        true -> ok;
        false -> {error, invalid_model_provenance}
    end;
validate_provenance(_Provenance) -> {error, invalid_model_provenance}.

request_within_profile(#{context := Context, instruction := Instruction,
    output_schema := #{max_bytes := SchemaMax}},
    #{max_input_bytes := MaxInput, max_output_bytes := MaxOutput}) when
    is_list(Context), is_binary(Instruction), is_integer(SchemaMax),
    is_integer(MaxInput), is_integer(MaxOutput)
->
    case context_bytes(Context, 0) of
        {ok, ContextBytes} ->
            ContextBytes + byte_size(Instruction) =< MaxInput andalso SchemaMax =< MaxOutput;
        error -> false
    end;
request_within_profile(_Request, _Profile) -> false.

context_bytes([], Bytes) -> {ok, Bytes};
context_bytes([#{content := Content} | Rest], Bytes) when is_binary(Content) ->
    context_bytes(Rest, Bytes + byte_size(Content));
context_bytes(_Context, _Bytes) -> error.

valid_parsed(#{format := markdown_draft_v1, markdown := Output} = Parsed, Output, Schema) when
    map_size(Parsed) =:= 2
-> byte_size(Output) =< maps:get(max_bytes, Schema);
valid_parsed(_Parsed, _Output, _Schema) -> false.

valid_usage(#{
    input_tokens := InputTokens,
    output_tokens := OutputTokens,
    input_bytes := InputBytes,
    output_bytes := OutputBytes
} = Usage, Profile) when map_size(Usage) =:= 4 ->
    lists:all(fun(Value) -> is_integer(Value) andalso Value >= 0 end,
        [InputTokens, OutputTokens, InputBytes, OutputBytes]) andalso
        InputTokens + OutputTokens =< maps:get(max_tokens, Profile) andalso
        InputBytes =< maps:get(max_input_bytes, Profile) andalso
        OutputBytes =< maps:get(max_output_bytes, Profile);
valid_usage(_Usage, _Profile) -> false.

valid_metadata(#{
    provider := Provider,
    model := Model,
    request_id := RequestId,
    finish_reason := FinishReason
} = Metadata) when map_size(Metadata) =:= 4 ->
    lists:all(fun(Value) -> valid_binary(Value, 0, 256) end,
        [Provider, Model, RequestId, FinishReason]) andalso
        external_size(Metadata) =< ?MAX_METADATA_BYTES;
valid_metadata(_Metadata) -> false.

metadata_allowed(Metadata, #{retain_provider_fields := Retained}) ->
    Fields = [
        {<<"provider">>, provider},
        {<<"model">>, model},
        {<<"request_id">>, request_id},
        {<<"finish_reason">>, finish_reason}
    ],
    lists:all(fun({External, Internal}) ->
        lists:member(External, Retained) orelse maps:get(Internal, Metadata) =:= <<>>
    end, Fields).

valid_diagnostic(#{code := Code, fragment := Fragment, offset := Offset} = Diagnostic) when
    map_size(Diagnostic) =:= 3
-> valid_id(Code) andalso valid_binary(Fragment, 0, 4096) andalso
    (Offset =:= none orelse (is_integer(Offset) andalso Offset >= 0)) andalso
    external_size(Diagnostic) =< ?MAX_DIAGNOSTIC_BYTES;
valid_diagnostic(_Diagnostic) -> false.

valid_failure_status(Status) -> lists:member(Status, [
    invalid_syntax,
    schema_failure,
    content_policy_denial,
    timeout,
    provider_error,
    budget_exhausted,
    outcome_unknown
]).

retryable(invalid_syntax, _Diagnostic) -> true;
retryable(schema_failure, _Diagnostic) -> true;
retryable(provider_error, #{code := <<"transient-provider-error">>}) -> true;
retryable(_Status, _Diagnostic) -> false.

outcome(outcome_unknown) -> uncertain;
outcome(_Status) -> definitive.

valid_id(Value) -> valid_binary(Value, 1, ?MAX_ID_BYTES).
valid_digest(Value) when is_binary(Value), byte_size(Value) =:= 64 ->
    lists:all(fun is_hex/1, binary_to_list(Value));
valid_digest(_Value) -> false.

valid_binary(Value, Minimum, Maximum) ->
    is_binary(Value) andalso byte_size(Value) >= Minimum andalso byte_size(Value) =< Maximum.

valid_size(Value, Minimum, Maximum) ->
    is_integer(Value) andalso Value >= Minimum andalso Value =< Maximum.

external_size(Term) ->
    try erlang:external_size(Term)
    catch error:badarg -> ?MAX_REQUEST_BYTES + 1
    end.

is_hex(Character) when Character >= $0, Character =< $9 -> true;
is_hex(Character) when Character >= $a, Character =< $f -> true;
is_hex(_Character) -> false.

hex(Binary) -> << <<(hex_digit(Nibble))>> || <<Nibble:4>> <= Binary >>.
hex_digit(Nibble) when Nibble < 10 -> $0 + Nibble;
hex_digit(Nibble) -> $a + Nibble - 10.
