---
title: "Erlang/OTP supervision and release handling"
kind: source
created: 2026-07-31
authors:
  - "Erlang/OTP"
published: 2026
citation_key: erlangOtp2026SupervisionReleases
container: "Erlang/OTP 29 documentation"
edition: "OTP 29"
isbn: null
doi: null
url: "https://www.erlang.org/doc/system/sup_princ.html"
accessed: 2026-07-31
tags:
  - beam
  - fault-tolerance
  - supervision
  - hot-code-loading
aliases:
  - "OTP supervision and upgrades"
---

# Erlang/OTP supervision and release handling

## Reference

Erlang/OTP. OTP design principles and system documentation, OTP 29.

- [Supervisor behaviour](https://www.erlang.org/doc/system/sup_princ.html)
- [`supervisor` module](https://www.erlang.org/doc/apps/stdlib/supervisor.html)
- [Release handling](https://www.erlang.org/doc/system/release_handling.html)
- [Code loading](https://www.erlang.org/doc/system/code_loading.html)

## Contribution

Supervisors start, stop, monitor, and restart child processes according to an
explicit strategy. Restart intensity limits turn repeated failure into a
larger failure instead of an infinite restart loop. OTP releases and the code
server add mechanisms for packaging, version transitions, and limited
coexistence of old and current module code.

## Finding

Supervision gives an agent runtime a declarative fault-containment topology. It
does not give it transaction semantics. Restarting an agent action after a
crash can duplicate an email, payment, deployment, or file mutation that
completed externally before its acknowledgement was recorded.

Likewise, hot code loading makes replacement possible but does not establish
that process state or serialized checkpoints remain meaningful under the new
code.

## Relevance

The new language should make a semantic distinction between process restart,
logical retry, replay, and compensation. External actions need stable
idempotency keys, a durable intent/outbox record, result reconciliation, and
explicit compensation where an action cannot be idempotent.

Language-level agent modules should declare state-version migrations and
whether live instances are pinned, drain and restart, or can adopt a new code
version at a defined call boundary.

## Limits

OTP behaviours are conventions implemented by ordinary modules. A compiler can
generate and use them without making Erlang the source language, but it must
still define the semantics visible to agent-language authors. Supervision
cannot repair corrupted external state or make arbitrary effects repeatable.

## Derived notes

- [BEAM as the runtime for a native agent language](../20-notes/beam-runtime-for-native-agent-language.md)
- [Can BEAM support a native agent language safely?](../40-inquiries/can-beam-support-a-native-agent-language.md)
