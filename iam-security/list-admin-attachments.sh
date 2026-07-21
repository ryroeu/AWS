#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/aws.sh
source "$SCRIPT_DIR/../lib/aws.sh"

usage() {
  cat <<'EOF'
Usage: list-admin-attachments.sh

List users, groups, and roles directly attached to AWS's managed
AdministratorAccess policy. Output is TSV.

Important: this is a narrow, useful signal—not a complete privilege-escalation or
effective-permissions analysis. Inline and custom managed policies are not inspected.
EOF
}

case "${1:-}" in
  -h | --help) usage; exit 0 ;;
  '') ;;
  *) usage >&2; die "Unknown argument: $1" ;;
esac

require_aws
require_jq

caller_arn="$(aws sts get-caller-identity --query Arn --output text)"
partition="${caller_arn#arn:}"
partition="${partition%%:*}"
policy_arn="arn:${partition}:iam::aws:policy/AdministratorAccess"

entities="$(aws iam list-entities-for-policy --policy-arn "$policy_arn" --output json)"
printf 'ENTITY_TYPE\tENTITY_NAME\tPOLICY_ARN\n'
jq -r --arg policy "$policy_arn" '
  ((.PolicyUsers[]? | ["USER", .UserName, $policy]),
   (.PolicyGroups[]? | ["GROUP", .GroupName, $policy]),
   (.PolicyRoles[]? | ["ROLE", .RoleName, $policy]))
  | @tsv
' <<<"$entities"
