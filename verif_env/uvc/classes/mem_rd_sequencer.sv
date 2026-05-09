// mem_rd_sequencer
    class mem_rd_sequencer #(int AW=10, int DW=32) extends uvm_sequencer #(mem_rd_item #(AW, DW));
        `uvm_component_param_utils(mem_rd_sequencer #(AW, DW))
        function new(string n, uvm_component p); super.new(n, p); endfunction
    endclass
