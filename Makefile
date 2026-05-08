# ================================================================
# SRAM Wrapper Verification Makefile
# ================================================================
# Testbench architectures:
#   decoupled  — per-port interface, independent clk domains (default)
#   dualclk    — dual-clock with multi-clock SVA
#   feature    — ref model + A/B + functional 3-way check
#   unified    — max-width unified interface + mask
# ================================================================

SIM           ?= verilator
TEST          ?= mem_fill_verify
TX_COUNT      ?= 50
ADDR_WIDTH    ?= 10
DATA_WIDTH    ?= 32
DUT_ORI       ?= dut_sram
DUT_NEW       ?= dut_sram
SRAM_MODE     ?= 2            # 0=SP, 1=SDP, 2=TDP
NUM_PORTS     ?= 2            # 1=single, 2=dual
CLK_A_PS      ?= 10000
CLK_B_PS      ?= 10000
CLK_B_PHASE_PS ?= 0
WAVE_FILE     ?= dump.fst
RUN_DIR       ?= run_dir

# DUT sources
DUT_SRCS      = ./rtl/dut_sram.sv ./rtl/dut_sram_v2.sv
DUT_DEFINES   = +define+DUT_ORI=$(DUT_ORI) +define+DUT_NEW=$(DUT_NEW)

# Include generated targets
-include gen/sram_b2b_list.mk

# Common sources
SRC_COMMON    = ./rtl/clk_gen.sv

# Verilator flags
VFLAGS_BASE   = --binary --main --timing -j 4 --trace-fst --assert \
                -Wno-fatal -Wno-lint -Wno-style -Wno-SYMRSVDWORD -Wno-IGNOREDRETURN \
                +incdir+./verif_env/tb +incdir+./gen

# ================================================================
# Source lists per architecture
# ================================================================
SRC_DECOUPLED = $(SRC_COMMON) ./rtl/clk_gen_dual.sv $(DUT_SRCS) \
                ./rtl/sram_ref_model.sv \
                ./verif_env/tb/mem_port_if.sv \
                ./verif_env/tb/mem_port_checker.sv \
                ./verif_env/tb/tb_top_decoupled.sv

SRC_DUALCLK   = $(SRC_COMMON) ./rtl/clk_gen_dual.sv $(DUT_SRCS) \
                ./rtl/sram_ref_model.sv \
                ./verif_env/tb/mem_if.sv \
                ./verif_env/tb/mem_if_dualclk.sv \
                ./verif_env/tb/tb_top_dualclk.sv

SRC_FEATURE   = $(SRC_COMMON) $(DUT_SRCS) \
                ./rtl/sram_ref_model.sv \
                ./verif_env/tb/mem_if.sv \
                ./verif_env/tb/tb_top_feature.sv

SRC_UNIFIED   = $(SRC_COMMON) $(DUT_SRCS) \
                ./verif_env/tb/mem_if.sv \
                ./verif_env/tb/tb_top_unified.sv

# ================================================================
# Default: decoupled architecture
# ================================================================
.PHONY: all build run

all: build run

build: build-decoupled
run: run-decoupled

# ================================================================
# Decoupled (recommended)
# ================================================================
.PHONY: build-decoupled run-decoupled

build-decoupled:
	@echo "==> [Decoupled] PORTS=$(NUM_PORTS) MODE=$(SRAM_MODE)"
	mkdir -p $(RUN_DIR)
	$(SIM) $(VFLAGS_BASE) $(DUT_DEFINES) $(SRC_DECOUPLED) \
		-GSRAM_MODE=$(SRAM_MODE) -GNUM_PORTS=$(NUM_PORTS) --top-module tb_top --Mdir $(RUN_DIR)

run-decoupled:
	@echo "==> [Decoupled] Test=$(TEST) PORTS=$(NUM_PORTS) cfg=$(ADDR_WIDTH)x$(DATA_WIDTH)"
	cd $(RUN_DIR) && ./Vtb_top +TEST=$(TEST) \
		+ADDR_WIDTH=$(ADDR_WIDTH) +DATA_WIDTH=$(DATA_WIDTH) +TX_COUNT=$(TX_COUNT) \
		+CLK_A_PS=$(CLK_A_PS) +CLK_B_PS=$(CLK_B_PS) +CLK_B_PHASE_PS=$(CLK_B_PHASE_PS)

