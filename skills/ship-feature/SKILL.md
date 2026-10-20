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

## 4. Independent reviews

**Light lane.** If the change can't alter what a user sees or hears, what a model is told, or
what is stored about a person — internal tooling, eval or test harness, price tables, scripts,
refactors with the suite unchanged — launch `request-reviewer` **once**, not twice. Everything
else below applies to that one review. If the project's own instructions set a lighter or
heavier rule, theirs wins.

Otherwise, launch the `request-reviewer` subagent **twice, in parallel, as separate invocations**.
Give each one only the request file, the repository path, the branch and the base. Don't
give either one your own summary, your view of the change, or the other's output.

- A **serious finding** is one with a reproduction. Fix it, re-run the full suite, and
  commit.
- A reviewer verdict of `QUESTION`, or a reviewer saying the request is wrong about the
  real system, is not yours to fix. Stop and end with `Question`.
- A concern without a reproduction goes in your report. Don't act on it.
- A requirement the review marks `missing` or `partly` under REQUEST COVERAGE counts as a
  serious finding. Its reproduction is the requirement's text set against what the diff
  does. Build it, or if the request itself should change, end with `Question`. The
  exception is a step the request puts after review, such as pushing, opening a PR or a
  remote CI run: note it in your report and carry on.
- A review **approves** when it leaves no serious finding open by these rules, and its
  REAL SYSTEM line says the check passed or didn't apply (a step after review, as above,
  aside). That holds whether its verdict line says `SHIP` or `REVISE`. A real-system check
  it couldn't make because the source was unreachable is `Blocked`, in step 7. One it
  skipped for any other reason means the review doesn't approve: give the next pass what
  it needs to make the check, within the repair-round limit.

**Repair rounds.** A repair round is: fix, re-run the full suite, then one fresh
`request-reviewer` pass over the fixed branch. Two rounds at most, counting any from
step 5. Stop sooner if a round ends with the same failure as the round before and you
learned nothing new about its cause. Then end with `Don't merge` and say what keeps
failing.

**Fix-only review.** If the second round raises new serious findings, you may fix them
and run one last check of that final fix alone. If any second-round finding repeats an
earlier failure, the stop rule above applies instead, and there is no fix-only review. The
check:
- Re-run the full suite.
- Re-run the step 5 check if a finding came from the running app, or if the fix changes
  anything a user exercises.
- Launch one `request-reviewer` pass. Give it:
  - a request file holding the findings verbatim, which says the reviewer judges only
    whether the fix resolves them and what the fix breaks;
  - the original request file, marked as context, not a checklist;
  - the fix's commits, with the commit before the first of them as the base.

