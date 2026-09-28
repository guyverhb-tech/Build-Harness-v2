---
name: ship-feature
description: "Use when the user asks to build, add, fix or change a feature in an existing project, or says 'next' or 'build the next slice'. Builds the change test-first on a new branch, checks it against the live source and in the running app, gets two independent reviews, and stops without merging. Not for edits that can't change behaviour (typos, comments, docs wording, formatting); make those directly on a branch."
argument-hint: "[request]"
---

# Ship a feature

The request:

$ARGUMENTS

## 0. Settle the request

First bring `docs/BACKLOG.md` up to date, if it exists:
- Find the default branch (`git symbolic-ref --short refs/remotes/origin/HEAD`, or `main`
  if there's no remote).
- For each slice whose `Status:` reads `built on <branch>`, check
  `git merge-base --is-ancestor <branch> <default>`. If it succeeds, the branch is merged:
  mark the slice `done`.
- If a branch no longer exists, or was squash-merged so the check can't tell, leave its
  status alone and mention it in your report.
- Write these `done` marks as the first commit on the new branch in step 2, never on the
  default branch. If you stop before step 2, just report them.

Then settle what to build:
- If the request above names a change, that is the request.
- If it is empty but the user described a change in the conversation that invoked this
  skill, that description is the request, in the user's words.
- Only if the user asked for "next" or "the next slice", or gave no request at all, open
  `docs/BACKLOG.md` and take the first slice whose `Status:` reads `todo`. Its outcome,
  acceptance criteria, verification and dependencies are the request. Check it against
  `docs/BRIEF.md`:
  - If it contradicts the brief, or depends on a slice that isn't `done`, stop and end
    with `Question`.
  - If there's no backlog, no `todo` slice, or no brief, say which and stop.

Write the settled request verbatim to a file outside the repo (for example in the
scratchpad). The reviewers get this file.

## 1. Check the premise against the live source

If the request names anything external — an API, feed, layer, endpoint, table, column,
field, file format, or a function that should already exist — go and look before writing
code. Fetch it, query it read-only, or read the schema, and list what is actually there.
Also check whether it has already been built.

- If the premise is false, write nothing. Report in one line what the request assumes and
  what the live source shows, then end with `Question`.
- If a source the change requires can't be reached, don't build against a guess. End with
  `Blocked`.
- If the request names nothing external, say so in one line and carry on.

## 2. Branch and write failing tests

- Create a new branch from the default branch; never work on the default branch.
- Write tests for the acceptance criteria before any implementation. Where the code reads
  external data, build fixtures from the **real response shapes** you fetched in step 1,
  trimmed but not invented.
- Any test that uses a mock, stub or fake says so in its name or a comment next to it,
  including what is mocked. It must never read as a test of the real system.
- Run the tests and show them failing, with the output. A test that passes before the
  implementation exists is testing nothing; fix it.
- Commit the tests.

## 3. Implement

Implement until the new tests pass **and** the project's full suite, typecheck and lint
pass. Never weaken, skip or delete a test to get green.

**What counts as passing.** Read the runner's counts, not just its exit code. None of
these is a pass, even with exit code 0:
- zero tests collected or run, in any suite;
- a skip, `todo` or `only` that you didn't add on purpose and explain;
- a collection, import or setup error.

If the change came from `docs/BACKLOG.md`, set that slice's `Status:` line to
`built on <branch>` in this branch. Commit.

## 4. Two independent reviews

Launch the `request-reviewer` subagent **twice, in parallel, as separate invocations**.
Give each one only the request file, the repository path, the branch and the base. Don't
give either one your own summary, your view of the change, or the other's output.

- A **serious finding** is one with a reproduction. Fix it, re-run the full suite, and
  commit.
- A reviewer verdict of `QUESTION`, or a reviewer saying the request is wrong about the
  real system, is not yours to fix. Stop and end with `Question`.
- A concern without a reproduction goes in your report. Don't act on it.

**Repair rounds.** A repair round is: fix, re-run the full suite, then one fresh
`request-reviewer` pass over the fixed branch. Two rounds at most, counting any from
step 5. Stop sooner if a round ends with the same failure as the round before and you
learned nothing new about its cause. Then end with `Don't merge` and say what keeps
failing.

## 5. Check it in the running app

Launch the app from this branch using the recipe in `.claude/skills/run-*/SKILL.md`, or
the README if there is no recipe. Then exercise the changed behaviour the way a user
would, through the app's real interface:
- open the page or call the route with `curl` for a web app;
- run the command for a CLI;
- drive a headless browser only if the project already has one set up.

Record what you did and what you observed, with the commands and their output. Stop the
app when you're done.

- **Don't write to a real external service or production database.** If the change's
  behaviour is a write, exercise it only when the recipe says the app runs against local
  or test storage. Otherwise record that the write was not exercised, and treat the change
  as not checked in the running app.
- If the running app shows the change not working, that's a serious finding. Fix it within
  the repair-round limit, re-running the suite and this check, or end with `Don't merge`.
- If the app can't be launched, record why. That doesn't block `Ready to merge`, but the
  verdict line must say `not checked in the running app`.

## 6. Stop

Don't merge, push, deploy or apply a migration. Leave the branch as it is.

## 7. Verdict

Pick exactly one verdict, checking in this order:
1. **`Blocked`**: a real integration the change requires could not be reached, in step 1
   or by either reviewer, so the change is unverified against it.
2. **`Question`**: the request is wrong or ambiguous about the real system, or either
   reviewer returned `QUESTION`.
3. **`Don't merge`**: a serious finding is still open (from a reviewer or from the running
   app), the suite doesn't pass by the rules in step 3, or the repair rounds ran out.
4. **`Ready to merge`**: none of the above. Both first-round reviews either approved or
   had every serious finding fixed, and the last re-review approved.

If either review pass raised a serious finding or a question, the verdict can't be
`Ready to merge` on the other pass's approval alone.

End with exactly this line, and nothing after it:

```
<Ready to merge | Don't merge | Question | Blocked> — <branch>: <the problem in plain words, or "no open problems">. State: built and tested; <checked in the running app | not checked in the running app: <why>>; not merged; not deployed.
```

If nothing was built, because the verdict came before step 2, the state reads
`State: nothing built; not merged; not deployed.`
