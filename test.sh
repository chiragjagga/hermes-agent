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
      vitest run --environment=node "$target" --reporter=default --reporter=junit --outputFile="$xml_out"
    else
      vitest run --environment=node apps/desktop/electron apps/desktop/scripts --exclude="**/git-review-ops.test.ts" --exclude="**/before-pack.test.mjs" --exclude="**/userdata-override.test.ts" --reporter=default --reporter=junit --outputFile="$xml_out"
    fi
  else
    if [ -n "$target" ]; then
      vitest run --environment=node "$target"
    else
      vitest run --environment=node apps/desktop/electron apps/desktop/scripts --exclude="**/git-review-ops.test.ts" --exclude="**/before-pack.test.mjs" --exclude="**/userdata-override.test.ts"
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
    run_vitest "electron" "" "results_vitest.xml"
    
    ORIG_OUTPUT_PATH="$OUTPUT_PATH"
    OUTPUT_PATH="results_pytest.xml"
    run_pytest \
      "tests/test_hermes_constants.py" \
      "tests/test_hermes_logging.py" \
      "tests/test_hermes_state.py" \
      "tests/test_hermes_home_profile_warning.py" \
      "tests/test_subprocess_home_isolation.py" \
      "tests/hermes_cli/test_commands.py" \
      "tests/hermes_cli/test_subparser_routing_fallback.py"
    OUTPUT_PATH="$ORIG_OUTPUT_PATH"
    ;;


  new)
    echo "Running new feature verification tests..."

    # 1. Run the custom path resolution vitest tests
    run_vitest "electron" "apps/desktop/electron/userdata-override.test.ts" "results_vitest.xml"
    
    # 2. Run the custom python path resolution and migration tests
    # Override OUTPUT_PATH temporarily for pytest
    ORIG_OUTPUT_PATH="$OUTPUT_PATH"
    OUTPUT_PATH="results_pytest.xml"
    run_pytest "tests/test_userdata_override.py"
    OUTPUT_PATH="$ORIG_OUTPUT_PATH"
    ;;
  *)
    echo "unknown mode: $MODE (expected base or new)" >&2
    exit 2
    ;;
esac

# Consolidated XML Report Merging (combines Vitest & Pytest suites)
if [ -f "results_vitest.xml" ] || [ -f "results_pytest.xml" ]; then
  echo '<?xml version="1.0" encoding="UTF-8"?>' > "$OUTPUT_PATH"
  echo '<testsuites>' >> "$OUTPUT_PATH"
  if [ -f "results_vitest.xml" ]; then
    grep -v -E '<\?xml|<testsuites|</testsuites>' "results_vitest.xml" >> "$OUTPUT_PATH" || true
    rm -f "results_vitest.xml"
  fi
  if [ -f "results_pytest.xml" ]; then
    grep -v -E '<\?xml|<testsuites|</testsuites>' "results_pytest.xml" >> "$OUTPUT_PATH" || true
    rm -f "results_pytest.xml"
  fi
  echo '</testsuites>' >> "$OUTPUT_PATH"
fi

exit "$STATUS"

