#!/usr/bin/env bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEVICE_ID="${DEVICE_ID:-edgeexplore2}"
RUN_SIM_TESTS="${RUN_SIM_TESTS:-0}"
DEVELOPER_KEY="${DEVELOPER_KEY:-$PROJECT_ROOT/developer_key.der}"

require_cmd() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    printf 'Missing required command: %s\n' "$cmd" >&2
    exit 1
  fi
}

compile_tests() {
  local field_dir="$1"
  local field_name
  field_name="$(basename "$field_dir")"
  local output_dir="$field_dir/bin"
  local output_prg="$output_dir/${field_name}-${DEVICE_ID}-tests.prg"

  mkdir -p "$output_dir"
  printf '[test-fields] compiling %s tests for %s\n' "$field_name" "$DEVICE_ID"
  monkeyc \
    -f "$field_dir/monkey.jungle" \
    -o "$output_prg" \
    -d "$DEVICE_ID" \
    -y "$DEVELOPER_KEY" \
    -w \
    -t

  if [[ "$RUN_SIM_TESTS" == "1" ]]; then
    printf '[test-fields] running %s tests in simulator\n' "$field_name"
    monkeydo "$output_prg" "$DEVICE_ID" -t
  fi
}

main() {
  require_cmd monkeyc
  if [[ "$RUN_SIM_TESTS" == "1" ]]; then
    require_cmd monkeydo
  fi
  if [[ ! -f "$DEVELOPER_KEY" ]]; then
    printf 'Missing developer key: %s\n' "$DEVELOPER_KEY" >&2
    exit 1
  fi

  local field_dir
  while IFS= read -r field_dir; do
    compile_tests "$field_dir"
  done < <(find "$PROJECT_ROOT/fields" -mindepth 1 -maxdepth 1 -type d | sort)
}

main "$@"
