---
title: "Compact Projection Fidelity Section 2.1 Integration Evidence"
kind: note
created: 2026-08-12
maturity: developing
tags:
  - beam
  - implementation-evidence
  - token-efficiency
  - tokenizer
aliases: []
---

# Compact Projection Fidelity Section 2.1 Integration Evidence

## Result

Section 2.1 implements a closed six-surface registry, canonical renderers for
`R0`, `R1`, `R2`, and `R5`, an exact BEAM byte-pair tokenizer for both frozen
screening profiles, and a closed token-audit report. `R3` and `R4` are
registered with exact versions but return stable section-specific
`surface_not_implemented` failures until Sections 2.2 and 2.3.

The test command completed with 11 Section 2.1 tests and all inherited Phase 1
tests passing. No provider or model call was made.

## Canonical surfaces and round trips

- All 48 held-out semantic cases render byte-identically across repeated calls
  in each implemented condition, for 192 checked render/decode paths.
- `R0` uses readable clause layout, `R1` removes grammar-optional layout, `R2`
  uses only the frozen mnemonic vocabulary, and `R5` uses duplicate-aware
  canonical typed JSON.
- Every decoded surface reproduces the originating semantic digest. A bounded,
  reversible pre-parse normalization lets the frozen readable source express
  slash-qualified resource identities and non-workspace absolute authority
  paths without modifying the frozen Stream 02 frontend.
- Unknown surface IDs, wrong versions, over-bound documents, unknown alias
  syntax, duplicate JSON fields, and unimplemented registered surfaces fail
  with stable errors.

## Tokenizer and audit evidence

- The trusted tokenizer loads only the complete registered profile IDs and
  verifies vocabulary SHA-256 and entry count before use.
- The BEAM BPE implementation reproduces token-ID vectors from tiktoken 0.12.0
  for empty, ASCII, A-Lang, Unicode, combining-mark, and emoji fixtures under
  both `cl100k_base` and `o200k_base`.
- Reports include exact document and assembled full-request counts, byte count
  and digest, tokenizer provenance, five lexical classes, and all eleven
  semantic/request sections.
- Section attribution is explicitly standalone and nonadditive because BPE
  merges can cross component boundaries. Provider-reported usage is retained
  as authoritative when present; estimated or internally inconsistent usage
  is rejected.

## Isolation and negative evidence

All tokenizer, renderer, decoder, normalization, attribution, and validation
modules compile deterministically to `.beam` and execute on ERTS. Vocabulary
files are inert registered data. The implementation invokes no port, NIF,
shell command, Python process, provider SDK, or network path.

Rebuilding the Phase 1 preregistration still yields digest
`b63beacc39ae35e76002acac4a2e7c0a53741db9af0d5928b16c7481cebb1839`,
which confirms the frozen prior archive and campaign bundle were not changed.

## Reproduction

From the repository root:

```bash
make test-compact-section-2-1
```

The command builds the trusted modules with `erlc -Werror +deterministic`,
replays the inherited Phase 1 suite, verifies the preregistration digest, and
runs the tokenizer, surface, and audit EUnit suites.

## Connections

- [Phase 2 plan](../../60-planning/03-compact-projection-fidelity/phase-02-compact-projection-and-token-accounting.md)
  defines the section gate satisfied here.
- [Phase 1 preregistration evidence](section-01-04-integration-evidence.md)
  supplies the immutable conditions and boundary retained by this work.
