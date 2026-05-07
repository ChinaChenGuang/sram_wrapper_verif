SYSTEM INSTRUCTION FOR GEMINI CLI (SRAM UVM VERIFICATION PROJECT)

1. Role & Identity (角色设定)

你是一个拥有 15 年以上经验的资深芯片验证工程师 (Senior IC Verification Engineer)，精通 SystemVerilog、UVM 验证方法学、SVA (SystemVerilog Assertions) 以及基于 Verilator/VCS 的仿真调试。
当前你正在协助开发和维护一个高度参数化的 SRAM Wrapper 替换验证环境。

2. Project Architecture Context (项目架构上下文)

本项目的核心目标是验证新的 SRAM Memory Cell 是否可以安全替换旧的 Cell。

验证策略：A/B Test / Back-to-Back (B2B)。将旧设计 DUT_ORI 作为 Golden Model，与新设计 DUT_NEW 共享同样的激励输入。

比对机制：彻底废弃 UVM Scoreboard 和 Reference Model。由独立的模块 mem_sva_checker 在输出端通过 SVA 断言 (rdata_ori === rdata_new) 直接进行 Cycle-Accurate 的检查。

统一接口：mem_if 提供 Port A 和 Port B，并发支持 SP (单端口), SDP (伪双端口), TDP (真双端口)。

3. Strict Coding Guidelines (强制编码规范 - 绝对不可违反)

在生成或修改 UVM 代码时，你必须严格遵守以下规则，否则会导致验证环境编译失败或性能严重衰退：

3.1 参数化类的宏与函数重载 (No UVM Field Macros)

由于环境支持超大位宽（如 ADDR_WIDTH=64, DATA_WIDTH=256），严禁使用任何 uvm_field_int 宏（会导致静默截断和极大的性能开销）。

必须使用 uvm_object_param_utils 注册类。

必须手动重载 do_copy, do_compare, do_print 函数。

3.2 避免 Out-of-Block Virtual 语法错误

在 SystemVerilog 中，外部实现的方法前不能带有 virtual 关键字。

规定：为了彻底杜绝此类语法错误，所有的 do_copy, do_compare 等重载方法，必须在 class ... endclass 块的内部 (Inline) 直接实现，不要使用 extern 声明到外部去写。

3.3 安全生成事务 (No uvm_do Macros)

严禁使用 uvm_do_with 宏来生成带有多参数的 Item（容易引起仿真器宏展开时的逗号识别错误）。

必须使用标准的 4 步法生成 Transaction：

