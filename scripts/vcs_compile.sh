#!/bin/bash
# ============================================================
# vcs_compile.sh — Compile & Run SRAM UVM Verification with VCS
# ============================================================
# Usage:
#   # Compile only
#   ./scripts/vcs_compile.sh compile [ARCH=uvm]
#
#   # Compile & run
#   ./scripts/vcs_compile.sh run [ARCH=uvm] [UVM_TEST=test_mem_sp] \
#       [ADDR_WIDTH=10] [DATA_WIDTH=32] [TX_COUNT=50] \
#       [CLK_A_PS=10000] [CLK_B_PS=10000]
#
#   # Clean
#   ./scripts/vcs_compile.sh clean
#
# Environment (set before running):
#   VCS_HOME     — VCS installation root
#   VERDI_HOME   — Verdi installation root (optional)
#   UVM_HOME     — UVM 1800.2 source root (optional, auto-detected)
#   LM_LICENSE_FILE — Synopsys license (e.g., 3710@license-server)
# ============================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$SCRIPT_DIR"

# -----------------------------------------------------------
# Defaults
# -----------------------------------------------------------
ARCH="${2:-uvm}"
UVM_TEST="${UVM_TEST:-test_mem_sp}"
ADDR_WIDTH="${ADDR_WIDTH:-10}"
DATA_WIDTH="${DATA_WIDTH:-32}"
TX_COUNT="${TX_COUNT:-50}"
CLK_A_PS="${CLK_A_PS:-10000}"
CLK_B_PS="${CLK_B_PS:-10000}"
CLK_B_PHASE_PS="${CLK_B_PHASE_PS:-0}"
DUT_ORI="${DUT_ORI:-dut_sram}"
DUT_NEW="${DUT_NEW:-dut_sram}"

WORK_DIR="${SCRIPT_DIR}/vcs_work"

# -----------------------------------------------------------
# UVM Installation Detection
# -----------------------------------------------------------
if [ -z "${UVM_HOME:-}" ]; then
    if [ -d "/home/chen/proj/UVM/UVM-1800.2-2020.3.1/1800.2-2020.3.1/src" ]; then
        UVM_HOME="/home/chen/proj/UVM/UVM-1800.2-2020.3.1/1800.2-2020.3.1/src"
    elif [ -d "${SCRIPT_DIR}/uvm-1.2/src" ]; then
        UVM_HOME="${SCRIPT_DIR}/uvm-1.2/src"
    elif [ -d "${SCRIPT_DIR}/uvm_lib/src" ]; then
        UVM_HOME="${SCRIPT_DIR}/uvm_lib/src"
    else
        echo "ERROR: UVM_HOME not found. Set UVM_HOME environment variable."
        echo "  e.g.: export UVM_HOME=/opt/Synopsys/VCS/etc/uvm/uvm_lib/uvm/src"
        exit 1
    fi
fi
echo "[VCS] UVM_HOME = ${UVM_HOME}"

# -----------------------------------------------------------
# VCS Binary
# -----------------------------------------------------------
VCS_BIN="${VCS_HOME:-/opt/Synopsys/VCS}/bin/vcs"
if [ ! -x "$VCS_BIN" ]; then
    # Check if vcs is in PATH (Docker mount)
    VCS_BIN="$(which vcs 2>/dev/null || true)"
    if [ -z "$VCS_BIN" ]; then
        echo "ERROR: VCS not found. Install Synopsys VCS or set VCS_HOME."
        echo "  e.g.: export VCS_HOME=/opt/Synopsys/VCS"
        exit 1
    fi
fi
echo "[VCS] Binary: ${VCS_BIN}"

# -----------------------------------------------------------
# VCS Compilation Flags
# -----------------------------------------------------------
VCS_FLAGS="-full64 -sverilog -timescale=1ns/1ps"
VCS_FLAGS+=" +vcs+lic+wait"                     # Wait for license
VCS_FLAGS+=" +define+VCS"                        # VCS-specific code
VCS_FLAGS+=" +define+UVM_NO_DPI"                 # Use native VCS DPI
VCS_FLAGS+=" +define+UVM_OBJECT_MUST_HAVE_CONSTRUCTOR"
VCS_FLAGS+=" +define+UVM_ENABLE_AUTO_ITEM_RECORDING"
VCS_FLAGS+=" +define+DEBUG"
VCS_FLAGS+=" +define+WAVE_DUMP"
VCS_FLAGS+=" -debug_access+all"                  # Full debug (for Verdi)
VCS_FLAGS+=" -line64"                            # Line debug info
VCS_FLAGS+=" -j 4"                               # Parallel compile
VCS_FLAGS+=" -l ${WORK_DIR}/vcs_compile.log"

# UVM library flags
VCS_FLAGS+=" -ntb_opts uvm-1.2"                  # Use VCS built-in UVM 1.2
# For UVM 1800.2, use:
# VCS_FLAGS+=" -ntb_opts uvm"

# For custom UVM 1800.2:
VCS_FLAGS_UVM_CUSTOM=""
VCS_FLAGS_UVM_CUSTOM+=" +incdir+${UVM_HOME}"
VCS_FLAGS_UVM_CUSTOM+=" +incdir+${UVM_HOME}/macros"
VCS_FLAGS_UVM_CUSTOM+=" +incdir+${UVM_HOME}/dpi"
VCS_FLAGS_UVM_CUSTOM+=" ${UVM_HOME}/uvm_pkg.sv"

