// ============================================================
// sram_web - WEB-interface SRAM (1K×32)
// ============================================================
// Uses common SRAM control signals:
//   ceb  (chip enable, active low): 0=enable, 1=disable
//   web  (write enable, active low): 0=write, 1=read (when ceb=0)
//   data_i / data_o  (separate input/output buses)
//   bw   (byte write mask, active low)
//
// This is the most common SRAM IP interface found in
// foundry memory compilers (TSMC, GF, SMIC, etc.)
// ============================================================

`timescale 1ns/1ps

module sram_web #(
    parameter ADDR_WIDTH = 10,
    parameter DATA_WIDTH = 32
)(
    input  logic                       clk,
    input  logic                       rst_n,

    // Port A — WEB-style control
    input  logic                       ceb_a,       // chip enable (0=active)
    input  logic                       web_a,       // write enable (0=write, 1=read)
    input  logic [ADDR_WIDTH-1:0]      addr_a,
    input  logic [DATA_WIDTH-1:0]      data_i_a,    // write data input
    input  logic [DATA_WIDTH-1:0]      bw_a,        // byte write mask (0=write)
    output logic [DATA_WIDTH-1:0]      data_o_a,    // read data output

    // Port B — WEB-style control
    input  logic                       ceb_b,
    input  logic                       web_b,
    input  logic [ADDR_WIDTH-1:0]      addr_b,
    input  logic [DATA_WIDTH-1:0]      data_i_b,
    input  logic [DATA_WIDTH-1:0]      bw_b,
    output logic [DATA_WIDTH-1:0]      data_o_b
);

    localparam DEPTH = 1 << ADDR_WIDTH;
    logic [DATA_WIDTH-1:0] mem [0:DEPTH-1];

    // Port A
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            data_o_a <= '0;
        end else if (!ceb_a && web_a) begin     // enabled + read
            data_o_a <= mem[addr_a];
        end
    end

    // Port B
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            data_o_b <= '0;
        end else if (!ceb_b && web_b) begin
            data_o_b <= mem[addr_b];
        end
    end

    // Write (both ports)
    always_ff @(posedge clk) begin
        if (!ceb_a && !web_a) begin             // enabled + write
            for (int i = 0; i < DATA_WIDTH; i++)
                if (!bw_a[i]) mem[addr_a][i] = data_i_a[i];
        end
        if (!ceb_b && !web_b) begin
            for (int i = 0; i < DATA_WIDTH; i++)
                if (!bw_b[i]) mem[addr_b][i] = data_i_b[i];
        end
    end

endmodule
