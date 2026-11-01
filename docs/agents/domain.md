# Domain Docs

How the engineering skills should consume this repo's domain documentation when exploring the codebase.

## Layout: multi-context

This repo is **multi-context**. A single `GLOSSARY-MAP.md` at the repo root points at one `GLOSSARY.md` per context, and context-specific ADRs live in that context's `docs/adr/`.

Neither the map nor any per-context glossary exists yet, by design: they are created the first time a term is actually written down, and the map becomes the entry point from that moment on. Missing domain docs are not a problem to flag or pre-emptively fix — `/domain-modeling` creates them lazily when terms or decisions get resolved.

## Before exploring, read these

- **`GLOSSARY-MAP.md`** at the repo root, if it exists: it points at one `GLOSSARY.md` per context. Read each one relevant to the topic.
- **`docs/adr/`**: read ADRs that touch the area you're about to work in. In this multi-context repo, also check `src/<context>/docs/adr/` for context-scoped decisions.

If any of these files don't exist, **proceed silently**. Don't flag their absence; don't suggest creating them upfront.

## File structure

Multi-context repo (this repo's layout, once the docs start to exist):

```
/
├── GLOSSARY-MAP.md
├── docs/adr/                          ← system-wide decisions
└── src/
    ├── ordering/
    │   ├── GLOSSARY.md
    │   └── docs/adr/                  ← context-specific decisions
    └── billing/
        ├── GLOSSARY.md
        └── docs/adr/
```

## Use the glossary's vocabulary

When your output names a domain concept (in an issue title, a refactor proposal, a hypothesis, a test name), use the term as defined in the context's `GLOSSARY.md`. Don't drift to synonyms the glossary explicitly avoids.

If the concept you need isn't in the glossary yet, that's a signal: either you're inventing language the project doesn't use (reconsider) or there's a real gap (note it for `/domain-modeling`).

## Flag ADR conflicts

If your output contradicts an existing ADR, surface it explicitly rather than silently overriding:

> _Contradicts ADR-0007 (event-sourced orders), but worth reopening because…_
