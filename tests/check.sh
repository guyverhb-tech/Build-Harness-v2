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

# --- Published files ---------------------------------------------------------------------

# A guard rather than a test of new behaviour: it passes today and must keep passing.
leaks="$(cd "$ROOT" && git ls-files -z | xargs -0 grep -n -I -E '/Users/[A-Za-z]|/home/[a-z]|[A-Za-z0-9._%+-]+@(gmail|googlemail|outlook|hotmail|icloud|me|yahoo|proton|protonmail)\.' 2>/dev/null)"
if [ -z "$leaks" ]; then ok "published files carry no home-directory paths or personal email addresses"
else bad "published files carry no home-directory paths or personal email addresses" "$leaks"; fi

echo "# tests $n, pass $pass, fail $fail, skip $skip"
[ "$fail" -eq 0 ] && [ "$pass" -gt 0 ]
