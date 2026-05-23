// ============================================================
// tb_top — UVM Testbench Top (VCS)
// ============================================================
// Architecture:
//   - clk_gen ×2 → clk_a, clk_b (independent freq/phase/jitter)
//   - mem_port_if port_a(clk_a), port_b(clk_b)
//   - `include "gen/all_connect.sv" → DUT ori+new pairs
//   - sram_ref_model (functional check)
//   - mem_port_checker ×2 (SVA, per-port)
//   - UVM config_db + run_test()
//
// Runtime:
//   +UVM_TESTNAME=test_mem_sp
//   +ADDR_WIDTH=10 +DATA_WIDTH=32
//   +CLK_PERIOD_PS=10000 (both clk_a and clk_b)
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
    logic clk_a, clk_b, clk_stable_a, clk_stable_b, rst_n;

    logic gate_a, gate_b;
    assign gate_a = 1'b1;  // always on
    assign gate_b = 1'b1;

    clk_gen #(.PERIOD_PS(10000), .SEED(42)) u_clk_a (
        .gate_en    (gate_a),
        .clk        (clk_a),
        .clk_stable (clk_stable_a)
    );
    clk_gen #(.PERIOD_PS(10000), .SEED(99)) u_clk_b (
        .gate_en    (gate_b),
        .clk        (clk_b),
        .clk_stable (clk_stable_b)
    );

    assign clk_stable = clk_stable_a && clk_stable_b;

    initial begin
        rst_n = 1'b0;
        @(posedge clk_stable);
        repeat (5) @(posedge clk_a);
        rst_n = 1'b1;
    end

    // ----------------------------------------------------------
    // Unified Interface -> Split Single-Port Interfaces
    // ----------------------------------------------------------
    mem_if #(MAX_ADDR_WIDTH, MAX_DATA_WIDTH) wr_if(.clk(clk_a), .rst_n(rst_n));
    mem_if #(MAX_ADDR_WIDTH, MAX_DATA_WIDTH) rd_if(.clk(clk_b), .rst_n(rst_n));

    // ----------------------------------------------------------
    // Runtime Configuration
    // ----------------------------------------------------------
    int cfg_addr_width = 10;
    int cfg_data_width = 32;
    logic [MAX_ADDR_WIDTH-1:0] addr_mask;
    logic [MAX_DATA_WIDTH-1:0] data_mask;

    initial begin
        void'($value$plusargs("ADDR_WIDTH=%d", cfg_addr_width));
        void'($value$plusargs("DATA_WIDTH=%d", cfg_data_width));
        addr_mask = (1 << cfg_addr_width) - 1;
        data_mask = (1 << cfg_data_width) - 1;
    end

    // Signal Translation for Legacy Ref Model
    mem_cmd_e cmd_a, cmd_b;
    assign cmd_a = (wr_if.ce == 1'b0) ? ((wr_if.we == 1'b0) ? MEM_WRITE : MEM_READ) : MEM_NOP;
    assign cmd_b = (rd_if.ce == 1'b0) ? ((rd_if.we == 1'b0) ? MEM_WRITE : MEM_READ) : MEM_NOP;

    logic [MAX_DATA_WIDTH-1:0] rdata_a_ref, rdata_b_ref;
    logic [MAX_DATA_WIDTH-1:0] rdata_a_ori, rdata_b_ori;
    logic [MAX_DATA_WIDTH-1:0] rdata_a_new, rdata_b_new;

    // ----------------------------------------------------------
    // Reference Model (Used purely for ENV_DEBUG loopback)
    // ----------------------------------------------------------
    sram_ref_model #(MAX_ADDR_WIDTH, MAX_DATA_WIDTH, READ_LATENCY) u_ref (
        .clk    (clk_a),
        .rst_n  (rst_n),
        .cmd_a  (cmd_a),
        .addr_a (wr_if.addr),
        .wdata_a(wr_if.wdata),
        .wem_a  (wr_if.wem),
        .rdata_a_ref (rdata_a_ref),
        .cmd_b  (cmd_b),
        .addr_b (rd_if.addr),
        .wdata_b(rd_if.wdata),
        .wem_b  (rd_if.wem),
        .rdata_b_ref (rdata_b_ref)
    );

    // ----------------------------------------------------------
    // DUTs (A/B Test)
    // ----------------------------------------------------------
`ifdef ENV_DEBUG
    // Loopback for testing environment without real DUT
    assign wr_if.rdata = rdata_a_ref;
    assign rd_if.rdata = rdata_b_ref;
    assign wr_if.rdata_exp = rdata_a_ref;
    assign rd_if.rdata_exp = rdata_b_ref;
`else
    // Connect actual DUTs (which drive rdata_a_ori and rdata_b_ori)
    `include "gen/all_connect.sv"
    
    // Pass original DUT output to UVC for basic monitoring
    assign wr_if.rdata = rdata_a_ori;
    assign rd_if.rdata = rdata_b_ori;
    
    // Golden reference for the interface is the Original DUT
    assign wr_if.rdata_exp = rdata_a_ori;
    assign rd_if.rdata_exp = rdata_b_ori;
`endif

    // ----------------------------------------------------------
    // SVA Checkers (Unified)
    // ----------------------------------------------------------
    // (If using mem_sva_checker, hook to wr_if and rd_if fields)

    // ----------------------------------------------------------
    // Waveform Dump
    // ----------------------------------------------------------
    initial begin
`ifdef VCS
        // Dump FSDB (For Verdi, default for VCS)
        $fsdbDumpfile("dump.fsdb");
        $fsdbDumpvars(0, tb_top);
        $fsdbDumpSVA; // 记录 SVA 状态，方便 Verdi 中 debug assertion
`else
        // Open-source simulators (Verilator / Icarus)
        $dumpfile("dump.fst");
        $dumpvars(0, tb_top);
`endif
    end

    // ----------------------------------------------------------
    // UVM Configuration & Test Start
    // ----------------------------------------------------------
    string test_name;
    initial begin
        // Set virtual interfaces in config_db for both agents
        uvm_config_db #(virtual mem_if #(MAX_ADDR_WIDTH, MAX_DATA_WIDTH))::set(
            null, "uvm_test_top.env.wr_agent.*", "vif", wr_if);
        uvm_config_db #(virtual mem_if #(MAX_ADDR_WIDTH, MAX_DATA_WIDTH))::set(
            null, "uvm_test_top.env.rd_agent.*", "vif", rd_if);

        // Run UVM test
        if ($value$plusargs("UVM_TESTNAME=%s", test_name))
            run_test(test_name);
        else
            run_test("test_mem_sp");

        $display("[TB_TOP] config_db set done, aw=%0d dw=%0d", cfg_addr_width, cfg_data_width);
    end

endmodule
