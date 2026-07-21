#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../Shared/aws.sh
source "$SCRIPT_DIR/../Shared/aws.sh"

usage() {
  cat <<'EOF'
Usage: find-unattached-eips.sh [--output table|json|text]

List Elastic IP allocations with no association in the configured region. Review
their intended use and current AWS pricing before deciding whether to release them.
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

aws ec2 describe-addresses \
  --region "$region" \
  --query 'Addresses[?AssociationId==null].{Name:Tags[?Key==`Name`]|[0].Value,PublicIP:PublicIp,AllocationId:AllocationId,Domain:Domain,NetworkBorderGroup:NetworkBorderGroup}' \
  --output "$output"
