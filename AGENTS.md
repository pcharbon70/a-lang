# Repository instructions

These instructions apply to the entire repository. This repository is a
Markdown research archive, not a conventional software project. Preserve its
ability to support exploratory thought while keeping provenance, navigation,
and document structure reliable.

Follow an explicit user request when it conflicts with this file. Otherwise,
use these conventions for every document and organizational change.

## Archive principles

- Folders describe what a document is doing; maps, links, and tags describe
  what it is about.
- Prefer a small stable top-level structure over speculative subject folders.
- Preserve provenance. Separate a source's claims from our synthesis and from
  unresolved questions.
- Keep navigation useful at two levels: directory READMEs are complete local
  inventories, while maps are selective conceptual paths.
- Treat `frontmatter.schema.json` as the authoritative metadata contract.
  Do not create a competing metadata convention in prose.
- Keep related changes atomic: a new, moved, renamed, or archived document and
  every affected index or map should be updated together.

## Canonical structure

```text
00-inbox/       Unprocessed, temporary captures
10-maps/        Curated paths through subjects and questions
20-notes/       Ideas and syntheses in the author's own words
30-sources/     Reading notes and bibliographic records
40-inquiries/   Active questions and research workbenches
50-journal/     Dated observations and exploratory writing
60-planning/    Numbered implementation roadmaps and phase evidence
90-archive/     Inactive or superseded material worth retaining
assets/         Images, PDFs, diagrams, datasets, and attachments
src/            A-Lang compiler, runtime, and supporting implementation source
templates/      Starting points for each document kind
```

Do not add or rename a top-level directory unless the user asks for it or a
repeated, demonstrated need makes the existing structure inadequate. Add
subject organization through tags, links, and maps first.

## A-Lang implementation invariant

“Runs on BEAM” covers the trusted compiler toolchain as well as generated
programs. Lexer, parser, resolver, static checker, IR passes, backend adapter,
compiler command, and validators must compile to `.beam` and execute on ERTS.
Erlang source may bootstrap those modules, but accepted A-Lang source must not
be translated to Erlang source or interpreted as Erlang AST/IR. Do not add
Rust, Cargo, C, C++, Zig, Go, or another foreign executable to the trusted
compiler path. Ports and sidecars are reserved for bounded external runtime
effects. Test-only evaluators must be explicitly nondeployable and cannot
satisfy an execution gate.

## Sources of truth

Use these files for different kinds of decisions:

1. `frontmatter.schema.json` defines valid fields and values.
2. `templates/` defines the minimum starting structure for each document kind.
3. The root `README.md` explains the archive to human readers.
4. Each directory's `README.md` describes that directory and inventories its
   direct contents.
5. `10-maps/` provides curated thematic navigation rather than exhaustive
   inventories.

If documentation and the filesystem disagree, inspect the intended change and
bring them back into sync. Never preserve a stale index merely because it was
previously committed.

## Directory README invariant

Every archive directory, including any future nested directory, must contain a
`README.md`. Create the README as part of creating the directory, not as later
cleanup.

Directory READMEs must:

- Use valid frontmatter with `kind: map`. The root `README.md` is the exception
  and does not need archive frontmatter.
- Use a human-readable title and an H1 that includes the directory name when
  useful—for example, an H1 naming Sources and `30-sources`.
- Include `## Purpose`, `## What belongs here`, `## Index`, and
  `## Maintaining this index` sections.
- Under `## Index`, list `### Subdirectories` and then `### Documents`,
  `### Files`, or `### Templates`, whichever describes the contents.
- Inventory every direct child directory and every direct child file except
  the README itself. Do not turn a directory README into a recursive inventory.
- Link entries with relative Markdown links and add a short description that
  explains their role. A filename alone is not a sufficient index entry.
- State `None yet` or an equivalent explicit empty state when a category has
  no entries.
- Link each nested directory through its README. The nested README should make
  its relationship to the parent clear.
