// ============================================================
// sram_ref_model - Golden Reference Model
// ============================================================
// Implements ideal SRAM behavior matching DUT timing exactly.
//
// READ_LATENCY=1:  read data appears 1 cycle after read command.
// Uses same always_ff structure as dut_sram for cycle-accuracy.
// ============================================================

`timescale 1ns/1ps

module sram_ref_model #(
    parameter ADDR_WIDTH   = 10,
    parameter DATA_WIDTH   = 32,
    parameter READ_LATENCY = 1,
    parameter SRAM_MODE    = 2    // 0=SP, 1=SDP, 2=TDP/WEB/BITWRITE/BANK4
)(
    input  logic                       clk,
    input  logic                       rst_n,

    input  logic [1:0]                 cmd_a,
    input  logic [ADDR_WIDTH-1:0]      addr_a,
    input  logic [DATA_WIDTH-1:0]      wdata_a,
    input  logic [DATA_WIDTH-1:0]      wem_a,
    output logic [DATA_WIDTH-1:0]      rdata_a_ref,

    input  logic [1:0]                 cmd_b,
    input  logic [ADDR_WIDTH-1:0]      addr_b,
    input  logic [DATA_WIDTH-1:0]      wdata_b,
    input  logic [DATA_WIDTH-1:0]      wem_b,
    output logic [DATA_WIDTH-1:0]      rdata_b_ref
);

    localparam DEPTH = 1 << ADDR_WIDTH;
    logic [DATA_WIDTH-1:0] mem [0:DEPTH-1];

    // ----------------------------------------------------------
    // READ (matches DUT: rdata <= mem[addr] with 1-cycle latency)
    // ----------------------------------------------------------
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rdata_a_ref <= '0;
            rdata_b_ref <= '0;
        end else begin
            // Port A: always active
            if (cmd_a == 2'b01) rdata_a_ref <= mem[addr_a];

            // Port B:
            //   SP (mode=0): returns 0 (no Port B)
            //   SDP (mode=1): read-only Port B
            //   TDP/WEB (mode=2): fully active
            if (SRAM_MODE == 0)
                rdata_b_ref <= '0;
            else if (cmd_b == 2'b01)
                rdata_b_ref <= mem[addr_b];
        end
    end

    // ----------------------------------------------------------
    // WRITE (matches DUT: wem masking, blocking = for Verilator)
    // ----------------------------------------------------------
    always_ff @(posedge clk) begin
        // Port A: always active for write
        if (cmd_a == 2'b10) begin
            for (int i = 0; i < DATA_WIDTH; i++) begin
                if (wem_a[i] == 1'b0) mem[addr_a][i] = wdata_a[i];
            end
        end

        // Port B:
        //   SP (mode=0): no writes
        //   SDP (mode=1): read-only, no writes
        //   TDP/WEB (mode=2): fully active
        if (SRAM_MODE >= 2) begin
            if (cmd_b == 2'b10) begin
                for (int i = 0; i < DATA_WIDTH; i++) begin
                    if (wem_b[i] == 1'b0) mem[addr_b][i] = wdata_b[i];
                end
            end
        end
    end

endmodule
