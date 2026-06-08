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
    input logic [DATA_WIDTH-1:0] rdata_emu,
    input logic has_emu,
    input logic [DATA_WIDTH-1:0] data_mask
);

    localparam MEM_READ = 2'b01;

    import uvm_pkg::*;
    `include "uvm_macros.svh"

    // A/B comparison: rdata_ori === rdata_new
    property p_ab_compare;
        @(posedge clk) disable iff (!rst_n)
        (cmd == MEM_READ)
        |-> ##READ_LATENCY
        (((rdata_ori & data_mask) === (rdata_new & data_mask)) &&
        !$isunknown(rdata_ori & data_mask) &&
        !$isunknown(rdata_new & data_mask)) until (cmd != MEM_READ);
    endproperty

    assert_ab: assert property(p_ab_compare)
        else `uvm_error($sformatf("SVA-ERROR-%s", PORT_NAME), 
                        $sformatf("Mismatch or X-state: ORI=%h, NEW=%h, MASK=%h", rdata_ori, rdata_new, data_mask));
    // Disable cover for now to avoid "not finished" prints at the end of sim
    cover_ab: cover property(p_ab_compare);
    // EMU comparison: rdata_new === rdata_emu
    property p_emu_compare;
        @(posedge clk) disable iff (!rst_n || !has_emu)
        (cmd == MEM_READ)
        |-> ##READ_LATENCY
        (((rdata_new & data_mask) === (rdata_emu & data_mask)) &&
        !$isunknown(rdata_new & data_mask) &&
        !$isunknown(rdata_emu & data_mask)) until (cmd != MEM_READ);
    endproperty

    assert_emu: assert property(p_emu_compare)
        else `uvm_error($sformatf("SVA-ERROR-%s-EMU", PORT_NAME), 
                        $sformatf("EMU Mismatch or X-state: NEW=%h, EMU=%h, MASK=%h", rdata_new, rdata_emu, data_mask));
    cover_emu: cover property(p_emu_compare);

endmodule
