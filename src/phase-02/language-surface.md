---
title: "Phase 2 A-Lang Source Surface"
kind: note
created: 2026-07-31
maturity: developing
tags:
  - compiler-design
  - json-schema
  - language-design
  - parsing
aliases: []
---

# Phase 2 A-Lang Source Surface

## Boundary

Phase 2 accepts exactly two source representations:

1. canonical UTF-8 JSON tagged with `alang-source-v1`; and
2. the small textual grammar below, implemented by the native Rust compiler.

Both produce the same A-Lang-owned untyped AST. JSON can preserve origins from
a textual file, so a tooling round trip does not erase source identity. JSON
objects reject unknown fields, and neither frontend turns input strings into
host module, function, or atom names.

The maximum source size is 1 MiB, identifiers are ASCII letters followed by
ASCII letters, digits, or underscores and are limited to 64 bytes, nesting is
limited to 64 levels, and every collection is limited to 1,024 elements.

## Complete declared surface

The canonical schema represents:

- one versioned named module;
- opaque, record, and two-alternative result type declarations;
- named effects with typed operation signatures;
- monomorphic functions and tasks with typed parameters and results;
- primitive, named, product, and result type expressions;
- literals, variables, records, fields, result constructors, calls, `let`,
  exhaustive result matches, `perform`, sequential composition, addition,
  and equality;
- declared effect-operation sets;
- resource-operation requirements with typed constraints, deadlines, call
  budgets, and byte budgets;
- task completion predicates introduced by `ensures`; and
- a byte span plus one-based start and end line-column on every AST node.

No polymorphism, recursion, handlers, parallel composition, user-defined
operators, implicit coercion, dynamic call, or portable authorization token is
part of this version.

## Textual grammar

The normative grammar is:

```text
module        := "module" identifier "version" string "{" declaration* "}"
declaration   := opaque | record | result | effect | function | task
opaque        := "opaque" identifier ";"
record        := "record" identifier "{" field-decl* "}"
result        := "result" identifier "=" "ok" type "|" "error" type ";"
effect        := "effect" identifier "{" operation* "}"
operation     := "operation" identifier parameters "->" type ";"
function      := "fn" identifier parameters "->" type "=" expression ";"
task          := "task" identifier parameters "->" type
                 "effect" "[" qualified-list? "]"
                 "requires" "[" requirement-list? "]"
                 "=" expression
                 "ensures" expression ";"
parameters    := "(" parameter-list? ")"
requirement   := qualified "(" constraint-list? ")"
type          := "Int" | "Bool" | "String" | identifier
               | "(" type ("," type)+ ")"
               | "Result" "<" type "," type ">"
expression    := literal | identifier | record-expression | field-expression
               | call | "ok" "(" expression ")"
               | "error" "(" expression ")"
               | "let" identifier "=" expression ";" expression
               | "match" expression "{" result-arms "}"
               | "perform" qualified arguments
               | expression ">>" expression
               | expression "+" expression
               | expression "==" expression
```

Qualified names have exactly two identifier segments in Phase 2. Record
fields and comma-separated lists accept an optional trailing comma.

## Precedence and evaluation order

From tightest to loosest, precedence is postfix field/call, addition,
equality, then `>>` sequential composition. Operators associate left except
that `let` and `match` own their complete bodies. Function arguments, record
fields, and sequence operands evaluate left to right. Static semantics later
make this order explicit in typed IR.

## Diagnostics and recovery

Diagnostics have stable uppercase codes, messages, primary origins, and
optional labels. JSON syntax and schema failures do not construct an AST.
Text parsing synchronizes at semicolons, closing braces, or the next
declaration keyword, allowing multiple independent declaration errors in one
pass. Recovery never inserts a declaration or expression node. Any error
causes the frontend to return diagnostics instead of a partial accepted
module.

## Connections

- [Phase 2 implementation plan](../../60-planning/01-minimal-proof-of-concept/phase-02-native-frontend-and-typed-task-ir.md)
- [Phase 1 BEAM execution evidence](../phase-01/beam-execution-evidence.md)
- [BEAM runtime synthesis](../../20-notes/beam-runtime-for-native-agent-language.md)
