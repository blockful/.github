#!/usr/bin/env bash
# Test suite for extract.sh. Run: bash actions/extract-task-id/extract_test.sh
set -u
cd "$(dirname "$0")"
FAILS=0

assert_line() { # desc, expected_line, then env pairs
  local desc="$1" expected="$2"; shift 2
  local actual
  actual="$(env -i PATH="$PATH" "$@" bash extract.sh)"
  if grep -q "^${expected}$" <<<"$actual"; then
    echo "ok: $desc"
  else
    echo "FAIL: $desc — expected '$expected', got:"
    sed 's/^/    /' <<<"$actual"
    FAILS=$((FAILS + 1))
  fi
}

assert_line "ID no nome da branch"        "task_id=DEV-970" BRANCH=feat/DEV-970-test-integration ACTOR=bruno
assert_line "branch minúscula normaliza"  "task_id=DEV-970" BRANCH=feat/dev-970-x ACTOR=bruno
assert_line "branch tem prioridade"       "task_id=DEV-1"   BRANCH=feat/DEV-1-x PR_TITLE="DEV-2 fix" ACTOR=bruno
assert_line "fallback: título do PR"      "task_id=DEV-12"  BRANCH=feat/no-id PR_TITLE="DEV-12 fix" ACTOR=bruno
assert_line "fallback: corpo do PR"       "task_id=DEV-33"  BRANCH=feat/no-id PR_TITLE="fix" PR_BODY="closes DEV-33" ACTOR=bruno
assert_line "sem ID -> found=false"       "found=false"     BRANCH=feat/nothing PR_TITLE=t PR_BODY=b ACTOR=bruno
assert_line "sem ID -> skip_reason=none"  "skip_reason=none" BRANCH=feat/nothing ACTOR=bruno
assert_line "dependabot é pulado"         "skip_reason=bot" BRANCH="dependabot/npm/x-DEV-1" ACTOR="dependabot[bot]"
assert_line "github-actions é pulado"     "skip_reason=bot" BRANCH="feat/DEV-5" ACTOR="github-actions[bot]"
assert_line "Version Packages é pulado"   "skip_reason=bot" BRANCH="changeset-release/dev" PR_TITLE="Version Packages" ACTOR=bruno
assert_line "prefixo customizado"         "task_id=OPS-7"   BRANCH=fix/OPS-7-thing PREFIX=OPS ACTOR=bruno
assert_line "prefixo não pega DEV"        "found=false"     BRANCH=feat/DEV-970 PREFIX=OPS ACTOR=bruno

if [ "$FAILS" -gt 0 ]; then echo "$FAILS failure(s)"; exit 1; fi
echo "all tests passed"
