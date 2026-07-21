#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/aws.sh
source "$SCRIPT_DIR/../lib/aws.sh"

usage() {
  cat <<'EOF'
Usage: month-to-date.sh

Show month-to-date unblended cost grouped by AWS service. Cost Explorer's end date is
exclusive, so the report covers the first of the month through the last completed UTC
day. Output is TSV, sorted from highest to lowest amount.
EOF
}

case "${1:-}" in
  -h | --help) usage; exit 0 ;;
  '') ;;
  *) usage >&2; die "Unknown argument: $1" ;;
esac

require_aws
require_jq
start="$(utc_first_day_of_month)"
end="$(utc_date)"
if [[ "$start" == "$end" ]]; then
  die "No completed UTC day exists in the current month yet; retry tomorrow."
fi

costs="$(aws ce get-cost-and-usage \
  --region us-east-1 \
  --time-period "Start=${start},End=${end}" \
  --granularity MONTHLY \
  --metrics UnblendedCost \
  --group-by Type=DIMENSION,Key=SERVICE \
  --output json)"

printf 'SERVICE\tAMOUNT\tUNIT\tPERIOD_START\tPERIOD_END_EXCLUSIVE\n'
jq -r '
  [.ResultsByTime[] as $period
   | $period.Groups[]
   | {service: .Keys[0], amount: (.Metrics.UnblendedCost.Amount | tonumber),
      unit: .Metrics.UnblendedCost.Unit, start: $period.TimePeriod.Start,
      end: $period.TimePeriod.End}]
  | sort_by(.amount) | reverse[]
  | [.service, (.amount | tostring), .unit, .start, .end]
  | @tsv
' <<<"$costs"