# ================================================================
# Dual-Clock
# ================================================================
.PHONY: build-dualclk run-dualclk

build-dualclk:
	@echo "==> [DualClk] MODE=$(SRAM_MODE)"
	mkdir -p $(RUN_DIR)
	$(SIM) $(VFLAGS_BASE) $(DUT_DEFINES) $(SRC_DUALCLK) \
		-GSRAM_MODE=$(SRAM_MODE) --top-module tb_top --Mdir $(RUN_DIR)

run-dualclk:
	@echo "==> [DualClk] Test=$(TEST) A=$(CLK_A_PS)ps B=$(CLK_B_PS)ps ph=$(CLK_B_PHASE_PS)ps"
	cd $(RUN_DIR) && ./Vtb_top +TEST=$(TEST) \
		+ADDR_WIDTH=$(ADDR_WIDTH) +DATA_WIDTH=$(DATA_WIDTH) +TX_COUNT=$(TX_COUNT) \
		+CLK_A_PS=$(CLK_A_PS) +CLK_B_PS=$(CLK_B_PS) +CLK_B_PHASE_PS=$(CLK_B_PHASE_PS)

# ================================================================
# Feature
# ================================================================
.PHONY: build-feature run-feature regress-feature

build-feature:
	@echo "==> [Feature] MODE=$(SRAM_MODE)"
	mkdir -p $(RUN_DIR)
	$(SIM) $(VFLAGS_BASE) $(DUT_DEFINES) $(SRC_FEATURE) \
		-GSRAM_MODE=$(SRAM_MODE) --top-module tb_top --Mdir $(RUN_DIR)

run-feature:
	@echo "==> [Feature] Test=$(TEST) cfg=$(ADDR_WIDTH)x$(DATA_WIDTH)"
	cd $(RUN_DIR) && ./Vtb_top +TEST=$(TEST) \
		+ADDR_WIDTH=$(ADDR_WIDTH) +DATA_WIDTH=$(DATA_WIDTH) +TX_COUNT=$(TX_COUNT)

regress-feature: clean build-feature
	@echo "===== Feature Regression ====="
	cd $(RUN_DIR) && ./Vtb_top +TEST=mem_feature_all \
		+ADDR_WIDTH=$(ADDR_WIDTH) +DATA_WIDTH=$(DATA_WIDTH) +TX_COUNT=100 2>&1 \
		| grep -E "FEATURE|ERROR|Done"

# ================================================================
# Unified
# ================================================================
.PHONY: build-unified run-unified sweep

build-unified:
	@echo "==> [Unified] Max AW=16 DW=256"
	mkdir -p $(RUN_DIR)
	$(SIM) $(VFLAGS_BASE) $(DUT_DEFINES) $(SRC_UNIFIED) \
		--top-module tb_top --Mdir $(RUN_DIR)

run-unified:
	@echo "==> [Unified] Test=$(TEST) cfg=$(ADDR_WIDTH)x$(DATA_WIDTH)"
	cd $(RUN_DIR) && ./Vtb_top +TEST=$(TEST) \
		+ADDR_WIDTH=$(ADDR_WIDTH) +DATA_WIDTH=$(DATA_WIDTH) +TX_COUNT=$(TX_COUNT)

sweep: clean build-unified
	@echo "==> [Unified] Config Sweep (6 configs, 1 run)"
	cd $(RUN_DIR) && ./Vtb_top +TEST=mem_sweep_all +TX_COUNT=30

# ================================================================
# Generators
# ================================================================
.PHONY: gen-b2b gen-b2b-force

gen-b2b:
	python3 scripts/gen_sram_b2b.py

gen-b2b-force:
	rm -rf gen/
	python3 scripts/gen_sram_b2b.py

# ================================================================
# Common
# ================================================================
.PHONY: wave clean

wave:
	gtkwave $(RUN_DIR)/$(WAVE_FILE) &

clean:
	rm -rf $(RUN_DIR)

.DEFAULT_GOAL := all
