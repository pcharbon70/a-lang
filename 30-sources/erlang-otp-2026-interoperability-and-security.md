---
title: "Erlang/OTP interoperability and secure coding"
kind: source
created: 2026-07-31
authors:
  - "Erlang/OTP"
published: 2026
citation_key: erlangOtp2026InteroperabilitySecurity
container: "Erlang/OTP 29 documentation"
edition: "OTP 29"
isbn: null
doi: null
url: "https://www.erlang.org/docs/29/system/secure_coding.html"
accessed: 2026-07-31
tags:
  - beam
  - security
  - ports
  - native-code
aliases:
  - "BEAM ports NIFs and security"
---

# Erlang/OTP interoperability and secure coding

## Reference

Erlang/OTP. ERTS documentation on interoperability and security, OTP 29.

- [Secure coding and deployment](https://www.erlang.org/docs/29/system/secure_coding.html)
- [ERTS overview: ports, distribution, and NIFs](https://www.erlang.org/doc/system/overview.html)
- [Native Implemented Functions](https://www.erlang.org/doc/apps/erts/erl_nif.html)
- [TLS distribution](https://www.erlang.org/doc/apps/ssl/ssl_distribution.html)

## Contribution

ERTS offers ports to communicate with isolated operating-system processes and
NIFs to run native code inside the VM. The documentation recommends an
external port program where practical: a faulty NIF can crash or block the VM,
leak memory, or compromise secrets. Dirty schedulers reduce interference from
long-running NIF work but cannot turn native code into an isolation boundary.

Secure-coding guidance also states that distributed Erlang assumes trusted
participating nodes. A cookie is not a sufficient authentication mechanism;
TLS with certificate verification is required for protected distribution.

## Finding

BEAM processes are a fault-isolation mechanism, not a security sandbox. Code in
one node shares the node's authority and finite resources. Untrusted generated
code, tools, parsers, and model servers therefore need a separate OS process,
container, or VM plus a narrow protocol and enforced resource limits.

## Relevance

Model inference and most agent tools should live behind ports or sidecar
services. A capability-aware effect broker should authorize each request,
attach deadlines and idempotency keys, normalize responses, and record an audit
event. NIFs should be reserved for small, trusted, measured operations where
cross-process overhead is demonstrably unacceptable.

Default distributed Erlang is inappropriate as a zero-trust multi-tenant agent
fabric. Distribution across trust domains should use an authenticated
application protocol or carefully configured mutual-TLS nodes with additional
authorization.

## Limits

Ports improve failure isolation but introduce serialization, lifecycle, and
backpressure concerns. TLS authenticates peers but does not implement
fine-grained language capabilities. The agent runtime must supply those policy
semantics itself.

## Derived notes

- [BEAM as the runtime for a native agent language](../20-notes/beam-runtime-for-native-agent-language.md)
- [BEAM runtime for agent languages](../10-maps/beam-runtime-for-agent-languages.md)
