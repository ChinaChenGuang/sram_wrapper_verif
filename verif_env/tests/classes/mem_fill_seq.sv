// ============================================================
// mem_fill_verify_seq — Fill all addresses + Verify by reading back
// ============================================================

class mem_fill_verify_seq #(int AW=16, int DW=256) extends mem_base_seq #(AW, DW);
    `uvm_object_param_utils(mem_fill_verify_seq #(AW, DW));
    function new(string n="mem_fill_verify_seq"); super.new(n); endfunction
    task body();
        mem_item #(AW, DW) item;
        `uvm_info("SEQ", $sformatf("Fill+Verify: depth=%0d", depth), UVM_MEDIUM)
        // Fill
        for (int a = 0; a < depth; a++) begin
            item = mem_item #(AW, DW)::type_id::create("item");
            start_item(item);
            if (!item.randomize() with {
                ce   == 1'b0;
                we   == 1'b0;
                addr == local::a;
                wem  == '0;
            }) `uvm_error("SEQ", "RND FAIL")
            finish_item(item);
        end
        // Drain
        repeat (5) begin
            item = mem_item #(AW, DW)::type_id::create("item");
            start_item(item);
            if (!item.randomize() with {
                ce == 1'b1;
            }) `uvm_error("SEQ", "RND FAIL")
            finish_item(item);
        end
        // Read back all
        for (int a = 0; a < depth; a++) begin
            item = mem_item #(AW, DW)::type_id::create("item");
            start_item(item);
            if (!item.randomize() with {
                ce   == 1'b0;
                we   == 1'b1;
                addr == local::a;
            }) `uvm_error("SEQ", "RND FAIL")
            finish_item(item);
        end
    endtask
endclass
