# SRAM Wrapper A/B Verification Environment

基于 Verilator 的 SRAM Wrapper 替换验证环境。A/B Back-to-Back 测试 + Golden Reference Model 功能验证。

## 架构

```
  +TEST= +ADDR_WIDTH= +DATA_WIDTH=
  +CLK_A_PS= +CLK_B_PS= +CLK_B_PHASE_PS=
              │
     ┌────────┴────────┐
     │   tb_top_*.sv   │
     └────────┬────────┘
              │
    ┌─────────┼─────────┐
    ▼         ▼         ▼
  port_a   port_b    ref_model
    │         │         │
    ▼         ▼         ▼
 dut_ori   dut_ori   golden
 dut_new   dut_new
    │         │         │
    ▼         ▼         ▼
  AB-CHECK  AB-CHECK  FUNC-CHECK
  (per port SVA assertions)
```

## 快速开始

```bash
# 默认：decoupled 架构，双端口 TDP，同频同相
make all TEST=mem_fill_verify

# 单端口 SP
make all NUM_PORTS=1 SRAM_MODE=0 DUT_ORI=sram_sp DUT_NEW=sram_sp \
     DUT_SRCS="./rtl/orig/sram_sp.sv ./rtl/new/sram_sp.sv"

# 双时钟 1:2 频率比
make all CLK_B_PS=20000 TEST=mem_tdp_concurrent

# 不同 DUT 模块对比
make all DUT_ORI=dut_sram DUT_NEW=dut_sram_v2
```

## 四种 Testbench 架构

| 架构 | 命令 | 特点 |
|------|------|------|
| **Decoupled** (默认) | `make all` | 端口解耦，每端口独立 clk，SP/SDP/TDP |
| **DualClk** | `make build-dualclk` | 双时钟域 + 多时钟 SVA |
| **Feature** | `make build-feature` | Ref Model + A/B + 功能正确性 3-way check |
| **Unified** | `make build-unified` | 最大位宽 + Mask，运行时切配置 |

## 测试用例

```bash
# 基本读写
make run TEST=mem_fill_verify        # 全填充+验证
make run TEST=mem_data_pattern       # 数据模式 (全0/1/棋盘/走马灯)
make run TEST=mem_wem_mask           # 写掩码专项
make run TEST=mem_sdp_crossdomain    # SDP 跨时钟域
make run TEST=mem_tdp_concurrent     # TDP 并发双端口

# 全部一次跑完
make run TEST=mem_decoupled_all

# Feature 回归 (9项)
make regress-feature
```

## 时钟配置

```bash
make run CLK_A_PS=10000 CLK_B_PS=20000                    # 1:2 频率比
make run CLK_A_PS=10000 CLK_B_PS=10000 CLK_B_PHASE_PS=5000  # 180° 反相
make run CLK_B_JITTER=1                                   # Port B 时钟抖动
```

## SRAM 实例

| 类型 | orig | new | 端口 | 位宽 |
|------|------|-----|------|------|
| SP | sram_sp | sram_sp | 1 | 256×32 |
| SDP | sram_sdp | sram_sdp | 2 | 512×64 |
| TDP | sram_tdp | sram_tdp | 2 | 1K×32 |
| BitWrite | sram_bitwrite | sram_bitwrite | 2 | 2K×16 |
| Bank4 | sram_bank4 | sram_bank4 | 1 | 1K×32 |
| WEB | sram_web | sram_web | 2 | 1K×32 |

配置在 `sram_instances.yaml`，通过 `make gen-b2b` 生成测试文件。

## 项目结构

```
├── rtl/
│   ├── orig/                  # 原始 SRAM 实现 (6种)
│   ├── new/                   # 新版 SRAM 实现 (6种)
│   ├── sram_ref_model.sv      # Golden Reference Model
│   ├── sram_proto_adapter.sv  # cmd ↔ ceb+web 协议适配
│   ├── clk_gen.sv / clk_gen_dual.sv
│   └── dut_sram.sv / dut_sram_v2.sv
├── verif_env/tb/
│   ├── mem_port_if.sv         # 单端口接口 (解耦架构)
│   ├── mem_port_checker.sv    # 每端口 SVA checker
│   ├── mem_if.sv / mem_if_dualclk.sv
│   ├── tb_top_decoupled.sv    # 解耦 testbench (默认)
│   ├── tb_top_dualclk.sv      # 双时钟 testbench
│   ├── tb_top_feature.sv      # Feature 验证 testbench
│   └── tb_top_unified.sv      # 统一最大位宽 testbench
├── scripts/                   # Python 生成器 + 日志分析
├── docs/                      # Feature checklist
├── sram_instances.yaml        # SRAM 实例配置
├── Makefile
└── README.md
```

## 依赖

- **Verilator 5.x** (`sudo apt install verilator`)
- **GTKWave** (波形查看, 可选)
- **Python 3** (脚本生成, 可选)

## License

MIT
