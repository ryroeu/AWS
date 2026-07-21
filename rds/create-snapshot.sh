#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/aws.sh
source "$SCRIPT_DIR/../lib/aws.sh"

usage() {
  cat <<'EOF'
Usage: create-snapshot.sh --db DB_IDENTIFIER [--snapshot SNAPSHOT_IDENTIFIER]
                          [--execute] [--yes]

Preview creation of a manual RDS DB snapshot. A timestamped snapshot identifier is
generated when --snapshot is omitted. Creation can incur storage charges. Nothing is
created without --execute; --yes skips the interactive confirmation.
EOF
}

db_id=""
snapshot_id=""
execute=false
ASSUME_YES=false
while (( $# > 0 )); do
  case "$1" in
    --db) [[ $# -ge 2 ]] || die "--db requires an identifier"; db_id="$2"; shift 2 ;;
    --snapshot) [[ $# -ge 2 ]] || die "--snapshot requires an identifier"; snapshot_id="$2"; shift 2 ;;
    --execute) execute=true; shift ;;
    --yes) ASSUME_YES=true; shift ;;
    -h | --help) usage; exit 0 ;;
    *) usage >&2; die "Unknown argument: $1" ;;
  esac
done

[[ -n "$db_id" ]] || die "--db is required"
if [[ -z "$snapshot_id" ]]; then
  snapshot_id="${db_id}-manual-$(date -u '+%Y%m%d-%H%M%S')"
fi

require_aws
region="$(require_region)"

aws rds describe-db-instances --region "$region" --db-instance-identifier "$db_id" \
  --query 'DBInstances[0].{Identifier:DBInstanceIdentifier,Engine:Engine,Status:DBInstanceStatus,Class:DBInstanceClass}' \
  --output table
info "Proposed snapshot identifier: ${snapshot_id}"

if [[ "$execute" != "true" ]]; then
  warn "Preview only. Re-run with --execute to create the snapshot."
  exit 0
fi

confirm "Create manual snapshot ${snapshot_id} from ${db_id}?"
aws rds create-db-snapshot \
  --region "$region" \
  --db-instance-identifier "$db_id" \
  --db-snapshot-identifier "$snapshot_id" \
  --query 'DBSnapshot.{SnapshotId:DBSnapshotIdentifier,DB:DBInstanceIdentifier,Status:Status,Created:SnapshotCreateTime}' \
  --output table

