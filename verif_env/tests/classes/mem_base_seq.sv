// mem_base_seq
    class mem_base_seq #(int AW=10, int DW=32) extends uvm_sequence #(uvm_sequence_item);
        `uvm_object_param_utils(mem_base_seq #(AW, DW))
        int num_tx = 200;
        int depth = 1 << AW;
        mem_wr_sequencer #(AW, DW) wr_sqr;
        mem_rd_sequencer #(AW, DW) rd_sqr;

        function new(string name = "mem_base_seq"); super.new(name); endfunction
        virtual task body(); endtask
    endclass
