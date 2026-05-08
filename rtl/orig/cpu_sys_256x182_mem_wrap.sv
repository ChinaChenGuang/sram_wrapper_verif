// ============================================================
// cpu_sys_256x182_mem_wrap - Original (Vendor A)
// ============================================================
// 256-depth x 182-bit system SRAM for CPU
// ADDR_WIDTH = 8, DATA_WIDTH = 182
// Vendor A implementation: standard double-port register file
// ============================================================

`timescale 1ns/1ps

module cpu_sys_256x182_mem_wrap #(
    parameter ADDR_WIDTH = 8,
    parameter DATA_WIDTH = 182
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

    // Port A - Read latency = 1
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rdata_a <= '0;
        end else begin
            if (cmd_a == 2'b01)  // READ
                rdata_a <= mem[addr_a];
        end
    end

    // Port A - Write
    always_ff @(posedge clk) begin
        if (cmd_a == 2'b10) begin  // WRITE
            for (int i = 0; i < DATA_WIDTH; i++) begin
                if (!wem_a[i])  // Active low: 0=write
                    mem[addr_a][i] = wdata_a[i];
            end
        end
    end

    // Port B - Read latency = 1
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rdata_b <= '0;
        end else begin
            if (cmd_b == 2'b01)
                rdata_b <= mem[addr_b];
        end
    end

    // Port B - Write
    always_ff @(posedge clk) begin
        if (cmd_b == 2'b10) begin
            for (int i = 0; i < DATA_WIDTH; i++) begin
                if (!wem_b[i])
                    mem[addr_b][i] = wdata_b[i];
            end
        end
    end

endmodule
