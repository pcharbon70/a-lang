---
title: "Phase 6 campaign execution runbook"
kind: note
created: 2026-08-10
maturity: seed
tags:
  - evaluation
  - phase-6
  - runbook
  - hosted-campaign
  - ollama
aliases: []
---

# Phase 6 Campaign Execution Runbook

## Purpose

This runbook describes how to execute the frozen 288-cell hosted campaign
authorized by the Phase 6 architecture decision. It is intentionally separate
from the implementation source: it records the operational procedure, the
expected wall-clock budget, the model-swap choreography for a single Ollama
instance, and the acceptance checks that close the Phase 6 gate. It is not
part of the trusted compiler path and is not compiled into a BEAM artifact.

## Schedule shape

The frozen schedule is built from 6 blocks of 48 cells each (seed
`2026080501`), ordered as:

| Block | Model | Repetition | Cells |
| --- | --- | --- | ---: |
| 1 | mixtral | 1 | 48 |
| 2 | mixtral | 2 | 48 |
| 3 | mixtral | 3 | 48 |
| 4 | ornith | 1 | 48 |
| 5 | ornith | 2 | 48 |
| 6 | ornith | 3 | 48 |

Each block covers all 24 corpus cases, each with two alternating
`[alang, json]` conditions. The cases within a block are deterministically
shuffled; the block order itself is fixed.

Total: 288 primary cells. The campaign runner allows at most one retry or
linked replacement per cell, so the maximum observable call count is 576.

## Ollama model-swap constraint

Ollama loads exactly one model into the process address space at a time.
Switching between `ornith-1.0` and `mixtral-8x7b` requires unloading the
current model and loading the target model. The schedule's blocked layout
(mintral first, then ornith) concentrates this choreography to a single
swap mid-campaign rather than interleaving it across trials.

The swap is expected to cost 30-120 seconds for `load` and under 5 seconds for
`unload`, depending on VRAM availability and whether the model is already
pinned to disk cache. The runner does not issue any swap commands itself; the
operator performs the swap between the mixtral and ornith blocks.

## Pre-flight checklist

Complete every item before starting the runner. Mark each as `done` here.

- [ ] Ollama server running and reachable on `localhost:11434`
- [ ] `ollama list` shows `ornith-1.0` and `mixtral-8x7b` both loaded or
  available for pull
- [ ] Both models respond to `/api/tags` and report their exact model IDs in
  the `name` field
- [ ] `ALANG_ALLOW_LIVE_MODEL_CALLS=1` is set in the runner environment
- [ ] No other process holds a lock on the Ollama API port
- [ ] Disk space is sufficient for both models to remain resident (est. 12-16
  GB VRAM / swap)
- [ ] The runner binary or `rebar3` test target that invokes
  `alang_fidelity_offline_campaign:run/1` (or the live campaign entry point)
  is compiled with `-Werror +deterministic`
- [ ] A fresh output directory exists under `build/effectful-source-fidelity/
  phase-06/campaign/` for the campaign journal, observations, and evidence
