#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/aws.sh
source "$SCRIPT_DIR/../lib/aws.sh"

usage() {
  cat <<'EOF'
Usage: audit-access-keys.sh [--days N]

List IAM user access keys, their age, status, and last use. Active keys at least N
days old are marked STALE. The default threshold is 90 days. Output is TSV.

This does not include temporary role credentials or the root user's access keys.
EOF
}

days=90
while (( $# > 0 )); do
  case "$1" in
    --days) [[ $# -ge 2 ]] || die "--days requires a value"; days="$2"; shift 2 ;;
    -h | --help) usage; exit 0 ;;
    *) usage >&2; die "Unknown argument: $1" ;;
  esac
done

validate_positive_integer "--days" "$days"
days=$((10#$days))
require_aws
require_jq

printf 'USER\tACCESS_KEY_ID\tSTATUS\tCREATED\tAGE_DAYS\tLAST_USED\tLAST_SERVICE\tASSESSMENT\n'

users="$(aws iam list-users --query 'Users[].UserName' --output text)"
[[ "$users" != "None" ]] || users=""

for user in $users; do
  keys_json="$(aws iam list-access-keys --user-name "$user" --output json)"
  while IFS=$'\t' read -r key_id status created; do
    [[ -n "$key_id" ]] || continue
    normalized_created="${created/+00:00/Z}"
    age_days="$(jq -nr --arg value "$normalized_created" \
      '((now - ($value | fromdateiso8601)) / 86400) | floor')"
    last_used_json="$(aws iam get-access-key-last-used --access-key-id "$key_id" --output json)"
    last_used="$(jq -r '.AccessKeyLastUsed.LastUsedDate // "NEVER"' <<<"$last_used_json")"
    last_service="$(jq -r '.AccessKeyLastUsed.ServiceName // "-"' <<<"$last_used_json")"
    assessment="OK"
    if [[ "$status" == "Active" ]] && (( age_days >= days )); then
      assessment="STALE"
    elif [[ "$status" == "Inactive" ]]; then
      assessment="INACTIVE"
    fi
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
      "$user" "$key_id" "$status" "$created" "$age_days" "$last_used" \
      "$last_service" "$assessment"
  done < <(jq -r '.AccessKeyMetadata[] | [.AccessKeyId, .Status, .CreateDate] | @tsv' \
    <<<"$keys_json")
done
