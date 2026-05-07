#!/bin/bash
# ================================================================
# run_tests.sh - Run all test cases on a single-config binary
# Usage: ./scripts/run_tests.sh <binary> <addr_w> <data_w> [tx_count]
# ================================================================

BINARY="$1"
ADDR_W="${2:-10}"
DATA_W="${3:-32}"
TX_COUNT="${4:-100}"
LOG_DIR="run_dir/logs"

mkdir -p "$LOG_DIR"

TESTS=(
    "mem_sp_test"
    "mem_sdp_test"
    "mem_tdp_test"
    "mem_wem_walking_test"
    "mem_b2b_raw_test"
)

PASS=0
FAIL=0

echo "============================================================"
echo "Single-Config Regression: ${ADDR_W}x${DATA_W}"
echo "Tx per test: $TX_COUNT"
echo "============================================================"

for t in "${TESTS[@]}"; do
    LOG="$LOG_DIR/${t}_${ADDR_W}x${DATA_W}.log"
    echo -n "  $t ... "
    "$BINARY" +TEST="$t" +TX_COUNT="$TX_COUNT" > "$LOG" 2>&1
    
    if grep -Eq "SVA ERROR|\[ENV.*ERROR|\[TB].*ERROR" "$LOG"; then
        echo "FAIL"
        FAIL=$((FAIL + 1))
        grep -E "ERROR|SVA" "$LOG" | head -3
    else
        echo "PASS"
        PASS=$((PASS + 1))
    fi
done

echo "============================================================"
echo "Result: $PASS PASSED, $FAIL FAILED"
echo "Logs: $LOG_DIR/"
echo "============================================================"

exit $FAIL
