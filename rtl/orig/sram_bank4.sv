// ============================================================
// sram_bank4 - 4-Bank Aggregated SRAM (1024×32)
// ============================================================
// Stitches 4 × 256×32 internal banks into 1 × 1024×32 SRAM.
// Upper 2 address bits select bank:
//   addr[9:8] = 00 → bank0, 01 → bank1, 10 → bank2, 11 → bank3
// ADDR_WIDTH=10 (8 internal + 2 bank select), DATA_WIDTH=32
// ============================================================

`timescale 1ns/1ps

module sram_bank4 #(
    parameter ADDR_WIDTH = 10,
    parameter DATA_WIDTH = 32
)(
    input  logic                       clk,
    input  logic                       rst_n,

    input  logic [1:0]                 cmd_a,
    input  logic [ADDR_WIDTH-1:0]      addr_a,
    input  logic [DATA_WIDTH-1:0]      wdata_a,
    input  logic [DATA_WIDTH-1:0]      wem_a,
    output logic [DATA_WIDTH-1:0]      rdata_a,

    input  logic [1:0]                 cmd_b,
    input  logic [ADDR_WIDTH-1:0]      addr_b,
    input  logic [DATA_WIDTH-1:0]      wdata_b,
    input  logic [DATA_WIDTH-1:0]      wem_b,
    output logic [DATA_WIDTH-1:0]      rdata_b
);

    localparam BANK_AW    = ADDR_WIDTH - 2;   // 8 bits per bank
    localparam BANK_DEPTH = 1 << BANK_AW;     // 256 per bank
    localparam NUM_BANKS  = 4;

    // Bank memory arrays
    logic [DATA_WIDTH-1:0] bank [0:NUM_BANKS-1] [0:BANK_DEPTH-1];

    // Bank selection
    wire [1:0] bank_sel_a = addr_a[ADDR_WIDTH-1 : BANK_AW];
    wire [1:0] bank_sel_b = addr_b[ADDR_WIDTH-1 : BANK_AW];
    wire [BANK_AW-1:0] bank_addr_a = addr_a[BANK_AW-1 : 0];
    wire [BANK_AW-1:0] bank_addr_b = addr_b[BANK_AW-1 : 0];

    // Read mux
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rdata_a <= '0;
            rdata_b <= '0;
        end else begin
            if (cmd_a == 2'b01) rdata_a <= bank[bank_sel_a][bank_addr_a];
            if (cmd_b == 2'b01) rdata_b <= bank[bank_sel_b][bank_addr_b];
        end
    end

    // Write with bank decode
    always_ff @(posedge clk) begin
        if (cmd_a == 2'b10) begin
            for (int i = 0; i < DATA_WIDTH; i++)
                if (!wem_a[i]) bank[bank_sel_a][bank_addr_a][i] <= wdata_a[i];
        end
        if (cmd_b == 2'b10) begin
            for (int i = 0; i < DATA_WIDTH; i++)
                if (!wem_b[i]) bank[bank_sel_b][bank_addr_b][i] <= wdata_b[i];
        end
    end

endmodule
