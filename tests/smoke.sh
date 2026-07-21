#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
failures=0

while IFS= read -r script; do
  if ! bash -n "$script"; then
    failures=$((failures + 1))
  fi
done < <(find "$ROOT_DIR" -type f -name '*.sh' -not -path '*/.git/*' | sort)

while IFS= read -r script; do
  if [[ ! -x "$script" ]]; then
    printf 'Not executable: %s\n' "${script#"$ROOT_DIR"/}" >&2
    failures=$((failures + 1))
  fi
  if ! "$script" --help >/dev/null; then
    printf 'Help check failed: %s\n' "${script#"$ROOT_DIR"/}" >&2
    failures=$((failures + 1))
  fi
done < <(find "$ROOT_DIR" -mindepth 2 -type f -name '*.sh' \
  -not -path '*/legacy/*' -not -path '*/lib/*' -not -path '*/tests/*' | sort)

if command -v shellcheck >/dev/null 2>&1; then
  scripts=()
  while IFS= read -r script; do
    scripts+=("$script")
  done < <(find "$ROOT_DIR" -type f -name '*.sh' \
    -not -path '*/.git/*' -not -path '*/legacy/*' | sort)
  if (( ${#scripts[@]} > 0 )); then
    shellcheck "${scripts[@]}" || failures=$((failures + 1))
  fi
else
  printf 'ShellCheck not installed; skipping lint.\n' >&2
fi

(( failures == 0 )) || exit 1
printf 'All smoke checks passed.\n'
