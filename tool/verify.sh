#!/usr/bin/env bash
#
# The gate. Everything that must be true before code leaves this machine,
# across every package in the repository.
#
#   tool/verify.sh              analyze, then run each package's suite once
#   tool/verify.sh --flake      run the suites repeatedly instead, to hunt
#                               timing flakes (see finding Q6); count
#                               defaults to 3
#   tool/verify.sh --tests-only skip analysis and just run the suites. For
#                               checking that an older SDK still builds and
#                               passes: lint rules move between analyzer
#                               versions, and an old analyzer disagreeing with
#                               a new one says nothing about whether the code
#                               works. The stable job is what holds the lints.
#
# The pre-push hook and the GitHub workflow both call this, so the check a
# contributor runs locally is the same one that guards the branch.

set -uo pipefail
cd "$(dirname "$0")/.."

PACKAGES=(packages/duraq packages/duraq_isar)

bold=$'\033[1m'; red=$'\033[31m'; green=$'\033[32m'; off=$'\033[0m'
if [ ! -t 1 ]; then bold=''; red=''; green=''; off=''; fi

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

in_package() {
  local pkg="$1"; shift
  ( cd "$pkg" && "$@" )
}

flake_runs=0
analyze=1
case "${1:-}" in
  --flake) flake_runs="${2:-3}" ;;
  --tests-only) analyze=0 ;;
esac

for pkg in "${PACKAGES[@]}"; do
  if [ ! -d "$pkg/.dart_tool" ]; then
    printf '%s==> %s: dart pub get%s\n' "$bold" "$pkg" "$off"
    in_package "$pkg" dart pub get || exit 1
    printf '\n'
  fi
done

for pkg in "${PACKAGES[@]}"; do
  # --fatal-infos is deliberate. Without it the analyzer reports a deprecated
  # API or an unused import and exits 0, which is how both shipped in 1.0.1.
  if [ "$analyze" -eq 1 ]; then
    step "$pkg: dart analyze (--fatal-infos --fatal-warnings)" \
      in_package "$pkg" dart analyze --fatal-infos --fatal-warnings
  fi

  if [ "$flake_runs" -gt 0 ]; then
    for i in $(seq 1 "$flake_runs"); do
      step "$pkg: dart test (run $i of $flake_runs)" \
        in_package "$pkg" dart test --reporter=failures-only
    done
  else
    step "$pkg: dart test" in_package "$pkg" dart test --reporter=failures-only
  fi
done

if [ "${#failures[@]}" -eq 0 ]; then
  printf '%s%sAll checks passed.%s\n' "$bold" "$green" "$off"
  exit 0
fi

printf '%s%sFailed: %s%s\n' "$bold" "$red" "${failures[*]}" "$off"
exit 1
