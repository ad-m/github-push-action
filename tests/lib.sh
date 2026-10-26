#!/bin/bash
# Minimal assertion helpers shared by unit.sh and e2e.sh.
PASS=0
FAIL=0

ok()   { PASS=$((PASS + 1)); echo "  ok   - $1"; }
fail() { FAIL=$((FAIL + 1)); echo "  FAIL - $1"; [ -n "${2:-}" ] && echo "         $2"; }

assert_eq() { # name expected actual
    if [ "$2" = "$3" ]; then ok "$1"; else fail "$1" "expected '$2', got '$3'"; fi
}
assert_contains() { # name haystack needle
    case "$2" in *"$3"*) ok "$1" ;; *) fail "$1" "'$3' not found in: $2" ;; esac
}
assert_not_contains() { # name haystack needle
    case "$2" in *"$3"*) fail "$1" "'$3' unexpectedly found in: $2" ;; *) ok "$1" ;; esac
}

summary() {
    echo; echo "passed: $PASS, failed: $FAIL"
    [ "$FAIL" -eq 0 ]
}
