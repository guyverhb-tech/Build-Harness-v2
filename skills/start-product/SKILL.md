---
name: start-product
description: "Use when the user describes a new product, app or tool idea, or asks to start a new project. Interviews them, checks every external data source live, writes the brief, decisions and a sliced backlog, then builds slice 1 end to end with CI and a verified launch recipe."
argument-hint: "[idea]"
---

# Start a product

The idea:

$ARGUMENTS

If that is empty, use the idea the user described in the conversation that invoked this
skill. Only if there is none, ask for the idea and stop.

## 1. Interview

Use AskUserQuestion to settle the following:
- who the users are;
- their main tasks;
- the outcomes they want;
- constraints (budget, platform, deadlines, data, legal);
- non-goals;
- how success will be judged.

Ask only where the answer would change what gets built, and offer concrete options, up to
four questions per call. Decide routine technical questions yourself (framework, styling,
test runner, hosting defaults) and record them in step 4. Don't ask about them.

Stop interviewing when every remaining ambiguity is one you can decide and record.

## 2. Check external data before any design

List every external API, dataset or service the product depends on. For each one:
- Call the live source (the API, the database read-only, or a specific URL) for real
  cases the product will actually serve. Don't rely on its documentation alone.
- Confirm it has the fields and coverage the product needs: which fields exist, their
  types and example values, how many records, which regions or periods, how fresh, and
  any rate limits or auth.
- Record what is actually there, with the request you made. This goes into
  `docs/DECISIONS.md` in step 4.

If a core premise fails — a field doesn't exist, coverage is missing where the product
needs it, or the source can't be reached — **stop and tell the user** what was assumed and
what the source showed. Write nothing else until they decide.

## 3. Write `docs/BRIEF.md`

It covers:
- **Users**: who they are.
- **Tasks**: what they come to do.
- **Outcomes**: what they get.
- **Non-goals**: what this product deliberately doesn't do.
- **Acceptance criteria**, as observable behaviour: what a user sees or can do, written so
  a test or a person can check it. Include the failure cases: bad input, missing data, a
  source that is down, empty states.

## 4. Write `docs/DECISIONS.md`

For each architecture choice (stack, hosting, storage, auth, data flow, how each external
source is read), write down the choice, the alternatives considered, and why this one.

Choose the simplest architecture that meets the brief. Add no abstraction, service or
layer for hypothetical scale; each one must trace to a line in the brief. Include the
external data record from step 2 and the routine choices you made in step 1.

## 5. Write `docs/BACKLOG.md`

This is an ordered list of vertical slices. Each slice cuts through every layer it needs
and leaves something a user could see. Use this format for every slice:

```
## <n>. <title>
Status: todo
Outcome: <what a user can see or do afterwards>
Acceptance criteria:
- <observable behaviour, including failure cases>
Verification: <tests and checks>; environment: <real data from <source> | labelled mock of <source>, because <why>>
Depends on: <slice numbers, or none>
```

`Status:` is `todo`, `built on <branch>`, or `done`. `ship-feature` reads it to find the
next slice, so keep it on its own line.

## 6. Build slice 1 as a thin end-to-end path

Build it on a new branch. Slice 1 has:
- a real entry point (a page, route, command or endpoint a user would actually use);
- the slice's behaviour;
- storage, if the slice needs it;
- at least one test, written failing first;
- a working build.

**Project setup, in the same slice:**
- **Pinned versions.** The runtime is pinned (`.nvmrc` / `engines`, `.python-version`, or
  the stack's equivalent), a lockfile is committed, and dependencies are exact or locked.
- **Standard commands for setup, dev, test and build**, discoverable from the project's
  usual place (`package.json` scripts, a `Makefile`, or `pyproject.toml`), and listed in
  the README.
- **CI** on the project's CI service, or GitHub Actions if there is none. It installs,
  runs the tests and builds on a clean runner, with every step running every time it
  triggers. It never deploys, publishes or needs production secrets.
- A new env var goes in `.env.example`, and you tell the user about it.

Run test and build locally and show them passing. The tests pass only if they actually
ran: zero tests, unexpected skips and collection errors don't count. Commit.

Don't push. Instead, once the CI workflow is written and committed, check it from a clean
clone:
- If the build or tests need environment variables, make sure `.env.example` exists and
  is committed before cloning. If it doesn't exist, create it with **placeholder values
  only**, never a real secret. Make each placeholder syntactically valid, so it fails at
  the service rather than at parsing: `https://example.invalid` for a URL, `replace-me`
  for a key. In the clone, copy it to the file the project reads (`.env`, or
  `.env.local` for Next.js). The CI workflow does the same copy step, so the check and
  the workflow stay identical.
- Clone the repo into a temporary folder: `git clone --branch <branch> <repo> <tmp>`.
- In that clone, run the same install, test and build commands the workflow runs, in the
  same order, with nothing else carried over from your working copy (no `node_modules`,
  no `.venv`, no real `.env`).
- Record whether they pass and, if not, the first failure. If the only failure is a real
  service or secret the placeholders can't stand in for (a refused connection, an auth
  rejection, a missing variable), that's not a build failure. Record which variables it
  needs.

## 7. Write the launch recipe

Once slice 1 builds, record how to run the app as a project skill at
`.claude/skills/run-<project-name>/SKILL.md`, where `<project-name>` is the package name,
or the folder name in lowercase kebab-case. That is the path the bundled `/run` and
`/verify` look for, and `ship-feature` uses the same recipe.

The skill contains:
- frontmatter: `name: run-<project-name>`, and a description saying it installs and
  launches this app, for use whenever the app needs to be run, started or checked;
- the install commands, in order;
- the names of the required environment variables, and which file they go in. Never the
  values; point to `.env.example`;
- the launch command, the address or command where the app answers once it is up, and how
  to stop it.

Verify it by actually launching from a clean state. In a fresh clone of the branch, follow
the recipe exactly as written: install, copy `.env.example`, launch, wait until the entry
point answers, request it once, and stop the app. If a step didn't work as written, fix
the recipe and launch again. If the app only fails because a real service or secret is
missing, the recipe stands; record which variables it needs.

Commit the recipe on the slice 1 branch. Set slice 1's `Status:` to `built on <branch>`.
Don't merge, push or deploy.

## 8. Stop and report

Report in exactly six lines:

```
Brief: <what the brief commits to, one sentence>
Premises: <any that failed or are shaky, and why — or "all checked against live sources">
Architecture: <one sentence>
Backlog: <n> slices
CI: <Clean-clone build passes; CI workflow written, not yet run remotely | Clean-clone build needs <VAR>[, <VAR>…] to complete | Clean-clone build fails: <reason>>
Launch: <recipe at .claude/skills/run-<project-name>/, launched from a clean clone | recipe written; launch needs <VAR>[, <VAR>…] | could not launch: <reason>>
```
