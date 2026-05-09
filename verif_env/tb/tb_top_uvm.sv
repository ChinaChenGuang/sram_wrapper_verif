// ============================================================
// tb_top_uvm — UVM Testbench Top
// ============================================================
// Architecture:
//   - clk_gen_dual → clk_a, clk_b (independent freq/phase)
//   - mem_port_if port_a(clk_a), port_b(clk_b) — decoupled ports
//   - DUT ori + new (A/B comparison)
//   - sram_ref_model (functional check)
//   - mem_port_checker ×2 (SVA, per-port)
//   - uvm_config_db::set for virtual interfaces
//   - run_test()
//
// Runtime:
//   +UVM_TESTNAME=test_mem_sp
//   +ADDR_WIDTH=10 +DATA_WIDTH=32
//   +CLK_A_PS=10000 +CLK_B_PS=10000 +CLK_B_PHASE_PS=0
// ============================================================

`timescale 1ns/1ps

import uvm_pkg::*;
`include "uvm_macros.svh"
import mem_uvc_pkg::*;
import mem_test_pkg::*;

module tb_top;

    localparam MAX_ADDR_WIDTH = 16;
    localparam MAX_DATA_WIDTH = 256;
    localparam READ_LATENCY    = 1;

    // ----------------------------------------------------------
    // Clocks & Reset
    // ----------------------------------------------------------
    logic clk_a, clk_b, clk_stable, rst_n;

    clk_gen_dual u_clk_gen (
        .clk_a      (clk_a),
        .clk_b      (clk_b),
        .clk_stable (clk_stable)
    );

    initial begin
        rst_n = 1'b0;
        @(posedge clk_stable);
        repeat (5) @(posedge clk_a);
        rst_n = 1'b1;
    end

    // ----------------------------------------------------------
    // Decoupled Port Interfaces
    // ----------------------------------------------------------
    mem_port_if #(MAX_ADDR_WIDTH, MAX_DATA_WIDTH) port_a(.clk(clk_a), .rst_n(rst_n));
    mem_port_if #(MAX_ADDR_WIDTH, MAX_DATA_WIDTH) port_b(.clk(clk_b), .rst_n(rst_n));

    // ----------------------------------------------------------
    // Runtime Configuration
    // ----------------------------------------------------------
    int cfg_addr_width = 10;
    int cfg_data_width = 32;
    logic [MAX_ADDR_WIDTH-1:0] addr_mask;
    logic [MAX_DATA_WIDTH-1:0] data_mask;
    logic [MAX_DATA_WIDTH-1:0] wem_mask;

    initial begin
        void'($value$plusargs("ADDR_WIDTH=%d", cfg_addr_width));
        void'($value$plusargs("DATA_WIDTH=%d", cfg_data_width));
        addr_mask = (1 << cfg_addr_width) - 1;
        data_mask = (1 << cfg_data_width) - 1;
        wem_mask  = (1 << cfg_data_width) - 1;
    end

    // ----------------------------------------------------------
    // DUTs (A/B Test)
    // ----------------------------------------------------------
`ifdef DUT_ORI
    `DUT_ORI #(MAX_ADDR_WIDTH, MAX_DATA_WIDTH) dut_ori (
`else
    dut_sram  #(MAX_ADDR_WIDTH, MAX_DATA_WIDTH) dut_ori (
`endif
        .clk    (clk_a),
        .rst_n  (rst_n),
        .cmd_a  (port_a.cmd),
        .addr_a (port_a.addr),
        .wdata_a(port_a.wdata),
        .wem_a  (port_a.wem),
        .rdata_a(port_a.rdata_ori),
        .cmd_b  (port_b.cmd),
        .addr_b (port_b.addr),
        .wdata_b(port_b.wdata),
        .wem_b  (port_b.wem),
        .rdata_b(port_b.rdata_ori)
    );

`ifdef DUT_NEW
    `DUT_NEW #(MAX_ADDR_WIDTH, MAX_DATA_WIDTH) dut_new (
`else
    dut_sram  #(MAX_ADDR_WIDTH, MAX_DATA_WIDTH) dut_new (
`endif
        .clk    (clk_a),
        .rst_n  (rst_n),
        .cmd_a  (port_a.cmd),
        .addr_a (port_a.addr),
        .wdata_a(port_a.wdata),
        .wem_a  (port_a.wem),
        .rdata_a(port_a.rdata_new),
        .cmd_b  (port_b.cmd),
        .addr_b (port_b.addr),
        .wdata_b(port_b.wdata),
        .wem_b  (port_b.wem),
        .rdata_b(port_b.rdata_new)
    );

    // ----------------------------------------------------------
    // Reference Model
    // ----------------------------------------------------------
    sram_ref_model #(MAX_ADDR_WIDTH, MAX_DATA_WIDTH, READ_LATENCY) u_ref (
        .clk    (clk_a),
        .rst_n  (rst_n),
        .cmd_a  (port_a.cmd),
        .addr_a (port_a.addr),
        .wdata_a(port_a.wdata),
        .wem_a  (port_a.wem),
        .rdata_a_ref(port_a.rdata_ref),
        .cmd_b  (port_b.cmd),
        .addr_b (port_b.addr),
        .wdata_b(port_b.wdata),
        .wem_b  (port_b.wem),
        .rdata_b_ref(port_b.rdata_ref)
    );

    // ----------------------------------------------------------
    // SVA Checkers (per-port)
    // ----------------------------------------------------------
    mem_port_checker #(MAX_DATA_WIDTH, READ_LATENCY, 1, "A") checker_a (
        .vif       (port_a.monitor),
        .data_mask (data_mask)
    );

    mem_port_checker #(MAX_DATA_WIDTH, READ_LATENCY, 1, "B") checker_b (
        .vif       (port_b.monitor),
        .data_mask (data_mask)
    );

    // ----------------------------------------------------------
    // Waveform Dump
    // ----------------------------------------------------------
    initial begin
        $dumpfile("dump.fst");
        $dumpvars(0, tb_top);
    end

    // ----------------------------------------------------------
    // UVM Configuration & Test Start
    // ----------------------------------------------------------
    string test_name;
    initial begin
        // Set virtual interfaces in config_db (max-width)
        uvm_config_db #(virtual mem_port_if #(MAX_ADDR_WIDTH, MAX_DATA_WIDTH))::set(
            null, "uvm_test_top.*", "port_a_vif", port_a);
        uvm_config_db #(virtual mem_port_if #(MAX_ADDR_WIDTH, MAX_DATA_WIDTH))::set(
            null, "uvm_test_top.*", "port_b_vif", port_b);

        // Bypass config_db: set global package variables for Verilator
        mem_uvc_pkg::global_wr_vif = port_a;   // port_a = write
        mem_uvc_pkg::global_rd_vif = port_b;   // port_b = read

        // Run UVM test
        if ($value$plusargs("UVM_TESTNAME=%s", test_name))
            run_test(test_name);
        else
            run_test("test_mem_sp");

        // Pass vif via config_db only for now
        $display("[TB_TOP] config_db set done, aw=%0d dw=%0d", cfg_addr_width, cfg_data_width);
    end

endmodule
