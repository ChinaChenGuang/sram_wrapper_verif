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

## 快速开始

```bash
# 编译 + 运行默认测试 (SDP, 1K×32)
make all

# 运行指定测试
make run TEST=mem_sp_test
make run TEST=mem_b2b_raw_test
make run TEST=mem_wem_walking_test

# 查看波形
make wave
```

## 三种 Testbench 方案

| 方案 | 文件 | 特点 |
|------|------|------|
| **Simple** | `tb_top_simple.sv` | 单配置，编译时固定 ADDR_WIDTH/DATA_WIDTH |
| **Multi (方案A)** | `tb_top_multi.sv` | generate 6 组不同配置，一次编译全部测试 |
| **Unified (方案B)** | `tb_top_unified.sv` | 最大位宽 + Mask，运行时动态切换配置 |

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
make run-unified ADDR_WIDTH=16 DATA_WIDTH=8   TEST=mem_b2b_raw_test

# 一次仿真遍历全部 6 种配置
make sweep
```

### Different DUT Modules

```bash
# ori 和 new 使用不同模块
make all DUT_ORI=dut_sram DUT_NEW=dut_sram_v2
make build-unified DUT_ORI=dut_sram DUT_NEW=dut_sram_v2
```

## 测试用例

| 测试 | 说明 |
|------|------|
| `mem_sp_test` | 单端口随机读写 |
| `mem_sdp_test` | 伪双端口 (A写 B读) |
| `mem_tdp_test` | 真双端口随机 |
| `mem_wem_walking_test` | 写掩码走马灯 |
| `mem_b2b_raw_test` | 同址背靠背 RAW |
| `mem_sweep_all` | 遍历全部 6 种配置 (仅方案 B) |

## 内置 SRAM 配置

| ID | 名称 | 深度 | 位宽 | 容量 |
|----|------|------|------|------|
| — | 256×8 | 256 | 8 | 2Kb |
| — | 1K×32 | 1024 | 32 | 32Kb |
| — | 4K×64 | 4096 | 64 | 256Kb |
| — | 64×256 | 64 | 256 | 16Kb |
| — | 64K×8 | 65536 | 8 | 512Kb |
| — | 512×128 | 512 | 128 | 64Kb |

## 项目结构

```
├── rtl/
│   ├── dut_sram.sv           # DUT (旧版)
│   ├── dut_sram_v2.sv        # DUT (新版, 演示不同模块名)
│   ├── dut_wrapper.sv        # DUT 选择包装器
│   └── sram_cfg_pkg.sv       # 配置定义包
├── verif_env/
│   ├── tb/
│   │   ├── mem_if.sv         # 统一参数化接口
│   │   ├── mem_sva_checker.sv # SVA 比对模块
│   │   ├── sram_test_env.sv  # 参数化测试环境
│   │   ├── tb_top_simple.sv  # 方案: 单配置
│   │   ├── tb_top_multi.sv   # 方案 A: 多配置 generate
│   │   └── tb_top_unified.sv # 方案 B: 统一+Mask
│   ├── tests/                # UVM 测试 (需商业仿真器)
│   └── uvc/                  # UVM 组件 (需商业仿真器)
├── scripts/                  # 回归脚本
├── docs/                     # 文档
├── Makefile
└── GEMINI.md                 # AI 辅助开发指引
```

## 依赖

- **Verilator 5.x** (`sudo apt install verilator`)
- **GTKWave** (波形查看, 可选)

## License

MIT
