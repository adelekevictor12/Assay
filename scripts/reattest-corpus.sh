#!/usr/bin/env bash
# Re-attest the whole attested corpus, one asset at a time, as an operator
# runs it by hand (docs/reattestation.md). It is a loop over
# scripts/attest-run.sh and adds no attestation logic of its own:
#
#   - attested (exit 0): done.
#   - refused (exit 1): the scan was undetermined, stale or otherwise refused
#     by attest.FromReport. Skipped, recorded, NEVER retried, never forced.
#   - errored (exit 2): a source outage or submission failure. Retried up to
#     ATTEMPTS times after RETRY_SLEEP seconds; if it still errors, nothing is
#     written for that asset and the run exits 2 so the operator re-runs later.
#
# It never reads or handles key material: signing is the stellar identity
# named by SOURCE, exactly as for `make attest`. It is meant to be started by
# a person at a terminal that holds the key, not from an unattended job.
#
#   scripts/reattest-corpus.sh [--assets FILE]
#
# Environment: everything attest-run.sh takes, plus
#   ATTEST_RUN   the single-asset runner   (default scripts/attest-run.sh)
#   ATTEMPTS     tries per asset            (default 3)
#   RETRY_SLEEP  seconds between tries      (default 300)
#   RECORD_DIR   run records land here      (default attest-runs)
#
# Exit: 0 every asset attested; 1 at least one refused/skipped, none errored;
# 2 at least one errored or usage error.
set -uo pipefail

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ATTEST_RUN=${ATTEST_RUN:-$HERE/attest-run.sh}
ATTEMPTS=${ATTEMPTS:-3}
RETRY_SLEEP=${RETRY_SLEEP:-300}
RECORD_DIR=${RECORD_DIR:-attest-runs}
ASSETS_FILE=$HERE/attested-assets.txt

while [ $# -gt 0 ]; do
    case "$1" in
        --assets) ASSETS_FILE=${2:-}; shift 2 ;;
        *) echo "reattest-corpus: unknown argument $1" >&2; exit 2 ;;
    esac
done
[ -r "$ASSETS_FILE" ] || { echo "reattest-corpus: cannot read $ASSETS_FILE" >&2; exit 2; }

n_ok=0; n_skip=0; n_err=0; summary=""
while IFS= read -r asset; do
    case "$asset" in ''|'#'*) continue ;; esac
    try=1
    while :; do
        RECORD_DIR=$RECORD_DIR "$ATTEST_RUN" --asset "$asset"
        rc=$?
        [ "$rc" = 2 ] && [ "$try" -lt "$ATTEMPTS" ] || break
        try=$((try + 1))
        echo "reattest-corpus: $asset errored; retry $try/$ATTEMPTS in ${RETRY_SLEEP}s" >&2
        sleep "$RETRY_SLEEP"
    done
    case "$rc" in
        0) n_ok=$((n_ok + 1)); summary+="attested  $asset"$'\n' ;;
        1) n_skip=$((n_skip + 1)); summary+="skipped   $asset (refused; not written)"$'\n' ;;
        *) n_err=$((n_err + 1)); summary+="errored   $asset (not written; re-run later)"$'\n' ;;
    esac
done <"$ASSETS_FILE"

printf '\nreattest-corpus summary\n%s' "$summary"
echo "attested=$n_ok skipped=$n_skip errored=$n_err"
[ "$n_err" -gt 0 ] && exit 2
[ "$n_skip" -gt 0 ] && exit 1
[ "$n_ok" -gt 0 ] || { echo "reattest-corpus: empty corpus" >&2; exit 2; }
exit 0
