# SRAM Wrapper A/B Verification Environment

基于 Verilator 的 SRAM Wrapper 替换验证环境。通过 **A/B Back-to-Back** 对比测试，验证新 SRAM Cell 能否安全替换旧 SRAM Cell。

## 架构

```
                    ┌─────────────┐
   +TEST=          │   Testbench  │
   +ADDR_WIDTH=    │  (tb_top_*)  │
   +DATA_WIDTH=    └──────┬──────┘
                          │ 共享激励
              ┌───────────┼───────────┐
              ▼           ▼           ▼
        ┌─────────┐ ┌─────────┐ ┌──────────┐
        │ dut_ori │ │ dut_new │ │   SVA    │
        │(Golden) │ │ (New)   │ │ Checker  │
        └────┬────┘ └────┬────┘ └────┬─────┘
             │            │           │
             ▼            ▼           ▼
        rdata_ori    rdata_new   rdata_ori === rdata_new ?
```

- 两个 DUT 共享完全相同的随机激励
- SVA 断言逐周期比对 `rdata_ori === rdata_new`
- 支持 SP / SDP / TDP 三种 SRAM 模式
- 无需 UVM，纯 SystemVerilog + Verilator

---

## 快速开始

```bash
# 编译 + 运行默认测试 (SDP, 1K×32)
make all

# 带时钟抖动运行 (Feature 1)
make all JITTER=1

# 运行指定测试
make run TEST=mem_sp_test
make run TEST=mem_b2b_raw_test
make run TEST=mem_wem_walking_test

# 查看波形
make wave
```

---

## 核心功能

### 🕐 时钟抖动 (Feature 1)

可参数化的时钟发生器，支持均匀/高斯随机抖动，运行时控制。

```bash
# 启用抖动 (默认 ±5% uniform)
make all JITTER=1

# 关闭抖动 → 理想时钟
make all JITTER=0

# 精细控制 (仿真时 plusargs)
cd run_dir && ./Vtb_top \
    +CLK_JITTER_EN=1 \
    +CLK_JITTER_PCT=5 \
    +CLK_JITTER_MODE=gaussian
```

### 🔄 B2B 批量处理 — 一键完成 module 改名 + 例化片段

当 Original 和 Replacement SRAM 的 module name **完全相同**（如 `cpu_sys_256x182_mem_wrap`）时，`make gen-b2b` 一条命令完成全部工作：

