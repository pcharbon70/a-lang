---
title: "Language Server Protocol Specification 3.18"
kind: source
created: 2026-08-05
authors:
  - "Microsoft"
published: null
citation_key: "microsoft-2026-language-server-protocol"
container: "Language Server Protocol"
edition: "3.18, repository revision b7f5132c95261c0898ae5124e7a91707abc48fcd"
isbn: null
doi: null
url: "https://microsoft.github.io/language-server-protocol/specifications/lsp/3.18/specification/"
accessed: 2026-08-05
tags:
  - code-navigation
  - language-server-protocol
  - symbol-identities
aliases:
  - "LSP 3.18"
---

# Language Server Protocol Specification 3.18

## Reference

Microsoft. *Language Server Protocol Specification 3.18*. [Rendered
specification](https://microsoft.github.io/language-server-protocol/specifications/lsp/3.18/specification/),
accessed 2026-08-05. The inspected specification source was repository revision
[`b7f5132c95261c0898ae5124e7a91707abc48fcd`](https://github.com/microsoft/language-server-protocol/tree/b7f5132c95261c0898ae5124e7a91707abc48fcd/_specifications/lsp/3.18).

## Contribution

LSP standardizes JSON-RPC interaction between development tools and
language-specific servers. A client can request a definition for the symbol at
a document position, request project-wide references, enumerate document or
workspace symbols, and receive locations or richer links.

`LocationLink` distinguishes the origin selection, full target range, and
target selection range. `DocumentSymbol` distinguishes a symbol’s full range
from the identifier range and can represent nested children. Capabilities let
clients and servers negotiate which operations and result forms they support.

## Relevance

LSP demonstrates a mature agent-facing vocabulary: `definition`, `references`,
`document symbols`, and `workspace symbols` are separate queries with
structured result types. A-Lang can borrow that separation, add explicit
bounds, and avoid adopting LSP as its compiler IR. The origin/target
distinction is especially useful for explaining why a reference exists and
what slice should be revealed.

## Limits

LSP is an interactive protocol, not a persistent index or source-annotation
syntax. Most requests identify a symbol by a document URI and position; those
coordinates are revision-sensitive, server capabilities vary, and the
specification does not define LLM context selection, provenance digests, or
security authority. An external language server also cannot become a foreign
executable in A-Lang’s trusted compiler path.

## Derived notes

- [Typed source references for LLM code understanding](../20-notes/typed-source-references-for-llm-code-understanding.md)
- [Can typed source references improve LLM code understanding?](../40-inquiries/can-typed-source-references-improve-llm-code-understanding.md)
- [Symbol-aware code context for LLM agents](../10-maps/symbol-aware-code-context-for-llm-agents.md)
