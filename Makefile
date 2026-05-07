# ================================================================
# SRAM Wrapper CLI Makefile
# ================================================================
# Supports:
#   1. Single-config testing (ADDR_WIDTH / DATA_WIDTH via variables)
#   2. Multi-config testing (6 configs in one build via generate)
#   3. Full regression (all configs x all test cases)
# ================================================================

SIM          ?= verilator
TOP          ?= tb_top
TEST         ?= mem_sdp_test
TX_COUNT     ?= 200
INST         ?= all          # all | 0 | 1 | ...
ADDR_WIDTH   ?= 10
DATA_WIDTH   ?= 32
DUT_ORI      ?= dut_sram     # Original DUT module name
DUT_NEW      ?= dut_sram     # New DUT module name (same or different)
WAVE_FILE    ?= dump.fst
RUN_DIR      ?= run_dir

# DUT module sources (add new DUT modules here)
DUT_SRCS     = ./rtl/dut_sram.sv
DUT_SRCS    += ./rtl/dut_sram_v2.sv   # alternative "new" DUT

# Pass DUT module names as Verilator defines
DUT_DEFINES  = +define+DUT_ORI=$(DUT_ORI) +define+DUT_NEW=$(DUT_NEW)

# Sources
SRC_COMMON  = ./verif_env/tb/mem_if.sv
SRC_SIMPLE  = $(SRC_COMMON) \
              ./verif_env/tb/mem_sva_checker.sv \
              $(DUT_SRCS) \
              ./verif_env/tb/tb_top_simple.sv

SRC_MULTI   = $(SRC_COMMON) \
              ./verif_env/tb/mem_sva_checker.sv \
              $(DUT_SRCS) \
              ./verif_env/tb/sram_test_env.sv \
              ./verif_env/tb/tb_top_multi.sv

SRC_FEATURE = $(SRC_COMMON) \
              $(DUT_SRCS) \
              ./rtl/sram_ref_model.sv \
              ./verif_env/tb/tb_top_feature.sv

# Verilator flags
VFLAGS_BASE = --binary --main --timing -j 4 --trace-fst --assert \
              -Wno-fatal -Wno-lint -Wno-style -Wno-SYMRSVDWORD -Wno-IGNOREDRETURN \
              +incdir+./verif_env/tb

# ================================================================
# Single-Config Targets (default)
# ================================================================
.PHONY: all build run

all: build run

build:
	@echo "==> [Single] Building: ORI=$(DUT_ORI) NEW=$(DUT_NEW) W=$(ADDR_WIDTH) D=$(DATA_WIDTH)"
	mkdir -p $(RUN_DIR)
	$(SIM) $(VFLAGS_BASE) $(DUT_DEFINES) -GADDR_WIDTH=$(ADDR_WIDTH) -GDATA_WIDTH=$(DATA_WIDTH) \
		$(SRC_SIMPLE) --top-module tb_top --Mdir $(RUN_DIR)

run:
	@echo "==> [Single] Test: $(TEST) Config: $(ADDR_WIDTH)x$(DATA_WIDTH) Tx: $(TX_COUNT)"
	cd $(RUN_DIR) && ./Vtb_top +TEST=$(TEST) +TX_COUNT=$(TX_COUNT)

# ================================================================
# Multi-Config Targets
# ================================================================
.PHONY: build-multi run-multi

build-multi:
	@echo "==> [Multi] Building 6 configs: ORI=$(DUT_ORI) NEW=$(DUT_NEW)"
	mkdir -p $(RUN_DIR)
	$(SIM) $(VFLAGS_BASE) $(DUT_DEFINES) $(SRC_MULTI) --top-module tb_top --Mdir $(RUN_DIR)

run-multi:
ifeq ($(INST),all)
	@echo "==> [Multi] Testing ALL configs: $(TEST) Tx=$(TX_COUNT)"
	@cd $(RUN_DIR) && ./Vtb_top +TEST=$(TEST) +TX_COUNT=$(TX_COUNT) 2>&1 \
		| tee $(TEST)_all.log
else
	@echo "==> [Multi] Testing config [$(INST)]: $(TEST) Tx=$(TX_COUNT)"
	cd $(RUN_DIR) && ./Vtb_top +INST_ID=$(INST) +TEST=$(TEST) +TX_COUNT=$(TX_COUNT)
endif

# ================================================================
# Regression: Single-Config (all tests, default config)
# ================================================================
.PHONY: regress

regress: clean build
	@echo "===== Single-Config Regression ($(ADDR_WIDTH)x$(DATA_WIDTH)) ====="
	@./scripts/run_tests.sh ./$(RUN_DIR)/Vtb_top $(ADDR_WIDTH) $(DATA_WIDTH) $(TX_COUNT)

# ================================================================
# Regression: Multi-Config (all configs x all tests)
# ================================================================
.PHONY: regress-multi

