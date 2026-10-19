# Changelog

## Unreleased

- `ship-feature`: a light lane. A change that can't alter what a user sees or hears, what
  a model is told, or what is stored about a person gets one review instead of two, and
  skips the running-app check when there is nothing a user could exercise. A project's
  own instructions can set a lighter or heavier rule. The report in the final message is
  now the evidence; full suite logs and evidence folders are no longer archived by
  default.

- `CLAUDE.md.snippet`: the rule against reading `.env*` files now excludes
  `.env.example`, which holds placeholders only and which `start-product` copies for its
  clean-clone check.

## 0.1.0 — 28 September 2026

First release.

- `start-product` skill: interview, live data check, brief, decisions, sliced backlog,
  first slice with CI, a clean-clone build check and a verified launch recipe.
- `ship-feature` skill: premise check, failing tests first, two independent reviews,
  running-app check, one-line verdict. It never merges, pushes or deploys.
- `request-reviewer` subagent: reviews a diff against the original request and the real
  system.
- `CLAUDE.md.snippet`, `install.sh`, the user guide and five fixtures.
