// mem_base_test
    class mem_base_test #(int AW=10, int DW=32) extends uvm_test;
        `uvm_component_param_utils(mem_base_test #(AW, DW))
        mem_env #(AW, DW) env;
        function new(string n, uvm_component p); super.new(n, p); endfunction
        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            env = mem_env #(AW, DW)::type_id::create("env", this);
        endfunction
    endclass