regress-multi: clean build-multi
	@echo "===== Multi-Config Regression ====="
	@./scripts/run_multi_regress.sh ./$(RUN_DIR)/Vtb_top $(TX_COUNT)

# ================================================================
# Quick Config Tests (single config, rebuilds per config)
# ================================================================
.PHONY: test-256x8 test-1Kx32 test-4Kx64 test-64x256 test-64Kx8 test-512x128

test-256x8:
	$(MAKE) clean build run ADDR_WIDTH=8  DATA_WIDTH=8   TEST=$(TEST)

test-1Kx32:
	$(MAKE) clean build run ADDR_WIDTH=10 DATA_WIDTH=32  TEST=$(TEST)

test-4Kx64:
	$(MAKE) clean build run ADDR_WIDTH=12 DATA_WIDTH=64  TEST=$(TEST)

test-64x256:
	$(MAKE) clean build run ADDR_WIDTH=6  DATA_WIDTH=256 TEST=$(TEST)

test-64Kx8:
	$(MAKE) clean build run ADDR_WIDTH=16 DATA_WIDTH=8   TEST=$(TEST)

test-512x128:
	$(MAKE) clean build run ADDR_WIDTH=9  DATA_WIDTH=128 TEST=$(TEST)

# ================================================================
# Unified Max-Width + Mask Targets (方案 B)
# ================================================================
.PHONY: build-unified run-unified sweep

build-unified:
	@echo "==> [Unified] Max AW=16 DW=256  ORI=$(DUT_ORI) NEW=$(DUT_NEW)"
	mkdir -p $(RUN_DIR)
	$(SIM) $(VFLAGS_BASE) $(DUT_DEFINES) $(SRC_UNIFIED) \
		--top-module tb_top --Mdir $(RUN_DIR)

run-unified:
	@echo "==> [Unified] Test: $(TEST) cfg: $(ADDR_WIDTH)x$(DATA_WIDTH)"
	cd $(RUN_DIR) && ./Vtb_top +TEST=$(TEST) \
		+ADDR_WIDTH=$(ADDR_WIDTH) +DATA_WIDTH=$(DATA_WIDTH) +TX_COUNT=$(TX_COUNT)

# 一次仿真遍历所有 6 种配置
sweep: clean build-unified
	@echo "==> [Unified] Config Sweep: 6 configs in 1 simulation"
	cd $(RUN_DIR) && ./Vtb_top +TEST=mem_sweep_all +TX_COUNT=30

# ================================================================
# Feature Verification Targets (方案 C: Ref Model + 3-way check)
# ================================================================
.PHONY: build-feature run-feature regress-feature

build-feature:
	@echo "==> [Feature] Ref Model + A/B + Func Check  ORI=$(DUT_ORI) NEW=$(DUT_NEW)"
	mkdir -p $(RUN_DIR)
	$(SIM) $(VFLAGS_BASE) $(DUT_DEFINES) $(SRC_FEATURE) \
		--top-module tb_top --Mdir $(RUN_DIR)

run-feature:
	@echo "==> [Feature] Test: $(TEST) cfg: $(ADDR_WIDTH)x$(DATA_WIDTH)"
	cd $(RUN_DIR) && ./Vtb_top +TEST=$(TEST) \
		+ADDR_WIDTH=$(ADDR_WIDTH) +DATA_WIDTH=$(DATA_WIDTH) +TX_COUNT=$(TX_COUNT)

# 全部 feature 测试一次跑完
regress-feature: clean build-feature
	@echo "===== Feature Regression ====="
	cd $(RUN_DIR) && ./Vtb_top +TEST=mem_feature_all \
		+ADDR_WIDTH=$(ADDR_WIDTH) +DATA_WIDTH=$(DATA_WIDTH) +TX_COUNT=100 2>&1 \
		| grep -E "FEATURE|ERROR|Done"

# ================================================================
# All configs quick sweep (single test across all configs)
# ================================================================
.PHONY: sweep-configs

sweep-configs:
	@echo "===== Config Sweep: $(TEST) ====="
	@for cfg in "8 8 256x8" "10 32 1Kx32" "12 64 4Kx64" "6 256 64x256" "16 8 64Kx8" "9 128 512x128"; do \
		set -- $$cfg; \
		echo "--- $$3 ---"; \
		$(MAKE) clean build run ADDR_WIDTH=$$1 DATA_WIDTH=$$2 TEST=$(TEST) TX_COUNT=50 2>&1 | grep -E "PASS|FAIL|ERROR|SVA"; \
	done

# ================================================================
# Common
# ================================================================
.PHONY: wave clean

wave:
	@echo "==> Opening Waveform with GTKWave..."
	gtkwave $(RUN_DIR)/$(WAVE_FILE) &

clean:
	@echo "==> Cleaning..."
	rm -rf $(RUN_DIR)

.DEFAULT_GOAL := all
