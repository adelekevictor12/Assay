#!/usr/bin/env bash
# Tests for scripts/reattest-corpus.sh with a stub single-asset runner: a
# refused asset is skipped and never retried, an errored one is retried then
# reported, and an empty corpus is an error. No network, no keys.
set -euo pipefail
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
SCRIPT="$ROOT/scripts/reattest-corpus.sh"
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
fail() { echo "FAIL: $*" >&2; exit 1; }

cat >"$TMP/runner" <<'STUB'
#!/usr/bin/env bash
echo "$2" >>"$CALLS"
case "$2" in
    BAD-*) exit 1 ;;
    DOWN-*) exit 2 ;;
    *) exit 0 ;;
esac
STUB
chmod +x "$TMP/runner"
export ATTEST_RUN="$TMP/runner" CALLS="$TMP/calls" RETRY_SLEEP=0 ATTEMPTS=3 RECORD_DIR="$TMP/rec"

run() { : >"$CALLS"; set +e; OUT=$("$SCRIPT" --assets "$1" 2>&1); RC=$?; set -e; }

printf '# c\nOK-G1\nOK-G2\n' >"$TMP/ok"
run "$TMP/ok"; [ "$RC" = 0 ] || fail "all ok: exit $RC"
[ "$(wc -l <"$CALLS")" = 2 ] || fail "all ok: want 2 calls"

printf 'OK-G1\nBAD-G2\n' >"$TMP/bad"
run "$TMP/bad"; [ "$RC" = 1 ] || fail "refused: exit $RC"
[ "$(grep -c BAD "$CALLS")" = 1 ] || fail "refused asset must not be retried"
grep -q "skipped   BAD-G2" <<<"$OUT" || fail "refused: not reported as skipped"

printf 'DOWN-G1\nOK-G2\n' >"$TMP/down"
run "$TMP/down"; [ "$RC" = 2 ] || fail "errored: exit $RC"
[ "$(grep -c DOWN "$CALLS")" = 3 ] || fail "errored asset must be tried ATTEMPTS times"
grep -q OK-G2 "$CALLS" || fail "errored asset must not stop the rest of the corpus"

printf '# nothing\n' >"$TMP/empty"
run "$TMP/empty"; [ "$RC" = 2 ] || fail "empty: exit $RC"
echo "test-reattest-corpus: ok"
