---
title: "Phase 4 Workspace Adapter Contract"
kind: note
created: 2026-08-03
maturity: developing
tags:
  - beam
  - capability-security
  - effect-systems
  - sandboxing
aliases: []
---

# Phase 4 Workspace Adapter Contract

## Boundary

The workspace adapter is an external-effect boundary, not part of the A-Lang
compiler or an interpreter for accepted A-Lang source. Its manager is a BEAM
process. It launches a separate Erlang VM that runs only the fixed
`alang_phase4_workspace_sidecar` BEAM module and exchanges bounded,
length-framed Erlang terms over a Port.

Only the broker process holding the manager's process-local seal can dispatch
a request. The sidecar payload contains a normalized workspace identifier,
relative path segments, bytes, an operation identifier, and a remaining
deadline. It never contains a capability reference, artifact grant, prompt,
dynamic module name, or dynamic function name.

## Isolation profile

The manager launches the sidecar through `prlimit` and Bubblewrap. The launch
profile:

- clears the inherited environment and disables networking through a new
  namespace;
- mounts the host filesystem read-only and mounts only the authorized
  workspace root read-write;
- starts a new PID, IPC, UTS, user, cgroup, and session boundary where the
  local kernel permits them;
- bounds address space, CPU seconds, open files, file size, child processes,
  BEAM process heap, request bytes, response bytes, content bytes, cache
  entries, and wall-clock request time;
- starts the fixed sidecar module from the already compiled Phase 4 BEAM
  directory.

Bubblewrap and resource limits are part of the Phase 4 execution requirement.
The manager fails closed when either executable is unavailable; it does not
silently fall back to an unsandboxed Port.

## Filesystem rules

Both the manager and sidecar accept only non-empty relative segments. They
reject separators within a segment, `.` and `..`, NUL bytes, an unexpected
workspace identity, excessive content, and malformed operation identifiers.
The sidecar walks each existing parent with `read_link_info`, rejects symlinks,
requires directory parents, and permits only a missing or regular final file.
Directories, devices, sockets, and other special targets are denied.

Writes use an exclusive temporary regular file in the authorized parent,
`sync`, and a same-directory rename. Bubblewrap makes every path outside the
workspace read-only even if a host process races the semantic checks.

## Operation identity and outcomes

The sidecar caches a digest of each successful request under its bounded
operation identifier. Repeating the same identifier and payload returns the
same artifact digest with `replayed`; reusing an identifier for a different
payload returns `operation_conflict`.

Phase 5 extends this boundary with a reserved `.alang-operations` directory.
The sidecar syncs an intent receipt before mutation and a completion receipt
after the target rename, and supports sealed lookup by operation, path,
payload, and artifact digest. This closes the sidecar-lifetime gap while
preserving the Phase 4 request and result ABI. Generated A-Lang paths cannot
address the receipt directory. See
[effect and capability recovery](../phase-05/effect-and-capability-recovery.md).

A timeout, malformed response, or sidecar exit has an unknown external
outcome. The manager kills and replaces the sidecar, reports that uncertainty,
and never converts it into success or automatically replays the request.

## Evidence and limits

The [adapter tests](alang_phase4_workspace_adapter_tests.erl) exercise the
authorized path, repeat identity, conflicting identity, bypass, traversal,
wrong workspace, symlink escape, special target, malformed frame, crash,
timeout, replacement, output digest, and redaction behavior. The broader
[Phase 4 plan](../../60-planning/01-minimal-proof-of-concept/phase-04-local-capability-broker-and-effect-boundary.md)
requires the next section to prove that loaded generated BEAM code reaches
this boundary only through the broker.

Phase 4's original gate does not itself claim crash recovery. Durable operation
records and reconciliation are Phase 5 claims; hostile multi-user workspace
coordination remains outside the proof of concept.
