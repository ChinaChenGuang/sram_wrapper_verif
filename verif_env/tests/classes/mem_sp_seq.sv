// mem_sp_seq
    class mem_sp_seq #(int AW=10, int DW=32) extends mem_base_seq #(AW, DW);
        `uvm_object_param_utils(mem_sp_seq #(AW, DW))
        function new(string n="mem_sp_seq"); super.new(n); endfunction
        task body();
            mem_wr_item #(AW, DW) wr;
            `uvm_info("SEQ", $sformatf("SP: %0d tx", num_tx), UVM_MEDIUM)
            for (int i = 0; i < num_tx; i++) begin
                wr = mem_wr_item #(AW, DW)::type_id::create("wr");
                start_item(wr);
                void'(wr.randomize());
                finish_item(wr);
            end
        endtask
    endclass
