// ============================================================
// dut_sram_v2 - "New" version SRAM with different module name
// ============================================================
// Same interface as dut_sram, but different module name.
// Demonstrates A/B test scenario where original and new are
// different modules (potentially from different vendors/IP).
//
// In a real project, this could be a completely different
// implementation (e.g. with ECC, different read latency, etc.)
// ============================================================

`timescale 1ns/1ps

module dut_sram_v2 #(
    parameter ADDR_WIDTH = 10,
    parameter DATA_WIDTH = 32
)(
    input  logic clk,
    input  logic rst_n,

    // Port A
    input  logic [1:0]               cmd_a,
    input  logic [ADDR_WIDTH-1:0]    addr_a,
    input  logic [DATA_WIDTH-1:0]    wdata_a,
    input  logic [DATA_WIDTH-1:0]    wem_a,
    output logic [DATA_WIDTH-1:0]    rdata_a,

    // Port B
    input  logic [1:0]               cmd_b,
    input  logic [ADDR_WIDTH-1:0]    addr_b,
    input  logic [DATA_WIDTH-1:0]    wdata_b,
    input  logic [DATA_WIDTH-1:0]    wem_b,
    output logic [DATA_WIDTH-1:0]    rdata_b
);

    localparam DEPTH = 1 << ADDR_WIDTH;
    logic [DATA_WIDTH-1:0] mem [0:DEPTH-1];

    // READ LATENCY = 1 (same as dut_sram)
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rdata_a <= '0;
            rdata_b <= '0;
        end else begin
            if (cmd_a == 2'b01) rdata_a <= mem[addr_a];
            if (cmd_b == 2'b01) rdata_b <= mem[addr_b];
        end
    end

    // WRITE (V2: slightly different implementation for demo)
    always_ff @(posedge clk) begin
        if (cmd_a == 2'b10) begin
            for (int i = 0; i < DATA_WIDTH; i++) begin
                if (wem_a[i] == 1'b0) mem[addr_a][i] = wdata_a[i];
            end
        end
        if (cmd_b == 2'b10) begin
            for (int i = 0; i < DATA_WIDTH; i++) begin
                if (wem_b[i] == 1'b0) mem[addr_b][i] = wdata_b[i];
            end
        end
    end

endmodule
