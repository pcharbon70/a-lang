---
title: "Erlang runtime processes, signals, scheduling, and memory"
kind: source
created: 2026-07-31
authors:
  - "Erlang/OTP"
published: 2026
citation_key: erlangOtp2026ProcessRuntime
container: "Erlang/OTP 29 documentation"
edition: "OTP 29"
isbn: null
doi: null
url: "https://www.erlang.org/doc/system/ref_man_processes.html"
accessed: 2026-07-31
tags:
  - beam
  - actor-model
  - concurrency
  - garbage-collection
aliases:
  - "BEAM process runtime"
---

# Erlang runtime processes, signals, scheduling, and memory

## Reference

Erlang/OTP. ERTS system documentation on processes and memory, OTP 29.

- [Processes and signals](https://www.erlang.org/doc/system/ref_man_processes.html)
- [Process efficiency](https://www.erlang.org/doc/system/eff_guide_processes.html)
- [Garbage collection](https://www.erlang.org/doc/apps/erts/garbagecollection.html)
- [Memory use](https://www.erlang.org/docs/29/system/memory.html)
- [`erlang` runtime interface](https://www.erlang.org/doc/apps/erts/erlang.html)

## Contribution

ERTS provides lightweight processes with isolated heaps, asynchronous signals,
mailboxes, links, monitors, timers, scheduler threads, and reduction-based
preemption. Garbage collection is primarily per process, using a generational
copying design; large binaries can be reference-counted outside individual
process heaps.

Signal order is guaranteed only for signals sent from the same sender to the
same destination. Selective receive can scan earlier unmatched messages.
Messages may be copied between heaps, and mailboxes can grow unless the
application enforces admission and backpressure.

## Finding

The runtime is an unusually good fit for large numbers of I/O-bound, waiting,
stateful agent sessions. A blocked model request does not require a blocked OS
thread, a failed worker can be observed through a monitor, and per-process GC
reduces global pauses.

Those advantages are operational, not transactional. Mailboxes are neither
durable queues nor bounded channels by default. Distribution failure can lose
messages, and scheduling does not make effect order deterministic.

## Relevance

An agent should normally be a supervision subtree, not one process. Separate
processes can own coordination, input admission, effect execution, policy,
trace emission, and durable checkpointing. This preserves failure locality and
makes mailbox and resource budgets observable.

The value model also requires discipline: arbitrary model or tool strings must
not become atoms because the atom table is finite and atoms are not garbage
collected. Use binaries, integers, and bounded internal registries.

## Limits

Process isolation is inside one VM. A runaway process, atom exhaustion, native
extension failure, or system-wide memory pressure can still affect the whole
node. Latency and fairness claims need measurement under representative agent
workloads, especially large messages, long mailboxes, and bursty tool replies.

## Derived notes

- [BEAM as the runtime for a native agent language](../20-notes/beam-runtime-for-native-agent-language.md)
- [Can BEAM support a native agent language safely?](../40-inquiries/can-beam-support-a-native-agent-language.md)
