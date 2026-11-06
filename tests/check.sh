#!/usr/bin/env bash
# Checks for this repository: the installer, the skills' frontmatter, the running-app
# browser recipe in ship-feature, and that published files carry no personal paths.
#
#   ./tests/check.sh
#
# The browser checks need Playwright's headless shell to be installed already. Without it
# they are skipped and say so; they never download a browser.
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

pass=0; fail=0; skip=0; n=0
ok()   { n=$((n + 1)); pass=$((pass + 1)); echo "ok $n - $1"; }
bad()  { n=$((n + 1)); fail=$((fail + 1)); echo "not ok $n - $1"; [ -n "${2:-}" ] && echo "  # $2"; }
skipped() { n=$((n + 1)); skip=$((skip + 1)); echo "ok $n - $1 # SKIP $2"; }

SKILL="$ROOT/skills/ship-feature/SKILL.md"
EXPECTED="skills/start-product/SKILL.md skills/ship-feature/SKILL.md skills/red-team/SKILL.md agents/request-reviewer.md"

# --- Installer ---------------------------------------------------------------------------

DEST="$WORK/config"
if out="$(CLAUDE_CONFIG_DIR="$DEST" "$ROOT/install.sh" 2>&1)"; then
  missing=""
  for f in $EXPECTED; do
    [ -f "$ROOT/$f" ] && cmp -s "$ROOT/$f" "$DEST/$f" || missing="$missing $f"
  done
  if [ -z "$missing" ]; then ok "install.sh installs every skill and the reviewer into an empty config dir"
  else bad "install.sh installs every skill and the reviewer into an empty config dir" "missing or different:$missing"; fi
else
  bad "install.sh installs every skill and the reviewer into an empty config dir" "install.sh failed: $out"
fi

if out="$(CLAUDE_CONFIG_DIR="$DEST" "$ROOT/install.sh" 2>&1)" \
   && [ "$(printf '%s\n' "$out" | grep -c '^installed ')" -eq 0 ] \
   && [ "$(printf '%s\n' "$out" | grep -c '^unchanged ')" -eq "$(echo $EXPECTED | wc -w)" ]; then
  ok "a second install.sh run changes nothing"
else
  bad "a second install.sh run changes nothing" "$(printf '%s\n' "$out" | grep -E '^(installed|unchanged) ' | tr '\n' ';')"
fi

# The CLAUDE.md the installer finds: an earlier snippet (copied from main before the
# red-team line existed) and the current one.
mkdir -p "$WORK/upgrade" "$WORK/current"
cp "$ROOT/tests/fixtures/CLAUDE.md.snippet-before-red-team" "$WORK/upgrade/CLAUDE.md"
cp "$ROOT/CLAUDE.md.snippet" "$WORK/current/CLAUDE.md"
out="$(CLAUDE_CONFIG_DIR="$WORK/upgrade" "$ROOT/install.sh" 2>&1)"
if printf '%s' "$out" | grep -q 'red-team line'; then ok "install.sh tells an upgrading user to add the red-team line"
else bad "install.sh tells an upgrading user to add the red-team line" "$(printf '%s\n' "$out" | grep '^(' )"; fi
out="$(CLAUDE_CONFIG_DIR="$WORK/current" "$ROOT/install.sh" 2>&1)"
if printf '%s' "$out" | grep -q 'already seems to have them' && ! printf '%s' "$out" | grep -q 'red-team line'; then
  ok "install.sh says a current CLAUDE.md already has the lines"
else bad "install.sh says a current CLAUDE.md already has the lines" "$(printf '%s\n' "$out" | grep '^(' )"; fi

# --- Skills ------------------------------------------------------------------------------

problems=""
for s in "$ROOT"/skills/*/SKILL.md; do
  dir="$(basename "$(dirname "$s")")"
  front="$(awk 'NR == 1 && /^---$/ { on = 1; next } on && /^---$/ { exit } on { print }' "$s")"
  name="$(printf '%s\n' "$front" | sed -n 's/^name: *//p')"
  [ "$name" = "$dir" ] || problems="$problems $dir:name"
  printf '%s\n' "$front" | grep -q '^description: *"..*"$' || problems="$problems $dir:description"
  grep -q "skills/$dir/SKILL.md" "$ROOT/install.sh" || problems="$problems $dir:not-installed"
done
if [ -z "$problems" ]; then ok "every skill's frontmatter names its folder, has a description, and is installed"
else bad "every skill's frontmatter names its folder, has a description, and is installed" "$problems"; fi

# --- Running-app browser recipe (ship-feature step 5) --------------------------------------

