#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/aws.sh
source "$SCRIPT_DIR/../lib/aws.sh"

usage() {
  cat <<'EOF'
Usage: inventory.sh [--output table|json|text]

List Lambda functions in the configured region. The default output is a table.
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

aws lambda list-functions \
  --region "$region" \
  --query 'Functions[].{Function:FunctionName,Runtime:Runtime,Architectures:join(`,`,Architectures),MemoryMiB:MemorySize,TimeoutSeconds:Timeout,CodeSizeBytes:CodeSize,Modified:LastModified,State:State,PackageType:PackageType}' \
  --output "$output"