This isn't a round, and there is only one. If it approves, the report says the last fix had
a fix-only review, not a full one. If it doesn't, end with `Don't merge`.

## 5. Check it in the running app

A light-lane change with nothing a user could exercise skips this step; the verdict line says
`not checked in the running app: no user-facing surface`.

Launch the app from this branch using the recipe in `.claude/skills/run-*/SKILL.md`, or
the README if there is no recipe. Then exercise the changed behaviour the way a user
would, through the app's real interface:
- open the page or call the route with `curl` for a web app;
- run the command for a CLI;
- when the change is in what a page renders or does in the browser, use a headless browser
  run from Bash under a hard time limit. Use the project's own Playwright if it has one;
  otherwise use Playwright's headless shell, if it is installed. The lookup below covers
  macOS and Linux; anywhere else, use the project's own Playwright:
  ```sh
  HS=$(find ${PLAYWRIGHT_BROWSERS_PATH:+"$PLAYWRIGHT_BROWSERS_PATH"} ~/Library/Caches/ms-playwright "${XDG_CACHE_HOME:-$HOME/.cache}/ms-playwright" -path '*chromium_headless_shell-*' -name chrome-headless-shell -type f 2>/dev/null | sort | tail -1)
  perl -e 'alarm shift; exec @ARGV or die "exec failed: $!\n"' 60 "$HS" --timeout=15000 --virtual-time-budget=5000 --window-size=390,844 --user-data-dir=<scratch>/hs --dump-dom '<url>'
  rm -f <scratch>/shot.png; perl -e 'alarm shift; exec @ARGV or die "exec failed: $!\n"' 60 "$HS" --timeout=15000 --virtual-time-budget=5000 --window-size=390,844 --user-data-dir=<scratch>/hs --screenshot=<scratch>/shot.png '<url>'
  ```
  - Run the `HS=` line and the browser line in the same Bash call. Shell variables don't
    survive between calls, and with an empty `$HS` the browser line fails with
    "exec failed" (exit 2).
  - The `perl` alarm kills the browser after 60 s (exit 142). `--timeout` alone stops a
    page load but not a script that never yields, and the Bash tool moves a long command
    to the background instead of killing it.
  - `--virtual-time-budget=5000` gives timers and fetches five seconds of page time before
    the DOM is dumped or the screenshot taken. Without it, both are taken at the load
    event, before content that arrives later. A page that holds a connection open
    (EventSource, long polling, a request that never returns) never uses up its virtual
    time. For such a page, use the `playwright-core` route below.
  - Read the screenshot to check layout.
  - For clicks, form input, a page behind a login, or waiting on a particular element, use
    `playwright-core`.
    - Run `npm install playwright-core` in a scratch folder. It downloads no browser.
    - Save the script below there as `check.mjs`, filling in the interaction and the
      element to wait for.
    - Launch it in the same command as the lookup, so the browser path reaches it:
      ```sh
      HS=$(find ${PLAYWRIGHT_BROWSERS_PATH:+"$PLAYWRIGHT_BROWSERS_PATH"} ~/Library/Caches/ms-playwright "${XDG_CACHE_HOME:-$HOME/.cache}/ms-playwright" -path '*chromium_headless_shell-*' -name chrome-headless-shell -type f 2>/dev/null | sort | tail -1) perl -e 'alarm shift; exec @ARGV or die "exec failed: $!\n"' 60 node <scratch>/pw/check.mjs '<url>'
      ```
      ```js
      if (!process.env.HS) {
        console.error("No headless shell path in HS: the lookup found none, or it ran in a different command from node");
        process.exit(2);
      }
      const { chromium } = await import("playwright-core");
      const browser = await chromium.launch({ executablePath: process.env.HS });
      try {
        const page = await browser.newPage({ viewport: { width: 390, height: 844 } });
        await page.goto(process.argv[2]);
        // The interaction and the wait for this change, for example:
        // await page.fill('input[name="password"]', "<password>"); await page.click("button");
        // await page.waitForSelector("<what the change should show>", { timeout: 15000 });
        console.log(await page.content());
      } finally {
        await browser.close();
      }
      ```
  - Never download a browser (`npx playwright install`) without asking the user first: it
    takes several hundred megabytes. If there is no headless shell and no project
    Playwright, check what `curl` can see, and record that the rendered page was not
    checked.

**Reading a failed browser check.** Decide by cause:
- The app isn't answering (`curl` gets no response), or the browser can't start ("exec
  failed", "No headless shell path in HS", or no headless shell found): record `not
  checked in the running app` and why. It isn't a finding against the change.
- The page loads but never finishes: exit 142, "Page load timed out", or an empty
  `<body>` while `curl` gets the page. Retry once with `playwright-core`, waiting
  explicitly for what the change should show. If it still hangs, that's a serious
  finding, since a user's browser would hang too.
- The page loads and shows the change wrong or missing: a serious finding.

Never use Claude in Chrome, or any tool that drives the user's own browser, for this step.
Its calls can hang with no timeout, and it can act before a page has hydrated and report a
failure that isn't there.

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
   app), the suite doesn't pass by the rules in step 3, or the repair rounds ran out with a
   serious finding the fix-only review didn't clear.
4. **`Ready to merge`**: none of the above. Every first-round review either approved or
   had every serious finding fixed, and the last re-review, or the fix-only review,
   approved.

If either review pass raised a serious finding or a question, the verdict can't be
`Ready to merge` on the other pass's approval alone.

The report is the evidence: commands run, test counts, findings and what was done about
them, in your final message, plus a short `.md` beside the work only if the project asks for
one. Don't archive full suite logs or build evidence folders by default.

End with exactly this line, and nothing after it:

```
<Ready to merge | Don't merge | Question | Blocked> — <branch>: <the problem in plain words, or "no open problems">. State: built and tested; <checked in the running app | not checked in the running app: <why>>; not merged; not deployed.
```

If nothing was built, because the verdict came before step 2, the state reads
`State: nothing built; not merged; not deployed.`
