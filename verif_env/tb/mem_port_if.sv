// ============================================================
// mem_port_if - Single SRAM Port Interface
// ============================================================
// Encapsulates one SRAM port's signals.
// For dual-port SRAMs, instantiate TWO of these.
// For single-port SRAMs, instantiate only port_a.
//
// Each port has its own clock domain (clk).
// ============================================================

`timescale 1ns/1ps

interface mem_port_if #(
    parameter ADDR_WIDTH = 10,
    parameter DATA_WIDTH = 32
)(
    input logic clk,
    input logic rst_n
);
    // Control
    logic [1:0]               cmd;       // 0=NOP 1=READ 2=WRITE
    logic [ADDR_WIDTH-1:0]    addr;
    logic [DATA_WIDTH-1:0]    wdata;
    logic [DATA_WIDTH-1:0]    wem;       // 0=write, 1=mask

    // A/B comparison outputs
    logic [DATA_WIDTH-1:0]    rdata_ori;
    logic [DATA_WIDTH-1:0]    rdata_new;

    // Reference model output (optional, for feature checking)
    logic [DATA_WIDTH-1:0]    rdata_ref;

    // Modport for driver (drives control, samples rdata)
    modport driver (
        input  clk, rst_n,
        output cmd, addr, wdata, wem,
        input  rdata_ori, rdata_new, rdata_ref
    );

    // Modport for DUT (receives control, drives rdata)
    modport dut (
        input  clk, rst_n,
        input  cmd, addr, wdata, wem,
        output rdata_ori
    );

    // Modport for monitor (monitors all)
    modport monitor (
        input  clk, rst_n,
        input  cmd, addr, wdata, wem,
        input  rdata_ori, rdata_new, rdata_ref
    );

endinterface
