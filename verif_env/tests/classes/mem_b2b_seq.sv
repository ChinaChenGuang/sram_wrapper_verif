// mem_b2b_raw_seq — Write+Read on same port (RAW hazard, wr-only)
class mem_b2b_raw_seq #(int AW=10, int DW=32) extends mem_base_seq #(AW, DW);
    `uvm_object_param_utils(mem_b2b_raw_seq #(AW, DW))
    function new(string n="mem_b2b_raw_seq"); super.new(n); endfunction
    task body();
        mem_wr_item #(AW, DW) wr;
        `uvm_info("SEQ", $sformatf("B2B RAW: %0d tx", num_tx), UVM_MEDIUM)
        for (int i = 0; i < num_tx; i++) begin
            int a = i % depth;
            // Write
            wr = mem_wr_item #(AW, DW)::type_id::create("wr");
            start_item(wr);
            void'(wr.randomize() with { cmd == MEM_WRITE; addr == a; wem == '0; });
            finish_item(wr);
            // Read same addr (on same port via cmd change)
            wr = mem_wr_item #(AW, DW)::type_id::create("wr");
            start_item(wr);
            void'(wr.randomize() with { cmd == MEM_READ; addr == a; });
            finish_item(wr);
        end
    endtask
endclass
