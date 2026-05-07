`timescale 1ns/1ps

module dut_sram #(
    parameter ADDR_WIDTH = 10,
    parameter DATA_WIDTH = 32
)(
    input  logic clk,
    input  logic rst_n,

    // Port A
    input  logic [1:0] cmd_a, // 0: NOP, 1: READ, 2: WRITE
    input  logic [ADDR_WIDTH-1:0] addr_a,
    input  logic [DATA_WIDTH-1:0] wdata_a,
    input  logic [DATA_WIDTH-1:0] wem_a, // Active low: 0 means write, 1 means mask
    output logic [DATA_WIDTH-1:0] rdata_a,

    // Port B
    input  logic [1:0] cmd_b,
    input  logic [ADDR_WIDTH-1:0] addr_b,
    input  logic [DATA_WIDTH-1:0] wdata_b,
    input  logic [DATA_WIDTH-1:0] wem_b,
    output logic [DATA_WIDTH-1:0] rdata_b
);

    localparam DEPTH = 1 << ADDR_WIDTH;
    logic [DATA_WIDTH-1:0] mem [0:DEPTH-1];

    // READ LATENCY = 1
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rdata_a <= '0;
            rdata_b <= '0;
        end else begin
            if (cmd_a == 2'b01) rdata_a <= mem[addr_a];
            if (cmd_b == 2'b01) rdata_b <= mem[addr_b];
        end
    end

    // WRITE (use blocking = for Verilator BLKLOOPINIT compatibility)
    always_ff @(posedge clk) begin
        if (cmd_a == 2'b10) begin
            for (int i = 0; i < DATA_WIDTH; i++) begin
                if (wem_a[i] == 1'b0) mem[addr_a][i] = wdata_a[i];
            end
        end
        if (cmd_b == 2'b10) begin
            for (int i = 0; i < DATA_WIDTH; i++) begin
                if (wem_b[i] == 1'b0) mem[addr_b][i] = wdata_b[i];
            end
        end
    end

endmodule

