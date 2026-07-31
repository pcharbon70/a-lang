# A-Lang Archive

This is a research and exploratory archive: a place for ideas to wander, meet,
and develop without losing their provenance.

Start at the [home map](10-maps/home.md).

## Structure

```text
00-inbox/       Unprocessed captures
10-maps/        Curated paths through subjects and questions
20-notes/       Ideas developed in the author's own words
30-sources/     Reading notes and bibliographic records
40-inquiries/   Active questions and research workbenches
50-journal/     Dated observations and exploratory writing
90-archive/     Inactive or superseded material worth retaining
assets/         Images, PDFs, diagrams, and other attachments
templates/      Starting points for each document kind
```

Folders describe what a document is doing. Links and maps describe what it is
about. Subject folders should only be introduced when repeated use demonstrates
a real need for them.

## Front matter

Every knowledge document begins with YAML front matter. The common fields are:

```yaml
---
title: "A human-readable title"
kind: note
created: 2026-07-30
tags:
  - example-topic
aliases: []
---
```

The `frontmatter.schema.json` file is the authoritative machine-readable
contract. Its current document kinds are:

- `note` — an idea in the author's own words; also requires `maturity`
- `source` — a work being read, watched, heard, or consulted
- `inquiry` — an active question; also requires `status`
- `map` — a curated route through related material
- `journal` — dated observation and exploratory writing

Use front matter for small facts that are useful for searching, grouping, or
automation. Arguments, summaries, quotations, and explanations belong in the
Markdown body.

### Field conventions

- Write dates as `YYYY-MM-DD`.
- Write tags in lowercase kebab case: `philosophy-of-language`.
- Keep tag and alias values as YAML lists, including when there is only one.
- Use `[]` for an intentionally empty list and `null` for an unknown value.
- Quote strings containing punctuation, URLs, or wiki-style links.
- Do not add `updated` by hand. Version history records changes more reliably;
  add the field later only if tooling maintains it automatically.
- Prefer links in the body when the nature of a relationship needs explanation.

Controlled lifecycle values:

```text
maturity: seed | developing | stable
status:   open | paused | resolved
```

## Filenames

Use readable, stable names:

```text
20-notes/meaning-as-use.md
30-sources/wittgenstein-1953-philosophical-investigations.md
40-inquiries/can-syntax-emerge-without-semantics.md
50-journal/2026-07-30.md
10-maps/language-and-thought.md
```

Renaming is acceptable when the title of an idea changes. Use `aliases` to
retain names that remain useful for search or link resolution.

## Working rhythm

1. Capture without ceremony in `00-inbox/`.
2. During review, turn worthwhile captures into a note, source, inquiry, map,
   or journal entry using the corresponding template.
3. Give every durable document at least one meaningful connection in its body
   or place it on a map.
4. Develop maps when clusters appear; do not predict the taxonomy in advance.
5. Move dormant or superseded work to `90-archive/` without erasing its links.

Templates contain `{placeholders}` that must be replaced when a document is
created. They are examples rather than archive documents themselves.
