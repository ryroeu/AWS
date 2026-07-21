#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/aws.sh
source "$SCRIPT_DIR/../lib/aws.sh"

usage() {
  cat <<'EOF'
Usage: tail-logs.sh --function NAME [--since DURATION] [--follow]

Print recent events from /aws/lambda/NAME in the configured region. The default
duration is 10m. AWS CLI duration examples include 30s, 10m, 2h, and 1d. --follow
continues waiting for new events until interrupted.
EOF
}

function_name=""
since="10m"
follow=false
while (( $# > 0 )); do
  case "$1" in
    --function) [[ $# -ge 2 ]] || die "--function requires a name"; function_name="$2"; shift 2 ;;
    --since) [[ $# -ge 2 ]] || die "--since requires a duration"; since="$2"; shift 2 ;;
    --follow) follow=true; shift ;;
    -h | --help) usage; exit 0 ;;
    *) usage >&2; die "Unknown argument: $1" ;;
  esac
done

[[ -n "$function_name" ]] || die "--function is required"
require_aws
region="$(require_region)"

args=(--region "$region" --since "$since" --format short)
if [[ "$follow" == "true" ]]; then
  args+=(--follow)
fi
aws logs tail "/aws/lambda/${function_name}" "${args[@]}"

