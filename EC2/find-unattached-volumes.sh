#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../Shared/aws.sh
source "$SCRIPT_DIR/../Shared/aws.sh"

usage() {
  cat <<'EOF'
Usage: find-unattached-volumes.sh [--output table|json|text]

List EBS volumes in the "available" state in the configured region. An available
volume is not attached, but it may still be intentionally retained.
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

aws ec2 describe-volumes \
  --region "$region" \
  --filters Name=status,Values=available \
  --query 'Volumes[].{Name:Tags[?Key==`Name`]|[0].Value,VolumeId:VolumeId,SizeGiB:Size,Type:VolumeType,AZ:AvailabilityZone,Encrypted:Encrypted,Created:CreateTime}' \
  --output "$output"