# The recipe's lines, exactly as the skill writes them.
HS_LINE="$(grep -m1 -E '^ *HS=\$\(find ' "$SKILL" | sed 's/^ *//')"
DUMP_LINE="$(grep -m1 -E "^ *perl -e 'alarm shift; exec @ARGV or die .* --dump-dom " "$SKILL" | sed 's/^ *//')"
JS_BLOCK="$(awk '/^ *```js$/ { on = 1; next } on && /^ *```$/ { exit } on { sub(/^  /, ""); print }' "$SKILL")"

found_shell=""
for root in "${PLAYWRIGHT_BROWSERS_PATH:-}" "$HOME/Library/Caches/ms-playwright" "${XDG_CACHE_HOME:-$HOME/.cache}/ms-playwright"; do
  [ -n "$root" ] && ls -d "$root"/chromium_headless_shell-* >/dev/null 2>&1 && found_shell=1
done

if [ -z "$HS_LINE" ]; then
  bad "the skill's HS= line finds the headless shell in bash and zsh" "no 'HS=\$(find ...' line in ship-feature"
elif [ -z "$found_shell" ]; then
  skipped "the skill's HS= line finds the headless shell in bash and zsh" "Playwright's headless shell is not installed here"
else
  hs_bash="$(bash -c "$HS_LINE; printf '%s' \"\$HS\"")"
  hs_zsh=""; command -v zsh >/dev/null 2>&1 && hs_zsh="$(zsh -c "$HS_LINE; printf '%s' \"\$HS\"")"
  if [ -x "$hs_bash" ] && { ! command -v zsh >/dev/null 2>&1 || [ "$hs_zsh" = "$hs_bash" ]; }; then
    ok "the skill's HS= line finds the headless shell in bash and zsh"
  else
    bad "the skill's HS= line finds the headless shell in bash and zsh" "bash: '$hs_bash' zsh: '$hs_zsh'"
  fi
fi

if [ -z "$DUMP_LINE" ] || [ -z "$HS_LINE" ]; then
  bad "the skill's dump line captures content set after the load event" "no dump line in ship-feature"
elif [ -z "$found_shell" ]; then
  skipped "the skill's dump line captures content set after the load event" "Playwright's headless shell is not installed here"
else
  cmd="${DUMP_LINE//<scratch>/$WORK}"; cmd="${cmd//<url>/file://$ROOT/tests/fixtures/late.html}"
  if out="$(bash -c "$HS_LINE; $cmd" 2>/dev/null)" && printf '%s' "$out" | grep -q '>after-load<'; then
    ok "the skill's dump line captures content set after the load event"
  else
    bad "the skill's dump line captures content set after the load event" "$(printf '%s' "$out" | grep -o '<p id="status">[^<]*' | head -1)"
  fi
fi

if [ -z "$DUMP_LINE" ]; then
  bad "the dump line fails loudly when the browser path is empty" "no dump line in ship-feature"
else
  cmd="${DUMP_LINE//<scratch>/$WORK}"; cmd="${cmd//<url>/file://$ROOT/tests/fixtures/late.html}"
  err="$(HS="" bash -c "$cmd" 2>&1 >/dev/null)"; code=$?
  if [ "$code" -ne 0 ] && printf '%s' "$err" | grep -q 'exec failed'; then
    ok "the dump line fails loudly when the browser path is empty"
  else
    bad "the dump line fails loudly when the browser path is empty" "exit $code, stderr: $err"
  fi
fi

if [ -z "$JS_BLOCK" ]; then
  bad "the playwright-core script stops when HS is unset, naming both causes" "no js block in ship-feature"
elif ! command -v node >/dev/null 2>&1; then
  skipped "the playwright-core script stops when HS is unset, naming both causes" "node is not installed here"
else
  printf '%s\n' "$JS_BLOCK" > "$WORK/check.mjs"
  err="$(cd "$WORK" && env -u HS node check.mjs file:///dev/null 2>&1)"; code=$?
  if [ "$code" -ne 0 ] && printf '%s' "$err" | grep -q 'found none' && printf '%s' "$err" | grep -q 'different command'; then
    ok "the playwright-core script stops when HS is unset, naming both causes"
  else
    bad "the playwright-core script stops when HS is unset, naming both causes" "exit $code: $(printf '%s' "$err" | head -2)"
  fi
fi

# The click must match any button: a <button> with no type attribute still submits its form,
# but a [type="submit"] selector doesn't match it.
if printf '%s\n' "$JS_BLOCK" | grep -q "page.fill('input\[name=\"password\"\]'" \
   && printf '%s\n' "$JS_BLOCK" | grep -q 'page.click("button")'; then
  ok "the playwright-core template's form example is an ordinary password login"
