-module(alang_phase6_mock_model).
-behaviour(gen_server).

-export([complete/3, live_complete/3, start_link/1, status/1, stop/1]).
-export([handle_call/3, handle_cast/2, handle_info/2, init/1, terminate/2]).

-define(CALL_TIMEOUT, 5000).
-define(MAX_FIXTURES, 256).
-define(MAX_MAILBOX, 32).

-spec start_link(map()) -> gen_server:start_ret().
start_link(Options) -> gen_server:start_link(?MODULE, Options, []).

-spec complete(pid(), map(), integer()) -> {ok, map()} | {error, atom()}.
complete(Adapter, Request, Deadline) when is_pid(Adapter), is_integer(Deadline) ->
    Remaining = Deadline - erlang:monotonic_time(millisecond),
    case {Remaining > 0, process_info(Adapter, message_queue_len)} of
        {false, _} -> {error, deadline_exceeded};
        {true, {message_queue_len, Length}} when Length >= ?MAX_MAILBOX ->
            {error, model_adapter_backpressure};
        {true, {message_queue_len, _Length}} ->
            try gen_server:call(Adapter, {complete, Request}, erlang:min(Remaining, ?CALL_TIMEOUT)) of
                Result -> Result
            catch
                exit:{timeout, _} -> {error, model_adapter_timeout};
                exit:{noproc, _} -> {error, model_adapter_unavailable}
            end;
        {true, undefined} -> {error, model_adapter_unavailable}
    end;
complete(_Adapter, _Request, _Deadline) -> {error, invalid_model_adapter_call}.

-spec live_complete(term(), map(), integer()) -> {error, live_provider_disabled}.
live_complete(_Config, _Request, _Deadline) -> {error, live_provider_disabled}.

-spec status(pid()) -> map().
status(Adapter) -> gen_server:call(Adapter, status, ?CALL_TIMEOUT).

-spec stop(pid()) -> ok.
stop(Adapter) -> gen_server:stop(Adapter).

init(#{profiles := Profiles, fixtures := Fixtures} = Options) when
    is_list(Profiles), is_map(Fixtures), map_size(Fixtures) =< ?MAX_FIXTURES
->
    case validate_profiles(Profiles) andalso validate_fixtures(Fixtures) of
        true -> {ok, #{
            profiles => maps:from_list([{maps:get(id, Profile), Profile} || Profile <- Profiles]),
            fixtures => Fixtures,
            calls => 0,
            max_calls => maps:get(max_calls, Options, 1024)
        }};
        false -> {stop, invalid_mock_model_configuration}
    end;
init(_Options) -> {stop, invalid_mock_model_configuration}.

handle_call({complete, Request}, _From, State) ->
    case maps:get(calls, State) < maps:get(max_calls, State) of
        false -> {reply, {error, model_adapter_call_limit}, State};
        true ->
            Reply = fixture_result(Request, State),
            {reply, Reply, State#{calls := maps:get(calls, State) + 1}}
    end;
handle_call(status, _From, State) ->
    {reply, #{
        format => alang_mock_model_status_v1,
        calls => maps:get(calls, State),
        fixture_count => map_size(maps:get(fixtures, State)),
        profile_ids => lists:sort(maps:keys(maps:get(profiles, State))),
        network => disabled,
        secrets => none
    }, State};
handle_call(_Request, _From, State) -> {reply, {error, unsupported_model_adapter_call}, State}.

handle_cast(_Message, State) -> {noreply, State}.
handle_info(_Message, State) -> {noreply, State}.
terminate(_Reason, _State) -> ok.

fixture_result(Request, State) ->
    case alang_phase6_model_protocol:validate_request(Request) of
        ok -> select_fixture(Request, State);
        {error, Reason} -> {error, Reason}
    end.

select_fixture(Request, State) ->
    Profile = maps:get(profile, Request),
    ProfileId = maps:get(id, Profile),
    case maps:find(ProfileId, maps:get(profiles, State)) of
        {ok, Profile} ->
            {ok, Digest} = alang_phase6_model_protocol:request_digest(Request),
            case maps:find(Digest, maps:get(fixtures, State)) of
                {ok, Fixture} -> build_result(Request, Fixture);
                error -> failure(Request, provider_error, <<"fixture-not-found">>, false)
            end;
        {ok, _DifferentProfile} -> {error, profile_configuration_mismatch};
        error -> {error, unknown_model_profile}
    end.

