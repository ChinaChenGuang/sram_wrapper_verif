#!/bin/bash
# ================================================================
# run_multi_regress.sh - Multi-config full regression
# ================================================================
# Runs ALL test cases on ALL SRAM configs from a single binary.
# The multi-config binary has 6 configs built-in via generate.
#
# Usage: ./scripts/run_multi_regress.sh <binary> [tx_count]
# ================================================================

BINARY="$1"
TX_COUNT="${2:-100}"
LOG_DIR="run_dir/logs"

mkdir -p "$LOG_DIR"

# Configurations: name, inst_id
CONFIGS=(
    "256x8   0"
    "1Kx32   1"
    "4Kx64   2"
    "64x256  3"
    "64Kx8   4"
    "512x128 5"
)

# Test cases
TESTS=(
    "mem_sp_test"
    "mem_sdp_test"
    "mem_tdp_test"
    "mem_wem_walking_test"
    "mem_b2b_raw_test"
)

TOTAL_PASS=0
TOTAL_FAIL=0

echo "============================================================"
echo "Multi-Config Full Regression"
echo "Configs: ${#CONFIGS[@]}  |  Tests: ${#TESTS[@]}  |  Tx: $TX_COUNT"
echo "Total cases: $((${#CONFIGS[@]} * ${#TESTS[@]}))"
echo "============================================================"

for cfg_entry in "${CONFIGS[@]}"; do
    set -- $cfg_entry
    CFG_NAME="$1"
    INST_ID="$2"

    echo ""
    echo "--- Config: $CFG_NAME (INST_ID=$INST_ID) ---"

    for t in "${TESTS[@]}"; do
        LOG="$LOG_DIR/${t}_${CFG_NAME}.log"
        echo -n "  $t ... "

        "$BINARY" +INST_ID="$INST_ID" +TEST="$t" +TX_COUNT="$TX_COUNT" \
            > "$LOG" 2>&1

        if grep -Eq "SVA ERROR|\[ENV.*ERROR|\[TB].*ERROR" "$LOG"; then
            echo "FAIL"
            TOTAL_FAIL=$((TOTAL_FAIL + 1))
            grep -E "ERROR|SVA" "$LOG" | head -3
        else
            echo "PASS"
            TOTAL_PASS=$((TOTAL_PASS + 1))
        fi
    done
done

echo ""
echo "============================================================"
echo "Multi-Config Regression Summary"
echo "  PASSED: $TOTAL_PASS"
echo "  FAILED: $TOTAL_FAIL"
echo "  TOTAL:  $((TOTAL_PASS + TOTAL_FAIL))"
echo "Logs: $LOG_DIR/"
echo "============================================================"

exit $TOTAL_FAIL
