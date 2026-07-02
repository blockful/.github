#!/usr/bin/env bash
# Offline tests for clickup.sh (status-order parsing only). Run: bash actions/clickup-api/clickup_test.sh
set -u
cd "$(dirname "$0")"
FAILS=0

assert_order() { # desc, expected, status-string
  local desc="$1" expected="$2" status="$3" actual
  actual="$(bash clickup.sh status-order "$status")"
  if [ "$actual" = "$expected" ]; then
    echo "ok: $desc"
  else
    echo "FAIL: $desc — expected '$expected', got '$actual'"
    FAILS=$((FAILS + 1))
  fi
}

assert_order "in progress"        "2"  "[2] in progress 🤠"
assert_order "code review"        "3"  "[3] code review 🤓"
assert_order "done"               "10" "[10] done ❤️‍🔥"
assert_order "sem prefixo [N]"    "-1" "in review"
assert_order "string vazia"       "-1" ""

if [ "$FAILS" -gt 0 ]; then echo "$FAILS failure(s)"; exit 1; fi
echo "all tests passed"
