# Operational Memory as Code — The 21 Gates

A reference specification for the pre-code gate system running in production
at NiraNexus Model Council (`model-council.niranexus.com`).

**This is a specification, not a tool you install.** The script hardcodes
NiraNexus paths, model registries, and brand palette. It runs against our
repository because that is where the lessons were learned. It is published
so the semantics can be checked, audited, and copied. Fork it, adapt it, or
write your own — the value is the specification, not the shell.

---

## The thesis

A pre-code gate is a production lesson compiled into a mechanical check. It
does not review. It does not recommend. It refuses — exit code non-zero, no
commit, no deploy.

Every gate is one of two things:

- **A fire, made mechanical.** A specific production failure happened, cost
  real time or real money, and a check was added so that exact failure cannot
  recur silently.
- **A discipline, made mechanical.** A governance rule that was previously
  advisory — "run the audit," "write the spec" — was compiled into a check
  because advisory rules get skipped under delivery pressure.

The distinction is not cosmetic. It is the difference between a scar and a
habit, and it is stated per gate below because an engineer reading this
deserves to know which is which.

---

## The count

- **21 checks** run on every commit.
- **17 are fire-derived.**
- **4 are discipline-derived.**
- **~15 distinct fires** — two pairs of checks share a single root cause
  (see annotations at #5/#15 and #7/#9).

The "~" is deliberate. Two check pairs each descend from one fire, so 17
fire-derived checks map to 15 distinct fires. Claiming "17 fires" would
overstate; claiming "15" still hides that two fires were severe enough to
warrant two checks each. The honest number is the range, and the annotations
below carry the detail.

---

## Fire-derived gates (17)

| # | Gate | Fire (provenance) |
|---|------|-------------------|
| 1 | Stray model references | Hero page listed Grok and Gemini as council models. Neither was in the roster. (2026-06-29) |
| 2 | JSX inline comments | `//` comments rendered as visible text in JSX return blocks. |
| 3 | HTML button nesting | A `<button>` nested inside another `<button>` — invalid HTML, broken interactions. |
| 4 | Async generators (Edge) | `async function*` does not work in Next.js Edge runtime; the build failed. |
| 5 | Model ID consistency | Six of eleven fallback model IDs were dead in the OpenRouter directory. (shared root — see #15) |
| 6 | Design spec for today | Phase 0-2 was skipped on multiple commits; each skip shipped bugs (Sessions 11, 13). The advisory "write a spec first" became a hard same-day requirement. |
| 7 | Dead duplicate files | Commit `b2bc7dc` added `src/components/` duplicates of `src/lib/` files with broken relative imports. Eight hours to diagnose. (shared root — see #9) |
| 8 | Eager process.env throws | `process.env.X!` at module scope crashed a clean clone with no `.env.local`. |
| 9 | Model gate (V4 routing) | The `b2bc7dc` dead-duplicate disaster would have been caught by stronger model reasoning. Architectural changes must route to the stronger model. (see caveat) |
| 10 | Import/dependency consistency | A dead export was removed but a consumer still imported it; Vercel build exposed the missing import three deploy cycles later. |
| 11 | Build cache freshness | Multiple `next dev` instances corrupted the Turbopack cache; source newer than `.next` must force a rebuild. |
| 12 | Brand colour audit | Card colours drifted across pages in a single session; the palette was pinned and every new hex must be approved. |
| 14 | Required skills manifest | Fifteen relevant skills were skipped across two sessions under cognitive load, costing seven auth deploy cycles. (2026-06-28) |
| 15 | Model change audit | Daily automated verification of every model ID against the live API directory. (shared root — see #5) |
| 18 | Shared component drift | `PhaseCard` was copy-pasted into a second page; a colour fix in one would have silently diverged from the other. |
| 19 | Impact audit for today | The impact audit was consistently run after deploy, not before, so cross-surface gaps shipped (Session 24). The check forces a same-day audit to exist before code. |
| 21 | Pre-completion pipeline | The checklist was skipped on its very next commit — steps 4+5 omitted, "done" claimed without grep evidence. The pipeline exists because the protocol was violated immediately after creation. |

## Discipline-derived gates (4)

| # | Gate | Discipline made mechanical |
|---|------|----------------------------|
| 13 | WCAG audit freshness | The accessibility audit must be re-run when UI files change. A freshness stamp, not a content audit. |
| 16 | Completion contract | File-existence and grep clauses that must hold before a feature is declared complete. |
| 17 | AGENTS.md health | Growth and staleness monitor for the operational memory file itself. |
| 20 | Production-readiness audit | A JSON artifact validated by a Node script against known production invariants. |

---

## Shared-root annotations

**#5 and #15 — one fire.** "Fallback chain model drift": six of eleven
fallback model IDs died in the OpenRouter directory. Check #5 verifies the
IDs declared in source are consistent with the reference file; check #15
verifies them against the live API directory daily. Two checks, one fire —
the second exists because consistency with a file is not the same as
liveness against the provider.

**#7 and #9 — one fire.** The `b2bc7dc` dead-duplicate disaster. Check #7
detects the duplicate files mechanically. Check #9 is the process-level
response: architectural changes (new files, new directories, import-path
changes) must be made by the stronger reasoning model, because the weaker
model missed an import-graph bug that the stronger model would have caught.

## Caveats, stated plainly

**Check #9 is the only check whose enforcement is not fully mechanical.**
It reads `.hermes/current-model` and requires it to name the stronger model
when architectural changes are staged. But it cannot verify *which model
actually ran the commit* — it trusts the file. This limitation is disclosed
here because a specification that hides its own soft spots is advertising,
not engineering. The check constrains what is *recorded*; it does not yet
mechanically verify what *happened*.

---

## What this is not

- Not a linter. A linter checks style; these check *known failure modes*.
- Not a CI framework. There is no YAML, no plugin system, no config DSL.
- Not turnkey. It will not run against a stranger's repository without
  adaptation. The hardcoded values are the point: they are the specific
  models, colours, and paths that this system burned on.

## Licence

MIT. The specification and the reference script are free to copy, adapt,
and ship. Attribution appreciated, not required.
