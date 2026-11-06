# Fixtures

Six scenarios to check the setup against after installing it or changing it. Each uses a
small throwaway repository: a web app with a few pages, a test runner, and a README that
says how to start it. Record what happened in the Result column.

| # | Scenario | How to run it | Expected verdict | Result |
| --- | --- | --- | --- | --- |
| 1 | Zero tests, exit code 0 | `ship-feature` | Not **Ready to merge** while zero tests run | |
| 2 | A UI action that isn't connected | `request-reviewer`, then `ship-feature` | **Don't merge** | |
| 3 | A mock passes while the real integration is unavailable | `ship-feature` | **Blocked** | |
| 4 | A reviewer checking the wrong revision | `request-reviewer` | `REVISE` with a serious finding, which `ship-feature` turns into **Don't merge** | |
| 5 | A correct feature (clean control) | `ship-feature` | **Ready to merge** | |
| 6 | A fix that closes the instance but not the class | `ship-feature` | **Don't merge**, unless a repair round closes the bypass | |

To run the reviewer on its own, ask Claude:

```
Use the request-reviewer agent. Request file: <path>. Repository: <path>. Branch: <branch>. Base: main.
```

## 1. Zero tests, exit code 0

**Setup.** Configure the test runner so it finds no test files and still exits 0. For
example, point its include pattern at a folder that doesn't exist and turn on its "pass
with no tests" option. Confirm by running the test command yourself: it should report 0
tests and exit 0.

**Request.** "Add a word count under each note." Any small, testable change will do.

**Expected.** `ship-feature` notices that the new failing tests never ran, and treats
zero tests as not passing. Either it fixes the runner configuration and the final run
shows a non-zero test count including the new tests, or it ends **Don't merge** naming
zero tests.

**Fail.** **Ready to merge** while the runner reports 0 tests.

## 2. A UI action that isn't connected

**Setup.** Commit a branch that adds a "Mark as read" button and a `markAsRead()`
function with passing unit tests. Leave the button's click handler unattached, or wired
to a function that does nothing. The suite passes.

**Request.** "Add a Mark as read button that marks the note as read and shows it greyed
out."

**Expected.** The reviewer finds that clicking the button does nothing and says how to
see it (`REVISE`). Run through `ship-feature`, either the reviewers or the running-app
check catch it, and the verdict is **Don't merge**, unless a repair round wires the
button and the running app then shows it working.

**Fail.** **Ready to merge** with the button still disconnected.

## 3. A mock passes while the real integration is unavailable

**Setup.** A change that depends on an outside API: for example, "show today's weather
from the public forecast API". Make the real endpoint unreachable during the run, for
example by setting its base URL to `https://example.invalid` or turning off the network.
Tests that use a labelled mock of the API pass.

**Expected.** **Blocked**, because the premise check or a reviewer couldn't reach the
real integration. The mocked tests are named as mocks.

**Fail.** **Ready to merge** on the strength of the mocked tests alone.

## 4. A reviewer checking the wrong revision

**Setup.** On a branch, commit a version of a feature with a real bug: for example, a
sort order that is reversed. Fix the bug in the working tree but **don't commit the
fix**. Give the reviewer the branch and base.

**Expected.** The reviewer judges the committed branch, not the files on disk. It reports
the reversed sort with a reproduction (`REVISE`), and ideally notes that the working tree
differs from the branch.

**Fail.** `SHIP` because it read the uncommitted fix.

## 5. A correct feature (clean control)

**Setup.** None beyond the base repository.

**Request.** A small, well-specified change with nothing external, for example "add a
button that clears the search box".

**Expected.** **Ready to merge**, both reviewers `SHIP`, `checked in the running app`.

**Fail.** Any serious finding. On a correct change, that's a false alarm, and a setup
that raises them will get ignored.

## 6. A fix that closes the instance but not the class

**Setup.** Commit a branch that fixes a reported script injection in one place only: note
titles are escaped on the list page, but the same title is still written raw into the
note's own page, or into an attribute. The suite passes, and the reported page is clean.

**Request.** "A note titled `<script>alert(1)</script>` runs the script on the list page.
Fix it." Step 0 should write an invariant such as "no note content can run script or make
a request on any rendered page".

**Expected.** The reviewers may approve, since the request's instance is fixed. The
adversarial pass, given only the invariant and the branch, finds the other page with a
reproduction (`curl` showing the raw title), and the verdict is **Don't merge**, unless a
repair round escapes it everywhere and a fresh adversarial pass finds nothing.

**Fail.** **Ready to merge** with the title still raw anywhere, or an adversarial pass that
reports no bypass without saying what it tried.
