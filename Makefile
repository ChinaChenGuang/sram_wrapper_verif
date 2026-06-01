# ================================================================
# SRAM Wrapper VCS Verification Makefile
# ================================================================
# Usage:
#   make                  # build + run
#   make build            # VCS compile
#   make run              # run simulation
#   make gen-b2b          # generate B2B connect files
#   make parse            # parse wrapper dirs → YAML
#   make clean            # remove build artifacts
#   make sp / fill / b2b  # quick test targets
#
# Include Verilator targets:
#   make -f Makefile.verilator build
# ================================================================

SHELL          = /bin/csh

VCS_BIN        ?= vcs
WORK_DIR       ?= vcs_work
GEN_DIR        ?= gen

UVM_TEST       ?= test_mem_fill_verify
UVM_VERBOSITY  ?= UVM_MEDIUM
TX_COUNT       ?= 100

# ================================================================
# VCS Sources (built-in UVM 1.2 via -ntb_opts)
# ================================================================

VCS_FLAGS = -full64 -sverilog -timescale=1ns/1ps \
            +vcs+lic+wait +define+VCS \
            +define+UVM_NO_DPI \
            -debug_access+all -j 4 \
            -ntb_opts uvm-1.2 \
            +incdir+./verif_env/tb +incdir+./verif_env/uvc \
            +incdir+./verif_env/uvc/classes +incdir+./verif_env/tests \
            +incdir+./verif_env/tests/classes \
            +incdir+./$(GEN_DIR) \
            -l vcs_compile.log
#           -f $(GEN_DIR)/gen_sram_b2b.f \

VCS_SRCS = ./rtl/sram_cfg_pkg.sv \
           ./verif_env/uvc/mem_uvc_pkg.sv \
           ./verif_env/tests/mem_test_pkg.sv \
           ./verif_env/tb/clk_gen.sv \
           ./verif_env/tb/mem_if.sv \
           ./verif_env/tb/mem_sva_checker.sv \
           ./rtl/sram_ref_model.sv \
           ./rtl/sram_proto_adapter.sv \
           ./verif_env/tb/tb_top.sv

# ================================================================
# Build & Run
# ================================================================

.PHONY: build run

build:
	@echo "==> [VCS] Compiling (Env Only Mode)..."
	mkdir -p $(WORK_DIR) $(GEN_DIR)
	$(VCS_BIN) $(VCS_FLAGS) $(VCS_SRCS) \
		+define+SIM_ALL \
		-o $(WORK_DIR)/simv |& tee $(WORK_DIR)/vcs_build.log
	@echo "==> [VCS] Done: $(WORK_DIR)/simv"

build_debug:
	@echo "==> [VCS] Compiling (Debug Mode)..."
	mkdir -p $(WORK_DIR) $(GEN_DIR)
	$(VCS_BIN) $(VCS_FLAGS) $(VCS_SRCS) \
		+define+SIM_ALL +define+ENV_DEBUG \
		-o $(WORK_DIR)/simv |& tee $(WORK_DIR)/vcs_build.log
	@echo "==> [VCS] Done: $(WORK_DIR)/simv"

run:
	@echo "==> [VCS] Test=$(UVM_TEST)"
	cd $(WORK_DIR) && ./simv \
		+UVM_TESTNAME=$(UVM_TEST) \
		+UVM_VERBOSITY=$(UVM_VERBOSITY) \
		+TX_COUNT=$(TX_COUNT) \
		-l vcs_simulation.log |& tee vcs_run.log

# ================================================================
# Quick tests
# ================================================================

.PHONY: sp sdp tdp wem b2b fill

sp:   build; $(MAKE) run UVM_TEST=test_mem_sp
sdp:  build; $(MAKE) run UVM_TEST=test_mem_sdp
tdp:  build; $(MAKE) run UVM_TEST=test_mem_tdp
wem:  build; $(MAKE) run UVM_TEST=test_mem_wem
b2b:  build; $(MAKE) run UVM_TEST=test_mem_b2b
fill: build; $(MAKE) run UVM_TEST=test_mem_fill_verify

gui: build
	cd $(WORK_DIR) && ./simv -gui &

# ================================================================
# Generators
# ================================================================

.PHONY: gen-b2b parse

gen-b2b:
	python3 scripts/gen_sram_b2b.py \
		--config sram_instances.yaml \
		--log $(GEN_DIR)/gen.log

parse:
	python3 scripts/parse_memoris.py \
		--orig ./memory_wrapper_orig \
		--new  ./memory_wrapper_new \
		--output sram_instances.yaml \
		--log $(GEN_DIR)/parse.log

parse_mem:
	python3 scripts/parse_memoris.py \
		--dir ./mem \
		--output sram_instances.yaml \
		--log $(GEN_DIR)/parse_mem.log

# ================================================================
# Packaging
# ================================================================

.PHONY: pack

pack:
	@echo "==> Packaging project (excluding .git and build artifacts)..."
	@set DIR_NAME=`basename "$$PWD"`; \
	cd .. && tar -czvf "$$DIR_NAME.tar.gz" \
		--exclude='.git' --exclude='vcs_work' --exclude='*.log' \
		--exclude='dump.fst' --exclude='gen' --exclude='run_dir' \
		"$$DIR_NAME/"
	@set DIR_NAME=`basename "$$PWD"`; \
	echo "==> Package created at ../$$DIR_NAME.tar.gz"

# ================================================================
# Clean
# ================================================================

.PHONY: clean

clean::
	rm -rf $(WORK_DIR) csrc simv* *.key *.log $(GEN_DIR)

.DEFAULT_GOAL := build