build_result(Request, #{status := success, output := Output}) ->
    Parsed = #{format => markdown_draft_v1, markdown => Output},
    alang_phase6_model_protocol:success(
        Request, Output, Parsed, usage(Request, Output), metadata(Request, <<"stop">>));
build_result(Request, #{status := transient}) ->
    failure(Request, provider_error, <<"transient-provider-error">>, true);
build_result(Request, #{status := permanent}) ->
    failure(Request, provider_error, <<"permanent-provider-error">>, false);
build_result(Request, #{status := Status, fragment := Fragment}) when
    Status =:= invalid_syntax; Status =:= schema_failure
-> failure(Request, Status, Fragment, true);
build_result(Request, #{status := Status}) when
    Status =:= content_policy_denial; Status =:= timeout;
    Status =:= budget_exhausted; Status =:= outcome_unknown
-> failure(Request, Status, atom_to_binary(Status), false);
build_result(Request, _Fixture) -> failure(Request, provider_error, <<"invalid-fixture">>, false).

failure(Request, Status, Fragment, FixtureRetryable) ->
    Code = case {Status, FixtureRetryable} of
        {provider_error, true} -> <<"transient-provider-error">>;
        {provider_error, false} -> <<"permanent-provider-error">>;
        _ -> atom_to_binary(Status)
    end,
    Diagnostic = #{code => Code, fragment => Fragment, offset => none},
    alang_phase6_model_protocol:failure(
        Request, Status, Diagnostic, usage(Request, <<>>), metadata(Request, atom_to_binary(Status))).

usage(Request, Output) ->
    InputBytes = byte_size(maps:get(instruction, Request)) + lists:sum([
        byte_size(maps:get(content, Fragment)) || Fragment <- maps:get(context, Request)
    ]),
    #{
        input_tokens => token_estimate(InputBytes),
        output_tokens => token_estimate(byte_size(Output)),
        input_bytes => InputBytes,
        output_bytes => byte_size(Output)
    }.

metadata(Request, FinishReason) ->
    Profile = maps:get(profile, Request),
    {ok, Digest} = alang_phase6_model_protocol:request_digest(Request),
    Raw = #{
        provider => <<"deterministic-mock">>,
        model => maps:get(model, Profile),
        request_id => binary:part(Digest, 0, 24),
        finish_reason => FinishReason
    },
    Retained = maps:get(retain_provider_fields, maps:get(redaction_policy, Request)),
    maps:map(fun(Key, Value) ->
        case lists:member(metadata_name(Key), Retained) of
            true -> Value;
            false -> <<>>
        end
    end, Raw).

metadata_name(provider) -> <<"provider">>;
metadata_name(model) -> <<"model">>;
metadata_name(request_id) -> <<"request_id">>;
metadata_name(finish_reason) -> <<"finish_reason">>.

token_estimate(0) -> 0;
token_estimate(Bytes) -> (Bytes + 3) div 4.

validate_profiles(Profiles) ->
    Profiles =/= [] andalso length(Profiles) =< 16 andalso
        lists:all(fun(Profile) ->
            alang_phase6_model_protocol:validate_profile(Profile) =:= ok andalso
                maps:get(provider_class, Profile) =:= mock
        end, Profiles) andalso
        length(Profiles) =:= length(lists:usort([maps:get(id, Profile) || Profile <- Profiles])).

validate_fixtures(Fixtures) ->
    maps:fold(fun(Digest, Fixture, Valid) ->
        Valid andalso valid_digest(Digest) andalso is_map(Fixture)
    end, true, Fixtures).

valid_digest(Value) when is_binary(Value), byte_size(Value) =:= 64 ->
    lists:all(fun(Character) ->
        (Character >= $0 andalso Character =< $9) orelse
            (Character >= $a andalso Character =< $f)
    end, binary_to_list(Value));
valid_digest(_Value) -> false.
