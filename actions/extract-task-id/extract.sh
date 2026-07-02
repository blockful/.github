#!/usr/bin/env bash
# Extracts a ClickUp custom task ID (e.g. DEV-970) from branch name, PR title, or PR body.
# Env inputs: BRANCH, PR_TITLE, PR_BODY, PREFIX (default DEV), ACTOR
# Stdout: GITHUB_OUTPUT-compatible lines: found=, task_id=, skip_reason=
set -uo pipefail

PREFIX="${PREFIX:-DEV}"
BRANCH="${BRANCH:-}"
PR_TITLE="${PR_TITLE:-}"
PR_BODY="${PR_BODY:-}"
ACTOR="${ACTOR:-}"

emit() { echo "found=$1"; echo "task_id=$2"; echo "skip_reason=$3"; }

if ! [[ "$PREFIX" =~ ^[A-Za-z0-9_]+$ ]]; then
  echo "::warning::Invalid task prefix '$PREFIX' (must be alphanumeric/underscore)" >&2
  emit false "" invalid_prefix; exit 0
fi

case "$ACTOR" in
  "dependabot[bot]" | "github-actions[bot]" | "renovate[bot]")
    emit false "" bot; exit 0 ;;
esac
case "$PR_TITLE" in
  "Version Packages"*)
    emit false "" bot; exit 0 ;;
esac

for source in "$BRANCH" "$PR_TITLE" "$PR_BODY"; do
  id="$(printf '%s' "$source" | grep -oiE "${PREFIX}-[0-9]+" | head -n1 | tr '[:lower:]' '[:upper:]' || true)"
  if [ -n "$id" ]; then
    emit true "$id" ""; exit 0
  fi
done

emit false "" none
