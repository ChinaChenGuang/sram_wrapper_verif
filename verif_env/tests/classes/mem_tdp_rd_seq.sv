// mem_tdp_rd_seq
    class mem_tdp_rd_seq #(int AW=10, int DW=32) extends mem_base_seq #(AW, DW);
        `uvm_object_param_utils(mem_tdp_rd_seq #(AW, DW))
        function new(string n="mem_tdp_rd_seq"); super.new(n); endfunction
        task body();
            mem_rd_item #(AW, DW) rd;
            for (int i = 0; i < num_tx; i++) begin
                rd = mem_rd_item #(AW, DW)::type_id::create("rd");
                start_item(rd);
                void'(rd.randomize() with { addr >= depth/2; });
                finish_item(rd);
            end
        endtask
    endclass
