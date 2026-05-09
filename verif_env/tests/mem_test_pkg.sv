// ============================================================
// mem_test_pkg — SRAM Test Package v2 (Read/Write Split)
// ============================================================
`ifndef MEM_TEST_PKG_SV
`define MEM_TEST_PKG_SV

package mem_test_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import mem_uvc_pkg::*;

    `include "mem_base_seq.sv"
    `include "mem_sp_seq.sv"
    `include "mem_sdp_seq.sv"
    `include "mem_rd_only_seq.sv"
    `include "mem_tdp_wr_seq.sv"
    `include "mem_tdp_rd_seq.sv"
    `include "mem_wem_seq.sv"
    `include "mem_b2b_seq.sv"
    `include "mem_fill_seq.sv"
    `include "mem_base_test.sv"

endpackage : mem_test_pkg

// Global scope concrete tests
import mem_test_pkg::*;

`include "test_mem_sp.sv"
`include "test_mem_sdp.sv"
`include "test_mem_tdp.sv"
`include "test_mem_wem.sv"
`include "test_mem_b2b.sv"
`include "test_mem_fill.sv"

`endif