```
sram_instances.yaml
        │
        ▼  make gen-b2b
        │
        ├── gen/cpu_sram_ori.sv          (module cpu_sram → cpu_sram_ori)
        ├── gen/cpu_sram_new.sv          (module cpu_sram → cpu_sram_new)
        ├── gen/cpu_sram_ori_connect.sv  (`include 片段, rdata→_ori)
        ├── gen/cpu_sram_new_connect.sv  (`include 片段, rdata→_new)
        ├── gen/gpu_sram_ori.sv
        ├── gen/gpu_sram_new.sv
        ├── gen/gpu_sram_ori_connect.sv
        ├── gen/gpu_sram_new_connect.sv
        ├── gen/sram_b2b_list.mk         (Makefile 片段)
        └── gen/regress_sram_b2b.sh      (回归脚本)
```

#### tb_top 中使用

```systemverilog
// tb_top 中用 `include 替代原来的 ifdef DUT_ORI/DUT_NEW 块：
`ifdef USE_CONNECT
    `include "dut_ori_connect.sv"
    `include "dut_new_connect.sv"
`else
    // ... legacy ifdef mode ...
`endif
```

```bash
# 一键生成所有 B2B 文件
make gen-b2b

# 对单个实例测试（自动 symlink 正确的 connect 文件）
make test-cpu_sys_256x182_mem_wrap TEST=mem_sdp_test

# 全量回归
make regress-b2b TX_COUNT=200
```

### 📦 非 B2B 单 DUT 例化 (Feature 5)

即使不做 A/B 对比，也可通过脚本自动生成 `include 片段，解析端口、连接 mem_if。

#### `connect` — 生成 `include 例化片段（推荐）

生成的文件直接 `include` 到 tb_top 中，内部已是 SRAM 的硬连线例化：

```bash
# 单 DUT
python3 scripts/gen_sram_wrapper.py connect rtl/dut_sram.sv --role ori -O dut_ori_connect

# B2B 双 DUT
python3 scripts/gen_sram_wrapper.py connect rtl/dut_sram.sv     --role ori -O dut_ori_connect
python3 scripts/gen_sram_wrapper.py connect rtl/dut_sram_v2.sv  --role new -O dut_new_connect

# 通过 Makefile
make gen-connect      SRAM_FILE=rtl/dut_sram.sv ROLE=ori OUTPUT=dut_connect
make gen-connect-pair ORI_FILE=rtl/dut_sram.sv NEW_FILE=rtl/dut_sram_v2.sv
```

生成的 `dut_ori_connect.sv`：
```systemverilog
// AUTO-GENERATED — `include in tb_top
dut_sram #(
    .ADDR_WIDTH (10),
    .DATA_WIDTH (32)
) u_dut_ori (
    .clk   (clk),
    .rst_n (rst_n),
    .cmd_a (vif.cmd_a),
    .addr_a (vif.addr_a),
    .wdata_a (vif.wdata_a),
    .wem_a (vif.wem_a),
    .rdata_a (vif.rdata_a_ori),   // role=ori → _ori
    .cmd_b (vif.cmd_b),
    .addr_b (vif.addr_b),
    .wdata_b (vif.wdata_b),
    .wem_b (vif.wem_b),
    .rdata_b (vif.rdata_b_ori)
);
```

tb_top 中使用：
```systemverilog
// 替换原来的 ifdef DUT_ORI / DUT_NEW 整段
`include "gen/dut_ori_connect.sv"
`include "gen/dut_new_connect.sv"
```

#### `instance` — 生成 wrapper module

```bash
python3 scripts/gen_sram_wrapper.py instance rtl/my_sram.sv --name my_dut
make gen-instance SRAM_FILE=rtl/dut_sram.sv INST_NAME=my_sram
```

#### 自动接口扫描与连线

脚本会解析 Verilog module 的端口列表，自动匹配标准接口信号，支持多种命名别名：

| 标准信号 | 识别的别名 |
|----------|-----------|
| `cmd_a` | `cena`, `ce_a`, `cs_a`, `chip_en_a` |
| `wdata_a` | `din_a`, `d_a`, `data_in_a` |
| `rdata_a` | `dout_a`, `q_a`, `data_out_a` |
| `wem_a` | `we_a`, `bweb_a`, `bw_a`, `write_mask_a` |
| ... | ... |

生成的 wrapper 自动处理：
- 端口名称映射
- 位宽适配 (参数化连线)
- 未连接端口自动 tie-off

### 📊 日志分析 (Feature 4)

解析仿真 log，提取测试结果、SVA 错误详情，生成多格式报告。

```bash
# 快速概要
make analyze-logs

# 生成 Markdown 报告
make analyze-md
# → run_dir/regress_report.md

# 生成 JSON 报告 (便于 CI 集成)
make analyze-json
# → run_dir/regress_report.json

# 回归 + 自动生成报告
make regress-report        # 单配置回归 + 报告
make regress-multi-report  # 多配置回归 + 报告
```

报告内容：
- ✅/❌ 统计、通过率
- SVA 错误详情 (ori/new 值逐行对比)
- 仿真时间、Transaction 计数
- Per-configuration 分项统计

---

## 三种 Testbench 方案

| 方案 | 文件 | 特点 |
|------|------|------|
| **Simple** | `tb_top_simple.sv` | 单配置，编译时固定 ADDR_WIDTH/DATA_WIDTH |
| **Multi (方案A)** | `tb_top_multi.sv` | generate 6 组不同配置，一次编译全部测试 |
| **Unified (方案B)** | `tb_top_unified.sv` | 最大位宽 + Mask，运行时动态切换配置 |
| **Feature (方案C)** | `tb_top_feature.sv` | Ref Model + 3-way 检查 (ori/new/ref) |

### 方案 A — 多配置 Generate

```bash
make build-multi                          # 编译 (6 组 DUT)
make run-multi INST=0 TEST=mem_sp_test    # 测配置 0 (256×8)
make run-multi TEST=mem_sdp_test          # 6 组并发测
make regress-multi                        # 全回归 (30 cases)
```

### 方案 B — 统一最大位宽 + Mask（推荐）

```bash
make build-unified                        # 编译 (1 组最大位宽 DUT)
make run-unified ADDR_WIDTH=8  DATA_WIDTH=8   TEST=mem_sp_test
make run-unified ADDR_WIDTH=12 DATA_WIDTH=64  TEST=mem_tdp_test

