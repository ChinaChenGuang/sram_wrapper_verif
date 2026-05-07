`timescale 1ns/1ps

interface mem_if #(
    parameter ADDR_WIDTH = 10,
    parameter DATA_WIDTH = 32
)(
    input logic clk,
    input logic rst_n
);
    logic [1:0] cmd_a;
    logic [ADDR_WIDTH-1:0] addr_a;
    logic [DATA_WIDTH-1:0] wdata_a;
    logic [DATA_WIDTH-1:0] wem_a;
    logic [DATA_WIDTH-1:0] rdata_a_ori;
    logic [DATA_WIDTH-1:0] rdata_a_new;

    logic [1:0] cmd_b;
    logic [ADDR_WIDTH-1:0] addr_b;
    logic [DATA_WIDTH-1:0] wdata_b;
    logic [DATA_WIDTH-1:0] wem_b;
    logic [DATA_WIDTH-1:0] rdata_b_ori;
    logic [DATA_WIDTH-1:0] rdata_b_new;

    // Driver modport or clocking blocks can be added here if needed,
    // but standard UVM environments can directly drive interface signals using virtual interface.
endinterface

