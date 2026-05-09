// mem_fill_verify_seq — Fill+Verify on write port
class mem_fill_verify_seq #(int AW=10, int DW=32) extends mem_base_seq #(AW, DW);
    `uvm_object_param_utils(mem_fill_verify_seq #(AW, DW))
    function new(string n="mem_fill_verify_seq"); super.new(n); endfunction
    task body();
        mem_wr_item #(AW, DW) wr;
        `uvm_info("SEQ", $sformatf("Fill+Verify: depth=%0d", depth), UVM_MEDIUM)
        // Fill
        for (int a = 0; a < depth; a++) begin
            wr = mem_wr_item #(AW, DW)::type_id::create("wr");
            start_item(wr);
            void'(wr.randomize() with { cmd == MEM_WRITE; addr == a; wem == '0; });
            finish_item(wr);
        end
        // Drain
        repeat (5) begin
            wr = mem_wr_item #(AW, DW)::type_id::create("wr");
            start_item(wr);
            void'(wr.randomize() with { cmd == MEM_NOP; });
            finish_item(wr);
        end
        // Read back all
        for (int a = 0; a < depth; a++) begin
            wr = mem_wr_item #(AW, DW)::type_id::create("wr");
            start_item(wr);
            void'(wr.randomize() with { cmd == MEM_READ; addr == a; });
            finish_item(wr);
        end
    endtask
endclass