# 一次仿真遍历全部 6 种配置
make sweep
```

### 不同 DUT 模块

```bash
# ori 和 new 使用不同模块
make all DUT_ORI=dut_sram DUT_NEW=dut_sram_v2
make build-unified DUT_ORI=dut_sram DUT_NEW=dut_sram_v2
```

---

## 测试用例

| 测试 | 说明 |
|------|------|
| `mem_sp_test` | 单端口随机读写 |
| `mem_sdp_test` | 伪双端口 (A写 B读) |
| `mem_tdp_test` | 真双端口随机 |
| `mem_wem_walking_test` | 写掩码走马灯 |
| `mem_b2b_raw_test` | 同址背靠背 RAW |
| `mem_fill_verify` | 写满全部地址再逐一读回 |
| `mem_data_pattern` | 全0/全1/棋盘/走马灯数据模式 |
| `mem_wem_mask` | 写掩码 byte/bit/随机验证 |
| `mem_addr_boundary` | 边界地址测试 |
| `mem_waw` / `mem_war` | 写后写 / 写后读冒险 |
| `mem_dual_conflict` | 双端口冲突场景 |
| `mem_reset` | 复位行为验证 |
| `mem_stress` | 随机 Hammer 压力测试 |
| `mem_sweep_all` | 遍历全部 6 种配置 (仅方案 B) |

---

## 内置 SRAM 配置

| ID | 名称 | 深度 | 位宽 | 容量 |
|----|------|------|------|------|
| — | 256×8 | 256 | 8 | 2Kb |
| — | 1K×32 | 1024 | 32 | 32Kb |
| — | 4K×64 | 4096 | 64 | 256Kb |
| — | 64×256 | 64 | 256 | 16Kb |
| — | 64K×8 | 65536 | 8 | 512Kb |
| — | 512×128 | 512 | 128 | 64Kb |

---

## Makefile 命令速查

| 命令 | 说明 |
|------|------|
| `make all` | 编译 + 运行默认测试 |
| `make build / run` | 分步编译/运行 |
| `make all JITTER=1` | 带时钟抖动 |
| `make gen-b2b` | 从 YAML 生成 B2B 文件 |
| `make gen-connect` | 生成 `include DUT 例化片段 |
| `make gen-connect-pair` | 生成 B2B 双 DUT connect 文件 |
| `make gen-instance` | 生成 sram_instance wrapper module |
| `make test-<name>` | 对特定 SRAM 实例测试 |
| `make regress-b2b` | B2B 全实例回归 |
| `make sweep` | 一次遍历 6 种配置 |
| `make analyze-md` | 生成 Markdown 日志报告 |
| `make regress-report` | 回归 + 生成报告 |
| `make wave` | 打开波形 |
| `make clean` | 清理 |

---

## 项目结构

```
├── rtl/
│   ├── clk_gen.sv               # 时钟发生器 (含抖动)
│   ├── dut_sram.sv               # DUT (旧版)
│   ├── dut_sram_v2.sv            # DUT (新版, 演示不同模块名)
│   ├── dut_wrapper.sv            # DUT 选择包装器
│   ├── sram_cfg_pkg.sv           # 配置定义包
│   ├── sram_ref_model.sv         # 黄金参考模型
│   ├── orig/                     # 原始 SRAM (同名 module 示例)
│   └── new/                      # 替换 SRAM (同名 module 示例)
├── verif_env/
│   └── tb/
│       ├── mem_if.sv             # 统一参数化接口
│       ├── mem_sva_checker.sv    # SVA 比对模块
│       ├── sram_test_env.sv      # 参数化测试环境
│       ├── tb_top_simple.sv      # 方案: 单配置
│       ├── tb_top_multi.sv       # 方案 A: 多配置 generate
│       ├── tb_top_unified.sv     # 方案 B: 统一+Mask
│       └── tb_top_feature.sv     # 方案 C: Ref Model 3-way check
├── scripts/
│   ├── gen_sram_b2b.py           # B2B 文件生成器 (YAML → _ori/_new.sv)
│   ├── gen_sram_wrapper.py       # Wrapper 生成器 (scan/wrap/full)
│   ├── analyze_logs.py           # 日志分析器 (text/md/json)
│   ├── run_tests.sh              # 单配置回归脚本
│   └── run_multi_regress.sh      # 多配置回归脚本
├── gen/                          # 自动生成文件 (已 gitignore)
├── docs/                         # 文档
├── sram_instances.yaml           # SRAM 实例配置
├── Makefile
└── GEMINI.md                     # AI 辅助开发指引
```

---

## 依赖

- **Verilator 5.x** (`sudo apt install verilator`)
- **Python 3.8+** (用于自动化脚本)
- **PyYAML** (`pip3 install pyyaml`)
- **GTKWave** (波形查看, 可选)

## License

MIT
