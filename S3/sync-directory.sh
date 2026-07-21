#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../Shared/aws.sh
source "$SCRIPT_DIR/../Shared/aws.sh"

usage() {
  cat <<'EOF'
Usage: sync-directory.sh --source DIR --destination s3://BUCKET/PREFIX
                         [--delete] [--execute] [--yes]

Preview an upload from a local directory using `aws s3 sync --dryrun`. Re-run with
--execute to perform the sync. --delete also removes destination objects absent from
the source and therefore deserves extra care. --yes skips interactive confirmation.
EOF
}

source_dir=""
destination=""
delete=false
execute=false
ASSUME_YES=false
while (( $# > 0 )); do
  case "$1" in
    --source) [[ $# -ge 2 ]] || die "--source requires a directory"; source_dir="$2"; shift 2 ;;
    --destination) [[ $# -ge 2 ]] || die "--destination requires an S3 URI"; destination="$2"; shift 2 ;;
    --delete) delete=true; shift ;;
    --execute) execute=true; shift ;;
    --yes) ASSUME_YES=true; shift ;;
    -h | --help) usage; exit 0 ;;
    *) usage >&2; die "Unknown argument: $1" ;;
  esac
done

[[ -d "$source_dir" ]] || die "Source directory does not exist: $source_dir"
[[ "$destination" == s3://* ]] || die "Destination must start with s3://"
require_aws

sync_args=("$source_dir" "$destination")
if [[ "$delete" == "true" ]]; then
  sync_args+=(--delete)
fi

info "Previewing sync: ${source_dir} -> ${destination}"
aws s3 sync "${sync_args[@]}" --dryrun

if [[ "$execute" != "true" ]]; then
  warn "Preview only. Re-run with --execute to perform this sync."
  exit 0
fi

if [[ "$delete" == "true" ]]; then
  confirm "Sync now and delete destination objects not present in the source?"
else
  confirm "Sync this directory now?"
fi
aws s3 sync "${sync_args[@]}"
