# Re-attestation runbook

Attestations age out. The registry stores `attested_at` and nothing else, and a
gate refuses anything older than its window ([freshness.md](freshness.md)). The
example gate's window is 24 hours, so a corpus nobody refreshes becomes a gate
that refuses everything. That is the policy working, not a defect: **a stale
attestation is the trigger for re-attestation, not an error.** This runbook is
the procedure that refreshes the whole attested corpus.

Scope: the testnet registry in [deployment.md](deployment.md). The corpus is
the ten assets under "Attested assets" there, listed one per line in
[`scripts/attested-assets.txt`](../scripts/attested-assets.txt).

## Cadence

Re-attest at least **twice per freshness window**. For the example gate's
24-hour window that is every **12 hours**; a single missed run still leaves
every attestation inside the window. A longer cadence than the window is a
countdown that guarantees a refusing gate between runs. A gate that picks a
shorter window than the cadence can sustain must not claim availability
(see [freshness.md](freshness.md#recommended-windows)). The cadence is a
property of the window, so change them together.

## Procedure

Run from a checkout, on the machine that holds the attester key
([attester-key.md](attester-key.md)), with the pinned `stellar` CLI:

```sh
make reattest        # every asset in scripts/attested-assets.txt
```

For a single asset, or to verify one afterwards:

```sh
make attest ASSET=AQUA-GBNZILSTVQZ4R7IKQDGHYGY2QXL5QOFJYQMXPKWRRM5PAV7Y4M67AQUA
make read   ASSET=AQUA-GBNZILSTVQZ4R7IKQDGHYGY2QXL5QOFJYQMXPKWRRM5PAV7Y4M67AQUA
```

`make reattest` is a loop over the same single-asset runner `make attest` uses
([attestation-writer.md](attestation-writer.md#the-run-record)). Every number
submitted still comes from a live `assay attestation` scan; nothing in the loop
can supply a value by hand. One run record per asset is written under
`attest-runs/`, whatever the outcome.

## What happens to each outcome

| Outcome | Meaning | Action |
| --- | --- | --- |
| **attested** | The scan completed and the attestation was written. | Record the transaction hash from the run record. |
| **refused** — undetermined scan | `attest.FromReport` refuses an undetermined (or stale, or never-evaluated) report. | **Skipped, never attested.** The reason is in the run record. The asset keeps its previous attestation, which keeps aging. The loop never retries a refusal and has no flag to force one. |
| **errored** — source outage or submission failure | A source was unreachable or the transaction failed. | Nothing is written for the asset. The loop retries (`ATTEMPTS`, default 3, `RETRY_SLEEP`, default 300 s) and, if it still fails, reports the asset as errored and exits 2. Re-run later; never attest a partial result. |

Exit codes: `0` every asset attested; `1` at least one asset refused and
skipped (none errored); `2` at least one errored. A skipped asset needs a
human to read the reason: an undetermined scan usually means a source
degraded, and the right response is to wait or investigate
([source-outage.md](source-outage.md)), not to lower a bar.

## Key custody: why this is manual

The attester is one ed25519 key held on one machine
([attester-key.md](attester-key.md#custody-and-backup--current-state-stated-plainly)).
Automating re-attestation would mean putting that key where an unattended job
can use it, which widens the exposure the threat model already calls its
central accepted risk. So **the procedure is manual, started by the key holder
at a terminal that already has the identity, and the repository contains no
scheduled job that signs.** `make reattest` is the scheduler in the sense of a
repeatable corpus run; the cadence above is how often a person (or a future,
separately reviewed signing service) must start it. If the admin moves to a
multisig ([attester-key.md](attester-key.md#signing-ceremony-for-a-multisig-admin)),
each run additionally needs the signers' ceremony and the cadence must account
for it.

## Recording a run

After each full run, add a row here with the date, the run IDs under
`attest-runs/`, and the per-asset outcome. A run that skips an asset is
recorded as skipped with the reason, not omitted.

| Date (UTC) | Operator | Attested | Skipped | Errored | Notes |
| --- | --- | --- | --- | --- | --- |
| — | — | — | — | — | No full run has been recorded yet. A run needs the attester key and live network access, so it is executed by the key holder and recorded here. |

## Out of scope

The freshness policy itself ([freshness.md](freshness.md)) and TTL extension.
