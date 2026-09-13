#!/usr/bin/env bash
#
# Points git at the hooks tracked in .githooks/, so they are version controlled
# and everyone gets the same ones. One setting, no copying into .git/hooks.

set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

git config core.hooksPath .githooks
echo "core.hooksPath -> .githooks"
echo "pre-push will now run tool/verify.sh. Skip a push with --no-verify."
