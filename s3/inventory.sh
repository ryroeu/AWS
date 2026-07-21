#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/aws.sh
source "$SCRIPT_DIR/../lib/aws.sh"

usage() {
  cat <<'EOF'
Usage: inventory.sh

List S3 buckets with creation date, bucket region, versioning state, and whether all
four bucket-level public access block settings are enabled. Output is TSV.

UNKNOWN means the setting could not be read with the active credentials.
EOF
}

case "${1:-}" in
  -h | --help) usage; exit 0 ;;
  '') ;;
  *) usage >&2; die "Unknown argument: $1" ;;
esac

require_aws
require_jq

buckets="$(aws s3api list-buckets --output json)"
printf 'BUCKET\tCREATED\tREGION\tVERSIONING\tALL_PUBLIC_ACCESS_BLOCKS\n'

while IFS=$'\t' read -r bucket created; do
  [[ -n "$bucket" ]] || continue

  if location="$(aws s3api get-bucket-location --bucket "$bucket" \
    --query 'LocationConstraint' --output text 2>/dev/null)"; then
    case "$location" in
      None | null) location="us-east-1" ;;
      EU) location="eu-west-1" ;;
    esac
  else
    location="UNKNOWN"
  fi

  if versioning="$(aws s3api get-bucket-versioning --bucket "$bucket" \
    --query 'Status' --output text 2>/dev/null)"; then
    [[ "$versioning" != "None" ]] || versioning="Disabled"
  else
    versioning="UNKNOWN"
  fi

  if block_json="$(aws s3api get-public-access-block --bucket "$bucket" \
    --output json 2>&1)"; then
    all_blocks="$(jq -r '[.PublicAccessBlockConfiguration.BlockPublicAcls,
      .PublicAccessBlockConfiguration.IgnorePublicAcls,
      .PublicAccessBlockConfiguration.BlockPublicPolicy,
      .PublicAccessBlockConfiguration.RestrictPublicBuckets] | all' <<<"$block_json")"
  elif [[ "$block_json" == *NoSuchPublicAccessBlockConfiguration* ]]; then
    all_blocks="false"
  else
    all_blocks="UNKNOWN"
  fi

  printf '%s\t%s\t%s\t%s\t%s\n' \
    "$bucket" "$created" "$location" "$versioning" "$all_blocks"
done < <(jq -r '.Buckets[] | [.Name, .CreationDate] | @tsv' <<<"$buckets")
