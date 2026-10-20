---
name: red-team
description: "Use before a product, demo or site is shown to its real audience for the first time, before a release to that audience that changes its headline claims or how it is accessed, or when the user asks to red team, stress test or attack a project. Runs three adversarial reviews in parallel (claims and method, security and engineering, the audience), verifies every high finding, and reports ranked fixes without changing anything. Not for reviewing a single change; ship-feature does that."
argument-hint: "[project or what is about to be shown, and to whom]"
---

# Red team a project

What is being red-teamed:

$ARGUMENTS

If that is empty, use what the user described in the conversation that invoked this skill.

This attacks the whole product as its audience will meet it, not a diff. It finds flaws that
no review of a change against its request can see, because the request itself was the
flaw.

## 1. Settle the target

Find, from the arguments, the conversation, the brief and the README:
- the repository path, and the live URL and how access works, if it is deployed;
- the branch the deployment builds from;
- who the audience is, by role (for example "a prospective customer", "an investor", "a
  technical reviewer"), and what they will decide after seeing it;
- what the product claims: every headline number, label and promise it makes.

If the audience isn't stated anywhere, ask once with AskUserQuestion, offering the likely
readers as options. Everything else you can find yourself.

## 2. Read it yourself first

Before launching anyone, read the README and brief, the pages or output a user sees, and
the code that produces each claim. List:
- each claim, with the file or function that computes it;
- each route or entry point, and which are behind access control;
- what data it rests on, and how that data was chosen.

The attack briefs in step 3 are written from this list. A generic brief gets generic
findings.

**Build the audience's pages.** You do this before launching anyone; the audience attacker
never builds or runs anything. Don't touch the working repository, and never read pages from
the live site: a page load fetches every asset, which uses up the request cap below, and it
stops at a login page.
1. Check free disk space (`df -h`). A clean clone with its dependencies can take a gigabyte
   or more.
2. Clone the deployed branch into the scratchpad. Use the remote the deployment builds from,
   or the local repository if there is no remote.
3. Copy `.env.example` to the env file the app reads, with throwaway values, including a
   throwaway password if the app has a login.
4. Install and build there.
5. Collect the pages into an output folder, in one of two ways:
   - the build's prerendered pages, with tags stripped. These are unaffected by a login;
   - the app started from its run recipe and read with the headless-browser recipe in
     ship-feature step 5. If the app has a login, use that step's `playwright-core` route
     to sign in with the throwaway password before reading pages. The headless shell alone
     can't fill in a form or send a cookie, so it only ever sees the login page.
6. Stop the app.

The audience attacker gets that output folder and the README, and nothing else.

## 3. Launch three attackers

Launch three `general-purpose` subagents **in parallel, in the background**, one per
lens. Write each brief for this project: named files, named numbers, named routes, and at
least eight concrete attacks. Don't give any attacker your view of the product or another
attacker's output.

1. **Claims and method.** A hostile data scientist, lawyer or domain expert. Recompute
   every headline number from the source data. Look for:
   - selection bias and small denominators (give 95% intervals);
   - metrics that measure something other than what the copy says;
   - defaults or fallbacks that hide failures;
   - anything else that flatters.
2. **Security and engineering.** Look at:
   - access control and what it actually covers, including asset, 404 and data routes;
   - secrets in source and git history;
   - security headers;
   - what a visitor learns with and without access;
   - dependencies (`npm audit` or the stack's equivalent);
   - robustness: resume, partial writes, error paths;
   - whether the product reproduces from a clean clone.
3. **The audience.** Play the named readers in turn, reading only the output folder from
   step 2 and the README, not the code. Ask:
   - what they would act on, and what they wouldn't trust without checking;
   - what is missing before they would use it;
   - where it over-claims (quote the line);
   - where it reads as written by a model rather than a practitioner (quote the line);
   - their first five minutes of questions;
   - whether they would carry on.

Put these rules of engagement in every brief, word for word:

- Read-only: create or change no file in the repository. Scratch scripts go in the
  scratchpad, and you list their paths so every number can be reproduced.
- No paid API calls, no contacting anyone, no posting, no reading `.env*` other than
  `.env.example`.
- Against a live deployment: GET and HEAD only, with `curl`, not a browser. At most 40
  requests in total and no more than two a second. No form submissions and no load
  testing. No guessing of passwords or other credentials. A handful of deliberately
  malformed or forged cookies is allowed.
- Never use Claude in Chrome or any tool that drives the user's own browser.
- Every high-severity finding carries evidence: a command and its output, a URL and its
  status, or a file:line with the data that contradicts it. No style or generic advice.
- Return under 1,800 words:
  - findings ranked by how much they would change the audience's trust, each with
    severity (high, medium or low), evidence and a proportionate fix;
  - a short list of what you checked and found sound;
  - the scratch script paths.

## 4. Probe while they run

Check what no attacker is covering:
- the login flow end to end. You may sign in once with real credentials, if the user has
  given them, to confirm the cookie and the redirect;
- the live headers;
- one headline number recomputed from the raw data.

Don't duplicate an attacker's lens.

If an attack would need a paid run (re-running a model, a paid scan), don't run it. List it
in the report with what it would cost to run.

## 5. Verify and merge

For every high finding, re-run its evidence yourself.
- Downgrade or drop anything that doesn't reproduce, and say so.
- Merge duplicates across lenses.
- Keep the attacker's numbers only where your re-run matches.

## 6. Report

Create `~/.claude/red-team/<project>-<YYYY-MM-DD>/`. That keeps the report on real disk,
outside any repository, so it is never committed or deployed by accident.
- Copy every attacker's scratch scripts into `scripts/` there, since scratch space may be
  cleared.
- Point each figure in the report at its copy there.

Write `report.md` in that folder. It holds:
- **Findings**: a table of number, finding, severity, evidence and proposed fix, ranked by
  how much each would change the audience's trust;
- **Checked and sound**: what was looked at and holds up;
- **Not checked**: what was out of reach, and why;
- **Fix order**: the fixes in order of signal per hour, noting any that would cost money to
  carry out.

Any replacement copy you propose follows the copy rules in CLAUDE.md, if there are any.

## 7. Stop

Don't fix anything, commit, push or deploy. Each fix the user approves goes through
ship-feature, so it gets its own tests and reviews.

End with exactly this line, and nothing after it:

```
Red team — <project>: <n> high, <n> medium, <n> low. Report: <path to report.md>. State: nothing changed; not merged; not deployed.
```
