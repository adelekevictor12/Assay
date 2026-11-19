#!/usr/bin/env bash
# Print the public-key-only plan for moving the registry admin to a 2-of-3
# Stellar multisig account (docs/attester-key.md, "Signing ceremony for a
# multisig admin"). It takes PUBLIC keys (G...) and prints commands for the
# signers to review and run on their own machines. It never reads, generates
# or prints a secret key or seed, and it submits nothing.
#
#   scripts/multisig-admin-plan.sh MULTISIG_ACCOUNT SIGNER1 SIGNER2 SIGNER3
#
# Exit: 0 plan printed; 2 usage error or a malformed or duplicated key.
set -euo pipefail

usage() { echo "usage: $0 MULTISIG_ACCOUNT SIGNER1 SIGNER2 SIGNER3 (public G... keys)" >&2; exit 2; }
[ $# -eq 4 ] || usage

# A secret seed starts with S; refuse it loudly rather than echo it anywhere.
for k in "$@"; do
    case "$k" in S*) echo "multisig-admin-plan: refusing an argument that looks like a secret seed" >&2; exit 2 ;; esac
    [[ "$k" =~ ^G[A-Z2-7]{55}$ ]] || { echo "multisig-admin-plan: not a public Stellar account key (G + 55 base32 characters)" >&2; exit 2; }
done
if [ "$(printf '%s\n' "$@" | sort -u | wc -l)" -ne 4 ]; then
    echo "multisig-admin-plan: the account and the three signers must be four distinct keys" >&2
    exit 2
fi

ACCOUNT=$1; S1=$2; S2=$3; S3=$4
cat <<PLAN
# 1. Configure $ACCOUNT as 2-of-3. Run ONCE, signed by the account's current
#    key holder, then verify with step 2 BEFORE the master key is retired.
stellar tx new set-options --source-account $ACCOUNT --network testnet \\
  --signer $S1 --signer-weight 1
stellar tx new set-options --source-account $ACCOUNT --network testnet \\
  --signer $S2 --signer-weight 1
stellar tx new set-options --source-account $ACCOUNT --network testnet \\
  --signer $S3 --signer-weight 1
stellar tx new set-options --source-account $ACCOUNT --network testnet \\
  --low-threshold 2 --med-threshold 2 --high-threshold 2 --master-weight 0

# 2. Verify: three signers of weight 1, master weight 0, thresholds all 2.
curl -s https://horizon-testnet.stellar.org/accounts/$ACCOUNT

# 3. Hand the admin role to $ACCOUNT (registry built with transfer_admin):
#    propose from the current admin, then accept signed by 2 of the 3 signers.
stellar contract invoke --id \$CONTRACT_ID --source-account assay-attester --network testnet \\
  -- transfer_admin --new_admin $ACCOUNT
# accept_admin must carry two of: $S1 $S2 $S3
PLAN
