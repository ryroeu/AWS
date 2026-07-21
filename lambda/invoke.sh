#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/aws.sh
source "$SCRIPT_DIR/../lib/aws.sh"

usage() {
  cat <<'EOF'
Usage: invoke.sh --function NAME (--payload JSON | --payload-file FILE)
                 --output-file FILE [--execute] [--yes]

Preview a synchronous Lambda invocation. Because invoking a function can cause side
effects, it requires --execute. The response payload is written to --output-file,
which must not already exist. --yes skips interactive confirmation.
EOF
}

function_name=""
payload=""
payload_file=""
output_file=""
execute=false
ASSUME_YES=false
while (( $# > 0 )); do
  case "$1" in
    --function) [[ $# -ge 2 ]] || die "--function requires a name"; function_name="$2"; shift 2 ;;
    --payload) [[ $# -ge 2 ]] || die "--payload requires JSON"; payload="$2"; shift 2 ;;
    --payload-file) [[ $# -ge 2 ]] || die "--payload-file requires a file"; payload_file="$2"; shift 2 ;;
    --output-file) [[ $# -ge 2 ]] || die "--output-file requires a file"; output_file="$2"; shift 2 ;;
    --execute) execute=true; shift ;;
    --yes) ASSUME_YES=true; shift ;;
    -h | --help) usage; exit 0 ;;
    *) usage >&2; die "Unknown argument: $1" ;;
  esac
done

[[ -n "$function_name" ]] || die "--function is required"
[[ -n "$output_file" ]] || die "--output-file is required"
[[ ! -e "$output_file" ]] || die "Output file already exists: $output_file"
if [[ -n "$payload" && -n "$payload_file" ]]; then
  die "Use either --payload or --payload-file, not both"
fi
if [[ -z "$payload" && -z "$payload_file" ]]; then
  die "--payload or --payload-file is required"
fi
if [[ -n "$payload_file" ]]; then
  [[ -f "$payload_file" ]] || die "Payload file does not exist: $payload_file"
  payload_argument="file://${payload_file}"
else
  payload_argument="$payload"
fi

require_jq
if [[ -n "$payload_file" ]]; then
  jq -e . "$payload_file" >/dev/null || die "Payload file does not contain valid JSON"
else
  jq -e . >/dev/null <<<"$payload" || die "--payload does not contain valid JSON"
fi
require_aws
region="$(require_region)"

aws lambda get-function-configuration --region "$region" --function-name "$function_name" \
  --query '{Function:FunctionName,Runtime:Runtime,State:State,LastUpdateStatus:LastUpdateStatus}' \
  --output table
info "Response will be written to: ${output_file}"

if [[ "$execute" != "true" ]]; then
  warn "Preview only. Re-run with --execute to invoke the function."
  exit 0
fi

confirm "Invoke ${function_name} synchronously?"
aws lambda invoke \
  --region "$region" \
  --function-name "$function_name" \
  --invocation-type RequestResponse \
  --cli-binary-format raw-in-base64-out \
  --payload "$payload_argument" \
  "$output_file"
info "Response payload saved to ${output_file}"
