#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/aws.sh
source "$SCRIPT_DIR/../lib/aws.sh"

usage() {
  cat <<'EOF'
Usage: set-log-retention.sh --log-group NAME --days N [--execute] [--yes]

Preview a retention change for one CloudWatch Logs group. N must be a retention value
accepted by CloudWatch Logs. Nothing changes without --execute; --yes skips the
interactive confirmation.
EOF
}

log_group=""
days=""
execute=false
ASSUME_YES=false
while (( $# > 0 )); do
  case "$1" in
    --log-group) [[ $# -ge 2 ]] || die "--log-group requires a name"; log_group="$2"; shift 2 ;;
    --days) [[ $# -ge 2 ]] || die "--days requires a value"; days="$2"; shift 2 ;;
    --execute) execute=true; shift ;;
    --yes) ASSUME_YES=true; shift ;;
    -h | --help) usage; exit 0 ;;
    *) usage >&2; die "Unknown argument: $1" ;;
  esac
done

[[ -n "$log_group" ]] || die "--log-group is required"
valid_days="1 3 5 7 14 30 60 90 120 150 180 365 400 545 731 1096 1827 2192 2557 2922 3288 3653"
case " $valid_days " in
  *" $days "*) ;;
  *) die "--days must be one of: $valid_days" ;;
esac

require_aws
region="$(require_region)"

require_jq
current="$(aws logs describe-log-groups --region "$region" \
  --log-group-name-prefix "$log_group" --output json \
  | jq --arg name "$log_group" '[.logGroups[]
      | select(.logGroupName == $name)
      | {LogGroup: .logGroupName, CurrentRetentionDays: .retentionInDays,
         StoredBytes: .storedBytes}]')"
[[ "$(jq 'length' <<<"$current")" -eq 1 ]] || die "Log group not found: $log_group"
jq -r '.[] | [.LogGroup, (.CurrentRetentionDays // "NEVER EXPIRES"), .StoredBytes] | @tsv' \
  <<<"$current" | awk 'BEGIN {print "LOG_GROUP\tCURRENT_RETENTION_DAYS\tSTORED_BYTES"} {print}'
info "Proposed retention: ${days} days"

if [[ "$execute" != "true" ]]; then
  warn "Preview only. Re-run with --execute to set retention."
  exit 0
fi

confirm "Set retention on ${log_group} to ${days} days?"
aws logs put-retention-policy --region "$region" \
  --log-group-name "$log_group" --retention-in-days "$days"
info "Retention updated. Existing events older than the new limit are scheduled for deletion by CloudWatch Logs."