- Treat the root README as the index of top-level archive directories and
  repository-facing root files, even though it uses a broader guide structure.

Whenever content is added, moved, renamed, archived, or removed:

1. update the README in its old directory, if applicable;
2. update the README in its new directory;
3. update affected maps and meaningful body links;
4. verify that no stale links or index entries remain.

Do not index `.git`, generated caches, editor state, or other repository
machinery as archive content.

## Frontmatter contract

Every durable knowledge document and every directory README begins with YAML
frontmatter that validates against `frontmatter.schema.json`.

All completed documents require:

```yaml
---
title: "A human-readable title"
kind: note
created: 2026-07-31
tags: []
aliases: []
---
```

Additional requirements depend on `kind`:

- `note` requires `maturity: seed | developing | stable`.
- `inquiry` requires `status: open | paused | resolved`.
- `source` may use the bibliographic fields defined in the schema, including
  `authors`, `published`, `citation_key`, `container`, `edition`, `isbn`,
  `doi`, `url`, and `accessed`.
- `map` and `journal` use the common fields unless the schema says otherwise.

Conventions:

- Use actual dates in `YYYY-MM-DD` form. Use the creation date of the archive
  document, not the publication date of its subject.
- Use lowercase kebab-case tags and YAML lists for `tags` and `aliases`, even
  when a list has one item.
- Use `[]` for an intentionally empty list and `null` for an unknown nullable
  value.
- Quote strings containing punctuation, URLs, or syntax that YAML may
  reinterpret.
- Keep searchable facts in frontmatter. Put summaries, arguments, quotations,
  evidence, and relationships in the Markdown body.
- Make the first H1 match the frontmatter title in meaning and capitalization.
- Do not add an `updated` date by hand; Git records revision history.

Exceptions:

- The root `README.md` and this `AGENTS.md` are repository documentation, not
  knowledge documents, and do not use archive frontmatter.
- Files in `templates/` intentionally contain braced placeholders and are not
  valid completed documents until copied and filled in. `templates/README.md`
  is a completed directory map and must validate.
- A transient capture in `00-inbox/` may begin incomplete, but it must have
  valid frontmatter before promotion into the durable archive.
- Binary assets do not use frontmatter; describe their provenance and purpose
  in `assets/README.md` or a nearby Markdown document.

## Document kinds and templates

| Kind | Destination | Template | Intended result |
| --- | --- | --- | --- |
| `map` | `10-maps/` or a directory README | `templates/map.md` | A selective, explained route through related material |
| `note` | `20-notes/` | `templates/note.md` | An idea, argument, model, or synthesis in the author's words |
| `source` | `30-sources/` | `templates/source.md` | A bibliographic record with evidence-focused reading notes |
| `inquiry` | `40-inquiries/` | `templates/inquiry.md` | A live question, hypotheses, findings, and outcome |
| `journal` | `50-journal/` | `templates/journal.md` | A dated observation or research-session record |

Copy the closest template, replace every placeholder, and extend its headings
only as the material requires. Do not edit a template merely to customize one
new document.

Implementation phase documents are the exception to the usual `20-notes/`
destination for `kind: note`: they live inside their numbered planning stream
under `60-planning/` and follow the planning conventions below.

If a metadata field or document kind changes:

1. update `frontmatter.schema.json` first;
2. update every affected template;
3. migrate existing completed documents when necessary;
4. update the root README and `templates/README.md`;
5. validate the complete archive.

Do not add a new document kind when an existing kind plus links or tags can
express the same role.

## Producing implementation plans

Implementation roadmaps live in `60-planning/`. Each planning stream uses the
next unused two-digit directory prefix so the order in which plans were
introduced remains visible. Never renumber an existing stream or reuse an
archived stream's number.

Each planning-stream directory must contain:

1. a `README.md` with `kind: map`, shared status rules, scope, dependencies,
   phase index, and roadmap completion gate;
