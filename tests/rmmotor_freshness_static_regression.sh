#!/usr/bin/env bash
set -euo pipefail

HEADER="${1:-RMMotor.hpp}"

need() {
  rg -q -U -- "$1" "$HEADER" || {
    echo "missing: $2" >&2
    exit 1
  }
}

forbid() {
  if rg -q -- "$1" "$HEADER"; then
    echo "forbidden: $2" >&2
    exit 1
  fi
}

need 'FEEDBACK_TIMEOUT_US = 150000U' '150 ms hard timeout'
need 'LibXR::MicrosecondTimestamp last_feedback_time_' 'feedback timestamp'
need 'last_feedback_time_\(LibXR::Timebase::GetMicroseconds\(\)\)' \
  'constructor initializes feedback timestamp'
need 'const auto NOW = LibXR::Timebase::GetMicroseconds\(\);[[:space:]]*bool get_feedback = false;[[:space:]]*while \(recv_queue_\.Pop\(pack\) == LibXR::ErrorCode::OK\) \{[[:space:]]*Decode\(pack\);[[:space:]]*get_feedback = true;[[:space:]]*\}' \
  'Update drains and decodes all queued feedback'
need 'if \(get_feedback\) \{[[:space:]]*last_feedback_time_ = NOW;[[:space:]]*return LibXR::ErrorCode::OK;[[:space:]]*\}' \
  'decoded feedback refreshes timestamp before returning OK'
need 'return \(NOW - last_feedback_time_\)\.ToMicrosecond\(\) <=[[:space:]]*FEEDBACK_TIMEOUT_US[[:space:]]*\?[[:space:]]*LibXR::ErrorCode::OK[[:space:]]*:[[:space:]]*LibXR::ErrorCode::NO_RESPONSE;' \
  'timeout is inclusive at exactly 150 ms'
forbid 'NO_RESPONSE_THRESHOLD' 'loop-count threshold'
forbid 'no_response_count_' 'loop-count freshness state'
forbid 'warning_timeout' 'warning freshness stage'
forbid 'stale_timeout' 'stale freshness stage'

if [[ "${RMMOTOR_FRESHNESS_MUTANT_CHECK:-1}" == "1" ]]; then
  mutant_dir="$(mktemp -d)"
  trap 'rm -rf "$mutant_dir"' EXIT

  boundary_mutant="$mutant_dir/boundary.hpp"
  sed 's/<= FEEDBACK_TIMEOUT_US/< FEEDBACK_TIMEOUT_US/' "$HEADER" >"$boundary_mutant"
  if RMMOTOR_FRESHNESS_MUTANT_CHECK=0 bash "$0" "$boundary_mutant" \
      >/dev/null 2>&1; then
    echo 'mutation survived: exclusive timeout boundary' >&2
    exit 1
  fi
  echo 'PASS: killed exclusive timeout boundary mutant'

  refresh_mutant="$mutant_dir/refresh.hpp"
  sed 's/last_feedback_time_ = NOW;/\/\/ feedback timestamp refresh removed/' \
    "$HEADER" >"$refresh_mutant"
  if RMMOTOR_FRESHNESS_MUTANT_CHECK=0 bash "$0" "$refresh_mutant" \
      >/dev/null 2>&1; then
    echo 'mutation survived: decoded feedback does not refresh timestamp' >&2
    exit 1
  fi
  echo 'PASS: killed feedback timestamp refresh mutant'
fi

echo 'PASS: RMMotor freshness static regression checks'
