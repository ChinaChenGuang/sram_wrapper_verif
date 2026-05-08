# SRAM Wrapper A/B Verification Environment

基于 Verilator 的 SRAM Wrapper 替换验证环境。通过 **A/B Back-to-Back** 对比测试，验证新 SRAM Cell 能否安全替换旧 SRAM Cell。

## 架构

```
                    ┌─────────────┐
   +TEST=          │   Testbench  │
   +ADDR_WIDTH=    │  (tb_top_*)  │
   +DATA_WIDTH=    └──────┬──────┘
                          │ 共享激励 (vif.cmd, vif.addr, vif.wdata, vif.wem)
              ┌───────────┼───────────┐
              ▼           ▼           ▼
        ┌─────────┐ ┌─────────┐ ┌──────────┐
        │ dut_ori │ │ dut_new │ │   SVA    │
        │(Golden) │ │ (New)   │ │ Checker  │
        └────┬────┘ └────┬────┘ └────┬─────┘
             │            │           │
             ▼            ▼           ▼
        rdata_ori    rdata_new   assert(rdata_ori === rdata_new)
```

- 两个 DUT 共享完全相同的随机激励，SVA 逐周期比对输出
- 支持 **SP**（单端口）/ **SDP**（伪双端口）/ **TDP**（真双端口）/ **BitWrite** / **Multi-Bank**
- 纯 SystemVerilog + Verilator，无需 UVM

---

## 快速开始

```bash
# 编译 + 运行默认测试
make all

# 带时钟抖动 (±5%)
make all JITTER=1

# 查看波形
make wave
```

---

## B2B 批量处理（核心工作流）

当 orig 和 new SRAM 的 **module name 完全相同** 时，`make gen-b2b` 一条命令完成全部工作：

```bash
# 1. 编辑配置文件，列出所有待测 SRAM
vim sram_instances.yaml

# 2. 一键生成：module 改名 + connect 片段 + 回归脚本
make gen-b2b

# 3. 对单个实例测试
make test-sram_tdp TEST=mem_sdp_test

# 4. 全量回归
make regress-b2b TX_COUNT=200

# 5. 分析结果
make analyze-md
```

### 生成的文件结构

```
sram_instances.yaml
        │
        ▼  make gen-b2b
        │
        ├── gen/sram_tdp_ori.sv         (module sram_tdp → sram_tdp_ori)
        ├── gen/sram_tdp_new.sv         (module sram_tdp → sram_tdp_new)
        ├── gen/sram_tdp_connect.sv     (ori + new + checker 三合一)
        ├── gen/sram_sp_ori.sv
        ├── gen/sram_sp_new.sv
        ├── gen/sram_sp_connect.sv
        ├── gen/sram_b2b_list.mk        (Makefile 片段, 自动 include)
        └── gen/regress_sram_b2b.sh     (回归脚本)
```

### 统一 Connect 文件（ori + new + checker）

每个 B2B 实例生成**一个** connect 文件，波形中并排可见：

```systemverilog
// gen/sram_tdp_connect.sv — `include in tb_top

// ── DUT Original ──
sram_tdp_ori #(.ADDR_WIDTH(10), .DATA_WIDTH(32)) u_dut_ori (
    .clk(clk), .rst_n(rst_n),
    .cmd_a(vif.cmd_a), .addr_a(vif.addr_a), ...
    .rdata_a(vif.rdata_a_ori), .rdata_b(vif.rdata_b_ori)
);

// ── DUT New ──
sram_tdp_new #(.ADDR_WIDTH(10), .DATA_WIDTH(32)) u_dut_new (
    .clk(clk), .rst_n(rst_n),
    .cmd_a(vif.cmd_a), .addr_a(vif.addr_a), ...
    .rdata_a(vif.rdata_a_new), .rdata_b(vif.rdata_b_new)
);

// ── SVA Checker ──
mem_sva_checker #(.ADDR_WIDTH(10), .DATA_WIDTH(32), .READ_LATENCY(1))
    u_sva_checker(vif);
```

tb_top 中一行搞定：

```systemverilog
`ifdef USE_CONNECT
    `include "dut_connect.sv"   // ori + new + checker 全部
`endif
```

切换实例时自动 symlink：`make test-sram_sp` → `gen/sram_sp_connect.sv` → `gen/dut_connect.sv`

### YAML 配置格式

```yaml
instances:
  - name: sram_tdp              # 唯一标识
    module_name: sram_tdp       # Verilog module name (orig/new 同名)
    orig_path: rtl/orig/sram_tdp.sv
    new_path: rtl/new/sram_tdp.sv
    addr_width: 10
    data_width: 32
    enabled: true               # false = 暂不参与回归
```

---

## 内置 SRAM DUT 库

