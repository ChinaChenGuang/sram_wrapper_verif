// ============================================================
// mem_sdp_seq — SDP Write Port
// ============================================================

class mem_sdp_seq #(int AW=10, int DW=32) extends mem_base_seq #(AW, DW);
    `uvm_object_param_utils(mem_sdp_seq #(AW, DW));
    function new(string n="mem_sdp_seq"); super.new(n); endfunction
    task body();
        mem_item #(AW, DW) item;
        `uvm_info("SEQ", $sformatf("SDP START: %0d tx", num_tx), UVM_MEDIUM)
        for (int i = 0; i < num_tx; i++) begin
            item = mem_item #(AW, DW)::type_id::create("item");
            start_item(item);
            if (!item.randomize() with {
                cmd_a != MEM_READ;
                cmd_b != MEM_WRITE;
            }) `uvm_error("SEQ", "RND FAIL")
            finish_item(item);
        end
    endtask
endclass