else
  bad "the playwright-core template's form example is an ordinary password login" "$(printf '%s\n' "$JS_BLOCK" | grep 'page.fill' | sed 's/^ *//')"
fi

# --- red-team rules of engagement ----------------------------------------------------------

# The no-guessing rule must cover every kind of secret, not passwords alone.
if grep -q 'No guessing of passwords or other credentials' "$ROOT/skills/red-team/SKILL.md"; then
  ok "red-team forbids guessing passwords or other credentials"
else
  bad "red-team forbids guessing passwords or other credentials" "$(grep -o 'No guessing of[^,]*' "$ROOT/skills/red-team/SKILL.md")"
fi

# --- Invariant and adversarial pass --------------------------------------------------------

REVIEWER="$ROOT/agents/request-reviewer.md"
# The body of one "## <n>. <title>" step of a skill.
section() { awk -v h="$2" '$0 ~ "^## [0-9]+\\. " h "$" { on = 1; next } on && /^## [0-9]+\. / { exit } on { print }' "$1"; }

# Step 0 writes the settled request and, under it, one line stating the class of the
# problem, not the instance: the invariant the reviewers test and the adversarial pass attacks.
step0="$(section "$SKILL" "Settle the request")"
if printf '%s\n' "$step0" | grep -q '`Invariant:`' && printf '%s\n' "$step0" | grep -qi 'the class, not the instance'; then
  ok "ship-feature step 0 adds a one-line Invariant that states the class, not the instance"
else
  bad "ship-feature step 0 adds a one-line Invariant that states the class, not the instance" "$(printf '%s\n' "$step0" | grep -n -i 'invariant' | head -3 | tr '\n' ';')"
fi

# The reviewer lists the invariant under REQUEST COVERAGE, so a gap is `partly` or `missing`,
# which ship-feature already treats as a serious finding.
if grep -q '^REQUEST COVERAGE:.*invariant' "$REVIEWER"; then
  ok "request-reviewer reports the invariant under REQUEST COVERAGE"
else
  bad "request-reviewer reports the invariant under REQUEST COVERAGE" "$(grep -n '^REQUEST COVERAGE:' "$REVIEWER")"
fi

# One more request-reviewer pass after every review approves, told to break the invariant with
# a reproduction; each bypass is a serious finding under the repair-round limits.
adv="$(section "$SKILL" "Adversarial pass")"
if [ -n "$adv" ] && printf '%s\n' "$adv" | grep -q 'request-reviewer' && printf '%s\n' "$adv" | grep -qi 'break' \
   && printf '%s\n' "$adv" | grep -q 'reproduction' && printf '%s\n' "$adv" | grep -q 'serious finding' \
   && printf '%s\n' "$adv" | grep -qi 'repair round'; then
  ok "ship-feature has an adversarial-pass step: break the invariant, with a reproduction, under the repair-round limits"
else
  bad "ship-feature has an adversarial-pass step: break the invariant, with a reproduction, under the repair-round limits" "$( [ -z "$adv" ] && echo 'no "## <n>. Adversarial pass" step' || printf '%s\n' "$adv" | head -3 | tr '\n' ';')"
fi

# The lead heads the adversarial brief with a marker and the reviewer keys its mode on the same
# marker; rename one and the other must follow.
marker='`Adversarial pass`'
if grep -qF "$marker" "$SKILL" && grep -qF "$marker" "$REVIEWER"; then
  ok "the adversarial brief's heading is the same in ship-feature and request-reviewer"
else
  bad "the adversarial brief's heading is the same in ship-feature and request-reviewer" "skill: $(grep -cF "$marker" "$SKILL"), reviewer: $(grep -cF "$marker" "$REVIEWER")"
fi

# Ready to merge needs the adversarial pass clear, not the reviews alone.
verdict="$(section "$SKILL" "Verdict")"
if printf '%s\n' "$verdict" | grep -qi 'adversarial pass'; then
  ok "ship-feature's verdict rules name the adversarial pass"
else
  bad "ship-feature's verdict rules name the adversarial pass" "$(printf '%s\n' "$verdict" | grep -n 'Ready to merge' | head -2 | tr '\n' ';')"
fi

# The scenario this exists for: a fix that closes the reported instance but not the class.
if grep -qi 'adversarial pass' "$ROOT/docs/FIXTURES.md"; then
  ok "FIXTURES.md has a scenario for a fix that closes the instance but not the class"
else
  bad "FIXTURES.md has a scenario for a fix that closes the instance but not the class" "no scenario names the adversarial pass"
fi

# --- Light lane, frozen invariant, ported rules ------------------------------------------

