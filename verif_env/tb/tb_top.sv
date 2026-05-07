`timescale 1ns/1ps

import uvm_pkg::*;
`include "uvm_macros.svh"
import mem_test_pkg::*;

module tb_top;

    parameter ADDR_WIDTH = 10;
    parameter DATA_WIDTH = 32;

    logic clk;
    logic rst_n;

    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // Reset generation
    initial begin
        rst_n = 0;
        #20 rst_n = 1;
    end

    mem_if #(ADDR_WIDTH, DATA_WIDTH) vif(clk, rst_n);

    // DUT ORI
    dut_sram #(ADDR_WIDTH, DATA_WIDTH) dut_ori (
        .clk    (clk),
        .rst_n  (rst_n),
        .cmd_a  (vif.cmd_a),
        .addr_a (vif.addr_a),
        .wdata_a(vif.wdata_a),
        .wem_a  (vif.wem_a),
        .rdata_a(vif.rdata_a_ori),
        .cmd_b  (vif.cmd_b),
        .addr_b (vif.addr_b),
        .wdata_b(vif.wdata_b),
        .wem_b  (vif.wem_b),
        .rdata_b(vif.rdata_b_ori)
    );

    // DUT NEW
    dut_sram #(ADDR_WIDTH, DATA_WIDTH) dut_new (
        .clk    (clk),
        .rst_n  (rst_n),
        .cmd_a  (vif.cmd_a),
        .addr_a (vif.addr_a),
        .wdata_a(vif.wdata_a),
        .wem_a  (vif.wem_a),
        .rdata_a(vif.rdata_a_new),
        .cmd_b  (vif.cmd_b),
        .addr_b (vif.addr_b),
        .wdata_b(vif.wdata_b),
        .wem_b  (vif.wem_b),
        .rdata_b(vif.rdata_b_new)
    );

    // SVA Checker
    mem_sva_checker #(ADDR_WIDTH, DATA_WIDTH, 1) checker_inst(vif);

    initial begin
        uvm_config_db#(virtual mem_if#(ADDR_WIDTH, DATA_WIDTH))::set(null, "uvm_test_top.env.agent.driver", "vif", vif);
        run_test();
    end

    // Waveform dump for open-source simulators
    initial begin
        $dumpfile("dump.fst");
        $dumpvars(0, tb_top);
    end

endmodule

