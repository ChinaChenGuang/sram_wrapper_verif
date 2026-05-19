// ============================================================
// mem_wem_walking_seq — Write with walking WEM mask
// ============================================================

class mem_wem_walking_seq #(int AW=10, int DW=32) extends mem_base_seq #(AW, DW);
    `uvm_object_param_utils(mem_wem_walking_seq #(AW, DW));
    function new(string n="mem_wem_walking_seq"); super.new(n); endfunction
    task body();
        mem_item #(AW, DW) item;
        `uvm_info("SEQ", $sformatf("WEM walking: %0d tx", num_tx), UVM_MEDIUM)
        for (int i = 0; i < num_tx; i++) begin
            item = mem_item #(AW, DW)::type_id::create("item");
            start_item(item);
            if (!item.randomize()) `uvm_error("SEQ", "RND FAIL")
            
            item.wem = ~(1 << (i % DW));
            finish_item(item);
        end
    endtask
endclass
