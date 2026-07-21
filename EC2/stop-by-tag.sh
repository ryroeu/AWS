#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../Shared/aws.sh
source "$SCRIPT_DIR/../Shared/aws.sh"

usage() {
  cat <<'EOF'
Usage: stop-by-tag.sh --tag KEY=VALUE [--execute] [--yes]

Preview running EC2 instances selected by an exact tag, then optionally stop them.
Without --execute, no instances are changed. --yes skips the interactive confirmation
and is intended only for reviewed automation.
EOF
}

tag=""
execute=false
ASSUME_YES=false
while (( $# > 0 )); do
  case "$1" in
    --tag) [[ $# -ge 2 ]] || die "--tag requires KEY=VALUE"; tag="$2"; shift 2 ;;
    --execute) execute=true; shift ;;
    --yes) ASSUME_YES=true; shift ;;
    -h | --help) usage; exit 0 ;;
    *) usage >&2; die "Unknown argument: $1" ;;
  esac
done

[[ "$tag" == *=* ]] || die "--tag KEY=VALUE is required"
tag_key="${tag%%=*}"
tag_value="${tag#*=}"
[[ -n "$tag_key" && -n "$tag_value" ]] || die "Both tag key and value must be non-empty"

require_aws
require_jq
region="$(require_region)"
filters="$(jq -nc \
  --arg tag_name "tag:${tag_key}" \
  --arg tag_value "$tag_value" \
  '[{Name: $tag_name, Values: [$tag_value]},
    {Name: "instance-state-name", Values: ["running"]}]')"

instances="$(aws ec2 describe-instances \
  --region "$region" \
  --filters "$filters" \
  --query 'Reservations[].Instances[].{InstanceId:InstanceId,Name:Tags[?Key==`Name`]|[0].Value,Type:InstanceType,AZ:Placement.AvailabilityZone,PrivateIP:PrivateIpAddress}' \
  --output json)"

count="$(jq 'length' <<<"$instances")"
if (( count == 0 )); then
  info "No running instances matched ${tag_key}=${tag_value} in ${region}."
  exit 0
fi

info "Matched ${count} running instance(s) in ${region}:"
jq -r '.[] | [.InstanceId, (.Name // "-"), .Type, .AZ, (.PrivateIP // "-")] | @tsv' \
  <<<"$instances" | awk 'BEGIN {print "INSTANCE_ID\tNAME\tTYPE\tAZ\tPRIVATE_IP"} {print}'

if [[ "$execute" != "true" ]]; then
  warn "Preview only. Re-run with --execute to stop these instances."
  exit 0
fi

confirm "Stop these ${count} instance(s)?"
instance_ids=()
while IFS= read -r instance_id; do
  instance_ids+=("$instance_id")
done < <(jq -r '.[].InstanceId' <<<"$instances")

aws ec2 stop-instances --region "$region" --instance-ids "${instance_ids[@]}" \
  --query 'StoppingInstances[].{InstanceId:InstanceId,Previous:PreviousState.Name,Current:CurrentState.Name}' \
  --output table
