// ============================================================
// mem_b2b_raw_seq — Write+Read on same port (RAW hazard)
// ============================================================

class mem_b2b_raw_seq #(int AW=10, int DW=32) extends mem_base_seq #(AW, DW);
    `uvm_object_param_utils(mem_b2b_raw_seq #(AW, DW));
    function new(string n="mem_b2b_raw_seq"); super.new(n); endfunction
    task body();
        mem_item #(AW, DW) item;
        `uvm_info("SEQ", $sformatf("B2B RAW: %0d tx", num_tx), UVM_MEDIUM)
        for (int i = 0; i < num_tx; i++) begin
            int a = i % depth;
            // Write
            item = mem_item #(AW, DW)::type_id::create("item");
            start_item(item);
            if (!item.randomize()) `uvm_error("SEQ", "RND FAIL")
            
            item.addr = a;
            item.wem = '0;
            finish_item(item);
            // Read same addr
            item = mem_item #(AW, DW)::type_id::create("item");
            start_item(item);
            if (!item.randomize()) `uvm_error("SEQ", "RND FAIL")
            
            item.addr = a;
            finish_item(item);
        end
    endtask
endclass
