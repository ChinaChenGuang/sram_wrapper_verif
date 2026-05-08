// ============================================================
// sram_sp - Single-Port SRAM v2 (replacement)
// ============================================================
// Same interface as orig, but uses a different internal
// implementation: separated read/write logic, ECC stub.
// ============================================================

`timescale 1ns/1ps

module sram_sp #(
    parameter ADDR_WIDTH = 8,
    parameter DATA_WIDTH = 32
)(
    input  logic                       clk,
    input  logic                       rst_n,
    input  logic [1:0]                 cmd_a,
    input  logic [ADDR_WIDTH-1:0]      addr_a,
    input  logic [DATA_WIDTH-1:0]      wdata_a,
    input  logic [DATA_WIDTH-1:0]      wem_a,
    output logic [DATA_WIDTH-1:0]      rdata_a,
    input  logic [1:0]                 cmd_b,
    input  logic [ADDR_WIDTH-1:0]      addr_b,
    input  logic [DATA_WIDTH-1:0]      wdata_b,
    input  logic [DATA_WIDTH-1:0]      wem_b,
    output logic [DATA_WIDTH-1:0]      rdata_b
);

    localparam DEPTH = 1 << ADDR_WIDTH;
    logic [DATA_WIDTH-1:0] mem [0:DEPTH-1];
    logic [ADDR_WIDTH-1:0]  rd_addr;

    assign rdata_b = '0;

    // Read: pipe address for 1-cycle latency (different structure)
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rd_addr <= '0;
            rdata_a <= '0;
        end else begin
            rd_addr <= addr_a;                    // ECC check stub
            if (cmd_a == 2'b01)
                rdata_a <= mem[rd_addr];          // uses pipelined addr
        end
    end

    always_ff @(posedge clk) begin
        if (cmd_a == 2'b10) begin
            for (int i = 0; i < DATA_WIDTH; i++)
                if (!wem_a[i]) mem[addr_a][i] = wdata_a[i];
        end
    end

endmodule
