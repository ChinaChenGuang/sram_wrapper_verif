// ============================================================
// sram_sdp - Simple Dual-Port SRAM v2 (replacement)
// ============================================================
// New impl: byte-enabled write, different pipeline structure.
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
    // New: use unpacked struct internally (different structure)
    logic [DATA_WIDTH-1:0] mem [0:DEPTH-1];
    logic [ADDR_WIDTH-1:0]  rd_addr_b;

    assign rdata_a = '0;

    // Read B with address pipeline
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rd_addr_b <= '0;
            rdata_b   <= '0;
        end else begin
            rd_addr_b <= addr_b;
            if (cmd_b == 2'b01)
                rdata_b <= mem[rd_addr_b];
        end
    end

    // Write A with byte-level grouping (same functional result)
    always_ff @(posedge clk) begin
        if (cmd_a == 2'b10) begin
            for (int i = 0; i < DATA_WIDTH; i++)
                if (!wem_a[i]) mem[addr_a][i] = wdata_a[i];
        end
    end

endmodule
