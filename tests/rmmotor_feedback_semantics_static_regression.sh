#!/usr/bin/env bash
set -euo pipefail

module_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
motor_header="$module_dir/../Motor/Motor.hpp"
rmmotor_header="$module_dir/RMMotor.hpp"

need() {
  local file=$1
  local pattern=$2
  local description=$3
  rg -q -U -- "$pattern" "$file" || {
    printf 'missing: %s\n' "$description" >&2
    exit 1
  }
}

need "$motor_header" 'uint64_t received_time_us = 0;' \
  'feedback receive timestamp'
need "$motor_header" 'uint16_t sequence = 0;' 'feedback sequence'
need "$rmmotor_header" \
  'const TimestampedFeedback RECEIVED\{[[:space:]]*pack, static_cast<uint64_t>\(LibXR::Timebase::GetMicroseconds\(\)\)\};' \
  'receive timestamp captured with CAN frame'
need "$rmmotor_header" \
  'if \(Decode\(received\)\) \{[[:space:]]*get_feedback = true;[[:space:]]*\}' \
  'only valid decode refreshes watchdog'
need "$rmmotor_header" \
  'pack.id != config_param_.id_feedback \|\|[[:space:]]*pack.type != LibXR::CAN::Type::STANDARD \|\| pack.dlc < 7U' \
  'CAN identity, type, and length validation'
need "$rmmotor_header" \
  'feedback_.received_time_us = received.received_time_us;[[:space:]]*\+\+feedback_.sequence;[[:space:]]*return true;' \
  'timestamp and sequence update only after successful decode'

python3 - "$rmmotor_header" <<'PY'
from pathlib import Path
import sys

source = Path(sys.argv[1]).read_text()
decode = source[source.index("  bool Decode("):source.index("  /**", source.index("  bool Decode("))]
if decode.count("feedback_.received_time_us =") != 1 or decode.count("++feedback_.sequence") != 1:
    raise SystemExit("timestamp/sequence must have one decode owner")
outside = source.replace(decode, "")
if "feedback_.received_time_us =" in outside or "++feedback_.sequence" in outside:
    raise SystemExit("timestamp/sequence changed outside Decode")

mutants = (
    decode.replace("pack.dlc < 7U", "pack.dlc < 6U"),
    decode.replace("++feedback_.sequence;", ""),
    decode.replace("feedback_.received_time_us = received.received_time_us;", ""),
)
checks = ("pack.dlc < 7U", "++feedback_.sequence;", "feedback_.received_time_us =")
for mutant, required in zip(mutants, checks):
    if required in mutant:
        raise SystemExit(f"mutation survived: {required}")
PY

printf 'PASS: RMMotor feedback timestamp and sequence semantics\n'