| 类型 | 实例名 | 配置 | Orig 实现 | New 实现 |
|------|--------|------|-----------|----------|
| **SP** 单端口 | `sram_sp` | 256×32 | Port A 读写, B 恒0 | 读地址流水线分离 |
| **SDP** 伪双端 | `sram_sdp` | 512×64 | A=只写, B=只读 | byte-group 写入 |
| **TDP** 真双端 | `sram_tdp` | 1K×32 | 同址写冲突 B 胜出 | 同址写冲突 A 胜出 |
| **BitWrite** | `sram_bitwrite` | 2K×16 | per-bit mask 直写 | byte-group + bit mask |
| **Bank4** 多 bank | `sram_bank4` | 1024×32 | MSB 选 bank (4×256) | LSB interleave 选 bank |

所有 DUT 对均为**同名 module**（orig 和 new 都叫 `sram_tdp` 等），`make gen-b2b` 自动处理重命名和连线。

---

## 时钟抖动

```bash
make all JITTER=1                           # ±5% uniform
make all JITTER=1 CLK_JITTER_MODE=gaussian  # 高斯分布
make all JITTER=1 CLK_JITTER_PCT=10          # ±10%
```

---

## 日志分析

```bash
make analyze-logs     # 终端概要
make analyze-md       # Markdown 报告 → run_dir/regress_report.md
make analyze-json     # JSON 报告 → run_dir/regress_report.json

# 回归 + 自动分析
make regress-report
make regress-multi-report
```

---

## Testbench 方案

| 方案 | 文件 | 说明 |
|------|------|------|
| **Simple** | `tb_top_simple.sv` | 单配置，编译时固定位宽 |
| **Multi** | `tb_top_multi.sv` | generate 6 组配置，一次编译全测 |
| **Unified** | `tb_top_unified.sv` | 最大位宽+Mask，运行时切换 |
| **Feature** | `tb_top_feature.sv` | Ref Model + 3-way 检查 |

```bash
# Multi 方案
make build-multi
make regress-multi                     # 6配置 × 5测试 = 30 cases

# Unified 方案（推荐）
make build-unified
make sweep                             # 一次仿真遍历全部配置
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
| `mem_fill_verify` | 写满全部地址逐一读回 |
| `mem_data_pattern` | 全0/全1/棋盘/走马灯 |
| `mem_wem_mask` | 写掩码 byte/bit/随机 |
| `mem_waw` / `mem_war` | 写后写 / 写后读冒险 |
| `mem_dual_conflict` | 双端口冲突场景 |
| `mem_stress` | 随机 Hammer 压力测试 |

---

## Makefile 速查

| 命令 | 说明 |
|------|------|
| `make all` | 编译 + 运行 |
| `make all JITTER=1` | 带时钟抖动 |
| `make gen-b2b` | **核心**: YAML → 改名+connect+回归脚本 |
| `make test-<name>` | 测试单个 SRAM 实例 |
| `make regress-b2b` | B2B 全实例回归 |
| `make regress-multi` | 多配置回归 (30 cases) |
| `make sweep` | 遍历 6 种配置 |
| `make analyze-md` | 生成 Markdown 报告 |
| `make gen-connect-pair` | 手动生成双 DUT connect |
| `make wave` | GTKWave 波形 |
| `make clean` | 清理 |

---

## 项目结构

```
├── rtl/
│   ├── clk_gen.sv               # 时钟发生器 (含抖动)
│   ├── dut_sram.sv / dut_sram_v2.sv  # 基础 DUT
│   ├── sram_ref_model.sv         # 黄金参考模型
│   ├── orig/                     # 原始 SRAM (同名 module)
│   │   ├── sram_sp.sv            #   单端口
│   │   ├── sram_sdp.sv           #   伪双端口
│   │   ├── sram_tdp.sv           #   真双端口
│   │   ├── sram_bitwrite.sv      #   位掩码
│   │   └── sram_bank4.sv         #   4-bank 拼接
│   └── new/                      # 替换 SRAM (同名 module, 不同实现)
│       └── (同上 5 个文件)
├── verif_env/tb/
│   ├── mem_if.sv                 # 统一参数化接口
│   ├── mem_sva_checker.sv        # SVA 比对
│   ├── tb_top_simple.sv          # 单配置 (支持 USE_CONNECT)
│   ├── tb_top_multi.sv           # 多配置 generate
│   ├── tb_top_unified.sv         # 统一+Mask
│   └── tb_top_feature.sv         # Ref Model 3-way
├── scripts/
│   ├── gen_sram_b2b.py           # B2B 批量生成 (module改名+connect+回归)
│   ├── gen_sram_wrapper.py       # Wrapper 生成器 (scan/wrap/connect/instance)
│   ├── analyze_logs.py           # 日志分析 (text/md/json)
│   ├── run_tests.sh              # 单配置回归
│   └── run_multi_regress.sh      # 多配置回归
├── gen/                          # 自动生成 (gitignored)
├── sram_instances.yaml           # SRAM 实例配置
├── Makefile
└── GEMINI.md                     # AI 辅助开发指引
```

---

## 依赖

- **Verilator 5.x**
- **Python 3.8+** + **PyYAML** (`pip3 install pyyaml`)
- **GTKWave** (波形, 可选)

## License

MIT
