-module(alang_fidelity_campaign).

-export([
    materialize/1,
    render_request/3,
    schedule_digest/1,
    validate_schedule/1
]).

-define(SEED, 2026080501).
-define(PRIMARY_CELLS, 288).

-spec materialize(file:filename()) -> {ok, map()} | {error, term()}.
materialize(Base) ->
    case alang_fidelity_corpus:validate(Base) of
        {ok, _} ->
            Corpus = filename:join(Base, "corpus"),
            ManifestPath = filename:join(Corpus, "corpus-manifest-v1.json"),
            case alang_fidelity_json:decode_file(ManifestPath) of
                {ok, Manifest} -> build_schedule(Base, maps:get(<<"cases">>, Manifest));
                {error, _} = Error -> Error
            end;
        {error, _} = Error -> Error
    end.

-spec render_request(file:filename(), map(), alang | json) -> {ok, binary()} | {error, term()}.
render_request(Base, Case, Condition) when Condition =:= alang; Condition =:= json ->
    try
        PromptPath = filename:join([Base, "campaign", "prompt-template-v1.txt"]),
        SchemaPath = filename:join([Base, "contracts", "alang-task-comprehension-v1.schema.json"]),
        {ok, Template} = file:read_file(PromptPath),
        {ok, Schema} = file:read_file(SchemaPath),
        Ref = case Condition of
            alang -> maps:get(<<"candidate">>, Case);
            json -> maps:get(<<"control">>, Case)
        end,
        Relative = maps:get(<<"path">>, Ref),
        SurfacePath = safe_corpus_path(Base, Relative),
        {ok, Surface0} = file:read_file(SurfacePath),
        Surface = case Condition of
            alang -> visible_alang(Surface0);
            json -> Surface0
        end,
        [Prefix, Suffix] = binary:split(Template, <<"@@TASK_SPECIFICATION@@">>),
        Request = <<
            Prefix/binary,
            Surface/binary,
            Suffix/binary,
            "\n--- BEGIN RESULT SCHEMA ---\n",
            Schema/binary,
            "--- END RESULT SCHEMA ---\n"
        >>,
        ensure(binary:match(Request, <<"\r">>) =:= nomatch, non_lf_line_endings),
        ensure(byte_size(Request) =< 16384, {request_too_large, byte_size(Request)}),
        ensure(binary:match(Request, <<"semantic-sha256">>) =:= nomatch, semantic_digest_leak),
        ensure(binary:match(Request, <<"alang-answer-key-v1">>) =:= nomatch, answer_key_leak),
        {ok, Request}
    catch
        error:{badmatch, Reason} -> {error, {request_materialization_failed, Reason}};
        error:{badkey, Key} -> {error, {request_materialization_failed, {missing_field, Key}}};
        throw:{campaign_error, Reason} -> {error, Reason}
    end.

-spec schedule_digest([map()]) -> binary().
schedule_digest(Cells) ->
    alang_fidelity_json:digest([
        maps:with([
            index,
            trial_id,
            pair_id,
            model_family,
            repetition,
            case_id,
            task_family,
            condition,
            request_digest
        ], Cell)
        || Cell <- Cells
    ]).

-spec validate_schedule(term()) -> {ok, map()} | {error, term()}.
validate_schedule(#{
    format := alang_fidelity_campaign_schedule_v1,
    schedule_seed := ?SEED,
    schedule_digest := Digest,
    cells := Cells
} = Schedule) when is_list(Cells) ->
    try
        ensure(length(Cells) =:= ?PRIMARY_CELLS, invalid_primary_cell_count),
        ensure([maps:get(index, Cell) || Cell <- Cells] =:= lists:seq(0, ?PRIMARY_CELLS - 1), invalid_schedule_indices),
        TrialIds = [maps:get(trial_id, Cell) || Cell <- Cells],
        ensure(length(TrialIds) =:= length(lists:usort(TrialIds)), duplicate_trial_id),
        ensure(Digest =:= schedule_digest(Cells), schedule_digest_mismatch),
        ensure_balanced(Cells),
        {ok, Schedule}
    catch
        throw:{campaign_error, Reason} -> {error, Reason};
        error:{badkey, Key} -> {error, {missing_schedule_field, Key}}
    end;
validate_schedule(_) -> {error, invalid_schedule}.

build_schedule(Base, Cases) ->
    try
        Groups = maps:from_list([{Family, family_cases(Family, Cases)} || Family <- task_families()]),
        {Cells0, _Index} = lists:mapfoldl(
            fun({ModelFamily, Repetition}, StartIndex) ->
                OrderedCases = balanced_cases(Groups, ModelFamily, Repetition),
                build_block(Base, OrderedCases, ModelFamily, Repetition, StartIndex)
            end,
            0,
            [{Model, Repetition} || Model <- [anthropic, openai], Repetition <- lists:seq(1, 3)]
        ),
        Cells = lists:append(Cells0),
        Digest = schedule_digest(Cells),
        Schedule = #{
            format => alang_fidelity_campaign_schedule_v1,
            schedule_seed => ?SEED,
            schedule_digest => Digest,
            cells => Cells
        },
        validate_schedule(Schedule)
    catch
        throw:{campaign_error, Reason} -> {error, Reason};
        error:{badmatch, Reason} -> {error, {campaign_materialization_failed, Reason}}
    end.

