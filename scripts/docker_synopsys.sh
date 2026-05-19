#!/bin/bash
# ============================================================
# docker_synopsys.sh — Docker Synopsys Environment Manager
# ============================================================
# Manages docker-synopsys containers for SRAM UVM verification.
#
# Prerequisites:
#   1. Docker installed
#   2. Synopsys VCS installed at /opt/Synopsys/VCS on the HOST
#   3. Synopsys license at /opt/Synopsys/synopsys.dat
#   4. docker-synopsys images built (see build step)
#
# Usage:
#   # Build Docker images (one-time)
#   ./scripts/docker_synopsys.sh build
#
#   # Start license server
#   ./scripts/docker_synopsys.sh license-start
#
#   # Stop license server
#   ./scripts/docker_synopsys.sh license-stop
#
#   # Compile with VCS in Docker
#   ./scripts/docker_synopsys.sh compile [UVM_TEST=test_mem_sp]
#
#   # Run simulation in Docker
#   ./scripts/docker_synopsys.sh run [UVM_TEST=test_mem_sp]
#
#   # Interactive shell in Docker
#   ./scripts/docker_synopsys.sh shell
#
#   # Run a custom command in Docker
#   ./scripts/docker_synopsys.sh exec <command>
# ============================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$SCRIPT_DIR"

# -----------------------------------------------------------
# Configuration
# -----------------------------------------------------------
DOCKER_SYNOPSYS_DIR="${SCRIPT_DIR}/docker-synopsys"
SYNOPSYS_HOST_DIR="/opt/Synopsys"
SCL_IMAGE="scl"
SYNOPSYS_IMAGE="synopsys"
SCL_CONTAINER="scl"
LICENSE_PORT="3710"
HOSTNAME="${HOSTNAME:-$(hostname)}"

# Simulation parameters (passthrough)
UVM_TEST="${UVM_TEST:-test_mem_sp}"
ADDR_WIDTH="${ADDR_WIDTH:-10}"
DATA_WIDTH="${DATA_WIDTH:-32}"
TX_COUNT="${TX_COUNT:-50}"
CLK_A_PS="${CLK_A_PS:-10000}"
CLK_B_PS="${CLK_B_PS:-10000}"
CLK_B_PHASE_PS="${CLK_B_PHASE_PS:-0}"
DUT_ORI="${DUT_ORI:-dut_sram}"
DUT_NEW="${DUT_NEW:-dut_sram}"

# -----------------------------------------------------------
# Docker run base arguments
# -----------------------------------------------------------
DOCKER_RUN_BASE="docker run --rm -it --network=host"
DOCKER_RUN_BASE+=" -v ${SYNOPSYS_HOST_DIR}:/opt/Synopsys"
DOCKER_RUN_BASE+=" -v ${SCRIPT_DIR}:${SCRIPT_DIR}"
DOCKER_RUN_BASE+=" -w ${SCRIPT_DIR}"
DOCKER_RUN_BASE+=" -e VCS_HOME=/opt/Synopsys/VCS"
DOCKER_RUN_BASE+=" -e VERDI_HOME=/opt/Synopsys/Verdi"
DOCKER_RUN_BASE+=" -e LM_LICENSE_FILE=${LICENSE_PORT}@localhost"
DOCKER_RUN_BASE+=" -e UVM_HOME=/home/chen/proj/UVM/UVM-1800.2-2020.3.1/1800.2-2020.3.1/src"
DOCKER_RUN_BASE+=" --hostname ${HOSTNAME}"

# -----------------------------------------------------------
# Helper: Check prerequisites
# -----------------------------------------------------------
check_prereqs() {
    # Check Docker
    if ! command -v docker &> /dev/null; then
        echo "ERROR: Docker not found. Install Docker first."
        echo "  Ubuntu: sudo apt install docker.io"
        echo "  Or: curl -fsSL https://get.docker.com | sudo sh"
        exit 1
    fi

    # Check Synopsys directory
    if [ ! -d "${SYNOPSYS_HOST_DIR}/VCS" ]; then
        echo "WARNING: ${SYNOPSYS_HOST_DIR}/VCS not found."
        echo "  VCS tools must be installed at ${SYNOPSYS_HOST_DIR}/VCS"
        echo "  The Docker container will not have VCS without this."
    fi

    # Check SCL (license server)
    if [ ! -d "${SYNOPSYS_HOST_DIR}/scl" ]; then
        echo "WARNING: ${SYNOPSYS_HOST_DIR}/scl not found."
        echo "  Synopsys SCL (license server) must be installed."
    fi

    # Check Docker images
    if ! docker image inspect "${SYNOPSYS_IMAGE}" &> /dev/null; then
        echo "ERROR: Docker image '${SYNOPSYS_IMAGE}' not found."
        echo "  Build it first: ./scripts/docker_synopsys.sh build"
        exit 1
    fi
}

