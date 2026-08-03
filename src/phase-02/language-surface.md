---
title: "Phase 2 A-Lang Source Surface"
kind: note
created: 2026-07-31
maturity: developing
tags:
  - beam
  - compiler-design
  - language-design
  - parsing
aliases: []
---

# Phase 2 A-Lang Source Surface

## Boundary

Phase 2 accepts one small UTF-8 textual source profile and derives a canonical
deterministic Erlang External Term Format representation of the resulting AST.
Both paths execute through compiler modules loaded into ERTS. No A-Lang source
is translated into Erlang source, and no Erlang evaluator executes the AST.

ETF is an internal compiler interchange format, not a user-facing language or
authorization envelope. Decoding is limited to 1 MiB, uses
`binary_to_term/2` with `[safe, used]`, rejects trailing bytes, and re-runs
semantic validation. Compressed ETF is rejected to prevent a small input from
expanding into an unbounded term. Encoding uses the `deterministic` option and must
round-trip byte-identically.

Text input is limited to 1 MiB. The Phase 2 vertical slice accepts ASCII
source, keeps identifiers as binaries rather than creating atoms, and records
the zero-based byte offset plus one-based line and column at every AST node.

## Complete implemented surface

The current compiler implements:

- a versioned named module containing one or more tasks;
- `Int` and `Bool` parameter and result types;
- non-negative signed-64-bit integer and Boolean literals;
- parameter and reserved `result` references;
- integer addition and same-type equality;
- an exact empty `effect []` declaration;
- an exact empty `requires []` declaration; and
- a Boolean completion predicate introduced by `ensures`.

Records, results, functions, effects, runtime requirements, operations,
handlers, recursion, polymorphism, branching, parallel composition, dynamic
calls, and portable authorization remain later-phase work.

## Textual grammar

```text
module       := "module" identifier "version" "alang-source-v1"
                "{" task+ "}"
task         := "task" identifier parameters "->" type
                "effect" "[" "]"
                "requires" "[" "]"
                "=" expression
                "ensures" expression ";"
parameters   := "(" (parameter ("," parameter)*)? ")"
parameter    := identifier ":" type
type         := "Int" | "Bool"
expression   := primary ("+" primary)*
                ("==" (primary ("+" primary)*))?
primary      := integer | "true" | "false" | identifier
                | "(" expression ")"
```

Addition binds more tightly than equality. Addition is left-associative;
equality appears at most once in an expression. `//` introduces a line
comment. Strings occur only in the module version and support escaped quote and
backslash.

## Diagnostics and rejection

The lexer and parser return stable diagnostic maps containing code, severity,
message, and origin. The minimal parser stops at the first error; it does not
return a partial accepted module or invent recovery nodes. Static checks reject
unsupported source versions, duplicate tasks or parameters, unresolved names,
unknown types, out-of-range integers, ill-typed addition or equality, result
type mismatch, non-Boolean completion, and nonempty effect or requirement
sets.

## Connections

- [Phase 2 implementation plan](../../60-planning/01-minimal-proof-of-concept/phase-02-native-frontend-and-typed-task-ir.md)
- [Phase 2 integration evidence](phase-02-integration-evidence.md)
- [BEAM runtime and compiler-host synthesis](../../20-notes/beam-runtime-for-native-agent-language.md)
