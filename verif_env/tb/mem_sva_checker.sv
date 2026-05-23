// ============================================================
// mem_sva_checker - Unified SVA Assertion Checker
// ============================================================
// Performs Cycle-Accurate comparison between Golden (ORI) and 
// DUT (NEW) designs.
// ============================================================

`timescale 1ns/1ps

module mem_sva_checker #(
    parameter DATA_WIDTH   = 32,
    parameter READ_LATENCY = 1,
    parameter PORT_NAME    = "A"
)(
    input logic clk,
    input logic rst_n,
    input logic [1:0] cmd,
    input logic [DATA_WIDTH-1:0] rdata_ori,
    input logic [DATA_WIDTH-1:0] rdata_new,
    input logic [DATA_WIDTH-1:0] data_mask
);

    localparam MEM_READ = 2'b01;

    // A/B comparison: rdata_ori === rdata_new
    property p_ab_compare;
        @(posedge clk) disable iff (!rst_n)
        (cmd == MEM_READ)
        |-> ##READ_LATENCY
        ((rdata_ori & data_mask) === (rdata_new & data_mask));
    endproperty

    assert_ab: assert property(p_ab_compare)
        else $error("[SVA-ERROR-%s] Mismatch: ORI=%h, NEW=%h, MASK=%h", 
                    PORT_NAME, rdata_ori, rdata_new, data_mask);

    cover_ab: cover property(p_ab_compare);

endmodule