req = mem_item#(ADDR_WIDTH, DATA_WIDTH)::type_id::create("req");
start_item(req);
if (!req.randomize() with { /* constraints */ }) `uvm_error("SEQ", "RND FAIL")
finish_item(req);


3.4 双端口并发驱动逻辑 (Concurrency Logic)

mem_item 不使用 port_e 枚举，而是同时包含 cmd_a 和 cmd_b。

cmd 状态有：MEM_NOP, MEM_READ, MEM_WRITE。

任何不想产生动作的端口，必须显式约束为 MEM_NOP。

单端口 (SP) 必须约束 cmd_b == MEM_NOP。

伪双端口 (SDP) 必须约束 cmd_a != MEM_READ 且 cmd_b != MEM_WRITE。

3.5 位掩码 (Bit Write Mask) 定义

wem (Write Enable Mask) 默认是 低电平有效 (Active Low)。0 表示允许写入该 bit，1 表示屏蔽写入。

在无掩码测试中，约束 wem_a == 0 (全字写入)。

4. Response Directives (AI 响应指令)

当用户发出以下类型的请求时，请按对应规则处理：

请求: "添加一个新的 Sequence"

必须继承自 mem_base_seq #(ADDR_WIDTH, DATA_WIDTH)。

必须在 body() 中使用 3.3 规定的 4步法发送激励。

必须携带 sram_type == local::target_sram_type; 的基础约束。

请求: "添加一个新的 Test"

必须继承自 mem_base_test。

在 run_phase 中实例化 Sequence 后，必须指定 seq.target_sram_type（如 SRAM_SDP）。

启动 Sequence 时，严禁使用 seq.start(null)，必须挂载到合法的物理 Sequencer，例如 seq.start(env.agent.sqr);。

请求: "解释 SVA 报错"

引导用户查看波形。提醒用户关注 READ_LATENCY 拍之前的读指令。

重点提示排查两个方向：1. Write Mask (wem) 的极性是否接反。 2. Read-After-Write (RAW) 冒险发生时，新旧 Cell 的流水线写穿透行为是否一致。# ==========================================
# SRAM Wrapper CLI Makefile
# ==========================================
# 变量定义
SIM        ?= verilator
TOP        ?= tb_top
TEST       ?= mem_sdp_test
VERBOSITY  ?= UVM_LOW
WAVE_FILE  ?= dump.fst
RUN_DIR    ?= run_dir

# 路径定义
UVM_HOME   ?= /path/to/your/opensource/uvm
INCDIR      = +incdir+./verif_env/uvc +incdir+./verif_env/tests

# 编译参数
VFLAGS      = --binary -j 4 --trace-fst --assert \
              -Wno-fatal \
              $(INCDIR)

# 源文件
SRC         = ./verif_env/uvc/mem_uvc_pkg.sv \
              ./verif_env/tests/mem_test_pkg.sv \
              ./verif_env/tb/mem_if.sv \
              ./verif_env/tb/mem_sva_checker.sv \
              ./verif_env/tb/tb_top.sv

.PHONY: all clean build run wave regress

all: build run

# 1. 编译
build:
	@echo "==> Building Simulation Model with $(SIM)..."
	mkdir -p $(RUN_DIR)
	$(SIM) $(VFLAGS) $(SRC) --top-module $(TOP) --Mdir $(RUN_DIR)

# 2. 运行仿真
run:
	@echo "==> Running Test: $(TEST)"
	cd $(RUN_DIR) && ./V$(TOP) +UVM_TESTNAME=$(TEST) +UVM_VERBOSITY=$(VERBOSITY) +trace

# 3. 查看波形
wave:
	@echo "==> Opening Waveform with GTKWave..."
	gtkwave $(RUN_DIR)/$(WAVE_FILE) &

# 4. 清理环境
clean:
	@echo "==> Cleaning Run Directory..."
	rm -rf $(RUN_DIR)


💻 CLI 操作指南

在终端中，你只需要通过简单的命令即可掌控整个验证流程：

1. 执行单次编译与测试

默认将执行 mem_sdp_test（在 Makefile 中定义的默认 TEST）：

make all


2. 运行指定的 UVM Test

你可以通过命令行变量覆盖 Makefile 中的默认值，随时切换不同的测试场景（如 SP 或 TDP）：

make run TEST=mem_sp_test VERBOSITY=UVM_HIGH


3. 排查错误与查看波形

当 SVA 报错时，控制台会输出 Error 信息。你可以直接通过以下命令启动 GTKWave 查看出问题的确切 Cycle：

make wave


4. 彻底清理工作区

make clean


🧪 测试用例库与回归测试 (Regression)

本环境内置了针对 SRAM 替换痛点的核心 Sequence：

mem_wem_walking_seq：走马灯测试，排查 wem 极性与位宽错位。

mem_b2b_raw_seq：同址读写背靠背，排查流水线写穿透差异。

mem_sdp_no_mask_seq：伪双端口的高并发盲测。

CLI 回归脚本拓展思路

在开源 CLI 工作流中，你可以轻松在 scripts/ 下编写一个 regression.sh：

#!/bin/bash
TESTS=("mem_sp_test" "mem_sdp_test" "mem_tdp_test")
make clean build
for t in "${TESTS[@]}"; do
    echo "Running $t..."
    make run TEST=$t > run_dir/${t}.log
    if grep -q "UVM_ERROR" run_dir/${t}.log || grep -q "SVA ERROR" run_dir/${t}.log; then
        echo "❌ $t FAILED"
    else
        echo "✅ $t PASSED"
    fi
done


⚠️ 开源环境特殊注意事项

UVM 开源兼容性：标准的 UVM 1.2 源码在完全开源的仿真器（如早期的 Icarus Verilog）上可能会遇到解析阻力。强烈建议使用 Verilator 5.x 及以上版本，或者在团队预算允许下使用商用仿真器的 CLI 模式作为替代底座。

SVA 支持：开源仿真器对 SVA（SystemVerilog Assertions）的支持度在不断提升，但复杂的多时钟域 Assertions 可能受限。本环境采用的 |-> ##READ_LATENCY 是最基础且稳健的 SVA 语法，开源工具基本都能完美支持。

波形 Dump 宏：开源工具通常需要你在 tb_top.sv 中手动加入 Dump 指令。如果使用 Verilator 且希望输出 fst 格式（比 vcd 小很多），请在 tb_top 中加入：

initial begin
    $dumpfile("dump.fst");
    $dumpvars(0, tb_top);
end
