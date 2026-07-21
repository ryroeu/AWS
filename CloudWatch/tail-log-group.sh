#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../Shared/aws.sh
source "$SCRIPT_DIR/../Shared/aws.sh"

usage() {
  cat <<'EOF'
Usage: tail-log-group.sh --log-group NAME [--since DURATION] [--follow]

Print recent CloudWatch Logs events. The default duration is 10m. AWS CLI duration
examples include 30s, 10m, 2h, and 1d. --follow waits for new events.
EOF
}

log_group=""
since="10m"
follow=false
while (( $# > 0 )); do
  case "$1" in
    --log-group) [[ $# -ge 2 ]] || die "--log-group requires a name"; log_group="$2"; shift 2 ;;
    --since) [[ $# -ge 2 ]] || die "--since requires a duration"; since="$2"; shift 2 ;;
    --follow) follow=true; shift ;;
    -h | --help) usage; exit 0 ;;
    *) usage >&2; die "Unknown argument: $1" ;;
  esac
done


[[ -n "$log_group" ]] || die "--log-group is required"
require_aws
region="$(require_region)"
args=(--region "$region" --since "$since" --format short)
if [[ "$follow" == "true" ]]; then
  args+=(--follow)
fi
aws logs tail "$log_group" "${args[@]}"
