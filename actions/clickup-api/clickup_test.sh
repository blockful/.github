#!/usr/bin/env bash
# Offline tests for clickup.sh (status-order parsing and CLI arg guards). Run: bash actions/clickup-api/clickup_test.sh
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

assert_exit() { # desc, expected_exit, args...
  local desc="$1" expected="$2"; shift 2
  bash clickup.sh "$@" >/dev/null 2>&1
  local actual=$?
  if [ "$actual" = "$expected" ]; then
    echo "ok: $desc"
  else
    echo "FAIL: $desc — expected exit $expected, got $actual"
    FAILS=$((FAILS + 1))
  fi
}

assert_order "in progress"        "2"  "[2] in progress 🤠"
assert_order "code review"        "3"  "[3] code review 🤓"
assert_order "done"               "10" "[10] done ❤️‍🔥"
assert_order "missing [N] prefix" "-1" "in review"
assert_order "empty string"       "-1" ""

assert_exit "get-status without args -> usage exit 2"  2 get-status
assert_exit "set-status with 1 arg -> usage exit 2"    2 set-status DEV-1
assert_exit "set-field with 2 args -> usage exit 2"    2 set-field DEV-1 field-uuid
assert_exit "unknown command -> usage exit 2"          2 bogus
assert_exit "mark-done-many empty list -> exit 0"      0 mark-done-many "" "[10] done ❤️‍🔥"

if [ "$FAILS" -gt 0 ]; then echo "$FAILS failure(s)"; exit 1; fi
echo "all tests passed"
