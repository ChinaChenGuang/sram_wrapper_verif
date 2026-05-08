// ============================================================
// sram_proto_adapter - 协议适配器
// ============================================================
// 将常见 SRAM 控制接口 (ceb/cs + web + data_i/data_o) 转换为
// 验证环境的标准 cmd 接口 (READ/WRITE/NOP + wdata/rdata 共用总线)。
//
// ============================================================
// 接口对照表:
// ============================================================
//  标准接口 (cmd)         常见 SRAM 接口 (ceb+web)        含义
//  ─────────────────      ────────────────────────        ────
//  cmd = 00 (NOP)         ceb = 1                        禁用
//  cmd = 01 (READ)        ceb = 0, web = 1               读
//  cmd = 10 (WRITE)       ceb = 0, web = 0               写
//
//  wdata                   data_i                         写入数据
//  rdata                   data_o                         读出数据
//  wem (0=write,1=mask)    wem / bw / bweb               位掩码
// ============================================================
//
// 自动检测接口类型:
//   TYPE 0: 标准 cmd 接口  → 直通 (bypass)
//   TYPE 1: ceb+web 接口   → cmd = {web_n, ceb_n}
//           其中 web=0写/1读, ceb=1禁止/0使能
//   TYPE 2: cs+we 接口     → cmd = {~we, ~cs}
//           cs=1选中/0禁止, we=1写/0读
// ============================================================

`timescale 1ns/1ps

module sram_proto_adapter #(
    parameter ADDR_WIDTH   = 10,
    parameter DATA_WIDTH   = 32,
    parameter PROTO_TYPE   = 1,       // 0=cmd, 1=ceb+web, 2=cs+we
    parameter HAS_RST_N    = 1,       // 1=有 rst_n, 0=无
    parameter HAS_BITMASK  = 1        // 1=有 wem/bw, 0=全字写入
)(
    // === 验证环境侧 (标准 cmd 接口) ===
    input  logic                       clk,
    input  logic                       rst_n,

    output logic [1:0]                 cmd_a_o,
    output logic [ADDR_WIDTH-1:0]      addr_a_o,
    output logic [DATA_WIDTH-1:0]      wdata_a_o,
    output logic [DATA_WIDTH-1:0]      wem_a_o,
    input  logic [DATA_WIDTH-1:0]      rdata_a_i,

    output logic [1:0]                 cmd_b_o,
    output logic [ADDR_WIDTH-1:0]      addr_b_o,
    output logic [DATA_WIDTH-1:0]      wdata_b_o,
    output logic [DATA_WIDTH-1:0]      wem_b_o,
    input  logic [DATA_WIDTH-1:0]      rdata_b_i,

    // === SRAM 侧 (原生接口) ===
    output logic                       ceb_a_o,     // chip enable (active low)
    output logic                       web_a_o,     // write enable (active low)
    output logic [ADDR_WIDTH-1:0]      addr_a_raw,
    output logic [DATA_WIDTH-1:0]      data_i_a,
    output logic [DATA_WIDTH-1:0]      wem_a_raw,
    input  logic [DATA_WIDTH-1:0]      data_o_a,

    output logic                       ceb_b_o,     // Port B
    output logic                       web_b_o,
    output logic [ADDR_WIDTH-1:0]      addr_b_raw,
    output logic [DATA_WIDTH-1:0]      data_i_b,
    output logic [DATA_WIDTH-1:0]      wem_b_raw,
    input  logic [DATA_WIDTH-1:0]      data_o_b
);

    // ============================================================
    // Port A — cmd → ceb/web 转换
    // ============================================================
    always_comb begin
        // Default pass-through
        addr_a_raw = addr_a_o;
        data_i_a   = wdata_a_o;
        wem_a_raw  = (HAS_BITMASK) ? wem_a_o : '0;

        case (PROTO_TYPE)
            0: begin  // 标准 cmd — 直通 (ceb/web 不使用)
                ceb_a_o = 1'b0;  // always enabled
                web_a_o = 1'b0;
            end
            1: begin  // ceb+web (active low)
                // cmd=00(NOP)→ceb=1,  cmd=01(READ)→ceb=0,web=1,  cmd=10(WRITE)→ceb=0,web=0
                ceb_a_o = (cmd_a_o == 2'b00);           // NOP → chip disable
                web_a_o = (cmd_a_o != 2'b10);           // WRITE → web=0, else web=1
            end
            2: begin  // cs+we (active high chip select)
                // cmd=00(NOP)→cs=0,  cmd=01(READ)→cs=1,we=0,  cmd=10(WRITE)→cs=1,we=1
                ceb_a_o = ~(cmd_a_o != 2'b00);          // cs = cmd!=NOP
                web_a_o = ~(cmd_a_o == 2'b10);           // we = cmd==WRITE
            end
            default: begin
                ceb_a_o = 1'b0;
                web_a_o = 1'b0;
            end
        endcase
    end

    // ============================================================
    // Port B — cmd → ceb/web 转换
    // ============================================================
    always_comb begin
        addr_b_raw = addr_b_o;
        data_i_b   = wdata_b_o;
        wem_b_raw  = (HAS_BITMASK) ? wem_b_o : '0;

        case (PROTO_TYPE)
            1: begin
                ceb_b_o = (cmd_b_o == 2'b00);
                web_b_o = (cmd_b_o != 2'b10);
            end
            2: begin
                ceb_b_o = ~(cmd_b_o != 2'b00);
                web_b_o = ~(cmd_b_o == 2'b10);
            end
            default: begin
                ceb_b_o = 1'b0;
                web_b_o = 1'b0;
            end
        endcase
    end

    // ============================================================
    // 读数据回传 (data_o → rdata)
    // ============================================================
    // 直通：SRAM 的 data_o 就是验证环境的 rdata
    // (在 adapter 外部连接到 dut_ori/dut_new 的 rdata 端口)

endmodule
