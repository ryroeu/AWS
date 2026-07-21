#!/usr/bin/env bash

# Shared helpers for the AWS CLI scripts. This file is sourced, not executed.

export AWS_PAGER=""
export AWS_CLI_AUTO_PROMPT=off

info() {
  printf 'INFO: %s\n' "$*" >&2
}

warn() {
  printf 'WARN: %s\n' "$*" >&2
}

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || die "Required command not found: $1"
}

require_aws() {
  local version
  require_command aws
  version="$(aws --version 2>&1)"
  case "$version" in
    aws-cli/2.*) ;;
    *) die "AWS CLI v2 is required (found: $version)" ;;
  esac
  aws sts get-caller-identity --output json >/dev/null \
    || die "AWS identity check failed. Verify credentials, network access, and the STS endpoint."
}

require_jq() {
  require_command jq
}

configured_region() {
  local region
  region="${AWS_REGION:-${AWS_DEFAULT_REGION:-}}"
  if [[ -z "$region" ]]; then
    region="$(aws configure get region 2>/dev/null || true)"
  fi
  printf '%s\n' "$region"
}

require_region() {
  local region
  region="$(configured_region)"
  [[ -n "$region" ]] || die \
    "No AWS region configured. Set AWS_REGION, AWS_DEFAULT_REGION, or a profile region."
  printf '%s\n' "$region"
}

validate_output() {
  case "$1" in
    table | json | text) ;;
    *) die "Unsupported output format '$1' (expected table, json, or text)" ;;
  esac
}

validate_positive_integer() {
  case "$2" in
    '' | *[!0-9]*) die "$1 must be a positive integer" ;;
  esac
  (( 10#$2 > 0 )) || die "$1 must be greater than zero"
}

confirm() {
  local prompt="$1"
  local answer
  if [[ "${ASSUME_YES:-false}" == "true" ]]; then
    return 0
  fi
  if [[ ! -t 0 ]]; then
    die "Confirmation requires a terminal. Re-run with --yes after reviewing the preview."
  fi
  read -r -p "$prompt [y/N] " answer
  case "$answer" in
    y | Y | yes | YES | Yes) return 0 ;;
    *) die "Cancelled" ;;
  esac
}

utc_date() {
  date -u '+%Y-%m-%d'
}

utc_first_day_of_month() {
  date -u '+%Y-%m-01'
}

utc_days_ago() {
  local days="$1"
  if date -u -d "$days days ago" '+%Y-%m-%d' >/dev/null 2>&1; then
    date -u -d "$days days ago" '+%Y-%m-%d'
  else
    date -u -v-"${days}"d '+%Y-%m-%d'
  fi
}

utc_timestamp_days_ago() {
  local days="$1"
  if date -u -d "$days days ago" '+%Y-%m-%dT%H:%M:%SZ' >/dev/null 2>&1; then
    date -u -d "$days days ago" '+%Y-%m-%dT%H:%M:%SZ'
  else
    date -u -v-"${days}"d '+%Y-%m-%dT%H:%M:%SZ'
  fi
}
