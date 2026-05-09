// mem_tdp_wr_seq
    class mem_tdp_wr_seq #(int AW=10, int DW=32) extends mem_base_seq #(AW, DW);
        `uvm_object_param_utils(mem_tdp_wr_seq #(AW, DW))
        function new(string n="mem_tdp_wr_seq"); super.new(n); endfunction
        task body();
            mem_wr_item #(AW, DW) wr;
            for (int i = 0; i < num_tx; i++) begin
                wr = mem_wr_item #(AW, DW)::type_id::create("wr");
                start_item(wr);
                void'(wr.randomize() with { addr < depth/2; });
                finish_item(wr);
            end
        endtask
    endclass
