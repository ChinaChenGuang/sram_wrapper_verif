// ============================================================
// sram_web - WEB-interface SRAM v2 (replacement)
// ============================================================
// Same WEB-interface, but with ECC + different pipeline.
// ============================================================

`timescale 1ns/1ps

module sram_web #(
    parameter ADDR_WIDTH = 10,
    parameter DATA_WIDTH = 32
)(
    input  logic                       clk,
    input  logic                       rst_n,

    input  logic                       ceb_a,
    input  logic                       web_a,
    input  logic [ADDR_WIDTH-1:0]      addr_a,
    input  logic [DATA_WIDTH-1:0]      data_i_a,
    input  logic [DATA_WIDTH-1:0]      bw_a,
    output logic [DATA_WIDTH-1:0]      data_o_a,

    input  logic                       ceb_b,
    input  logic                       web_b,
    input  logic [ADDR_WIDTH-1:0]      addr_b,
    input  logic [DATA_WIDTH-1:0]      data_i_b,
    input  logic [DATA_WIDTH-1:0]      bw_b,
    output logic [DATA_WIDTH-1:0]      data_o_b
);

    localparam DEPTH = 1 << ADDR_WIDTH;
    logic [DATA_WIDTH-1:0] mem [0:DEPTH-1];
    logic [ADDR_WIDTH-1:0] rd_addr_a, rd_addr_b;

    // Read with address pipeline (different structure)
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rd_addr_a <= '0;
            rd_addr_b <= '0;
            data_o_a  <= '0;
            data_o_b  <= '0;
        end else begin
            rd_addr_a <= addr_a;
            rd_addr_b <= addr_b;
            // ECC check stub
            if (!ceb_a && web_a)   data_o_a <= mem[rd_addr_a];
            if (!ceb_b && web_b)   data_o_b <= mem[rd_addr_b];
        end
    end

    // Write
    always_ff @(posedge clk) begin
        if (!ceb_a && !web_a) begin
            for (int i = 0; i < DATA_WIDTH; i++)
                if (!bw_a[i]) mem[addr_a][i] = data_i_a[i];
        end
        if (!ceb_b && !web_b) begin
            for (int i = 0; i < DATA_WIDTH; i++)
                if (!bw_b[i]) mem[addr_b][i] = data_i_b[i];
        end
    end

endmodule
