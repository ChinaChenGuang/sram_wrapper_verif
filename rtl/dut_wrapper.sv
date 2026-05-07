// ============================================================
// dut_wrapper - Flexible DUT instantiation wrapper
// ============================================================
// Problem: In A/B testing, original and new SRAM may have
//   a) Same module name (e.g. both called "sram_top")  → compile conflict
//   b) Different module names (e.g. "sram_v1" vs "sram_v2")
//   c) Same interface but different internal implementations
//
// Solution: Use compile-time defines to select which DUT
// module to instantiate. The wrapper presents a uniform
// interface to the testbench.
//
// Usage:
//   verilator ... +define+DUT_MODULE=dut_sram
//   verilator ... +define+DUT_MODULE=dut_sram_v2
//
// For A/B test: instantiate TWO wrappers with different defines:
//   dut_wrapper +define+THIS_DUT=dut_sram     → dut_ori
//   dut_wrapper +define+THIS_DUT=dut_sram_v2  → dut_new
//
// When the module names clash: use `ifdef to guard
// compilation and compile only one at a time.
// ============================================================

`timescale 1ns/1ps

module dut_wrapper #(
    parameter int ADDR_WIDTH = 10,
    parameter int DATA_WIDTH = 32
)(
    input  logic                       clk,
    input  logic                       rst_n,

    // Port A
    input  logic [1:0]                 cmd_a,
    input  logic [ADDR_WIDTH-1:0]      addr_a,
    input  logic [DATA_WIDTH-1:0]      wdata_a,
    input  logic [DATA_WIDTH-1:0]      wem_a,
    output logic [DATA_WIDTH-1:0]      rdata_a,

    // Port B
    input  logic [1:0]                 cmd_b,
    input  logic [ADDR_WIDTH-1:0]      addr_b,
    input  logic [DATA_WIDTH-1:0]      wdata_b,
    input  logic [DATA_WIDTH-1:0]      wem_b,
    output logic [DATA_WIDTH-1:0]      rdata_b
);

    // ----------------------------------------------------------
    // DUT selection via compile-time define
    // ----------------------------------------------------------
    // Set +define+THIS_DUT=<module_name> on verilator command line.
    // e.g.: +define+THIS_DUT=dut_sram
    //       +define+THIS_DUT=dut_sram_v2
    //
    // If no define, defaults to dut_sram.
    // ----------------------------------------------------------

`ifdef THIS_DUT
    `THIS_DUT #(
        .ADDR_WIDTH (ADDR_WIDTH),
        .DATA_WIDTH (DATA_WIDTH)
    ) u_dut (
        .clk     (clk),
        .rst_n   (rst_n),
        .cmd_a   (cmd_a),
        .addr_a  (addr_a),
        .wdata_a (wdata_a),
        .wem_a   (wem_a),
        .rdata_a (rdata_a),
        .cmd_b   (cmd_b),
        .addr_b  (addr_b),
        .wdata_b (wdata_b),
        .wem_b   (wem_b),
        .rdata_b (rdata_b)
    );
`else
    dut_sram #(
        .ADDR_WIDTH (ADDR_WIDTH),
        .DATA_WIDTH (DATA_WIDTH)
    ) u_dut (
        .clk     (clk),
        .rst_n   (rst_n),
        .cmd_a   (cmd_a),
        .addr_a  (addr_a),
        .wdata_a (wdata_a),
        .wem_a   (wem_a),
        .rdata_a (rdata_a),
        .cmd_b   (cmd_b),
        .addr_b  (addr_b),
        .wdata_b (wdata_b),
        .wem_b   (wem_b),
        .rdata_b (rdata_b)
    );
`endif

endmodule
