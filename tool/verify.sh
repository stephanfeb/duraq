#!/usr/bin/env bash
#
# The gate. Everything that must be true before code leaves this machine.
#
#   tool/verify.sh            analyze, then run the suite once
#   tool/verify.sh --flake    run the suite repeatedly instead, to hunt timing
#                             flakes (see finding Q6); count defaults to 3
#
# The pre-push hook and the GitHub workflow both call this, so the check a
# contributor runs locally is the same one that guards the branch.

set -uo pipefail
cd "$(dirname "$0")/.."

bold=$'\033[1m'; red=$'\033[31m'; green=$'\033[32m'; dim=$'\033[2m'; off=$'\033[0m'
if [ ! -t 1 ]; then bold=''; red=''; green=''; dim=''; off=''; fi

failures=()

step() {
  local name="$1"; shift
  printf '%s==> %s%s\n' "$bold" "$name" "$off"
  if "$@"; then
    printf '%s    ok%s\n\n' "$green" "$off"
  else
    printf '%s    FAILED%s\n\n' "$red" "$off"
    failures+=("$name")
  fi
}

flake_runs=0
if [ "${1:-}" = "--flake" ]; then
  flake_runs="${2:-3}"
fi

if [ ! -d .dart_tool ]; then
  printf '%s==> dart pub get%s\n' "$bold" "$off"
  dart pub get || exit 1
  printf '\n'
fi

# --fatal-infos is deliberate. Without it the analyzer reports a deprecated API
# or an unused import and exits 0, which is how both shipped in 1.0.1.
step "dart analyze (--fatal-infos --fatal-warnings)" \
  dart analyze --fatal-infos --fatal-warnings

if [ "$flake_runs" -gt 0 ]; then
  for i in $(seq 1 "$flake_runs"); do
    step "dart test (run $i of $flake_runs)" dart test --reporter=failures-only
  done
else
  step "dart test" dart test --reporter=failures-only
fi

if [ "${#failures[@]}" -eq 0 ]; then
  printf '%s%sAll checks passed.%s\n' "$bold" "$green" "$off"
  exit 0
fi

printf '%s%sFailed: %s%s\n' "$bold" "$red" "${failures[*]}" "$off"
exit 1
