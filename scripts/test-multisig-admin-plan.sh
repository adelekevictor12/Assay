#!/usr/bin/env bash
# Tests for scripts/multisig-admin-plan.sh: validates public keys, refuses
# seeds and duplicates, prints the 2-of-3 thresholds. No network, no keys.
set -euo pipefail
S="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/multisig-admin-plan.sh"
fail() { echo "FAIL: $*" >&2; exit 1; }
k() { printf 'G%s' "$(printf '%s' "$1" | head -c1 | tr -c 'A-Z' 'A')$(printf 'A%.0s' {1..54})"; }
A=$(k A) B=$(k B) C=$(k C) D=$(k D)
out=$("$S" "$A" "$B" "$C" "$D") || fail "valid input rejected"
grep -q -- "--low-threshold 2 --med-threshold 2 --high-threshold 2 --master-weight 0" <<<"$out" || fail "thresholds missing"
[ "$(grep -c -- '--signer-weight 1' <<<"$out")" = 3 ] || fail "want three weight-1 signers"
"$S" "$A" "$B" "$C" "$C" >/dev/null 2>&1 && fail "duplicate accepted"
"$S" "$A" "$B" "$C" "S$(printf 'A%.0s' {1..55})" >/dev/null 2>&1 && fail "seed accepted"
"$S" "$A" "$B" >/dev/null 2>&1 && fail "short args accepted"
echo "test-multisig-admin-plan: ok"
