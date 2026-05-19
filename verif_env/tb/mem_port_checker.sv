// ============================================================
// mem_port_checker - Per-Port SVA Assertion Checker
// ============================================================
// Checks one port's outputs:
//   1. A/B comparison: rdata_ori === rdata_new
//   2. Functional correctness: rdata_ori === rdata_ref (optional)
//
// Instantiate one per port. For single-port, only check port_a.
// Mask support: only compare bits within data_mask.
// ============================================================

`timescale 1ns/1ps

module mem_port_checker #(
    parameter DATA_WIDTH   = 32,
    parameter READ_LATENCY = 1,
    parameter CHECK_FUNC   = 1,     // 1=also check against ref model
    parameter PORT_NAME    = "A"    // for error messages
)(
    mem_port_if.monitor vif,

    input logic [DATA_WIDTH-1:0] data_mask   // valid data bits
);

    // A/B comparison: ori === new on read (web=1, ceb=0)
    property p_ab;
        @(posedge vif.clk) disable iff (!vif.rst_n)
        (vif.ceb == 1'b0 && vif.web == 1'b1)
        |=>
        ((vif.rdata_ori & data_mask) === (vif.rdata_new & data_mask));
    endproperty

    assert_ab: assert property(p_ab)
        else $error("[AB-CHECK-%s] Mismatch at current addr=%0h: ori=%h new=%h mask=%h",
                    PORT_NAME, $sampled(vif.addr), vif.rdata_ori, vif.rdata_new, data_mask);

    cover_ab: cover property(p_ab);

    // Functional correctness: ori === ref_model
    if (CHECK_FUNC) begin : gen_func_check
        property p_func;
            @(posedge vif.clk) disable iff (!vif.rst_n)
            (vif.ceb == 1'b0 && vif.web == 1'b1)
            |=>
            ((vif.rdata_ori & data_mask) === (vif.rdata_ref & data_mask));
        endproperty

        assert_func: assert property(p_func)
            else $error("[FUNC-CHECK-%s] DUT!=Ref at current addr=%0h: dut=%h ref=%h mask=%h",
                        PORT_NAME, $sampled(vif.addr), vif.rdata_ori, vif.rdata_ref, data_mask);

        cover_func: cover property(p_func);
    end

endmodule