# -----------------------------------------------------------
# Build Docker images
# -----------------------------------------------------------
build_images() {
    echo "========================================"
    echo "[DOCKER] Building Synopsys Docker images..."
    echo "========================================"

    if [ ! -d "${DOCKER_SYNOPSYS_DIR}/docker" ]; then
        echo "ERROR: docker-synopsys not found at ${DOCKER_SYNOPSYS_DIR}"
        echo "  Clone it: git clone https://github.com/RUC-Turing/docker-synopsys.git"
        exit 1
    fi

    # Build SCL image
    echo "[DOCKER] Building SCL (license server) image..."
    cd "${DOCKER_SYNOPSYS_DIR}/docker"
    docker build -f Dockerfile.scl -t "${SCL_IMAGE}" .
    echo "[DOCKER] SCL image built: ${SCL_IMAGE}"

    # Build Synopsys image
    echo "[DOCKER] Building Synopsys (VCS) image..."
    docker build -f Dockerfile.synopsys -t "${SYNOPSYS_IMAGE}" .
    echo "[DOCKER] Synopsys image built: ${SYNOPSYS_IMAGE}"

    # Build CLI tool
    echo "[DOCKER] Building CLI launcher..."
    cd "${DOCKER_SYNOPSYS_DIR}/cli"
    make
    echo "[DOCKER] CLI launcher built at ${DOCKER_SYNOPSYS_DIR}/bin/synopsys"

    cd "${SCRIPT_DIR}"
    echo "[DOCKER] All images built successfully."
}

# -----------------------------------------------------------
# License server management
# -----------------------------------------------------------
license_start() {
    echo "[DOCKER] Starting Synopsys license server (SCL)..."
    docker rm -f "${SCL_CONTAINER}" 2>/dev/null || true
    docker run -d --name="${SCL_CONTAINER}" \
        --network=host \
        -v "${SYNOPSYS_HOST_DIR}:/opt/Synopsys" \
        "${SCL_IMAGE}"
    sleep 2
    if docker ps --filter "name=${SCL_CONTAINER}" --format "{{.Names}}" | grep -q "${SCL_CONTAINER}"; then
        echo "[DOCKER] License server started (${LICENSE_PORT}@localhost)"
    else
        echo "[DOCKER] License server failed to start. Check: docker logs ${SCL_CONTAINER}"
        exit 1
    fi
}

license_stop() {
    echo "[DOCKER] Stopping license server..."
    docker rm -f "${SCL_CONTAINER}" 2>/dev/null || true
    echo "[DOCKER] License server stopped."
}

license_status() {
    if docker ps --filter "name=${SCL_CONTAINER}" --format "{{.Names}}" | grep -q "${SCL_CONTAINER}"; then
        echo "[DOCKER] License server is RUNNING"
        docker logs --tail 5 "${SCL_CONTAINER}"
    else
        echo "[DOCKER] License server is STOPPED"
    fi
}

