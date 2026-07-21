#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/aws.sh
source "$SCRIPT_DIR/../lib/aws.sh"

usage() {
  cat <<'EOF'
Usage: inventory.sh [--output table|json|text]

List EC2 instances in the configured region. The default output is a table.
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

aws ec2 describe-instances \
  --region "$region" \
  --query 'Reservations[].Instances[].{Name:Tags[?Key==`Name`]|[0].Value,InstanceId:InstanceId,State:State.Name,Type:InstanceType,AZ:Placement.AvailabilityZone,PrivateIP:PrivateIpAddress,PublicIP:PublicIpAddress,LaunchTime:LaunchTime}' \
  --output "$output"