# DUT defines
DUT_DEFINES="+define+DUT_ORI=${DUT_ORI} +define+DUT_NEW=${DUT_NEW}"

# -----------------------------------------------------------
# Testbench files per architecture
# -----------------------------------------------------------
SRC_COMMON+=" ./rtl/sram_ref_model.sv"
SRC_DUTS="./rtl/dut_sram.sv ./rtl/dut_sram_v2.sv ./rtl/dut_wrapper.sv"
SRC_SRAM="./rtl/orig/sram_sp.sv ./rtl/orig/sram_sdp.sv ./rtl/orig/sram_tdp.sv"
SRC_SRAM+=" ./rtl/orig/sram_bank4.sv ./rtl/orig/sram_bitwrite.sv ./rtl/orig/sram_web.sv"
SRC_SRAM+=" ./rtl/new/sram_sp.sv ./rtl/new/sram_sdp.sv ./rtl/new/sram_tdp.sv"
SRC_SRAM+=" ./rtl/new/sram_bank4.sv ./rtl/new/sram_bitwrite.sv ./rtl/new/sram_web.sv"

SRC_VERIF="./verif_env/tb/mem_port_if.sv ./verif_env/tb/mem_port_checker.sv"
SRC_VERIF+=" ./verif_env/tb/mem_if.sv ./verif_env/tb/mem_if_dualclk.sv"

SRC_UVC="./verif_env/uvc/mem_uvc_pkg.sv"
SRC_UVC_CLASSES=""

SRC_TESTS="./verif_env/tests/mem_test_pkg.sv"
SRC_TESTS_CLASSES=""

SRC_TB_UVM="./verif_env/tb/tb_top.sv"

ALL_SRCS="${VCS_FLAGS_UVM_CUSTOM} ${SRC_COMMON} ${SRC_DUTS} ${SRC_SRAM}"
ALL_SRCS+=" ${SRC_VERIF} ${SRC_UVC} ${SRC_UVC_CLASSES}"
ALL_SRCS+=" ${SRC_TESTS} ${SRC_TESTS_CLASSES} ${SRC_TB_UVM}"

# -----------------------------------------------------------
# Commands
# -----------------------------------------------------------
case "${1:-compile}" in
    compile)
        echo "========================================"
        echo "[VCS] Compiling UVM SRAM verification..."
        echo "      Architecture: ${ARCH}"
        echo "      UVM Test:     ${UVM_TEST}"
        echo "========================================"
        mkdir -p "${WORK_DIR}"
        cd "${WORK_DIR}"

        CMD="${VCS_BIN} ${VCS_FLAGS} ${DUT_DEFINES} ${ALL_SRCS}"
        CMD+=" -o ${WORK_DIR}/simv"

        echo "[VCS] CMD: ${CMD}"
        eval "${CMD}"
        echo "[VCS] Compilation done. Simv at ${WORK_DIR}/simv"
        ;;

    run)
        # Compile first
        $0 compile "${ARCH}"

        echo "========================================"
        echo "[VCS] Running ${UVM_TEST}..."
        echo "      ADDR_WIDTH=${ADDR_WIDTH} DATA_WIDTH=${DATA_WIDTH}"
        echo "      TX_COUNT=${TX_COUNT}"
        echo "      CLK_A_PS=${CLK_A_PS} CLK_B_PS=${CLK_B_PS}"
        echo "========================================"

        cd "${WORK_DIR}"
        ./simv \
            +UVM_TESTNAME="${UVM_TEST}" \
            +UVM_VERBOSITY="${UVM_VERBOSITY:-UVM_MEDIUM}" \
            +ADDR_WIDTH="${ADDR_WIDTH}" \
            +DATA_WIDTH="${DATA_WIDTH}" \
            +TX_COUNT="${TX_COUNT}" \
            +CLK_A_PS="${CLK_A_PS}" \
            +CLK_B_PS="${CLK_B_PS}" \
            +CLK_B_PHASE_PS="${CLK_B_PHASE_PS}" \
            -l "${WORK_DIR}/vcs_simulation.log"
        echo "[VCS] Simulation done. Log: vcs_work/vcs_simulation.log"
        ;;

    clean)
        echo "[VCS] Cleaning VCS work directory..."
        rm -rf "${WORK_DIR}" csrc simv* *.key *.log
        echo "[VCS] Done."
        ;;

    gui)
        # Compile with debug, run with Verdi/DVE
        $0 compile "${ARCH}"
        echo "[VCS] Starting GUI (DVE)..."
        cd "${WORK_DIR}"
        ./simv -gui &
        ;;

    *)
        echo "Usage: $0 {compile|run|clean|gui} [ARCH=uvm]"
        echo ""
        echo "Environment variables:"
        echo "  VCS_HOME        — VCS installation path"
        echo "  UVM_HOME        — UVM source path"
        echo "  UVM_TEST        — UVM test name (default: test_mem_sp)"
        echo "  ADDR_WIDTH      — Address width (default: 10)"
        echo "  DATA_WIDTH      — Data width (default: 32)"
        echo "  TX_COUNT        — Transaction count (default: 50)"
        echo "  CLK_A_PS        — Clock A period in ps (default: 10000)"
        echo "  CLK_B_PS        — Clock B period in ps (default: 10000)"
        echo "  CLK_B_PHASE_PS  — Clock B phase shift in ps (default: 0)"
        echo "  DUT_ORI         — Original DUT module name (default: dut_sram)"
        echo "  DUT_NEW         — New DUT module name (default: dut_sram)"
        exit 1
        ;;
esac
