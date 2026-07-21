#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../Shared/aws.sh
source "$SCRIPT_DIR/../Shared/aws.sh"

usage() {
  cat <<'EOF'
Usage: find-old-manual-snapshots.sh [--days N]

List manual RDS DB snapshots created at least N days ago in the configured region.
The default is 90 days. Output is TSV. No snapshots are deleted.
EOF
}

days=90
while (( $# > 0 )); do
  case "$1" in
    --days) [[ $# -ge 2 ]] || die "--days requires a value"; days="$2"; shift 2 ;;
    -h | --help) usage; exit 0 ;;
    *) usage >&2; die "Unknown argument: $1" ;;
  esac
done

validate_positive_integer "--days" "$days"
days=$((10#$days))
require_aws
require_jq
region="$(require_region)"
cutoff="$(utc_timestamp_days_ago "$days")"

snapshots="$(aws rds describe-db-snapshots --region "$region" \
  --snapshot-type manual --output json)"
printf 'SNAPSHOT_ID\tDB_INSTANCE\tCREATED\tENGINE\tSIZE_GIB\tENCRYPTED\n'
jq -r --arg cutoff "$cutoff" '
  .DBSnapshots[]
  | select(.SnapshotCreateTime[0:19] <= $cutoff[0:19])
  | [.DBSnapshotIdentifier, .DBInstanceIdentifier, .SnapshotCreateTime,
     .Engine, .AllocatedStorage, .Encrypted]
  | @tsv
' <<<"$snapshots"
