# User guide

## The everyday flow

**Starting something new.** Tell Claude what you want to build, in your own words. The
`start-product` skill takes over:
1. It asks you about the people who'll use it, what they need to get done, what's out of
   scope, and how you'll judge success. It only asks where your answer changes what gets
   built; routine technical choices it makes itself and writes down.
2. It checks every outside data source the idea depends on by calling it for real. If the
   data isn't there, it stops and tells you before writing anything.
3. It writes `docs/BRIEF.md` (what the product commits to), `docs/DECISIONS.md` (the
   architecture and why) and `docs/BACKLOG.md` (small slices, each one something a user
   could see).
4. It builds the first slice end to end on a new branch. That includes CI, a clean-clone
   build check, and a launch recipe that later runs use to start the app.

**Adding to it.** Say "next" to build the next slice in the backlog, or describe a change
("add a dark mode toggle", "fix the empty-list crash"). The `ship-feature` skill:
1. Checks the request against the real data source, if it depends on one.
2. Makes a new branch and writes tests that fail first.
3. Builds the change until the full test suite, typecheck and lint pass.
4. Has two independent reviewers check the change against your request, and fixes what
   they can reproduce. It allows at most two repair rounds.
5. Launches the app and tries the change the way a user would.
6. Stops with a one-line verdict. Nothing is merged, pushed or deployed.

When you're happy, merge the branch yourself. The next "next" picks up from there.

## Verdicts

| Verdict | What it means | What to do |
| --- | --- | --- |
| **Ready to merge** | Tests pass for real, both reviews came back clean (or their serious findings were fixed and re-reviewed), and the live data matched. | Look at the branch if you like, then merge it. |
| **Don't merge** | A serious problem is still open, the tests don't genuinely pass, or two repair rounds weren't enough. The line says what's wrong. | Read the problem. Ask for a fix in a new request, or drop the branch. |
| **Question** | The request is wrong or unclear about the real system, or a reviewer asked a question only you can answer. | Answer it, usually by correcting or narrowing the request, then ask again. |
| **Blocked** | Something the change depends on couldn't be reached, so it can't be checked against the real thing. | Make the service reachable (network, credentials, the service being up) and run it again. |

## What "State:" means

The verdict line ends with the state of the work, for example:

```
State: built and tested; checked in the running app; not merged; not deployed.
```

- **built and tested**: the branch exists and its tests genuinely ran and passed.
  `nothing built` means it stopped before writing code, usually on a Question.
- **checked in the running app**: the app was launched and the change tried by hand.
  `not checked in the running app: <why>` means it couldn't launch, or the change writes
  data and the app wasn't on local or test storage. The verdict can still be Ready to
  merge, but try it yourself before merging.
- **not merged; not deployed**: always true. Merging and deploying are yours.

## Small edits skip all this

Edits that can't change behaviour, like typos, comments, docs wording and formatting, are
made directly on a branch without `ship-feature`. If there's any doubt whether an edit
could change behaviour, it goes through `ship-feature`.

## Troubleshooting

**A skill didn't trigger.**
- Run `/skills` in a session and check that `start-product` and `ship-feature` are listed.
- If they aren't, check the files exist at `~/.claude/skills/<name>/SKILL.md`, and start a
  new session; skills load when a session starts.
- Check that the `CLAUDE.md.snippet` lines are in `~/.claude/CLAUDE.md`.
- Automatic triggering matches on what you say, and it can miss. Name the skill ("use
  ship-feature to add …") or type `/ship-feature`.

**The app won't launch.**
The verdict will say `not checked in the running app`.
- Look at the launch recipe `start-product` wrote at `.claude/skills/run-<name>/SKILL.md`.
- Check that every variable in `.env.example` has a real value in your local env file.
- Try the launch command yourself. If the recipe is out of date, Claude Code's built-in
  `/run-skill-generator` can record it again.

**Tests "pass" with zero tests.**
A run that collected no tests is not a pass, and `ship-feature` won't report it as one.
If you see it anyway, the test runner is usually looking in the wrong place or for the
wrong file names. Check its include pattern, and whether a "pass with no tests" option is
switched on. Tell Claude "the suite ran zero tests" and it will treat that as a failure
to fix.

**A session is going in circles.**
`ship-feature` stops after two repair rounds, or sooner if the same failure repeats with
nothing new learned. If a session still loops:
- Stop it (Esc) and ask what failure keeps repeating.
- A loop usually means the request is wrong about the real system, or two requirements
  contradict each other. Either way it's a Question, not a bug to keep fixing.
- Restate the request more narrowly in a fresh session.

## Changing the setup

Add something only when a real build fails in a way you can name, for example "the
reviewer passed a branch that reverted an earlier migration". Write the failure down, add
the smallest rule or step that would have caught it, and check the result against
[FIXTURES.md](FIXTURES.md). Don't add checks for failures you haven't seen; every extra
step costs time on every run.
