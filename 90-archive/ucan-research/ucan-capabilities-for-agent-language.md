---
title: "UCAN capabilities for A-Lang: a deep dive"
kind: note
created: 2026-07-31
maturity: developing
tags:
  - agent-programming
  - authorization
  - beam
  - capability-security
  - ucan
aliases:
  - "UCAN for A-Lang"
  - "UCAN capability deep dive"
---

# UCAN capabilities for A-Lang: a deep dive

> **Archived 2026-07-31:** UCAN was removed from the active A-Lang
> architecture and proof-of-concept scope. This synthesis is retained only as
> a reversible record and is not part of the current implementation plan.

## Executive conclusion

UCAN is a strong candidate for A-Lang's **portable delegation and invocation
proof layer**, but it is not a complete capability system for the language.
The right fit is a layered one:

1. A-Lang's type-and-effect system states what an operation may do.
2. A task's `requires` clause computes the authority it needs.
3. A trusted capability broker finds or issues a short-lived UCAN Delegation
   proving that one runtime principal has that authority.
4. A typed effect request becomes a signed UCAN Invocation with concrete
   arguments and a proof path.
5. A reference monitor validates the UCAN chain, applies stateful A-Lang
   policy, records durable intent, and only then calls the effect adapter.

UCAN contributes properties that are particularly useful for agents:

- signed grants that can cross process, host, and organizational boundaries;
- explicit provenance from resource subject to current invoker;
- attenuation by command, argument policy, audience, and time;
- content-addressed proofs that can travel with work;
- decentralized validation without a central authorization-server lookup on
  every action;
- a clean distinction between being authorized and requesting execution.

It does **not** contribute several properties A-Lang still needs:

- static effect checking or capability-requirement inference;
- confinement or a protocol-level “may not redelegate” restriction;
- canonical semantics for files, URLs, accounts, tools, or other resources;
- stateful budgets, rate limits, approvals, or contextual policy;
- immediate global revocation under partitions;
- replay-safe and exactly-once external effects by itself;
- cancellation, compensation, durable workflow recovery, or OS isolation;
- proof that an LLM understood the grant it attempted to exercise.

The design recommendation is therefore: **adopt a narrow, version-pinned UCAN
profile behind the A-Lang broker, never expose signing keys or a general UCAN
wallet to the model, and preserve A-Lang's own capability IR as the source of
semantic truth.**

## Scope and decision standard

This study asks whether the current UCAN protocol can turn the declarative
capability ideas in the
[task-language synthesis](../../20-notes/llm-agent-task-languages-deep-dive.md), the
[categorical design](../../20-notes/set-and-category-principles-for-agent-programming-language.md),
and the [BEAM runtime proposal](../../20-notes/beam-runtime-for-native-agent-language.md)
into enforceable runtime authority.

“Fits” means more than being able to serialize a permission. A suitable layer
must:

- preserve least authority through multi-step and multi-agent delegation;
- bind concrete effect requests to authorized principals and arguments;
- allow validation at the executor without trusting model-generated prose;
- work across BEAM processes, nodes, sidecars, and external services;
- provide inspectable provenance for audit and recovery;
- have failure semantics that remain safe under replay, delay, partition, and
  stale state;
- admit a practical implementation whose protocol and semantic risk can be
  tested independently.

This is a design analysis of official specifications and implementations, not
a security audit. Protocol claims below are sourced; A-Lang mappings and
architecture are proposals unless identified otherwise.

## 1. Version scope: “UCAN” is not one stable format

