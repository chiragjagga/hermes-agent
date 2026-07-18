#!/usr/bin/env bash
# Test runner for the custom userData and migration feature.
#
# Usage:
#   ./test.sh [--output_path <junit.xml>] <base|new>
#
#   base  run the existing repository tests in the change's blast radius; these
#         must pass both before and after the solution is applied.
#   new   run the new feature verification tests; these fail before the solution
#         and pass after it.
set -uo pipefail

cd /app

OUTPUT_PATH=""
if [ "${1:-}" = "--output_path" ]; then
  OUTPUT_PATH="$2"
  shift 2
fi

MODE="${1:-new}"

STATUS=0

# Helper to execute tests and log results
run_vitest() {
  local project="$1"
  local target="${2:-}"
  local xml_out="${3:-$OUTPUT_PATH}"
  
  if [ -n "$target" ]; then
    npx vitest run "$target" --reporter=junit --outputFile="$xml_out"
  else
    npx vitest run --project "$project" --reporter=junit --outputFile="$xml_out"
  fi
  
  local val=$?
  if [ $val -ne 0 ]; then
    STATUS=$val
  fi
}

run_pytest() {
  local target="$1"
  local xml_out="${2:-$OUTPUT_PATH}"
  
  pytest "$target" -v --junitxml="$xml_out"
  local val=$?
  if [ $val -ne 0 ]; then
    STATUS=$val
  fi
}

case "$MODE" in
  base)
    echo "Running base regression checks..."
    # Run the existing electron native test suite
    run_vitest "electron" "" "$OUTPUT_PATH"
    
    # Run the existing python unit tests
    # Note: exclude integration tests that require network or full app launch
    run_pytest "tests/" "$OUTPUT_PATH"
    ;;
  new)
    echo "Running new feature verification tests..."

    # 1. Run the custom path resolution vitest tests
    run_vitest "electron" "apps/desktop/electron/userdata-override.test.ts" "$OUTPUT_PATH"
    
    # 2. Run the custom python path resolution and migration tests
    run_pytest "tests/test_userdata_override.py" "$OUTPUT_PATH"
    ;;
  *)
    echo "unknown mode: $MODE (expected base or new)" >&2
    exit 2
    ;;
esac

exit "$STATUS"
