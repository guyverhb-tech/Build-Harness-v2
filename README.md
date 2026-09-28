# Build Harness v2

Two skills, one reviewer subagent and a few rules on top of stock Claude Code, for solo
builders who don't review code line by line.

## How you use it

Describe what you want. There are no commands to remember.

- Say **"I want to build …"** and `start-product` runs. It asks a few questions, checks
  any outside data the idea depends on, writes a brief, a decisions log and a backlog of
  small slices, and builds the first slice end to end.
- In an existing project, say **"add …"**, **"fix …"** or **"next"** and `ship-feature`
  runs. It checks the request against the real data source, writes failing tests, builds
  the change on a new branch, gets two independent reviews, tries the change in the
  running app, and stops.

Each run ends in a one-line verdict: **Ready to merge**, **Don't merge**, **Question** or
**Blocked**, with the problem in plain words. What happens next is your call. Typing
`/start-product` or `/ship-feature` still works if you'd rather.

The everyday flow, the verdicts and troubleshooting are in
[docs/USER-GUIDE.md](docs/USER-GUIDE.md).

## Install

```sh
git clone <this repository>
cd Build-Harness-v2
./install.sh
```

`install.sh` copies the two skills and the reviewer into `~/.claude`. It won't overwrite
files you already have unless you run `./install.sh --force`, and then it backs them up
first. It never edits your `CLAUDE.md`. Instead it prints the lines from
[CLAUDE.md.snippet](CLAUDE.md.snippet) for you to paste into `~/.claude/CLAUDE.md`. Start
a new Claude Code session afterwards.

## Requirements

Claude Code 2.1.271 or later, with a Claude subscription or API access.

## Why it's this small

An earlier, much larger harness went through several versions: an orchestrator with a
critic panel, then a mutation-testing gate, then an overnight runner. Its gate version
was compared with plain Claude Code on 7 features of one real app, one run per arm.

- Correctness was the same in both arms.
- The harness cost about 1.6 times as much and took about 3.6 times as long.
- The component that caught real faults was a reviewer running in a fresh context.
- 3 of the 7 features were wrong in both arms, because the requests were wrong about the
  real data. The tests passed and the code could never have worked. That's why both
  skills check the request against the live source before anything else.

So this version keeps the fresh-context reviewer and the up-front checks, and drops the
rest.

On 28 September 2026, the reviewer in this repository was run on cases the earlier
evaluator had been measured on, two runs each. There were two branches with real faults,
one branch that was wrong about live data, and one clean control. The reviewer flagged
both faulty branches every time, and raised no false alarm on the clean one. It caught
the live-data fault in one of its two runs, which is also how often the earlier evaluator
caught it. That miss is why `ship-feature` runs the reviewer twice.

This is a small sample from a single repository, not a benchmark.

## Limitations

- It never merges, pushes or deploys. You do those.
- The running-app check skips anything that writes data unless the app runs against local
  or test storage.
- Skills start automatically by matching what you say against their descriptions, and
  that can miss. If it does, name the skill ("use ship-feature") or type the slash
  command.

## Licence

MIT. See [LICENSE](LICENSE).
