// ============================================================
// sram_sp - Single-Port SRAM (256×32)
// ============================================================
// Only Port A is active. Port B is not connected internally.
// This is the simplest SRAM type.
// ADDR_WIDTH=8, DATA_WIDTH=32
// ============================================================

`timescale 1ns/1ps

module sram_sp #(
    parameter ADDR_WIDTH = 8,
    parameter DATA_WIDTH = 32
)(
    input  logic                       clk,
    input  logic                       rst_n,

    // Port A (active)
    input  logic [1:0]                 cmd_a,   // 0:NOP 1:READ 2:WRITE
    input  logic [ADDR_WIDTH-1:0]      addr_a,
    input  logic [DATA_WIDTH-1:0]      wdata_a,
    input  logic [DATA_WIDTH-1:0]      wem_a,   // 0=write, 1=mask
    output logic [DATA_WIDTH-1:0]      rdata_a,

    // Port B (unused — single-port)
    input  logic [1:0]                 cmd_b,
    input  logic [ADDR_WIDTH-1:0]      addr_b,
    input  logic [DATA_WIDTH-1:0]      wdata_b,
    input  logic [DATA_WIDTH-1:0]      wem_b,
    output logic [DATA_WIDTH-1:0]      rdata_b
);

    localparam DEPTH = 1 << ADDR_WIDTH;
    logic [DATA_WIDTH-1:0] mem [0:DEPTH-1];

    // Port B always returns 0 (not used in SP mode)
    assign rdata_b = '0;

    // Port A — Read (latency=1)
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rdata_a <= '0;
        end else if (cmd_a == 2'b01) begin
            rdata_a <= mem[addr_a];
        end
    end

    // Port A — Write
    always_ff @(posedge clk) begin
        if (cmd_a == 2'b10) begin
            for (int i = 0; i < DATA_WIDTH; i++)
                if (!wem_a[i]) mem[addr_a][i] <= wdata_a[i];
        end
    end

endmodule
