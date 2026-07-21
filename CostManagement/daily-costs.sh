#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../Shared/aws.sh
source "$SCRIPT_DIR/../Shared/aws.sh"

usage() {
  cat <<'EOF'
Usage: daily-costs.sh [--days N]

Show daily unblended cost totals for the last N completed UTC days. The default is
14 days. Cost Explorer data can lag behind current usage. Output is TSV.
EOF
}

days=14
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
start="$(utc_days_ago "$days")"
end="$(utc_date)"

costs="$(aws ce get-cost-and-usage \
  --region us-east-1 \
  --time-period "Start=${start},End=${end}" \
  --granularity DAILY \
  --metrics UnblendedCost \
  --output json)"

printf 'DATE\tAMOUNT\tUNIT\tESTIMATED\n'
jq -r '.ResultsByTime[]
  | [.TimePeriod.Start, .Total.UnblendedCost.Amount,
     .Total.UnblendedCost.Unit, .Estimated]
  | @tsv' <<<"$costs"
