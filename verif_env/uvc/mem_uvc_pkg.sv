// ============================================================
// mem_uvc_pkg — SRAM UVC Package v2 (Read/Write Split)
// ============================================================
`ifndef MEM_UVC_PKG_SV
`define MEM_UVC_PKG_SV

package mem_uvc_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"

    typedef enum logic [1:0] {
        MEM_NOP   = 2'b00,
        MEM_READ  = 2'b01,
        MEM_WRITE = 2'b10
    } mem_cmd_e;

    // Global vif (bypasses config_db for Verilator)
    virtual mem_port_if #(16, 256) global_wr_vif;
    virtual mem_port_if #(16, 256) global_rd_vif;

    `include "mem_wr_item.sv"
    `include "mem_rd_item.sv"
    `include "mem_wr_driver.sv"
    `include "mem_rd_driver.sv"
    `include "mem_wr_sequencer.sv"
    `include "mem_rd_sequencer.sv"
    `include "mem_wr_agent.sv"
    `include "mem_rd_agent.sv"
    `include "mem_env.sv"

endpackage : mem_uvc_pkg

`endif
