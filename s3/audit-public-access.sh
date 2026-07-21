#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/aws.sh
source "$SCRIPT_DIR/../lib/aws.sh"

usage() {
  cat <<'EOF'
Usage: audit-public-access.sh

Review S3 bucket policy status, public ACL grants, and bucket-level public access
block configuration. Output is TSV. UNKNOWN means a signal was absent or unreadable.

This is a configuration audit, not proof of effective access. Account-level block
settings are printed separately and may override a bucket's configuration.
EOF
}

case "${1:-}" in
  -h | --help) usage; exit 0 ;;
  '') ;;
  *) usage >&2; die "Unknown argument: $1" ;;
esac

require_aws
require_jq

account_id="$(aws sts get-caller-identity --query Account --output text)"
if account_block="$(aws s3control get-public-access-block --account-id "$account_id" \
  --output json 2>/dev/null)"; then
  info "Account-level public access block: $(jq -c '.PublicAccessBlockConfiguration' \
    <<<"$account_block")"
else
  warn "Account-level public access block is not configured or could not be read."
fi

printf 'BUCKET\tPOLICY_PUBLIC\tACL_PUBLIC\tALL_BUCKET_BLOCKS\tASSESSMENT\n'
buckets="$(aws s3api list-buckets --query 'Buckets[].Name' --output text)"
[[ "$buckets" != "None" ]] || buckets=""

for bucket in $buckets; do
  policy_public="UNKNOWN"
  if policy_json="$(aws s3api get-bucket-policy-status --bucket "$bucket" \
    --output json 2>&1)"; then
    policy_public="$(jq -r '.PolicyStatus.IsPublic' <<<"$policy_json")"
  elif [[ "$policy_json" == *NoSuchBucketPolicy* ]]; then
    policy_public="false"
  fi

  acl_public="UNKNOWN"
  if acl_json="$(aws s3api get-bucket-acl --bucket "$bucket" --output json 2>/dev/null)"; then
    acl_public="$(jq -r '[.Grants[]?.Grantee.URI // "" |
      contains("acs.amazonaws.com/groups/global/")] | any' <<<"$acl_json")"
  fi

  all_blocks="UNKNOWN"
  if block_json="$(aws s3api get-public-access-block --bucket "$bucket" \
    --output json 2>&1)"; then
    all_blocks="$(jq -r '[.PublicAccessBlockConfiguration.BlockPublicAcls,
      .PublicAccessBlockConfiguration.IgnorePublicAcls,
      .PublicAccessBlockConfiguration.BlockPublicPolicy,
      .PublicAccessBlockConfiguration.RestrictPublicBuckets] | all' <<<"$block_json")"
  elif [[ "$block_json" == *NoSuchPublicAccessBlockConfiguration* ]]; then
    all_blocks="false"
  fi

  assessment="NO_PUBLIC_GRANTS_FOUND"
  if [[ "$policy_public" == "true" || "$acl_public" == "true" ]]; then
    if [[ "$all_blocks" == "true" ]]; then
      assessment="PUBLIC_CONFIGURATION_BLOCKED_AT_BUCKET"
    else
      assessment="REVIEW_PUBLIC_ACCESS"
    fi
  elif [[ "$policy_public" == "UNKNOWN" || "$acl_public" == "UNKNOWN" ]]; then
    assessment="INCOMPLETE_DATA"
  fi

  printf '%s\t%s\t%s\t%s\t%s\n' \
    "$bucket" "$policy_public" "$acl_public" "$all_blocks" "$assessment"
done
