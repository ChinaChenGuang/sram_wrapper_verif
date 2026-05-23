`timescale 1ns/1ps

interface mem_if #(
    parameter ADDR_WIDTH = 10,
    parameter DATA_WIDTH = 32
)(
    input logic clk,
    input logic rst_n
);
    logic          ce;
    logic          we;
    logic [ADDR_WIDTH-1:0] addr;
    logic [DATA_WIDTH-1:0] wdata;
    logic [DATA_WIDTH-1:0] wem;
    logic [DATA_WIDTH-1:0] rdata;
    logic [DATA_WIDTH-1:0] rdata_exp;

endinterface