- [ ] A scratch directory exists for recording manual timing notes (this
  runbook's companion log)
- [ ] The frozen schedule digest matches the one recorded in the Phase 1
  integration evidence (`schedule_digest` under
  `src/effectful-source-fidelity/alang_fidelity_campaign.erl`)

## Execution procedure

### Step 1: warm mixtral

```bash
curl -fsSL http://localhost:11434/api/generate \
  -d '{"model":"mixtral-8x7b","prompt":"ok","stream":false,"num_predict":1}' \
  -o /dev/null
```

This pins `mixtral-8x7b` in VRAM before the first trial. Record the elapsed
time and any error. If the model is not already resident, this warm-up loads
it and should take 30-90 seconds.

### Step 2: start the campaign runner

```bash
ALANG_ALLOW_LIVE_MODEL_CALLS=1 rebar3 eunit --suite \
  src/effectful-source-fidelity/alang_fidelity_campaign_tests.erl \
  --verbose
```

Or, for the full hosted run through the runner:

```bash
ALANG_ALLOW_LIVE_MODEL_CALLS=1 rebar3 as fidelity run-campaign
```

The runner writes a hash-chained journal to
`build/effectful-source-fidelity/phase-06/campaign/` as each cell completes.
Watch the journal file size grow; each cell appends one record. The first
record is `campaign_started` and the last must be `campaign_closed`.

### Step 3: monitor the mixtral block (cells 0-143)

Expected duration for the mixtral block: 48 trials × ~15s average = 10-15
minutes, plus retry budget. Watch for:

- Any `timeout` or `tls_rejected` observations — these count against the 576
  total call ceiling
- Any `sidecar_crash` events — record the timestamp and the trial ID; the
  runner will continue, but the journal must capture the crash signature
- The journal file growing at roughly one entry per trial

If the runner pauses unexpectedly, do not restart. Inspect the journal tail,
note the last recorded `trial_id`, and resume from the same runner process if
possible. A restart invalidates the journal hash chain.

### Step 4: swap to ornith

When cells 0-143 complete and the runner is idle (or at a natural block
boundary), perform the model swap:

1. Unload mixtral:
   ```bash
   curl -X POST http://localhost:11434/api/generate \
     -d '{"model":"mixtral-8x7b","prompt":"unload","stream":false}'
   ```
   Or, if the runner holds the model open and Ollama refuses unload while a
   connection is active, wait for the runner to release it first.

2. Verify unload:
   ```bash
   curl -fsSL http://localhost:11434/api/tags \
     | python3 -c "import sys,json; d=json.load(sys.stdin); names=[m['name'] for m in d.get('models',[])]"; echo "$names"
   ```
   Confirm `mixtral-8x7b` no longer appears in the loaded list.

3. Load ornith:
   ```bash
   curl -fsSL http://localhost:11434/api/pull -d '{"model":"ornith-1.0"}'
   ```
   If the model is already cached, this should return immediately. Otherwise
   expect 1-3 minutes of download + load time.

4. Warm-up ornith with a single token:
   ```bash
   curl -fsSL http://localhost:11434/api/generate \
     -d '{"model":"ornith-1.0","prompt":"ok","stream":false,"num_predict":1}' \
     -o /dev/null
   ```

Record the total swap elapsed time and any errors. A successful swap is a
prerequisite for Step 5.

### Step 5: run the ornith block (cells 144-287)

Restart (or continue) the runner. It must process cells 144-287 against
`ornith-1.0`. The procedure is identical to Step 3, with the model family
reversed.

If the runner does not naturally resume from cell 144, consult the campaign
journal: the runner must reconstruct state from the hash chain before
processing the next cell. If reconstruction fails, the campaign is invalid
and must be restarted from cell 0.

### Step 6: close and validate

The runner appends `campaign_closed` once all 288 primary cells have been
processed (or the call ceiling of 576 has been reached). At that point:

1. Confirm the journal ends with `campaign_closed`.
2. Confirm `completed_primary_cells == 288` in the final journal record. If
   the ceiling was reached first, the campaign is invalid per the policy.
3. Run the offline replay command:
   ```bash
   make build-fidelity-phase-6-evidence
   ```
   This must reproduce the same evidence bytes from the journal alone, with
   no network access.
4. Confirm the bootstrap intervals and final decision match the Phase 6
   decision contract.
5. Confirm Ornith and Mixtral results are reported separately and pooled.

## Timing budget

| Phase | Expected duration | Notes |
| --- | --- | --- |
| Preflight | 5 min | Model probe, env check, disk check |
| Mixtral warm-up | 1-2 min | One-shot token generation |
| Mixtral block (48 cells) | 10-20 min | ~15s/trial average, retries add headroom |
| Model swap | 1-3 min | Unload + load + warm-up |
| Ornith block (48 cells) | 10-20 min | Same as mixtral |
| Validation | 5 min | Replay, score, decision |

Total expected wall-clock time: **30-50 minutes**. Allow 2 hours for
unexpected retries or model pull delays.

## Acceptance criteria for Phase 6 completion

The Phase 6 gate closes only when every item below is satisfied:

- [ ] All 288 primary cells completed (or the campaign was formally declared
  invalid with a recorded reason)
- [ ] No raw HTTP envelopes, credentials, or secret-bearing payloads appear
  in the retained evidence under `build/effectful-source-fidelity/`
- [ ] Ornith and Mixtral results are reported separately and pooled in the
  evidence bundle
- [ ] Offline replay from the journal alone reproduces the evidence bytes
  byte-for-byte
- [ ] The promote/replace/stop rule was applied without post-hoc threshold
  changes
- [ ] The model swap was recorded in the companion log (swap timestamp,
  duration, any errors)
- [ ] All research inquiries, maps, implementation status, and deferred work
  referenced by the decision have been reconciled

## Rollback

If the campaign must be aborted mid-run:

1. Do not delete the journal. The partial journal is itself evidence of a
   failed campaign and must be retained.
2. Record the abort reason, the last processed `trial_id`, and the time of
   abort in the companion log.
3. Do not modify the frozen corpus, contracts, or schedule.
4. Decide whether to restart from cell 0 (full redo) or document the partial
   campaign as invalid (no efficacy conclusion).

## Companion log

Maintain a parallel log file alongside this runbook under
`build/effectful-source-fidelity/phase-06/runbook-log.md` recording:

- Wall-clock start and end times
- Each model swap: timestamp, duration, outcome
- Any non-standard events (crashes, timeouts, retries, network blips)
- Operator notes and deviations from this procedure

This log is not part of the deterministic evidence; it is an operator record.

## Connections

- [Phase 6 planning section](../../60-planning/02-effectful-source-fidelity/phase-06-fidelity-decision-and-roadmap-handoff.md)
- [Fidelity roadmap](../../60-planning/02-effectful-source-fidelity/README.md)
- [Effectful source fidelity implementation](../../src/effectful-source-fidelity/README.md)
- [Phase 1 experiment freeze evidence](../../src/effectful-source-fidelity/phase-01-integration-evidence.md)
