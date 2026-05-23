// ============================================================
// mem_uvc_pkg — SRAM UVC Package (Unified)
// ============================================================
// Single transaction/driver/sequencer/agent.
// Distinguish write vs read via port_type_e parameter at
// instantiation time (PORT_WRITE / PORT_READ).
// ============================================================

`ifndef MEM_UVC_PKG_SV
`define MEM_UVC_PKG_SV

package mem_uvc_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"

    // -------------------------------------------------------
    // Types
    // -------------------------------------------------------
    typedef enum logic [1:0] {
        MEM_NOP   = 2'b00,
        MEM_READ  = 2'b01,
        MEM_WRITE = 2'b10
    } mem_cmd_e;

    typedef enum {
        SRAM_SP,
        SRAM_SDP,
        SRAM_TDP
    } sram_type_e;

    // -------------------------------------------------------
    // Unified classes (write + read merged)
    // -------------------------------------------------------
    `include "mem_item.sv"
    `include "mem_driver.sv"
    `include "mem_sequencer.sv"
    `include "mem_agent.sv"
    `include "mem_env.sv"

endpackage : mem_uvc_pkg

`endif
