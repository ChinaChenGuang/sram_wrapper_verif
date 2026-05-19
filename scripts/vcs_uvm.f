// ============================================================
// vcs_uvm.f — VCS UVM Simulation Filelist
// Usage:
//   vcs -f scripts/vcs_uvm.f -l vcs_compile.log
//   ./simv +UVM_TESTNAME=test_mem_sp +ADDR_WIDTH=10 +DATA_WIDTH=32
// ============================================================
// -----------------------------------------------------------
// UVM 1800.2 library
// -----------------------------------------------------------
// UVM_HOME is expected to be set via +define+UVM_HOME="..."
// or use the default path below:
// /home/chen/proj/UVM/UVM-1800.2-2020.3.1/1800.2-2020.3.1/src/uvm_pkg.sv
// -----------------------------------------------------------
// UVM compile-time defines (VCS-optimized)
// -----------------------------------------------------------
+define+UVM_NO_DPI          // Use native VCS DPI
+define+UVM_OBJECT_MUST_HAVE_CONSTRUCTOR
+define+UVM_ENABLE_AUTO_ITEM_RECORDING
+define+VCS                 // Enable VCS-specific code paths
// -----------------------------------------------------------
// Timescale
// -----------------------------------------------------------
-timescale=1ns/1ps
// -----------------------------------------------------------
// Debug & Coverage
// -----------------------------------------------------------
+define+DEBUG
+define+WAVE_DUMP
+incdir+./verif_env/tb
+incdir+./verif_env/uvc
+incdir+./verif_env/uvc/classes
+incdir+./verif_env/tests
+incdir+./verif_env/tests/classes
// -----------------------------------------------------------
// UVM 1800.2 Source
// -----------------------------------------------------------
// Uncomment and set UVM_HOME to your UVM installation path:
// -y /home/chen/proj/UVM/UVM-1800.2-2020.3.1/1800.2-2020.3.1/src
// +libext+.sv+.svh+.v
// -----------------------------------------------------------
// Common RTL Sources
// -----------------------------------------------------------
./verif_env/tb/clk_gen.sv
./rtl/sram_ref_model.sv
./rtl/sram_cfg_pkg.sv
./rtl/sram_proto_adapter.sv
./rtl/dut_sram.sv
./rtl/dut_sram_v2.sv
./rtl/dut_wrapper.sv
// -----------------------------------------------------------
// SRAM Instances (orig + new)
// -----------------------------------------------------------
./rtl/orig/sram_sp.sv
./rtl/orig/sram_sdp.sv
./rtl/orig/sram_tdp.sv
./rtl/orig/sram_bank4.sv
./rtl/orig/sram_bitwrite.sv
./rtl/orig/sram_web.sv
./rtl/new/sram_sp.sv
./rtl/new/sram_sdp.sv
./rtl/new/sram_tdp.sv
./rtl/new/sram_bank4.sv
./rtl/new/sram_bitwrite.sv
./rtl/new/sram_web.sv
// -----------------------------------------------------------
// Verification Environment
// -----------------------------------------------------------
./verif_env/tb/mem_port_if.sv
./verif_env/tb/mem_port_checker.sv
./verif_env/tb/mem_if.sv
./verif_env/tb/mem_if_dualclk.sv
// -----------------------------------------------------------
// UVM Testbench Architecture Files
// -----------------------------------------------------------
// Pick ONE testbench top:
./verif_env/tb/tb_top.sv
// -----------------------------------------------------------
// UVM Verification Components
// -----------------------------------------------------------
./verif_env/uvc/mem_uvc_pkg.sv
// -----------------------------------------------------------
// UVM Test Sequences & Tests
// -----------------------------------------------------------
./verif_env/tests/mem_test_pkg.sv
