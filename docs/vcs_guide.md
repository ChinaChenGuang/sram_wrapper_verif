# Synopsys VCS & UVM 仿真指南

## 概述

本项目支持 **Verilator** (开发用) 和 **Synopsys VCS** (正式验证用) 两种仿真器。

VCS 优势：
- 原生 UVM 1.2/1800.2 支持（`-ntb_opts uvm-1.2`）
- 完整的 DPI/PLI/VPI 实现
- 专业波形调试 (Verdi/DVE)
- 覆盖率收集
- 更快的 UVM 仿真性能

---

## 方法一：使用本地 VCS（推荐，如果有安装）

### 前提条件

- Synopsys VCS 已安装，`vcs` 命令在 PATH 中
- Synopsys 许可服务器已启动
- UVM 库可用（项目已包含 UVM 1800.2-2020.3.1）

### 编译 UVM Testbench

```bash
# 编译 UVM 测试平台 (test_mem_sp 为默认测试)
make build

# 指定 DUT 模块
make build DUT_ORI=dut_sram DUT_NEW=dut_sram_v2
```

### 运行仿真

```bash
# 运行指定 UVM 测试
make run-vcs UVM_TEST=test_mem_sp

# 完整配置
make run-vcs UVM_TEST=test_mem_fill_verify \
    ADDR_WIDTH=10 DATA_WIDTH=32 TX_COUNT=100 \
    CLK_A_PS=10000 CLK_B_PS=20000
```

### 快速测试（一键编译+运行）

```bash
make vcs-sp     # 单端口 (SP) 测试
make vcs-sdp    # 伪双端口 (SDP) 测试
make vcs-tdp    # 真双端口 (TDP) 测试
make vcs-wem    # 写掩码 (WEM) 测试
make vcs-b2b    # Back-to-Back 测试
make vcs-fill   # 全填充+验证测试
```

### 使用图形界面

```bash
make vcs-gui                    # 启动 DVE
# 或者用 Verdi
cd vcs_work && verdi -ssf dump.fst &
```

### 清理

```bash
make vcs-clean
```

---

## 方法二：使用 Docker-Synopsys 容器

### 前提条件

1. **安装 Docker**
   ```bash
   # Ubuntu
   sudo apt install docker.io
   sudo systemctl enable --now docker
   
   # 或者用官方脚本
   curl -fsSL https://get.docker.com | sudo sh
   ```

2. **安装 Synopsys VCS 到宿主机**
   ```
   /opt/Synopsys/
   ├── scl/           # 许可管理工具
   │   ├── bin/
   │   └── synopsys.dat (许可文件)
   ├── VCS/           # VCS 编译器
   └── Verdi/         # 波形查看工具 (可选)
   ```

### 构建 Docker 镜像

```bash
# 一次性构建所有 Docker 镜像
make docker-build
```

这会执行：
1. 构建 `scl` 镜像 - 运行许可服务器
2. 构建 `synopsys` 镜像 - 包含 VCS 运行环境
3. 构建 CLI 启动器 `docker-synopsys/bin/synopsys`

### 启动许可服务器

```bash
# 启动许可服务器（需要 /opt/Synopsys/scl/synopsys.dat）
make docker-license-start

# 检查状态
make docker-license-status

# 停止
make docker-license-stop
```

### 编译和运行

```bash
# 在 Docker 中编译 VCS
make docker-compile

# 在 Docker 中运行仿真
make docker-run UVM_TEST=test_mem_sp

# 完整配置
make docker-run UVM_TEST=test_mem_fill_verify \
    ADDR_WIDTH=10 DATA_WIDTH=32 TX_COUNT=100
```

### 交互式 Shell

```bash
# 进入 Docker 容器交互式环境
make docker-shell

# 容器内部可直接用 vcs 命令
vcs -full64 -sverilog -timescale=1ns/1ps \
    +vcs+lic+wait \
    -ntb_opts uvm-1.2 \
    +incdir+./verif_env/tb \
    -o vcs_work/simv \
    ./verif_env/tb/tb_top_uvm.sv
```

---

## VCS UVM 编译说明

### 使用 VCS 内置 UVM 1.2

```bash
vcs -full64 -sverilog -timescale=1ns/1ps \
    +vcs+lic+wait \
    -ntb_opts uvm-1.2 \              # VCS 内置 UVM 1.2
    -debug_access+all \
    -o simv \
    -f scripts/vcs_uvm.f
```

### 使用自定义 UVM 1800.2

```bash
vcs -full64 -sverilog -timescale=1ns/1ps \
    +vcs+lic+wait \
    +incdir+/path/to/uvm-1800.2/src \
    /path/to/uvm-1800.2/src/uvm_pkg.sv \
    -debug_access+all \
    -o simv \
    -f scripts/vcs_uvm.f
```

### 常用 VCS 选项

| 选项 | 说明 |
|------|------|
| `-full64` | 64位模式 |
| `-sverilog` | 启用 SystemVerilog |
| `-ntb_opts uvm-1.2` | 启用内置 UVM 1.2 |
| `+vcs+lic+wait` | 等待可用的许可 |
| `-debug_access+all` | 完整调试信息 |
| `-line64` | 行级调试 |
| `-j N` | 并行编译线程数 |
| `-l logfile` | 日志文件 |
| `+define+VCS` | 定义 VCS 宏 |

---

## 常见问题

### Q: VCS 报 `license` 错误

确保：
1. 许可服务器已启动：`make docker-license-status`
2. 许可文件 `/opt/Synopsys/scl/synopsys.dat` 配置正确
3. MAC 地址和主机名与许可匹配

### Q: Docker 无法连接

```bash
# 检查 Docker 服务
sudo systemctl status docker

# 加入 docker 组（避免 sudo）
sudo usermod -aG docker $USER
newgrp docker
```

### Q: VCS 找不到 UVM 包

```bash
# 设置 UVM_HOME 环境变量
export UVM_HOME=/home/chen/proj/UVM/UVM-1800.2-2020.3.1/1800.2-2020.3.1/src
```

### Q: 如何切换回 Verilator？

```bash
# Verilator 是默认的，直接运行：
make build-uvm UVM_TEST=test_mem_sp
make run-uvm UVM_TEST=test_mem_sp

# 或者
make uvm-sp
```
