# SRAM Wrapper B2B UVM Verification Environment (VCS Only)

基于 VCS 的 SRAM Wrapper 替换验证环境。采用 A/B Back-to-Back (B2B) 测试策略，由独立的 `mem_sva_checker` 模块进行 Cycle-Accurate 的检查。

## 核心特性

1. **VCS 专用流程**：彻底删除 Verilator 支持，优化 VCS 编译与仿真性能。
2. **B2B 验证**：将旧设计 (ORI) 作为 Golden Model，与新设计 (NEW) 共享激励。
3. **SVA 检查**：废弃 Scoreboard，在输出端直接通过 SVA 断言 (`rdata_ori === rdata_new`) 进行比对。
4. **严格 UVM 规范**：
   - 严禁使用 `uvm_field` 宏，手动重载 `do_copy`, `do_compare`, `do_print`。
   - 统一双端口接口 `mem_if`，支持并发 SP/SDP/TDP。
   - 安全激励生成：采用标准 4 步法生成 Transaction。

## 架构

```
  +UVM_TESTNAME= +ADDR_WIDTH= +DATA_WIDTH=
              │
      ┌───────┴───────┐
      │    tb_top     │ (Unified Interface)
      └───────┬───────┘
              │
    ┌─────────┼─────────┐
    ▼         ▼         ▼
  Port A    Port B   Ref Model (Golden)
    │         │         │
    ▼         ▼         ▼
  DUT ORI   DUT ORI   Golden
  DUT NEW   DUT NEW
    │         │         │
    ▼         ▼         ▼
  mem_sva_checker (A/B Compare)
```

## 快速开始

```bash
# 1. 编译
make build

# 2. 运行单次测试 (例如 SP)
make run UVM_TEST=test_mem_sp

# 3. 运行 SDP 测试并指定位宽
make run UVM_TEST=test_mem_sdp ADDR_WIDTH=12 DATA_WIDTH=64

# 4. 清理环境
make clean
```

## 测试用例库

- `test_mem_sp`: 单端口随机读写。
- `test_mem_sdp`: 伪双端口并发测试。
- `test_mem_tdp`: 真双端口并发测试。
- `test_mem_wem`: 写掩码专项测试。
- `test_mem_b2b`: 背靠背 RAW (Read-After-Write) 冒险测试。

## 项目结构

```
├── rtl/
│   ├── sram_ref_model.sv      # Golden Reference Model (VCS optimized)
│   ├── sram_cfg_pkg.sv        # 配置参数
│   └── sram_proto_adapter.sv  # 协议适配器
├── verif_env/
│   ├── tb/
│   │   ├── tb_top.sv          # 统一 Testbench Top
│   │   ├── mem_if.sv          # 统一双端口接口
│   │   └── mem_sva_checker.sv # 独立 SVA Checker 模块
│   ├── uvc/                   # UVM UVC
│   │   ├── mem_uvc_pkg.sv
│   │   └── classes/           # Item/Driver/Agent/Env
│   └── tests/                 # UVM Tests & Sequences
├── scripts/                   # B2B 生成脚本
├── sram_instances.yaml        # 实例配置
├── Makefile                   # VCS Makefile
└── README.md
```

## 依赖

- **VCS 2020+**
- **Verdi** (波形查看, 可选)
- **Python 3** (脚本生成)
