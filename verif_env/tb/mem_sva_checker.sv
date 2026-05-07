`timescale 1ns/1ps

module mem_sva_checker #(
    parameter ADDR_WIDTH = 10,
    parameter DATA_WIDTH = 32,
    parameter READ_LATENCY = 1
)(
    mem_if vif
);
    // Check if rdata_ori === rdata_new after a read
    property p_rdata_a_match;
        @(posedge vif.clk) disable iff (!vif.rst_n)
        (vif.cmd_a == 2'b01) |=> (vif.rdata_a_ori === vif.rdata_a_new);
    endproperty

    property p_rdata_b_match;
        @(posedge vif.clk) disable iff (!vif.rst_n)
        (vif.cmd_b == 2'b01) |=> (vif.rdata_b_ori === vif.rdata_b_new);
    endproperty

    assert_rdata_a_match: assert property(p_rdata_a_match) 
        else $error("SVA ERROR: Port A read data mismatch! ori=%h, new=%h", vif.rdata_a_ori, vif.rdata_a_new);
        
    assert_rdata_b_match: assert property(p_rdata_b_match) 
        else $error("SVA ERROR: Port B read data mismatch! ori=%h, new=%h", vif.rdata_b_ori, vif.rdata_b_new);
        
endmodule

