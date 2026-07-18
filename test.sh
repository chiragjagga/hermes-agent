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

OUTPUT_PATH="results.xml"
if [ "${1:-}" = "--output_path" ]; then
  OUTPUT_PATH="$2"
  shift 2
fi


MODE="${1:-new}"

STATUS=0

run_vitest() {
  local project="$1"
  local target="${2:-}"
  local xml_out="${3:-$OUTPUT_PATH}"
  
  if [ -n "$xml_out" ]; then
    if [ -n "$target" ]; then
      npx vitest run --environment=node "$target" --reporter=default --reporter=junit --outputFile="$xml_out"
    else
      npx vitest run --environment=node "apps/desktop/electron/**/*.test.ts" "apps/desktop/scripts/**/*.test.ts" --reporter=default --reporter=junit --outputFile="$xml_out"
    fi

  else
    if [ -n "$target" ]; then
      npx vitest run --environment=node "$target"
    else
      npx vitest run --environment=node "apps/desktop/electron/**/*.test.ts" "apps/desktop/scripts/**/*.test.ts"
    fi
  fi
  
  local val=$?
  if [ $val -ne 0 ]; then
    STATUS=$val
    if [ -n "$xml_out" ] && [ -f "$xml_out" ]; then
      echo "=== Vitest Failure Report: Printing $xml_out ==="
      cat "$xml_out"
      echo "================================================"
    fi
  fi
}


run_pytest() {
  # Run pytest with all target arguments and the output path
  pytest "$@" -v --junitxml="$OUTPUT_PATH"
  local val=$?
  if [ $val -ne 0 ]; then
    STATUS=$val
    if [ -f "$OUTPUT_PATH" ]; then
      echo "=== Pytest Failure Report: Printing $OUTPUT_PATH ==="
      cat "$OUTPUT_PATH"
      echo "==============================================="
    fi
  fi
}


case "$MODE" in
  base)
    echo "Running base regression checks..."
    # Run the existing electron native test suite
    run_vitest "electron" "" "$OUTPUT_PATH"
    
    # Run the existing python unit tests in the blast radius of constants, logging, state, and CLI routing
    run_pytest \
      "tests/test_hermes_constants.py" \
      "tests/test_hermes_logging.py" \
      "tests/test_hermes_state.py" \
      "tests/test_hermes_home_profile_warning.py" \
      "tests/test_subprocess_home_isolation.py" \
      "tests/hermes_cli/test_commands.py" \
      "tests/hermes_cli/test_subparser_routing_fallback.py"
    ;;


  new)
    echo "Running new feature verification tests..."

    # 1. Run the custom path resolution vitest tests
    run_vitest "electron" "apps/desktop/electron/userdata-override.test.ts" "$OUTPUT_PATH"
    
    # 2. Run the custom python path resolution and migration tests
    run_pytest "tests/test_userdata_override.py"
    ;;
  *)
    echo "unknown mode: $MODE (expected base or new)" >&2
    exit 2
    ;;
esac

exit "$STATUS"
