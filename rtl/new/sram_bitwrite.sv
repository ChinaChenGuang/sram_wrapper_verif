// ============================================================
// sram_bitwrite - TDP SRAM v2 (replacement) with byte-grouped mask
// ============================================================
// Same interface but uses byte-level grouping internally.
// Wem is applied at byte granularity first, then at bit level.
// ============================================================

`timescale 1ns/1ps

module sram_bitwrite #(
    parameter ADDR_WIDTH = 11,
    parameter DATA_WIDTH = 16
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

    localparam DEPTH  = 1 << ADDR_WIDTH;
    localparam BYTES  = DATA_WIDTH / 8;  // 2 bytes for DW=16
    logic [DATA_WIDTH-1:0] mem [0:DEPTH-1];

    // Read
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rdata_a <= '0;
            rdata_b <= '0;
        end else begin
            if (cmd_a == 2'b01) rdata_a <= mem[addr_a];
            if (cmd_b == 2'b01) rdata_b <= mem[addr_b];
        end
    end

    // Write — byte-group then bit-level (same functional result)
    always_ff @(posedge clk) begin
        if (cmd_a == 2'b10) begin
            for (int b = 0; b < BYTES; b++) begin
                // Check if entire byte is masked
                logic byte_masked;
                byte_masked = 1'b1;
                for (int i = 0; i < 8; i++)
                    if (!wem_a[b*8 + i]) byte_masked = 1'b0;
                if (!byte_masked) begin
                    for (int i = 0; i < 8; i++)
                        if (!wem_a[b*8 + i])
                            mem[addr_a][b*8 + i] <= wdata_a[b*8 + i];
                end
            end
        end
        if (cmd_b == 2'b10) begin
            for (int b = 0; b < BYTES; b++) begin
                logic byte_masked;
                byte_masked = 1'b1;
                for (int i = 0; i < 8; i++)
                    if (!wem_b[b*8 + i]) byte_masked = 1'b0;
                if (!byte_masked) begin
                    for (int i = 0; i < 8; i++)
                        if (!wem_b[b*8 + i])
                            mem[addr_b][b*8 + i] <= wdata_b[b*8 + i];
                end
            end
        end
    end

endmodule
