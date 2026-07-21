#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../Shared/aws.sh
source "$SCRIPT_DIR/../Shared/aws.sh"

usage() {
  cat <<'EOF'
Usage: inventory.sh [--output table|json|text]

List RDS DB instances in the configured region. The default output is a table.
EOF
}

output=table
while (( $# > 0 )); do
  case "$1" in
    --output) [[ $# -ge 2 ]] || die "--output requires a value"; output="$2"; shift 2 ;;
    -h | --help) usage; exit 0 ;;
    *) usage >&2; die "Unknown argument: $1" ;;
  esac
done


validate_output "$output"
require_aws
region="$(require_region)"

aws rds describe-db-instances \
  --region "$region" \
  --query 'DBInstances[].{Identifier:DBInstanceIdentifier,Engine:Engine,Version:EngineVersion,Class:DBInstanceClass,Status:DBInstanceStatus,AZ:AvailabilityZone,MultiAZ:MultiAZ,Encrypted:StorageEncrypted,StorageGiB:AllocatedStorage,Endpoint:Endpoint.Address}' \
  --output "$output"
