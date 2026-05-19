// ============================================================
// mem_sequencer — Unified SRAM Sequencer
// ============================================================

class mem_sequencer #(int AW=10, int DW=32) extends uvm_sequencer #(mem_item #(AW, DW));
    `uvm_component_param_utils(mem_sequencer #(AW, DW));
    function new(string n, uvm_component p); super.new(n, p); endfunction
endclass
