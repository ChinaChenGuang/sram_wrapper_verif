// ============================================================
// mem_tdp_rd_seq — TDP Read Port (addr >= depth/2)
// ============================================================

class mem_tdp_rd_seq #(int AW=10, int DW=32) extends mem_base_seq #(AW, DW);
    `uvm_object_param_utils(mem_tdp_rd_seq #(AW, DW));
    function new(string n="mem_tdp_rd_seq"); super.new(n); endfunction
    task body();
        mem_item #(AW, DW) item;
        for (int i = 0; i < num_tx; i++) begin
            item = mem_item #(AW, DW)::type_id::create("item");
            start_item(item);
            if (!item.randomize()) `uvm_error("SEQ", "RND FAIL")
            
            item.addr = (depth/2) + i % (depth/2);
            finish_item(item);
        end
    endtask
endclass