Version precision is mandatory. The table below compares the official
[specification](https://github.com/ucan-wg/spec),
[sub-specifications](https://github.com/ucan-wg), and implementation
repositories as read on 2026-07-31; the detailed evidence is preserved in the
[implementation source note](ucan-wg-2026-implementations-and-container.md).

| Component | Repository state | Role in this design |
| --- | --- | --- |
| high-level UCAN | main says 1.0.0; newest tag is `v1.0-rc.1` | normative model, pinned by commit |
| Delegation | main says 1.0.0 | required grant format |
| Invocation | main says 1.0.0 | required request format |
| Revocation | `v1.0.0-rc.1` | optional, maturity-gated extension |
| Promise/Receipt | incomplete or older work | not a basis for A-Lang durability |
| container | separate 0.1-era repository | possible proof-bundle transport |
| `rs-ucan` | active; claims RC.1; explicitly unaudited | prototype candidate |
| `go-ucan` | active release; core specs implemented | validator oracle candidate |
| `ts-ucan` | older 0.8.1 JWT model | incompatible; do not use for version 1 |

The current specification is a DAG-CBOR, CID-addressed envelope. Older
tutorials commonly describe JWTs with `att`, `with`, and `can` fields. That is
not a cosmetic syntax difference; it is an older protocol model. A-Lang should
name its profile, for example:

```text
alang-ucan-profile/0
  ucan spec:        github main commit <pinned-sha>
  delegation type: ucan/dlg@1.0.0
  invocation type: ucan/inv@1.0.0
  DID methods:      did:key with Ed25519 initially
  digest:           sha2-256
  limits:           profile-defined
  revocation:       disabled or separately versioned
```

Persisted grants and invocations must carry the A-Lang profile identifier.
Without it, a future library upgrade could silently change validation or
encoding semantics.

There is already a concrete issue for the profile to resolve. The current
Invocation prose orders `prf` from the root Delegation toward the invoker; the
current Go implementation documents and walks the invocation-facing leaf
toward the root. This may be a documentation or implementation defect, but it
is enough to prevent treating either implementation as an unquestioned oracle.
The first profile needs an official clarification or fixture-backed canonical
choice and negative tests for the opposite order.

## 2. A precise vocabulary for A-Lang

Existing research used “capability” in several related senses. UCAN makes that
ambiguity dangerous, because a declared need, a signed grant, a tool handle,
and a successful authorization decision are not interchangeable.

| Term | Meaning | Owned by |
| --- | --- | --- |
| **effect** | a named family of observable operations, such as `workspace.write` | A-Lang type system |
| **capability requirement** | a declarative upper bound on authority a task needs | source program and compiler |
| **grant** | signed evidence that a principal holds some authority | UCAN Delegation and proof store |
| **invocation** | a signed request with concrete arguments to exercise authority | broker and UCAN Invocation |
| **decision** | allow, deny, or require escalation at execution time | reference monitor |
| **policy** | restrictions evaluated over invocation arguments | UCAN policy plus A-Lang policy engine |
| **effect result** | durable observation of what execution actually produced | A-Lang journal and adapter |

This separation resolves the earlier phrase “capabilities as a declarative
concept.” The **requirement** is declarative; the **grant** is cryptographic;
the **decision** is contextual; the **effect** is operational.

A tool being installed is not authority to use it. A valid grant is not an
instruction to act. A syntactically valid invocation is not proof that its
external resource relationship is legitimate. A successful decision is not
proof that the external effect completed.

## 3. UCAN's core model

### 3.1 Certificate capabilities

The current [UCAN specification](https://github.com/ucan-wg/spec) models a
capability as:

```text
subject × command × policy
```

The subject is a DID anchoring the authority chain. The command is a
slash-delimited hierarchical name. The policy is a small predicate tree over
invocation arguments. An issuer signs a Delegation to an audience, who may
then attenuate and delegate onward.

This is a certificate-capability model related to SPKI/SDSI. It differs from an
object-capability system: possession and validation of a certificate chain can
cross disconnected contexts, but the token alone does not enforce reference
locality or confinement.

### 3.2 Delegation

The version-1 [Delegation specification](https://github.com/ucan-wg/delegation)
contains the following authority-bearing shape, shown here as diagnostic
pseudodata rather than canonical wire bytes:

```text
Delegation {
  iss:   DID             # signer/delegator
  aud:   DID             # delegate
  sub:   DID | null      # authority subject
  cmd:   CommandPath
  pol:   Policy[]
  nonce: Bytes
  nbf:   Time?           # optional
  exp:   Time | null
  meta:  Data?           # signed, not authority
}
```

The audience of each proof must match the issuer of the next link. All links
must apply to the same effective subject, cover the invoked command, be valid
at execution time, and have valid signatures. Ancestor policies remain in
force; a descendant can add another conjunct but cannot discard the
restrictions it inherited.

The command tree provides simple syntactic attenuation:

```text
/
└── workspace
    ├── read
    └── write
        ├── create
        └── replace
```

A grant for `/workspace/write` covers the two nested commands but not
`/workspace/read`. A grant for `/workspace/write/create` does not expand to
`/workspace/write`.

### 3.3 Invocation

The [Invocation specification](https://github.com/ucan-wg/invocation) is
deliberately separate from Delegation. It represents a request to do work:

```text
Invocation {
  iss:   DID             # invoker
  sub:   DID             # authority subject/default executor
  aud:   DID?            # another executor, when needed
  cmd:   CommandPath
  args:  Map
  prf:   CID[]           # spec order; profile must resolve Go discrepancy
  nonce: Bytes
  exp:   Time | null
  iat:   Time?
  cause: ReceiptCID?
  meta:  Data?
}
```

All proof policies are evaluated against the concrete `args`. The proof list
identifies one direct path from subject to invoker; its canonical ordering is a
profile-blocking interoperability question described above. A random nonce
gives a non-idempotent task a unique content-derived identity; an empty nonce
is recommended for an intentionally idempotent task. Short invocation
expiries constrain replay windows.

### 3.4 Execution-time validation

The executor must validate at the moment it attempts the action. At minimum it
must verify:

1. canonical decoding, hashes, signatures, and supported algorithms;
2. DID-to-verification-key resolution;
3. proof availability and proof-chain principal alignment;
4. subject consistency and command coverage;
5. the intersection of all time bounds;
6. every policy conjunct against canonical invocation arguments;
7. applicable revocations;
8. external-resource ownership and command-specific semantics;
9. replay and idempotency rules;
10. local stateful policy before the effect adapter is called.

Cryptography establishes who signed which bytes. It cannot establish that a
filesystem URI belongs to the subject, that a URL is safe after redirects, or
that the current purchase remains within a cumulative budget. Those are
executor responsibilities.

## 4. The set-theoretic fit

UCAN's attenuation model fits the set-based portion of the proposed language
cleanly.

Let `I` be the set of well-typed, canonical A-Lang effect invocations. A
capability `c` denotes the subset it authorizes:

```text
⟦c⟧ ⊆ I
```

Define attenuation as subset inclusion:

```text
c′ ≤ c  iff  ⟦c′⟧ ⊆ ⟦c⟧
```

The three main restriction dimensions have direct set interpretations:

- a child command denotes a subset of a parent command's invocations;
- adding a policy conjunct intersects the authorized set;
- intersecting validity intervals narrows the times at which an invocation is
  authorized.

For a proof chain `d₀ … dₙ`, effective authority is approximately:

```text
Chain(d₀ … dₙ)
  = CommandCoverage(d₀ … dₙ)
  ∩ Policy(d₀)
  ∩ …
  ∩ Policy(dₙ)
  ∩ Validity(d₀)
  ∩ …
  ∩ Validity(dₙ)
```

Across independent valid proof paths, the principal's provable authority is a
union. This distinction matters:

- **within one chain:** restrictions accumulate by intersection;
- **among independent grants:** usable authority accumulates by union.

[SPKI's tuple-reduction theory](https://www.rfc-editor.org/rfc/rfc2693.html)
makes the same narrowing intuition explicit through authorization and validity
intersections. UCAN adds a contemporary encoding, DIDs, invocations, and its
policy language.

### 4.1 Categorical interpretation

The signed grant should not be confused with the task morphism. A useful
judgment is:

```text
Γ ; R ⊢ task : A ~{E}-> B
```

where `E` is the effect row and `R` is the inferred capability requirement.
At deployment, an environment supplies a grant `G` and the checker requires:

```text
⟦R⟧ ⊆ ⟦G⟧
```

Sequential task composition generally combines required authority by union:

```text
requires(g ∘ f) ⊆ requires(f) ∪ requires(g)
```

The inclusion allows optimization when the tasks share authority. Parallel
composition needs more than union: handlers must also prove that the effects
do not contend for exclusive or order-sensitive resources.

Delegation composition should be associative **up to observable validation**:
changing the grouping of a proof-chain construction must not change the set of
accepted invocations, its effective validity interval, or its provenance.
Literal token bytes may differ because issuance nonce and metadata differ.

This gives category/set principles a concrete job: specify attenuation and
composition laws for the authorization interpreter without claiming that
effectful agent behavior is merely a total function in `Set`.

## 5. Mapping A-Lang to UCAN

| A-Lang construct | UCAN representation | Remaining runtime work |
| --- | --- | --- |
| effect operation | command namespace | adapter semantics and interception |
| resource parameter | subject and normalized policy argument | ownership and canonicalization |
| `requires` clause | capability requirement, then Delegation | matching and grant issuance |
| task/subagent identity | session DID as audience/invoker | key custody and lifecycle |
| effect call | Invocation `cmd` and `args` | durable intent and execution |
| parent-to-child authority | attenuated Delegation | non-redelegation rule when desired |
| deadline | `nbf`/`exp` intersection | clock policy and workflow deadline |
| static constraint | UCAN policy where expressible | capability-specific type checking |
| budget/rate/approval | not safely represented by token alone | online stateful policy store |
| cancellation | no direct equivalent | scheduler and journal |
| grant withdrawal | Revocation of proof CID | dissemination and cache invalidation |
| compensation | no direct equivalent | effect-specific compensating workflow |
| completion evidence | not established by Delegation/Invocation | verifier and durable result record |

### 5.1 Illustrative source language

An A-Lang program should declare meaning without constructing tokens:

```text
resource Workspace(id: WorkspaceId)

effect workspace.write(
  workspace: WorkspaceId,
  path: CanonicalRelativePath,
  content: Bytes
) -> ArtifactRef

task write_research_note(input: Research) -> ArtifactRef
  requires workspace.write {
    workspace = input.workspace
    path within "20-notes/"
    max_bytes = 262_144
  }
  ensures result.hash is present
{
  workspace.write(
    input.workspace,
    "20-notes/" ++ input.slug ++ ".md",
    render(input)
  )
}
```

The compiler produces a typed requirement, not a bearer token:

```text
Requirement {
  effect: workspace.write,
  subject_kind: Workspace,
  constraints: {
    workspace_id: input.workspace,
    path_prefix: ["20-notes"],
    max_bytes: 262144
  }
}
```

At task spawn, a trusted broker can map that requirement into a profile-defined
UCAN command and policy:

```text
Delegation {
  iss: broker_did,
  aud: task_session_did,
  sub: workspace_authority_did,
  cmd: "/workspace/write",
  pol: [
    ["==", ".workspace_id", expected_workspace_id],
    ["==", ".path.root", "workspace"],
    ["==", ".path.segments.0", "20-notes"],
    ["<=", ".content_size", 262144]
  ],
  exp: short_deadline,
  nonce: random_bytes
}
```

The exact selector operators must be limited to those in the pinned profile.
More importantly, the policy should operate on canonical structured arguments,
not on a raw filesystem string. The broker resolves path segments, rejects
`..`, controls symlink traversal, and opens the file relative to a workspace
directory handle. A naive glob such as `20-notes/*` is not a filesystem
sandbox.

The agent's effect call then becomes an Invocation signed by the session signer
after type validation:

```text
Invocation {
  iss: task_session_did,
  sub: workspace_authority_did,
  aud: workspace_executor_did,
  cmd: "/workspace/write",
  args: {
    workspace_id: expected_workspace_id,
    path: {root: "workspace", segments: ["20-notes", "ucan.md"]},
    content_digest: digest,
    content_size: 8450
  },
  prf: [root_to_broker_cid, broker_to_session_cid],
  nonce: random_bytes,
  exp: near_term_deadline
}
```

Large or secret content need not be embedded in the authorization object. The
invocation can bind a digest to content transmitted over a confidential,
integrity-protected channel.

## 6. Proposed BEAM architecture

```text
A-Lang source
    │ type/effect/capability checking
    ▼
typed task IR ───────────────► capability manifest
    │                                  │
    │ spawn                            ▼
    │                         trusted capability broker
    │                         ├─ key custody / signer
    │                         ├─ proof store / resolver
    │                         ├─ attenuation
    │                         └─ policy and budget state
    ▼                                  │ opaque CapabilityRef
BEAM task process ◄────────────────────┘
    │ typed effect intent
    ▼
effect gateway
    ├─ canonicalize arguments
    ├─ construct/sign Invocation
    ├─ validate chain + revocation + replay
    ├─ check dynamic local policy
    ├─ record durable intent
    ▼
port / sidecar / resource executor
    │ result
    ▼
durable result + verifier + audit event
```

### 6.1 Keep authority outside the language model

The LLM should receive a summarized, typed view such as:

```text
available: workspace.write(path under 20-notes/, ≤256 KiB)
expires:   in 8 minutes
```

It should not receive:

- a private signing key;
- a general token wallet;
- an unrestricted proof store;
- a root or Powerline grant;
- an API key wrapped only in prompt instructions;
- an operation for producing arbitrary Delegations.

The model emits a typed effect intent. The broker decides whether that intent
matches the task requirement and available authority, constructs the
Invocation, and signs through a key service. An opaque `CapabilityRef` in the
BEAM process names broker-held state; it is not itself a secret with ambient
meaning outside the broker.

### 6.2 Principal design

Do not identify a principal directly with a BEAM PID. PIDs are runtime routing
identities, not durable cryptographic principals, and distributed PIDs inherit
the trust assumptions of Erlang distribution.

A workable hierarchy is:

```text
offline or hardware-backed user root DID
  └─ device / deployment broker DID
      └─ ephemeral agent-session DID
          └─ task or tightly scoped subagent DID, when needed
```

Use `did:key` and Ed25519 for the smallest initial interoperability profile.
Session keys should be generated and retained by the broker or an isolated
signer. Deleting an ephemeral key prevents new invocations but does not revoke
already signed delegations or invocations; expiry, replay control, and
revocation remain necessary.

### 6.3 Subagents and nondelegable authority

UCAN's default delegation model allows a delegate to subdelegate. It has no
general confinement guarantee. A-Lang can nevertheless prevent ordinary model
subagents from redelegating by architecture:

- the broker owns each subagent's signing key;
- the agent can request only typed effect invocations;
- the broker exposes no arbitrary “sign delegation” operation;
- child grants are derived only from compiler-calculated requirements;
- each child receives a narrower command/policy/time envelope.

This is broker-enforced confinement, not a UCAN protocol property. If an
external delegate controls its own signing key, it can further delegate within
its UCAN authority without notifying A-Lang. That gap must be explicit at
trust-boundary crossings. SPKI's delegation-control bit demonstrates that a
different certificate design can express this restriction; current UCAN does
not.

Avoid `sub: null` Powerline grants for general agents. Their legitimate role is
closer to connecting a user's stable identity across controlled devices. Avoid
the root command `/` except in an offline or tightly governed root context.

### 6.4 Proof storage and transport

Version-1 invocations refer to Delegations by CID. The executor therefore
needs a resolver. A-Lang should support two bounded modes:

1. an attached container with all proofs needed for this invocation;
2. a local or mutually authenticated proof service keyed by CID.

Validation must fail closed when a proof is missing. Before decoding or
resolving, enforce limits on:

- token and container byte size;
- decompressed size;
- chain depth and number of alternate chains;
- policy tree depth, predicates, selectors, and argument size;
- DID document and proof-resolution time;
- algorithms and DID methods;
- total validation CPU and memory.

Compute CIDs from received canonical bytes. Do not trust a sender-provided
mapping from claimed CID to content.

## 7. Stateful policy remains in the reference monitor

UCAN policy is intentionally a small predicate language over invocation
arguments. That makes it deterministic and cacheable, but it cannot safely be
the whole policy system.

| Constraint | Token-local? | Enforcement location |
| --- | --- | --- |
| exact workspace ID | yes | UCAN policy and typed decoder |
| normalized path prefix | partly | canonicalizer plus policy |
| maximum bytes for this call | yes | UCAN policy and adapter |
| cumulative spend this month | no | transactional budget store |
| no more than ten calls/minute | no | online rate limiter |
| approval from current reviewer | no | approval service/reference monitor |
| resource still belongs to subject | no | executor/resource registry |
| URL remains in scope after redirects | no | network adapter on each hop |
| destination is not a symlink escape | no | filesystem adapter |
| effect is reversible | semantic | effect catalog and workflow |

Putting a claimed dynamic fact into `args`, such as
`"day_of_week": "friday"`, does not make it trustworthy merely because a
policy compares it. The executor must derive or validate authoritative facts.

For externally delegated resources, A-Lang needs a registry mapping each
subject-and-command namespace to:

- a typed argument schema;
- canonical resource identification rules;
- ownership verification;
- policy interpretation;
- effect adapter;
- idempotency and compensation behavior;
- audit redaction rules.

This registry is part of the trusted computing base.

## 8. Revocation, replay, cancellation, and compensation

These four mechanisms solve different problems.

### Revocation

The current [UCAN Revocation specification](https://github.com/ucan-wg/revocation)
invalidates a particular Delegation CID in a proof path. The revocation set is
immutable, monotonic, and potentially eventually consistent. Another
independent proof path may still authorize the same operation.

Each executor needs a subject-scoped revocation store. Cached validation
results need a reverse dependency index from proof CID to every decision
derived from it. A received revocation invalidates those cached decisions.

For high-impact effects such as payment, secret release, or external
communication, eventual revocation is insufficient as the only emergency
control. Use very short grants and an online broker decision at execution.

### Replay

Expiry reduces a replay window but does not eliminate replay. A non-idempotent
invocation needs a unique nonce and an executor-side seen-task store. The store
must be durable across BEAM process restarts and, if several executors share a
resource, coordinated at the resource's consistency boundary.

For an idempotent command, stable task identity can support result reuse, but
the adapter must actually implement the promised idempotency. HTTP method
names, model confidence, or retry intention are not enough.

### Cancellation

Cancellation tells the A-Lang scheduler not to start or continue pending work.
It does not invalidate a grant and cannot recall an invocation already
accepted by an external executor.

### Compensation

Compensation is a domain-specific effect that attempts to offset a completed
effect, such as refunding a payment or creating a reverting commit. It is not
revocation and often cannot restore the prior world exactly.

A durable effect gateway should use a state machine such as:

```text
planned → authorized → intent-recorded → submitted → observed
                                      ↘ uncertain → reconciled
```

UCAN evidence belongs in the `authorized` and `submitted` records. A-Lang's
journal owns transitions and recovery.

## 9. Security analysis

### 9.1 What UCAN improves

- **Least-authority delegation:** a broker can issue per-task grants instead of
  sharing a long-lived API key.
- **Provenance:** the proof path records who delegated to whom.
- **Offline/local validation:** an executor can verify signatures and policies
  without a central authorization server, if it has proofs and relevant state.
- **Key separation:** authority can be shared without moving a root private
  key.
- **Cross-runtime interoperability:** grants are not tied to one BEAM process or
  one language implementation.
- **Auditable invocations:** signed concrete arguments make the requested
  operation attributable to an invoker.

### 9.2 What remains trusted

“Trustless” is best read here as “self-verifying without a central
authorization server.” The system still trusts:

- the subject's initial authority claim;
- the DID method and key-resolution implementation;
- secure key generation, storage, and signing;
- clock bounds;
- canonical encoding, hashing, and signature libraries;
- command and policy semantics;
- external-resource ownership checks;
- the proof resolver and revocation dissemination path;
- the executor and its complete interception of effects;
- the adapter's idempotency, isolation, and result reporting.

### 9.3 Principal threats and controls

| Threat | Consequence | Required control |
| --- | --- | --- |
| key exposed to model or tool | arbitrary signed invocations/delegations | isolated signer; opaque handles |
| overbroad `/` or Powerline grant | authority amplification across tasks | deny in normal profiles |
| semantic resource confusion | valid proof used against wrong object | typed canonical IDs and executor ownership check |
| path/URL normalization mismatch | policy bypass | one canonicalizer shared by policy and adapter |
| missing proof bounds | memory/CPU or resolution denial of service | byte, depth, time, and algorithm limits |
| stale revocation cache | post-revocation use | short TTL and online checks for high risk |
| alternate proof path | apparent revocation does not remove authority | authority graph and path-aware UI |
| invocation replay | duplicate non-idempotent effect | nonce store plus adapter idempotency |
| confused deputy at broker | agent borrows broker ambient power | manifest-bound grant selection |
| token/log disclosure | graph, DID, resource, or policy leakage | minimization, encryption, structured redaction |
| library/spec drift | inconsistent validation across nodes | pinned profile, fixtures, differential tests |
| validator bug in ERTS | VM crash or compromise | port/sidecar before NIF |

UCAN proofs can reveal principals, relationships, commands, policy arguments,
and graph topology. Full proof chains should be protected as authorization
records, not copied into prompts or verbose logs. User-facing explanations can
be generated from redacted, typed summaries.

### 9.4 Wrapped ambient authority

If an A-Lang adapter ultimately holds a broad OAuth token or cloud API key,
UCAN narrows authority **inside** the A-Lang system but does not narrow what the
external service would accept from a compromised adapter. The adapter remains
a powerful deputy. Prefer resource-scoped downstream credentials where the
external service supports them, and isolate each high-authority adapter.

## 10. Comparison with alternatives

| Approach | Strength | Weakness for A-Lang |
| --- | --- | --- |
| prompt-only permissions | trivial to describe | no hard enforcement or portable proof |
| central ACL/RBAC service | immediate centralized updates and mature operations | central dependency; awkward ad hoc delegation |
| OAuth-style access token | broad service compatibility | delegation and resource semantics vary; often bearer-oriented |
| macaroon-style caveats | compact attenuation through added caveats | different identity/proof-chain and invocation model |
| object capabilities | strong reference-local reasoning and possible confinement | harder across partitions and heterogeneous services |
| SPKI-style certificates | explicit authorization chains and delegation control | old ecosystem and no A-Lang invocation model |
| UCAN | signed distributed delegation plus distinct invocation | no confinement; version and implementation maturity risks |
| broker-only opaque handle | simple local enforcement and revocation | not portable beyond the broker's trust domain |

UCAN and broker handles are complementary rather than mutually exclusive. The
BEAM process should normally hold an opaque local handle; the broker materializes
UCAN only at a boundary where portable proof is useful.

## 11. Implementation recommendation

### 11.1 Start with a deliberately small profile

The first profile should support:

- Ed25519 `did:key` principals only;
- Delegation and Invocation only;
- a fixed A-Lang-owned command registry;
- a safe subset of policy operators and selectors;
- mandatory finite expiries;
- no Powerline and no `/` grants;
- one direct proof chain with a conservative depth bound;
- attached proof containers or a local CID store;
- mandatory replay tracking for non-idempotent commands;
- A-Lang-owned revocation/status checks for high-risk effects.

Do not depend initially on Promise, Receipt, or the RC Revocation format for
workflow correctness. Add each through a versioned profile extension after its
semantics and implementation pass tests.

### 11.2 Isolate the implementation

Use an external Rust or Go validator/signer through a framed BEAM port or
sidecar API:

```text
validate(profile, now, invocation_bytes, proof_bundle, local_facts)
  -> allow {subject, invoker, command, canonical_args, proof_cids, expires}
   | deny {stable_reason_code}
```

The validator should return a normalized authorization fact, never directly
execute the effect. The BEAM reference monitor consumes that fact, applies
stateful policy, and records intent.

Do not begin with a NIF. The current
[Rust implementation](https://github.com/ucan-wg/rs-ucan) explicitly says it
is not formally audited, and hostile or malformed authorization input is
exactly the sort of parser/cryptography boundary that should not be able to
crash the VM. A native BEAM implementation can follow only if interoperability
and profiling justify it.

### 11.3 Keep A-Lang's IR independent

The compiler's requirement representation should remain typed and richer than
UCAN policy. A backend maps it to:

- UCAN for portable delegation;
- a local broker handle for same-node execution;
- an ACL or OAuth scope when integrating a legacy service;
- a simulator fact for dry runs;
- a human-readable approval request.

That is the functorial-interpreter idea in practical form: one semantic
requirement, several concrete authorization interpretations. UCAN is one
backend, not the language's abstract syntax.

## 12. Property-based and differential validation

The categorical and set laws produce useful executable properties. Generate
subjects, command trees, policies, validity intervals, proof graphs, typed
arguments, invocations, and revocation sets. On finite generated invocation
domains, check:

### Attenuation laws

```text
child ≤ parent
adding_policy(c, p) ≤ c
narrow_time(c, t) ≤ c
```

- a child command never accepts an invocation rejected only because it lies
  outside the parent command;
- adding a policy cannot expand the accepted set;
- narrowing time cannot expand the accepted set;
- identity delegation preserves accepted invocations;
- command coverage is reflexive and transitive.

### Composition laws

- chain composition is associative up to the validation observation;
- accumulated policy is associative, commutative, and idempotent where the
  policy semantics are pure conjunction;
- effective validity intersection is associative, commutative, and
  idempotent;
- independent authority union is associative, commutative, and idempotent;
- a descendant cannot remove an ancestor restriction.

### Encoding and interoperability laws

- canonical encode/decode round trips preserve semantics;
- equivalent canonical bytes produce the same CID;
- changed authority-bearing bytes change signature validation and normally the
  CID;
- Rust, Go, and A-Lang validators agree on shared positive and negative
  fixtures, including proof order;
- unsupported algorithms, DID methods, fields, and version tags fail closed.

### Stateful model properties

- a seen non-idempotent invocation cannot execute twice;
- a revoked proof path never validates once the executor has observed the
  revocation;
- an alternate unrevoked path can still validate, making that behavior visible
  rather than surprising;
- expiry and revocation invalidate dependent cache entries;
- killing and restarting a BEAM worker between journal transitions does not
  duplicate an acknowledged effect;
- path and URL canonicalization give the policy engine and adapter identical
  resource identities.

PropEr can run state-machine and generative tests on BEAM. The Rust
implementation's property tests and the Go implementation can serve as
independent comparison points. Agreement does not prove the specification, but
disagreement supplies high-value counterexamples.

## 13. Prototype and evaluation program

### Phase 0 — freeze semantics

1. Pin exact specification commits and define the A-Lang profile.
2. Define five commands: workspace read/write, web fetch, message send, and
   budgeted model call.
3. Define typed canonical arguments and external-resource ownership rules.
4. Write positive and adversarial fixtures before integrating a library.

### Phase 1 — portable proof

1. Implement session DID creation in an isolated signer.
2. Issue a short-lived workspace grant from broker to agent session.
3. Construct an Invocation for a typed write effect.
4. Validate it independently in Rust/Go and the A-Lang gateway.
5. Demonstrate denial for wrong command, path, audience, time, signature, and
   missing proof.

### Phase 2 — BEAM broker

1. Give each task process only an opaque `CapabilityRef`.
2. Route every effect through one monitored gateway.
3. Journal intent and results around a port/sidecar adapter.
4. Inject BEAM worker and node failures.
5. Demonstrate replay-safe recovery and bounded validation load.

### Phase 3 — delegation graph

1. Spawn nested subagents whose grants are mechanically attenuated.
2. Verify that no child can exceed its inferred requirement or parent grant.
3. Test alternate proof paths and revocation-cache invalidation.
4. Compare token-visible authority with a broker-only opaque-handle baseline.

### Phase 4 — security and usability

1. Attack path normalization, URL redirects, proof resolution, policy
   complexity, replay, clock skew, and key leakage.
2. Measure grant size, proof depth, signing/validation latency, cache hit rate,
   and memory under realistic task graphs.
3. Test whether humans can understand the summarized grant and alternate proof
   paths.
4. Commission independent review before enabling consequential production
   effects.

## 14. Success and falsification criteria

UCAN earns its place if the prototype demonstrates:

- cross-runtime verification with an explicitly pinned profile;
- no authority expansion under generated delegations;
- model and subagent operation without access to signing keys;
- complete effect interception through the reference monitor;
- bounded validation and proof resolution under hostile inputs;
- replay-safe recovery under BEAM faults;
- understandable provenance and authorization-denial reasons;
- a material portability or delegation benefit over broker-only handles.

The proposal should be rejected or narrowed if:

- specification or library drift makes independent validators disagree
  persistently;
- canonical resource semantics cannot be made consistent with adapters;
- proof-chain and key management complexity exceeds the value of portability;
- eventual revocation is unacceptable for the intended risks and online broker
  checks remove UCAN's architectural advantage;
- a simpler opaque broker capability matches the needed trust domain and
  performs substantially better;
- review finds that the unaudited implementation risk is not containable.

## 15. Verdict

Use UCAN as an **authorization interchange and provenance protocol**, not as
the definition of capability in A-Lang.

The initial architecture should combine:

- A-Lang effect declarations and inferred capability requirements;
- an A-Lang-owned typed authority IR;
- opaque broker references inside BEAM;
- short-lived, attenuated UCAN Delegations at portable trust boundaries;
- signed UCAN Invocations for concrete effect requests;
- an execution-time reference monitor for resource semantics and stateful
  policy;
- durable intent/result journaling for replay and recovery;
- ports or sidecars for validators and untrusted effect adapters;
- property-based and differential testing of attenuation laws.

This fit is compelling because it gives the declarative language design a
cryptographic runtime counterpart without forcing protocol concepts into the
surface language. Its biggest unresolved issue is confinement: A-Lang can
prevent model-controlled redelegation through broker key custody, but current
UCAN cannot stop a genuinely external key holder from subdelegating. That
tradeoff, along with version and audit maturity, should remain an explicit
prototype gate rather than being hidden behind the word “capability.”

## Connections

- [UCAN and delegated agent authority](ucan-and-delegated-agent-authority.md)
  gives the shortest path through this research.
- [Can UCAN enforce A-Lang agent capabilities?](can-ucan-enforce-a-lang-agent-capabilities.md)
  keeps the engineering and security hypotheses open.
- [Task languages for LLM agents](../../20-notes/llm-agent-task-languages-deep-dive.md)
  defines the declarative effect and requirement layers that UCAN can realize.
- [Set and category principles](../../20-notes/set-and-category-principles-for-agent-programming-language.md)
  supplies the subset and composition semantics for attenuation.
- [BEAM runtime](../../20-notes/beam-runtime-for-native-agent-language.md) supplies the
  process, port, supervision, durability, and isolation architecture.

## Sources

- [UCAN specification](ucan-wg-2026-ucan-specification.md) — the
  current high-level certificate-capability and security model.
- [UCAN Delegation and Invocation](ucan-wg-2026-delegation-and-invocation.md)
  — the required authority-transfer and effect-request formats.
- [UCAN Revocation](ucan-wg-2025-revocation.md) — the monotonic,
  potentially eventually consistent proof-invalidation mechanism.
- [UCAN implementations and container](ucan-wg-2026-implementations-and-container.md)
  — compatibility, audit, transport, and BEAM-integration evidence.
- [SPKI Certificate Theory](ellison-et-al-1999-spki-certificate-theory.md)
  — the authorization-chain precedent and delegation-control comparison.
