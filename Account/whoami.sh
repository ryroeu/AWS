#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../Shared/aws.sh
source "$SCRIPT_DIR/../Shared/aws.sh"

usage() {
  cat <<'EOF'
Usage: whoami.sh

Show the active AWS identity, account alias, configured region, and profile. This is
a read-only preflight check to run before operating on an account.
EOF
}

case "${1:-}" in
  -h | --help) usage; exit 0 ;;
  '') ;;
  *) usage >&2; die "Unknown argument: $1" ;;
esac

require_aws
require_jq

identity="$(aws sts get-caller-identity --output json)"
alias_name="$(aws iam list-account-aliases --query 'AccountAliases[0]' --output text 2>/dev/null || true)"
[[ "$alias_name" != "None" ]] || alias_name=""
region="$(configured_region)"
profile="${AWS_PROFILE:-default credential chain}"

jq -n \
  --argjson identity "$identity" \
  --arg alias "$alias_name" \
  --arg region "$region" \
  --arg profile "$profile" \
  '{
    account_id: $identity.Account,
    account_alias: (if $alias == "" then null else $alias end),
    principal_arn: $identity.Arn,
    user_id: $identity.UserId,
    region: (if $region == "" then null else $region end),
    profile: $profile
  }'
