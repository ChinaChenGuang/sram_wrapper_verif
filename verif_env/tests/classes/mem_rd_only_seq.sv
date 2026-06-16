// ============================================================
// mem_rd_only_seq — Read-only helper sequence
// ============================================================

class mem_rd_only_seq #(int AW=16, int DW=256) extends mem_base_seq #(AW, DW);
    `uvm_object_param_utils(mem_rd_only_seq #(AW, DW));
    function new(string n="mem_rd_only_seq"); super.new(n); endfunction
    task body();
        mem_item #(AW, DW) item;
        for (int i = 0; i < num_tx; i++) begin
            item = mem_item #(AW, DW)::type_id::create("item");
            start_item(item);
            if (!item.randomize()) `uvm_error("SEQ", "RND FAIL")
            
            item.addr = (i*2+1) % depth;
            finish_item(item);
        end
    endtask
endclass
