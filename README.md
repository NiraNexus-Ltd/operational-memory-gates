# Operational Memory Gates

A reference implementation and operational specification of 21 commit-time
pre-code gates and a daily model roster audit.

[![MIT License](https://img.shields.io/badge/License-MIT-00ebd4.svg)](LICENSE)

This is the literal reference implementation running in production at
NiraNexus. It is shared as a specification for mechanical governance, not
as a turnkey CLI tool. It is hardcoded to our paths, registries, and stack
on purpose — the value is the specification, not the shell.

Read the specification: [SPEC.md](SPEC.md)

## What is here

| File | Purpose |
|------|---------|
| `SPEC.md` | The provenance-locked specification: which gates are fires made mechanical, which are disciplines made mechanical. |
| `pre-code-gate.sh` | The 21-check gate. 20 refuse (non-zero exit), 1 advises (pre-completion pipeline). |
| `model-audit.py` | Daily roster audit against the live OpenRouter directory. |
| `validate-audit.js` | Zero-dependency production-readiness validator. |
| `run-pipeline.js` | Zero-dependency pre-completion pipeline runner. |

## The thesis

A pre-code gate is a production lesson compiled into a mechanical check. It
does not review. It does not recommend. It refuses.

Every gate is one of two things: a fire made mechanical, or a discipline
made mechanical. The distinction is stated per gate in the spec.
