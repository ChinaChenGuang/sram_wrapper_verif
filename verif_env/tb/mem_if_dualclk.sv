// ============================================================
// mem_if_dualclk - Dual-Clock SRAM Interface
// ============================================================
// Port A signals are synchronous to clk_a.
// Port B signals are synchronous to clk_b.
// Both share a common async reset (rst_n).
// ============================================================

`timescale 1ns/1ps

interface mem_if_dualclk #(
    parameter ADDR_WIDTH = 10,
    parameter DATA_WIDTH = 32
)(
    input logic clk_a,
    input logic clk_b,
    input logic rst_n
);
    // Port A (clk_a domain)
    logic [1:0]               cmd_a;
    logic [ADDR_WIDTH-1:0]    addr_a;
    logic [DATA_WIDTH-1:0]    wdata_a;
    logic [DATA_WIDTH-1:0]    wem_a;
    logic [DATA_WIDTH-1:0]    rdata_a_ori;
    logic [DATA_WIDTH-1:0]    rdata_a_new;

    // Port B (clk_b domain)
    logic [1:0]               cmd_b;
    logic [ADDR_WIDTH-1:0]    addr_b;
    logic [DATA_WIDTH-1:0]    wdata_b;
    logic [DATA_WIDTH-1:0]    wem_b;
    logic [DATA_WIDTH-1:0]    rdata_b_ori;
    logic [DATA_WIDTH-1:0]    rdata_b_new;

endinterface