# Prose checks that don't depend on where a line wraps.
flat() { tr -s '[:space:]' ' '; }

# A project rule about the number of reviews can't be read as dropping the adversarial pass:
# the sentence that step 6 always runs comes after "theirs wins", not before it.
lane="$(section "$SKILL" "Independent reviews" | flat)"
if printf '%s' "$lane" | grep -q 'theirs wins\. Step 6 runs in both lanes and under any project rule\.'; then
  ok "ship-feature's light lane says step 6 runs under any project rule, after 'theirs wins'"
else
  bad "ship-feature's light lane says step 6 runs under any project rule, after 'theirs wins'" "$(printf '%s' "$lane" | grep -o '.\{70\}theirs wins.\{0,70\}')"
fi

# The lead can't narrow the invariant after a bypass: the line is fixed once step 0 writes it,
# and one that turns out wrong about the request ends in Question, for the user to settle.
step0f="$(section "$SKILL" "Settle the request" | flat)"
if printf '%s' "$step0f" | grep -q 'Once written, the `Invariant:` line doesn.t change' \
   && printf '%s' "$step0f" | grep -q 'end with `Question`[^.]*rather than rewriting it' \
   && section "$SKILL" "Adversarial pass" | flat | grep -q 'never by narrowing the invariant'; then
  ok "ship-feature step 0 fixes the Invariant line once written; a wrong one ends in Question"
else
  bad "ship-feature step 0 fixes the Invariant line once written; a wrong one ends in Question" "$(printf '%s' "$step0f" | grep -o 'Once written.\{0,100\}' || echo 'no "Once written" sentence in step 0')"
fi

verdictf="$(section "$SKILL" "Verdict" | flat)"
if printf '%s' "$verdictf" | grep -q 'returned `QUESTION`, or the invariant turned out wrong about the request'; then
  ok "ship-feature's Question rule names an invariant that turned out wrong about the request"
else
  bad "ship-feature's Question rule names an invariant that turned out wrong about the request" "$(printf '%s' "$verdictf" | grep -o '`Question`\*\*:.\{0,120\}')"
fi

# Rules that lived only in an installed copy, ported so an install can't drop them.
step1f="$(section "$SKILL" "Check the premise against the live source" | flat)"
if printf '%s' "$step1f" | grep -q 'If a `design-eval` skill is installed and the change touches what a model is told' \
   && printf '%s' "$step1f" | grep -q 'pinned by hash' && printf '%s' "$step1f" | grep -q 'docs/EVAL.md'; then
  ok "ship-feature step 1 applies design-eval, when that skill is installed, to a change in what a model is told"
else
  bad "ship-feature step 1 applies design-eval, when that skill is installed, to a change in what a model is told" "design-eval mentions in step 1: $(printf '%s' "$step1f" | grep -o 'design-eval' | wc -l | tr -d ' ')"
fi

if printf '%s' "$step1f" | grep -q 'a walkthrough of what the user will meet, end to end and in order' \
   && printf '%s' "$step1f" | grep -q 'the reviewers read it beside the request'; then
  ok "ship-feature step 1 writes a walkthrough for a change to what a user sees or hears"
else
  bad "ship-feature step 1 writes a walkthrough for a change to what a user sees or hears" "walkthrough mentions in step 1: $(printf '%s' "$step1f" | grep -o 'walkthrough' | wc -l | tr -d ' ')"
fi

step2f="$(section "$SKILL" "Branch and write failing tests" | flat)"
if printf '%s' "$step2f" | grep -q 'take at least one fixture from the real file, with the punctuation and lengths it actually holds'; then
  ok "ship-feature step 2 takes a fixture from the product's real stored content"
else
  bad "ship-feature step 2 takes a fixture from the product's real stored content" "$(printf '%s' "$step2f" | grep -o 'trimmed but not invented.\{0,80\}')"
fi

# --- Published files ---------------------------------------------------------------------

# A guard rather than a test of new behaviour: it passes today and must keep passing.
leaks="$(cd "$ROOT" && git ls-files -z | xargs -0 grep -n -I -E '/Users/[A-Za-z]|/home/[a-z]|[A-Za-z0-9._%+-]+@(gmail|googlemail|outlook|hotmail|icloud|me|yahoo|proton|protonmail)\.' 2>/dev/null)"
if [ -z "$leaks" ]; then ok "published files carry no home-directory paths or personal email addresses"
else bad "published files carry no home-directory paths or personal email addresses" "$leaks"; fi

echo "# tests $n, pass $pass, fail $fail, skip $skip"
[ "$fail" -eq 0 ] && [ "$pass" -gt 0 ]
