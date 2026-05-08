// ============================================================
// sram_sdp - Simple Dual-Port SRAM (512×64)
// ============================================================
// Port A: WRITE only  (cmd_a forced to WRITE/NOP)
// Port B: READ  only  (cmd_b forced to READ/NOP)
// This is common for FIFO / buffer applications.
// ADDR_WIDTH=9, DATA_WIDTH=64
// ============================================================

`timescale 1ns/1ps

module sram_sdp #(
    parameter ADDR_WIDTH = 9,
    parameter DATA_WIDTH = 64
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

    localparam DEPTH = 1 << ADDR_WIDTH;
    logic [DATA_WIDTH-1:0] mem [0:DEPTH-1];

    // Port A read always 0 (write-only port)
    assign rdata_a = '0;

    // Port B — Read
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rdata_b <= '0;
        end else if (cmd_b == 2'b01) begin
            rdata_b <= mem[addr_b];
        end
    end

    // Port A — Write
    always_ff @(posedge clk) begin
        if (cmd_a == 2'b10) begin
            for (int i = 0; i < DATA_WIDTH; i++)
                if (!wem_a[i]) mem[addr_a][i] = wdata_a[i];
        end
    end

endmodule