2. one `kind: note` document per phase, normally with `maturity: developing`;
3. links to the research notes and inquiries whose claims the plan tests;
4. a completion-evidence section that remains unchecked until reproducible
   implementation evidence exists.

Use the Catena planning hierarchy consistently:

```text
# Phase N: Name
**Description:** ...

## Section N.M: Name
**Description:** ...
- [ ] **Section N.M Complete**

### Task N.M.K: Name
**Description:** ...
- [ ] **Task N.M.K Complete**

#### Subtask N.M.K.L: Name
**Description:** ...
- [ ] **Subtask N.M.K.L Complete**
```

Every phase ends with a numbered integration-test section and a phase
completion evidence checklist. A task starts with a description of its purpose
and observable result; a title or checkbox alone is not a sufficient task.
Keep planned work unchecked. Do not mark research, a stub, a lowered artifact,
or a happy-path demo as completed implementation evidence unless it satisfies
the roadmap's stated gate.

Name planning-stream directories `<NN>-<descriptive-name>` with a stable,
zero-padded sequence number. Name their phase documents
`phase-<NN>-<descriptive-name>.md`.

## Filenames and paths

- Use lowercase kebab-case Markdown filenames.
- Name conceptual notes and maps for their subject, not their creation date.
- Name inquiries as concise questions in kebab case.
- Name journal entries `YYYY-MM-DD.md`; add a short suffix if a date needs more
  than one entry.
- Prefer `<lead-author>-et-al-<year>-<short-title>.md` for multi-author source
  notes and `<author>-<year>-<short-title>.md` for single-author sources.
- Use stable, descriptive asset names and retain meaningful extensions.
- Use relative Markdown links for local documents and assets.
- Before renaming or moving a file, find and update every incoming local link.
- Use frontmatter `aliases` for useful former titles, not as a substitute for
  repairing links.

## Producing ordinary documents

Before creating a document:

1. read the root README, this file, the destination README, the relevant
   template, and `frontmatter.schema.json`;
2. search the archive for an existing document that already serves the need;
3. choose the document kind based on the work it performs, not merely its
   topic;
4. use the current local date and purposeful tags;
5. add at least one meaningful connection in the body or place the document on
   a relevant map;
6. update the destination README in the same change.

Write prose for a thoughtful reader rather than for a search engine. Prefer
clear claims, explicit uncertainty, and explanations of why links matter.
Avoid empty boilerplate headings; either develop a section or leave a concise
statement of what remains unknown.

## Producing research and deep dives

A deep dive should preserve both the evidence trail and the resulting model of
the subject. Unless the user asks for a different artifact shape, create or
update this connected bundle:

1. one synthesis note in `20-notes/`;
2. one source note in `30-sources/` for each substantively used primary work;
3. an inquiry in `40-inquiries/` when the central question remains open;
4. a topic map in `10-maps/` that provides a selective path through the work;
5. the home map when the topic should be discoverable from the archive entry
   point;
6. every affected directory README.

### Research method

- Define the question, scope, terminology, and an operational standard for
  claims such as “understands,” “better,” or “reliable.”
- Search current sources when facts, software, papers, standards, or product
  behavior may have changed. Do not rely on model memory for unstable claims.
- Prefer primary research papers, published proceedings, official
  specifications, and official project documentation. Use surveys and
  secondary sources to find primary work or to identify scholarly context.
- Record exact authorship, title, year, venue or container, DOI or canonical
  URL, and access date when available. Never invent missing metadata.
- Read enough of a source to support the claim for which it is cited. A search
  snippet or abstract alone is not evidence for detailed methodological or
  empirical claims.
- Distinguish reported results from our interpretation. Label extrapolations,
  design proposals, and cross-paper synthesis as such.
- Compare evidence across approaches and include negative results, limitations,
  evaluation weaknesses, and unresolved questions.
- Paraphrase by default. Use only short quotations with a precise location and
  respect copyright restrictions.
