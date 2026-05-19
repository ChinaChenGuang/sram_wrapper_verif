// ============================================================
// mem_base_test — Base UVM Test
// ============================================================

class mem_base_test #(int AW=10, int DW=32, int MAX_AW=16, int MAX_DW=256) extends uvm_test;
    `uvm_component_param_utils(mem_base_test #(AW, DW, MAX_AW, MAX_DW));
    mem_env #(AW, DW, MAX_AW, MAX_DW) env;
    function new(string n, uvm_component p); super.new(n, p); endfunction
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        env = mem_env #(AW, DW, MAX_AW, MAX_DW)::type_id::create("env", this);
    endfunction
endclass
