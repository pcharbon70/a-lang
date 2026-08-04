---
title: "Phase 6 Mechanically Attenuated Child Task"
kind: note
created: 2026-08-03
maturity: developing
tags:
  - beam
  - capability-security
  - multi-agent-systems
  - otp
aliases: []
---

# Phase 6 Mechanically Attenuated Child Task

## Typed child boundary

`alang_child_spec_v1` carries only the parent and child task identities, fresh
child session and artifact identity, deadline, bounded topic and source draft,
output schema, completion predicate, and a redacted capability summary. Exact
shape validation and recursive authority checks reject grants, references,
process addresses, credentials, and undeclared fields before the child starts.

The dynamic OTP supervisor starts a temporary child worker. A private reply
fence, session identity, task identity, and stable correlation ID bind its
reply. The worker monitors its executor, enforces the absolute deadline,
propagates cancellation, validates the typed result and evidence digest, and
emits only a correlated complete, incomplete, failed, or cancelled result.
Wrong-session replies are discarded and neither the child grant nor node-local
fences appear in the public handle snapshot.

## Mechanical attenuation

The Phase 4 grant store now offers one trusted child restriction operation.
Only the owning parent process may use it. The operation first applies the
existing invocation, resource, argument, budget, and deadline subset checks,
then creates a fresh opaque reference bound to the child PID, fresh session,
child task, artifact, runtime instance, and generation. Child and parent share
the ancestor budget pool, so child use reduces the parent's remaining budget.

The child grant has `combination: deny` and `delegation: deny`; it cannot be
restricted again or combined. Parent, sibling, wrong-presenter, wrong-session,
wrong-artifact, and wrong-generation presentations fail binding checks. Owner
death removes the child grant. Generated A-Lang artifacts retain only the
closed `model.complete` and `workspace.write` effect surface: the BEAM import
allowlist and effect registry expose no grant issue, clone, export, or delegate
primitive.

See the [task orchestration contract](task-orchestration-and-context.md),
[repair and completion gate](repair-and-completion-verification.md),
[Phase 6 roadmap](../../60-planning/01-minimal-proof-of-concept/phase-06-bounded-llm-task-and-subagent-execution.md),
and [Phase 6 implementation index](README.md).