build_block(Base, OrderedCases, ModelFamily, Repetition, StartIndex) ->
    {Cells0, EndIndex} = lists:mapfoldl(
        fun({Case, CasePosition}, Index) ->
            Conditions = condition_order(ModelFamily, Repetition, CasePosition),
            PairId = opaque_id({pair, ?SEED, ModelFamily, Repetition, CasePosition}),
            {PairCells, NextIndex} = lists:mapfoldl(
                fun(Condition, CellIndex) ->
                    {ok, Request} = render_request(Base, Case, Condition),
                    TrialId = opaque_id({trial, ?SEED, ModelFamily, Repetition, CellIndex}),
                    Cell = #{
                        format => alang_fidelity_trial_manifest_v1,
                        index => CellIndex,
                        trial_id => TrialId,
                        pair_id => PairId,
                        model_family => ModelFamily,
                        model_id => maps:get(model_id, alang_fidelity_provider_protocol:profile(ModelFamily)),
                        repetition => Repetition,
                        case_id => maps:get(<<"case_id">>, Case),
                        task_family => maps:get(<<"family">>, Case),
                        condition => Condition,
                        request => Request,
                        request_digest => alang_fidelity_json:hex(crypto:hash(sha256, Request)),
                        answer_path => maps:get(<<"path">>, maps:get(<<"answer_key">>, Case))
                    },
                    {Cell, CellIndex + 1}
                end,
                Index,
                Conditions
            ),
            {PairCells, NextIndex}
        end,
        StartIndex,
        lists:zip(OrderedCases, lists:seq(0, length(OrderedCases) - 1))
    ),
    {lists:append(Cells0), EndIndex}.

balanced_cases(Groups, ModelFamily, Repetition) ->
    Shuffled = maps:from_list([
        {Family, shuffle(maps:get(Family, Groups), {ModelFamily, Repetition, Family})}
        || Family <- task_families()
    ]),
    lists:append([
        begin
            Families = rotate(task_families(), (Round + Repetition + model_offset(ModelFamily)) rem 3),
            [lists:nth(Round + 1, maps:get(Family, Shuffled)) || Family <- Families]
        end
        || Round <- lists:seq(0, 7)
    ]).

condition_order(ModelFamily, Repetition, Position) ->
    case (Position + Repetition + model_offset(ModelFamily)) rem 2 of
        0 -> [alang, json];
        1 -> [json, alang]
    end.

shuffle(List, Salt) ->
    Seed = seed_tuple({?SEED, Salt}),
    State0 = rand:seed_s(exsss, Seed),
    {Decorated, _State} = lists:mapfoldl(
        fun(Item, State) ->
            {Value, Next} = rand:uniform_s(16#3fffffffffffffff, State),
            {{Value, maps:get(<<"case_id">>, Item), Item}, Next}
        end,
        State0,
        List
    ),
    [Item || {_Value, _Id, Item} <- lists:sort(Decorated)].

seed_tuple(Term) ->
    <<A:58, B:58, C:58, _/bitstring>> = crypto:hash(sha256, term_to_binary(Term, [deterministic])),
    {A + 1, B + 1, C + 1}.

family_cases(Family, Cases) ->
    Selected = [Case || Case <- Cases, maps:get(<<"family">>, Case) =:= Family],
    ensure(length(Selected) =:= 8, {invalid_family_case_count, Family}),
    Selected.

ensure_balanced(Cells) ->
    lists:foreach(
        fun(Model) ->
            ModelCells = [Cell || Cell <- Cells, maps:get(model_family, Cell) =:= Model],
            ensure(length(ModelCells) =:= 144, {unbalanced_model, Model}),
            lists:foreach(fun(Condition) ->
                Count = length([Cell || Cell <- ModelCells, maps:get(condition, Cell) =:= Condition]),
                ensure(Count =:= 72, {unbalanced_condition, Model, Condition})
            end, [alang, json]),
            lists:foreach(fun(TaskFamily) ->
                Count = length([Cell || Cell <- ModelCells, maps:get(task_family, Cell) =:= TaskFamily]),
                ensure(Count =:= 48, {unbalanced_task_family, Model, TaskFamily})
            end, task_families())
        end,
        [anthropic, openai]
    ).

visible_alang(Binary) ->
    Marker = <<"// model-visible-begin\n">>,
    case binary:split(Binary, Marker) of
        [_Metadata, Visible] -> Visible;
        _ -> throw({campaign_error, missing_model_visible_marker})
    end.

safe_corpus_path(Base, Relative) when is_binary(Relative) ->
    Corpus = filename:absname(filename:join(Base, "corpus")),
    Path = filename:absname(filename:join(Corpus, binary_to_list(Relative))),
    ensure(lists:prefix(Corpus ++ "/", Path), unsafe_corpus_path),
    Path.

opaque_id(Term) -> alang_fidelity_json:digest(Term).

task_families() -> [
    <<"attenuated-delegation">>,
    <<"repair-and-publish">>,
    <<"single-model-artifact">>
].

model_offset(anthropic) -> 0;
model_offset(openai) -> 1.

rotate(List, 0) -> List;
rotate([Head | Rest], Count) -> rotate(Rest ++ [Head], Count - 1).

ensure(true, _Reason) -> ok;
ensure(false, Reason) -> throw({campaign_error, Reason}).
