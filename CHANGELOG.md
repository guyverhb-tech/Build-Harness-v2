# Changelog

## Unreleased

- `red-team` skill. Runs before a product is shown to its audience for the first time, or
  before a release that changes its headline claims or how it is accessed. The lead reads
  the product, then builds the audience's pages in a clean clone of the deployed branch.
  Three attackers work in parallel: claims and method, security and engineering, and the
  audience. The lead re-runs the evidence for every high finding, and writes a ranked
  report outside the repository. It changes nothing; fixes go through `ship-feature`. It
  exists because the per-change reviewer judges a diff against its request, and can't see
  a flaw in the request itself.

- `ship-feature`, review loop:
  - A review approves when no serious finding is left open and its real-system check
    passed, whatever its verdict word.
  - A requirement the reviewer marks missing or partly done counts as a serious finding.
    Steps that only happen after review, such as pushing, are the exception.
  - When the second repair round finds something new, one review of just the final fix
    is allowed.
  - A repeat of an earlier failure still stops the loop.

- `ship-feature`, running-app check:
  - Rendered pages are checked with Playwright's headless shell under a hard 60-second
    limit. The shell is found in Playwright's default browser folder on macOS or Linux, or
    in `PLAYWRIGHT_BROWSERS_PATH`. Elsewhere, a project's own Playwright is used.
  - A virtual time budget lets content that arrives after load appear before the page is
    read.
  - A `playwright-core` route handles clicks, forms and pages behind a login.
  - A failed browser check is read by cause: a browser or app that can't start means
    "not checked", and a page that hangs or shows the change wrong is a serious finding.
  - Tools that drive the user's own browser are not used: they have no timeout, and they
    can act before a page has hydrated.
  - No browser is downloaded without asking.

- `install.sh` installs `red-team`. `CLAUDE.md.snippet` gains the line that triggers it.
  When upgrading, `install.sh` says to add that line to a CLAUDE.md that has the earlier
  lines but not this one.

- `tests/check.sh`: checks for the installer, skill frontmatter, the browser recipe, and
  home-directory paths or personal email addresses in published files.

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
