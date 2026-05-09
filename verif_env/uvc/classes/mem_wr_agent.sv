// mem_wr_agent
    class mem_wr_agent #(int AW=10, int DW=32) extends uvm_agent;
        `uvm_component_param_utils(mem_wr_agent #(AW, DW))
        mem_wr_driver    #(AW, DW) drv;
        mem_wr_sequencer #(AW, DW) sqr;
        function new(string n, uvm_component p); super.new(n, p); endfunction
        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            drv = mem_wr_driver    #(AW, DW)::type_id::create("drv", this);
            sqr = mem_wr_sequencer #(AW, DW)::type_id::create("sqr", this);
        endfunction
        function void connect_phase(uvm_phase phase);
            super.connect_phase(phase);
            drv.seq_item_port.connect(sqr.seq_item_export);
        endfunction
    endclass