# -----------------------------------------------------------
# VCS simulation in Docker
# -----------------------------------------------------------
vcs_compile() {
    check_prereqs

    # Ensure license is running
    if ! docker ps --filter "name=${SCL_CONTAINER}" --format "{{.Names}}" | grep -q "${SCL_CONTAINER}"; then
        echo "[DOCKER] License server not running. Starting..."
        license_start
    fi

    echo "[DOCKER] Compiling with VCS in Docker..."
    echo "  UVM_TEST: ${UVM_TEST}"
    echo "  DUT_ORI:  ${DUT_ORI}"
    echo "  DUT_NEW:  ${DUT_NEW}"

    mkdir -p "${SCRIPT_DIR}/vcs_work"

    docker run --rm -it --network=host \
        -v "${SYNOPSYS_HOST_DIR}:/opt/Synopsys" \
        -v "${SCRIPT_DIR}:${SCRIPT_DIR}" \
        -w "${SCRIPT_DIR}" \
        -e VCS_HOME=/opt/Synopsys/VCS \
        -e VERDI_HOME=/opt/Synopsys/Verdi \
        -e LM_LICENSE_FILE=${LICENSE_PORT}@localhost \
        -e UVM_HOME=/home/chen/proj/UVM/UVM-1800.2-2020.3.1/1800.2-2020.3.1/src \
        --hostname "${HOSTNAME}" \
        "${SYNOPSYS_IMAGE}" \
        bash -c "
            cd ${SCRIPT_DIR}
            vcs -full64 -sverilog -timescale=1ns/1ps \
                +vcs+lic+wait \
                +define+VCS +define+UVM_NO_DPI \
                +define+UVM_OBJECT_MUST_HAVE_CONSTRUCTOR \
                +define+UVM_ENABLE_AUTO_ITEM_RECORDING \
                +define+DEBUG +define+WAVE_DUMP \
                +define+DUT_ORI=${DUT_ORI} +define+DUT_NEW=${DUT_NEW} \
                -debug_access+all -line64 -j 4 \
                -ntb_opts uvm-1.2 \
                +incdir+/home/chen/proj/UVM/UVM-1800.2-2020.3.1/1800.2-2020.3.1/src \
                +incdir+./verif_env/tb +incdir+./verif_env/uvc +incdir+./verif_env/uvc/classes \
                +incdir+./verif_env/tests +incdir+./verif_env/tests/classes \
                -l ${SCRIPT_DIR}/vcs_work/vcs_compile.log \
                -o ${SCRIPT_DIR}/vcs_work/simv \
                ./rtl/sram_ref_model.sv ./rtl/sram_cfg_pkg.sv \
                ./rtl/dut_sram.sv ./rtl/dut_sram_v2.sv ./rtl/dut_wrapper.sv \
                ./rtl/orig/sram_sp.sv ./rtl/orig/sram_sdp.sv ./rtl/orig/sram_tdp.sv \
                ./rtl/orig/sram_bank4.sv ./rtl/orig/sram_bitwrite.sv ./rtl/orig/sram_web.sv \
                ./rtl/new/sram_sp.sv ./rtl/new/sram_sdp.sv ./rtl/new/sram_tdp.sv \
                ./rtl/new/sram_bank4.sv ./rtl/new/sram_bitwrite.sv ./rtl/new/sram_web.sv \
                ./verif_env/tb/mem_port_if.sv ./verif_env/tb/mem_port_checker.sv \
                ./verif_env/tb/mem_if.sv ./verif_env/tb/mem_if_dualclk.sv \
                ./verif_env/uvc/mem_uvc_pkg.sv \
                ./verif_env/tests/mem_test_pkg.sv \
                ./verif_env/tb/tb_top.sv
        "
    echo "[DOCKER] VCS compilation done. Simv at vcs_work/simv"
}

vcs_run() {
    check_prereqs

    # Ensure license is running
    if ! docker ps --filter "name=${SCL_CONTAINER}" --format "{{.Names}}" | grep -q "${SCL_CONTAINER}"; then
        echo "[DOCKER] License server not running. Starting..."
        license_start
    fi

    # Compile if simv doesn't exist
    if [ ! -f "${SCRIPT_DIR}/vcs_work/simv" ]; then
        vcs_compile
    fi

    echo "[DOCKER] Running UVM test in Docker..."
    echo "  UVM_TEST: ${UVM_TEST}"
    echo "  ADDR_WIDTH=${ADDR_WIDTH} DATA_WIDTH=${DATA_WIDTH}"

    docker run --rm -it --network=host \
        -v "${SYNOPSYS_HOST_DIR}:/opt/Synopsys" \
        -v "${SCRIPT_DIR}:${SCRIPT_DIR}" \
        -w "${SCRIPT_DIR}/vcs_work" \
        -e VCS_HOME=/opt/Synopsys/VCS \
        -e VERDI_HOME=/opt/Synopsys/Verdi \
        -e LM_LICENSE_FILE=${LICENSE_PORT}@localhost \
        --hostname "${HOSTNAME}" \
        "${SYNOPSYS_IMAGE}" \
        ./simv \
            +UVM_TESTNAME="${UVM_TEST}" \
            +UVM_VERBOSITY="${UVM_VERBOSITY:-UVM_MEDIUM}" \
            +ADDR_WIDTH="${ADDR_WIDTH}" \
            +DATA_WIDTH="${DATA_WIDTH}" \
            +TX_COUNT="${TX_COUNT}" \
            +CLK_A_PS="${CLK_A_PS}" \
            +CLK_B_PS="${CLK_B_PS}" \
            +CLK_B_PHASE_PS="${CLK_B_PHASE_PS}" \
            -l "${SCRIPT_DIR}/vcs_work/vcs_simulation.log"
    echo "[DOCKER] Simulation done."
}

# -----------------------------------------------------------
# Interactive shell
# -----------------------------------------------------------
shell() {
    check_prereqs
    echo "[DOCKER] Starting interactive shell in Synopsys container..."
    echo "  Use 'vcs' command for compilation."
    echo "  Use 'verdi' for waveform viewing (if Verdi is available)."
    echo "  Type 'exit' to leave."
    echo ""

    docker run --rm -it --network=host \
        -v "${SYNOPSYS_HOST_DIR}:/opt/Synopsys" \
        -v "${SCRIPT_DIR}:${SCRIPT_DIR}" \
        -w "${SCRIPT_DIR}" \
        -e VCS_HOME=/opt/Synopsys/VCS \
        -e VERDI_HOME=/opt/Synopsys/Verdi \
        -e LM_LICENSE_FILE=${LICENSE_PORT}@localhost \
        --hostname "${HOSTNAME}" \
        "${SYNOPSYS_IMAGE}" \
        /bin/bash
}

