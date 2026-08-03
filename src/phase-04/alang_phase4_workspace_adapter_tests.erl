-module(alang_phase4_workspace_adapter_tests).

-include_lib("eunit/include/eunit.hrl").

authorized_write_is_scoped_digesting_and_idempotent_test() ->
    with_adapter(fun(Adapter, Seal, Root, _Outside) ->
        Deadline = erlang:monotonic_time(millisecond) + 2000,
        Decoded = decoded([<<"notes">>, <<"result.md">>], <<"body">>, <<"write-1">>),
        {ok, First} = alang_phase4_workspace_adapter:dispatch(Adapter, Seal, Decoded, Deadline),
        ?assertEqual(created, maps:get(disposition, First)),
        ?assertEqual(hex(crypto:hash(sha256, <<"body">>)), maps:get(digest, First)),
        {ok, Second} = alang_phase4_workspace_adapter:dispatch(Adapter, Seal, Decoded, Deadline),
        ?assertEqual(replayed, maps:get(disposition, Second)),
        ?assertEqual(maps:get(digest, First), maps:get(digest, Second)),
        Target = filename:join([Root, "notes", "result.md"]),
        ?assertEqual({ok, <<"body">>}, file:read_file(Target)),
        Conflict = decoded([<<"notes">>, <<"result.md">>], <<"different">>, <<"write-1">>),
        ?assertEqual({error, operation_conflict},
            alang_phase4_workspace_adapter:dispatch(Adapter, Seal, Conflict, Deadline)),
        ?assertEqual({ok, <<"body">>}, file:read_file(Target))
    end).

direct_bypass_and_malformed_requests_have_no_effect_test() ->
    with_adapter(fun(Adapter, Seal, Root, _Outside) ->
        Parent = self(),
        Decoded = decoded([<<"notes">>, <<"bypass.md">>], <<"no">>, <<"bypass-1">>),
        spawn(fun() ->
            Result = alang_phase4_workspace_adapter:dispatch(
                Adapter,
                make_ref(),
                Decoded,
                erlang:monotonic_time(millisecond) + 1000
            ),
            Parent ! {bypass_result, Result}
        end),
        receive
            {bypass_result, Result} -> ?assertEqual({error, adapter_bypass_denied}, Result)
        after 2000 -> error(bypass_test_timeout)
        end,
        Forged = Decoded#{arguments := #{
            workspace_id => <<"workspace-a">>,
            path_segments => [<<"..">>, <<"escape.md">>],
            content => <<"no">>,
            operation_id => <<"forged">>
        }},
        ?assertEqual({error, invalid_adapter_request},
            alang_phase4_workspace_adapter:dispatch(
                Adapter, Seal, Forged, erlang:monotonic_time(millisecond) + 1000
            )),
        Absolute = Forged#{arguments := #{
            workspace_id => <<"workspace-a">>,
            path_segments => [<<"/absolute">>],
            content => <<"no">>,
            operation_id => <<"absolute">>
        }},
        ?assertEqual({error, invalid_adapter_request},
            alang_phase4_workspace_adapter:dispatch(
                Adapter, Seal, Absolute, erlang:monotonic_time(millisecond) + 1000
            )),
        Oversized = Forged#{arguments := #{
            workspace_id => <<"workspace-a">>,
            path_segments => [<<"notes">>, <<"oversized.md">>],
            content => binary:copy(<<"x">>, 65537),
            operation_id => <<"oversized">>
        }},
        ?assertEqual({error, invalid_adapter_request},
            alang_phase4_workspace_adapter:dispatch(
                Adapter, Seal, Oversized, erlang:monotonic_time(millisecond) + 1000
            )),
        ?assertEqual(false, filelib:is_file(filename:join(Root, "notes/bypass.md")))
    end).

