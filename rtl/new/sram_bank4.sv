// ============================================================
// sram_bank4 - 4-Bank Aggregated SRAM v2 (replacement)
// ============================================================
// New: interleaved bank architecture (address LSBs select bank).
// addr[1:0] = bank, addr[9:2] = intra-bank address.
// This gives better bandwidth for sequential access patterns.
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

    localparam BANK_AW    = ADDR_WIDTH - 2;
    localparam BANK_DEPTH = 1 << BANK_AW;
    localparam NUM_BANKS  = 4;

    logic [DATA_WIDTH-1:0] bank [0:NUM_BANKS-1] [0:BANK_DEPTH-1];

    // New: LSB interleave — bank = addr[1:0], row = addr[9:2]
    wire [1:0] bank_sel_a = addr_a[1:0];
    wire [1:0] bank_sel_b = addr_b[1:0];
    wire [BANK_AW-1:0] bank_addr_a = addr_a[ADDR_WIDTH-1 : 2];
    wire [BANK_AW-1:0] bank_addr_b = addr_b[ADDR_WIDTH-1 : 2];

    // Read mux (structurally different but functionally equivalent)
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rdata_a <= '0;
            rdata_b <= '0;
        end else begin
            if (cmd_a == 2'b01) rdata_a <= bank[bank_sel_a][bank_addr_a];
            if (cmd_b == 2'b01) rdata_b <= bank[bank_sel_b][bank_addr_b];
        end
    end

    // Write
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