# -----------------------------------------------------------
# Custom command execution
# -----------------------------------------------------------
exec_cmd() {
    check_prereqs
    shift  # remove 'exec' subcommand
    docker run --rm -it --network=host \
        -v "${SYNOPSYS_HOST_DIR}:/opt/Synopsys" \
        -v "${SCRIPT_DIR}:${SCRIPT_DIR}" \
        -w "${SCRIPT_DIR}" \
        -e VCS_HOME=/opt/Synopsys/VCS \
        -e VERDI_HOME=/opt/Synopsys/Verdi \
        -e LM_LICENSE_FILE=${LICENSE_PORT}@localhost \
        --hostname "${HOSTNAME}" \
        "${SYNOPSYS_IMAGE}" \
        "$@"
}

# -----------------------------------------------------------
# Install (setup bin directory)
# -----------------------------------------------------------
install_bin() {
    echo "[DOCKER] Installing docker-synopsys CLI launcher..."

    # Build CLI
    if [ -d "${DOCKER_SYNOPSYS_DIR}/cli" ]; then
        cd "${DOCKER_SYNOPSYS_DIR}/cli"
        make
        echo "[DOCKER] CLI launcher: ${DOCKER_SYNOPSYS_DIR}/bin/synopsys"
        echo ""
        echo "To install system-wide, run with sudo:"
        echo "  sudo cp ${DOCKER_SYNOPSYS_DIR}/bin/synopsys /usr/local/bin/vcs-launcher"
        echo "  or add ${DOCKER_SYNOPSYS_DIR}/bin to your PATH"
    fi

    cd "${SCRIPT_DIR}"
    echo ""
    echo "To make 'vcs' available system-wide via Docker, add to /etc/profile:"
    echo "  export PATH=${DOCKER_SYNOPSYS_DIR}/bin:\$PATH"
    echo ""
    echo "Or use aliases:"
    echo "  alias vcs='docker run --rm -it -v /opt/Synopsys:/opt/Synopsys -v \$(pwd):\$(pwd) -w \$(pwd) --network=host synopsys vcs'"
    echo "  alias simv='./simv'"
}

# -----------------------------------------------------------
# Main
# -----------------------------------------------------------
case "${1:-help}" in
    build)
        build_images
        ;;
    license-start)
        license_start
        ;;
    license-stop)
        license_stop
        ;;
    license-status)
        license_status
        ;;
    compile)
        vcs_compile
        ;;
    run)
        vcs_run
        ;;
    shell)
        shell
        ;;
    exec)
        exec_cmd "$@"
        ;;
    install)
        install_bin
        ;;
    help|*)
        echo "Docker Synopsys Manager for SRAM UVM Verification"
        echo ""
        echo "Usage: $0 <command> [options]"
        echo ""
        echo "Commands:"
        echo "  build           Build Docker images (scl + synopsys)"
        echo "  license-start   Start Synopsys license server"
        echo "  license-stop    Stop license server"
        echo "  license-status  Check license server status"
        echo "  compile         Compile VCS in Docker"
        echo "  run             Run UVM test in Docker"
        echo "  shell           Interactive shell in Docker container"
        echo "  exec <cmd>      Run custom command in Docker container"
        echo "  install         Build & install CLI launcher"
        echo "  help            Show this help"
        echo ""
        echo "Environment variables (all optional):"
        echo "  UVM_TEST=test_mem_sp     UVM test name"
        echo "  ADDR_WIDTH=10             Address width"
        echo "  DATA_WIDTH=32             Data width"
        echo "  TX_COUNT=50               Transaction count"
        echo "  CLK_A_PS=10000            Clock A period (ps)"
        echo "  CLK_B_PS=10000            Clock B period (ps)"
        echo "  CLK_B_PHASE_PS=0          Clock B phase shift (ps)"
        echo "  DUT_ORI=dut_sram          Original DUT module"
        echo "  DUT_NEW=dut_sram          New DUT module"
        echo ""
        echo "Examples:"
        echo "  $0 build                           # Build Docker images"
        echo "  $0 license-start                   # Start license server"
        echo "  $0 run UVM_TEST=test_mem_fill      # Run fill-verify test"
        echo "  $0 shell                           # Interactive shell"
        ;;
esac
