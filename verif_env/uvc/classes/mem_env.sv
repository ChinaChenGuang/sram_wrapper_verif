// mem_env
    class mem_env #(int AW=10, int DW=32) extends uvm_env;
        `uvm_component_param_utils(mem_env #(AW, DW))
        mem_wr_agent #(AW, DW) wr_agent;
        mem_rd_agent #(AW, DW) rd_agent;
        int cfg_depth;

        function new(string n, uvm_component p); super.new(n, p); endfunction
        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            wr_agent = mem_wr_agent #(AW, DW)::type_id::create("wr_agent", this);
            rd_agent = mem_rd_agent #(AW, DW)::type_id::create("rd_agent", this);
            cfg_depth = 1 << AW;
        endfunction
    endclass
