// ============================================================
// mem_port_if — SRAM Port Interface
// ============================================================
// 1P: 例化一个 port_a, 连接 clk, rst_n(如果有)
// 2P: 例化两个 port_a (write) + port_b (read)
//
// ceb: 0=芯片使能, 1=禁用
// web: 0=写, 1=读
// wem: 0=写该位, 1=屏蔽
// ============================================================

`timescale 1ns/1ps

interface mem_port_if #(
    parameter ADDR_WIDTH = 10,
    parameter DATA_WIDTH = 32
)(
    input logic clk,
    input logic rst_n
);
    logic                       ceb;
    logic                       web;

    // Derived cmd for DUT connection
    logic [1:0] cmd;
    assign cmd = (!ceb && !web) ? 2'b10 : (!ceb && web) ? 2'b01 : 2'b00;

    logic [ADDR_WIDTH-1:0]      addr;
    logic [DATA_WIDTH-1:0]      wdata;
    logic [DATA_WIDTH-1:0]      wem;
    logic [DATA_WIDTH-1:0]      rdata_ori;
    logic [DATA_WIDTH-1:0]      rdata_new;
    logic [DATA_WIDTH-1:0]      rdata_ref;

    modport driver (
        input  clk, rst_n,
        output ceb, web, addr, wdata, wem,
        input  rdata_ori, rdata_new, rdata_ref
    );

    modport dut (
        input  clk, rst_n,
        input  ceb, web, addr, wdata, wem,
        output rdata_ori
    );

    modport monitor (
        input  clk, rst_n,
        input  ceb, web, addr, wdata, wem,
        input  rdata_ori, rdata_new, rdata_ref
    );

endinterface