- Put external citations close to the claims they support and link local source
  notes where they help the reader follow the evidence trail.

### Source-note shape

Adapt the source template to the work, normally using:

- `## Reference` for the complete citation and canonical link;
- `## Method`, `## Contribution`, or `## Research question` as appropriate;
- `## Finding` for results actually supported by the work;
- `## Relevance` for why it matters to the archive's question;
- `## Limits` for scope, assumptions, and evaluation weaknesses;
- links to derived notes, inquiries, and maps.

Do not copy an abstract into a source note as a substitute for analysis. Avoid
creating source notes for papers mentioned only incidentally.

### Synthesis-note shape

Use structure proportionate to the topic. A substantial deep dive will often
need:

- an executive conclusion;
- scope, method, and definitions;
- technical or historical foundations;
- a taxonomy of relevant approaches;
- a comparison of what evidence supports and does not support;
- a proposed model, design, or set of implications when warranted;
- tradeoffs, limitations, and falsification criteria;
- research priorities or open questions;
- an annotated route to the source notes;
- connections to the topic map and active inquiry.

Do not force this exact outline onto a topic when another structure explains it
better. Preserve the separation between evidence, inference, and proposal.

## Maps, inquiries, and lifecycle

- Maps are curated explanations, not file dumps. Group links into meaningful
  trails and explain the relationship among them.
- The home map remains selective. Add major active inquiries, topic maps, and
  recently developed syntheses; do not mirror every directory index there.
- Inquiries state why a question matters, provisional hypotheses, paths to
  explore, findings, and an outcome. Update `status` as the work changes.
- Promote independently useful conclusions from inquiries or journals into
  notes.
- Move dormant or superseded work to `90-archive/` rather than silently
  deleting valuable context. Record why it was archived and link replacements.
- Do not call a note `stable` or an inquiry `resolved` merely because a writing
  pass is complete; the content must support that lifecycle state.

## Assets

- Store an asset locally only when the archive needs a durable copy and doing
  so is lawful. Prefer a canonical external link when duplication adds no
  value.
- Record provenance, creator, source URL, license, and the document that uses
  the asset when those facts are available.
- Create a descriptive subdirectory with its own README when a group of assets
  becomes large enough to benefit from one.
- Never leave an unreferenced asset without an index description.

## Verification checklist

Before reporting archive work complete:

1. inspect `git status` and preserve unrelated user changes;
2. validate `frontmatter.schema.json` as JSON;
3. validate every completed knowledge document and directory README against
   the schema, excluding unfinished inbox captures and placeholder templates;
4. when parsing YAML for JSON Schema validation, preserve ISO dates as strings
   rather than converting them to language-specific date objects;
5. confirm that no braced template placeholder remains outside `templates/`;
6. resolve every local Markdown link and asset link;
7. confirm that each directory README inventories every direct child directory
   and file except itself;
8. confirm that every new durable document has a meaningful connection or map
   entry;
9. verify external citations used by new research and spot-check metadata
   against the primary sources;
10. run `git diff --check` and review the complete diff for stale paths,
    accidental rewrites, or unrelated changes.

Use `rg` for repository searches. Useful quick checks include:

```bash
python3 -m json.tool frontmatter.schema.json >/dev/null
rg -n '\{(title|question|YYYY-MM-DD|author)\}' \
  --glob '*.md' --glob '!templates/*.md' --glob '!AGENTS.md'
git diff --check
git status --short
```

The placeholder search should return no completed documents. Template files
are expected to match it.

## Git and handoff

- Do not commit, push, open a pull request, or otherwise publish changes unless
  the user asks.
- When asked to commit, stage only the intended archive changes and use a terse
  message that describes the content.
- Before pushing, report and resolve validation failures. Do not hide broken
  links or invalid metadata in a commit.
- In the final handoff, summarize the documents created or changed, the maps
  and indexes updated, the validation performed, and whether changes remain
  uncommitted.