filesystem_escape_and_special_targets_are_rejected_test() ->
    with_adapter(fun(Adapter, Seal, Root, Outside) ->
        OutsideFile = filename:join(Outside, "outside.md"),
        ok = file:write_file(OutsideFile, <<"unchanged">>),
        Symlink = filename:join([Root, "notes", "escape"]),
        ok = file:make_symlink(Outside, Symlink),
        Deadline = erlang:monotonic_time(millisecond) + 2000,
        Escape = decoded([<<"notes">>, <<"escape">>, <<"outside.md">>],
            <<"changed">>, <<"escape-1">>),
        ?assertEqual({error, symlink_escape},
            alang_phase4_workspace_adapter:dispatch(Adapter, Seal, Escape, Deadline)),
        DirectoryTarget = decoded([<<"notes">>], <<"changed">>, <<"special-1">>),
        ?assertEqual({error, special_file},
            alang_phase4_workspace_adapter:dispatch(Adapter, Seal, DirectoryTarget, Deadline)),
        WrongWorkspace = (decoded([<<"notes">>, <<"wrong.md">>], <<"changed">>, <<"wrong-1">>))#{
            arguments := #{
                workspace_id => <<"workspace-b">>,
                path_segments => [<<"notes">>, <<"wrong.md">>],
                content => <<"changed">>,
                operation_id => <<"wrong-1">>
            }
        },
        ?assertEqual({error, invalid_adapter_request},
            alang_phase4_workspace_adapter:dispatch(Adapter, Seal, WrongWorkspace, Deadline)),
        ?assertEqual({ok, <<"unchanged">>}, file:read_file(OutsideFile))
    end).

malformed_crashed_and_stuck_sidecars_are_replaced_test() ->
    with_adapter(fun(Adapter, Seal, Root, _Outside) ->
        lists:foreach(
            fun({Fault, Expected}) ->
                ok = alang_phase4_workspace_adapter:inject_test_fault(Adapter, Seal, Fault),
                Result = alang_phase4_workspace_adapter:dispatch(
                    Adapter,
                    Seal,
                    decoded([<<"notes">>, <<(atom_to_binary(Fault))/binary, ".md">>],
                        <<"fault">>, atom_to_binary(Fault)),
                    erlang:monotonic_time(millisecond) + 100
                ),
                ?assertMatch(Expected, Result),
                ?assertEqual(false, filelib:is_file(
                    filename:join([Root, "notes", atom_to_list(Fault) ++ ".md"])
                ))
            end,
            [
                {malformed, {error, {adapter_protocol_error, outcome_unknown}}},
                {crash, {error, {adapter_exit, outcome_unknown}}},
                {hang, {error, {adapter_timeout, outcome_unknown}}}
            ]
        ),
        Status = alang_phase4_workspace_adapter:status(Adapter),
        ?assert(maps:get(restarts, Status) >= 3),
        Recovery = decoded([<<"notes">>, <<"recovered.md">>], <<"recovered">>, <<"recovery">>),
        ?assertMatch({ok, #{disposition := created}},
            alang_phase4_workspace_adapter:dispatch(
                Adapter, Seal, Recovery, erlang:monotonic_time(millisecond) + 2000
            )),
        ?assertEqual({ok, <<"recovered">>},
            file:read_file(filename:join([Root, "notes", "recovered.md"])))
    end).

status_and_events_expose_limits_but_not_secrets_test() ->
    with_adapter(fun(Adapter, Seal, _Root, _Outside) ->
        Secret = <<"prompt-like-secret-content">>,
        ?assertMatch({ok, _}, alang_phase4_workspace_adapter:dispatch(
            Adapter,
            Seal,
            decoded([<<"notes">>, <<"redacted.md">>], Secret, <<"secret-operation">>),
            erlang:monotonic_time(millisecond) + 2000
        )),
        Status = alang_phase4_workspace_adapter:status(Adapter),
        ?assertEqual(beam_sidecar, maps:get(runtime, maps:get(isolation, Status))),
        ?assertEqual(bubblewrap, maps:get(filesystem, maps:get(isolation, Status))),
        ?assertEqual(prlimit, maps:get(resources, maps:get(isolation, Status))),
        Events = alang_phase4_workspace_adapter:events(Adapter),
        ?assertNot(contains_binary(Events, Secret)),
        ?assertNot(contains_binary(Events, <<"secret-operation">>)),
        ?assertNot(contains_reference(Events))
    end).

with_adapter(Fun) ->
    Base = filename:absname(filename:join(["build", "phase-04", "adapter-tests",
        integer_to_list(erlang:unique_integer([positive, monotonic]))])),
    Root = filename:join(Base, "workspace"),
    Outside = filename:join(Base, "outside"),
    ok = filelib:ensure_dir(filename:join([Root, "notes", ".keep"])),
    ok = filelib:ensure_dir(filename:join(Outside, ".keep")),
    BeamDir = filename:dirname(code:which(alang_phase4_workspace_sidecar)),
    Seal = make_ref(),
    Config = adapter_config(Root, BeamDir),
    {ok, Adapter} = alang_phase4_workspace_adapter:start(self(), Config, Seal),
    ok = await_ready(Adapter, 100),
    try Fun(Adapter, Seal, Root, Outside)
    after
        _ = try alang_phase4_workspace_adapter:stop(Adapter, Seal)
            catch
                exit:_StopReason -> ok
            end,
        ok = file:del_dir_r(Base)
    end.

adapter_config(Root, BeamDir) -> #{
    workspace_id => <<"workspace-a">>,
    root => list_to_binary(Root),
    beam_dir => list_to_binary(BeamDir),
    test_faults => true,
    limits => #{
        max_request_bytes => 98304,
        max_response_bytes => 4096,
        max_content_bytes => 65536,
        max_cache_entries => 128,
        request_timeout_ms => 1000,
        address_space_bytes => 2147483648,
        cpu_seconds => 5,
        open_files => 64,
        file_size_bytes => 67108864,
        processes => 4096
    }
}.

