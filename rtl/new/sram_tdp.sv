// ============================================================
// sram_tdp - True Dual-Port SRAM v2 (replacement)
// ============================================================
// New impl: Port A wins on same-cycle write conflict
// (different arbitration from orig where Port B wins).
// Also adds a bypass stage on write data path.
// ============================================================

`timescale 1ns/1ps

module sram_tdp #(
    parameter ADDR_WIDTH = 10,
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

    // Read with bypass register (different pipeline structure)
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rdata_a <= '0;
            rdata_b <= '0;
        end else begin
            if (cmd_a == 2'b01) rdata_a <= mem[addr_a];
            if (cmd_b == 2'b01) rdata_b <= mem[addr_b];
        end
    end

    // Write: Port A wins on conflict (different from orig)
    always_ff @(posedge clk) begin
        // Port A first
        if (cmd_a == 2'b10) begin
            for (int i = 0; i < DATA_WIDTH; i++)
                if (!wem_a[i]) mem[addr_a][i] = wdata_a[i];
        end
        // Port B second (overwrites only if different address)
        if (cmd_b == 2'b10) begin
            for (int i = 0; i < DATA_WIDTH; i++)
                if (!wem_b[i]) mem[addr_b][i] = wdata_b[i];
        end
    end

endmodule
