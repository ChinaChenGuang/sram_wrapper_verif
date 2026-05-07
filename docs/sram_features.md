# SRAM Feature Verification Checklist

## A. 基本读写 (Basic Read/Write)
| ID | Feature | 描述 | 测试方法 |
|----|---------|------|----------|
| A1 | Write+Read | 写数据后读回验证 | 写随机数据 → 读同地址 → 比对 |
| A2 | Uninitialized Read | 未写过的地址读回应为 0 | 读未写过地址 → 验证 rdata==0 |
| A3 | Overwrite | 同地址再次写入覆盖旧值 | 写 A → 写 B → 读 → 验证 B |
| A4 | Address Independence | 各地址独立，互不影响 | 写 addr0 → 写 addr1 → 读 addr0 → 验证 addr0 值 |

## B. 写掩码 (Write Enable Mask)
| ID | Feature | 描述 | 测试方法 |
|----|---------|------|----------|
| B1 | Full Write | wem=0 全字写入 | wem=0 → 写 → 读 → 全部 bit 匹配 |
| B2 | Byte Mask | 按 byte 选择性写入 | wem 部分 byte 为 0，验证未选 byte 不变 |
| B3 | Bit Mask | 单 bit 写入 | wem 仅 1 bit 为 0 |
| B4 | No Write | wem=all1 不写入任何 bit | 写 A(wem=0) → 写 B(wem=all1) → 读 → A |
| B5 | Walking 0 | wem 逐 bit 走 0 | for i: wem=~(1<<i) → 写 → 读 |
| B6 | Walking 1 | wem 逐 bit 走 1 | wem = 1<<i (仅 1 bit masked) |
| B7 | Random Mask | 随机 wem 模式 | 随机 wem + 预填背景 → 验证仅选中 bit 变 |
| B8 | Polarity Check | wem 极性: 0=write, 1=mask | 显式验证 wem=0 写入, wem=1 保留 |

## C. 数据模式 (Data Patterns)
| ID | Feature | 描述 |
|----|---------|------|
| C1 | All Zeros | 0x00000000 |
| C2 | All Ones | 0xFFFFFFFF |
| C3 | Checkerboard | 0x55555555 / 0xAAAAAAAA |
| C4 | Walking 1 | 0x00000001, 0x00000002, ... |
| C5 | Walking 0 | 0xFFFFFFFE, 0xFFFFFFFD, ... |
| C6 | Random | $urandom |

## D. 地址遍历 (Address Patterns)
| ID | Feature | 描述 |
|----|---------|------|
| D1 | Addr Min | 地址 0 |
| D2 | Addr Max | 最大地址 (2^AW - 1) |
| D3 | Sequential | 0,1,2,...,N-1 |
| D4 | Random | 随机地址 |
| D5 | Reverse | N-1,N-2,...,0 |

## E. 冒险处理 (Hazards)
| ID | Feature | 描述 |
|----|---------|------|
| E1 | RAW Same Port | 同端口 Read-After-Write |
| E2 | RAW Cross Port | SDP: Port A 写, Port B 读同地址 |
| E3 | WAR Same Port | Write-After-Read 同地址 |
| E4 | WAW Same Port | Write-After-Write 同端口 |
| E5 | WAW Cross Port | Write-After-Write 双端口 |

## F. 双端口 (Dual Port)
| ID | Feature | 描述 |
|----|---------|------|
| F1 | Independent R/W | TDP: A/B 各独立操作不同地址 |
| F2 | Simultaneous Read | A/B 同时读同地址 |
| F3 | Simultaneous Write | A/B 同时写同地址 (冲突行为) |
| F4 | Read+Write Same Addr | A 读 B 写同地址 (RAW 跨端口) |
| F5 | SDP Mode | A 写 B 读 (伪双端口) |

## G. 复位行为 (Reset)
| ID | Feature | 描述 |
|----|---------|------|
| G1 | Read After Reset | 复位后读 → 应为 0 |
| G2 | Write-Reset-Read | 写 → 复位 → 读 → 应为 0 |
| G3 | Reset During Op | 操作中复位 → 后续行为正确 |

## H. 时序/流水线 (Timing)
| ID | Feature | 描述 |
|----|---------|------|
| H1 | Read Latency | 验证 READ_LATENCY 拍后数据有效 |
| H2 | Back-to-Back Cmd | 连续命令无气泡 |
| H3 | NOP Insertion | 读写间插入 NOP |
| H4 | Max Throughput | 每拍发命令 |

## I. 压力测试 (Stress)
| ID | Feature | 描述 |
|----|---------|------|
| I1 | Full Fill+Verify | 写满所有地址 → 逐一读回验证 |
| I2 | Random Hammer | 大量随机操作 |
| I3 | Long Sequence | 长时间连续操作 |

## J. Corner Cases
| ID | Feature | 描述 |
|----|---------|------|
| J1 | Single Location | 仅反复操作 1 个地址 |
| J2 | Two Locations | 两个地址交替操作 |
| J3 | Power-of-2 Boundary | 地址在 2^n 边界附近 |
| J4 | Max Data Width | 最大位宽操作 |