decoded(Segments, Content, OperationId) -> #{
    format => alang_decoded_effect_v1,
    registry_version => 1,
    operation => <<"workspace.write">>,
    operation_tag => workspace_write,
    request_schema => alang_workspace_write_v1,
    adapter => workspace_adapter,
    trace_name => <<"effect.workspace.write">>,
    requirement => <<"workspace:write">>,
    resource => #{workspace_id => <<"workspace-a">>, path_segments => Segments},
    arguments => #{
        workspace_id => <<"workspace-a">>,
        path_segments => Segments,
        content => Content,
        operation_id => OperationId
    },
    operation_id => OperationId
}.

contains_reference(Term) when is_reference(Term) -> true;
contains_reference(Term) when is_map(Term) ->
    lists:any(fun contains_reference/1, maps:keys(Term) ++ maps:values(Term));
contains_reference(Term) when is_tuple(Term) -> contains_reference(tuple_to_list(Term));
contains_reference(Term) when is_list(Term) -> lists:any(fun contains_reference/1, Term);
contains_reference(_Term) -> false.

contains_binary(Binary, Binary) -> true;
contains_binary(Term, Binary) when is_map(Term) ->
    lists:any(fun(Value) -> contains_binary(Value, Binary) end,
        maps:keys(Term) ++ maps:values(Term));
contains_binary(Term, Binary) when is_tuple(Term) -> contains_binary(tuple_to_list(Term), Binary);
contains_binary(Term, Binary) when is_list(Term) ->
    lists:any(fun(Value) -> contains_binary(Value, Binary) end, Term);
contains_binary(_Term, _Binary) -> false.

hex(Binary) -> iolist_to_binary([io_lib:format("~2.16.0b", [Byte]) || <<Byte>> <= Binary]).

await_ready(_Adapter, 0) -> error(sidecar_not_ready);
await_ready(Adapter, Attempts) ->
    case maps:get(sidecar_ready, alang_phase4_workspace_adapter:status(Adapter)) of
        true -> ok;
        false -> receive after 5 -> await_ready(Adapter, Attempts - 1) end
    end.
