// ============================================================
// mem_b2b_raw_seq — Write+Read on same port (RAW hazard)
// ============================================================

class mem_b2b_raw_seq #(int AW=10, int DW=32) extends mem_base_seq #(AW, DW);
    `uvm_object_param_utils(mem_b2b_raw_seq #(AW, DW));
    uvm_sequencer_base rd_sqr;

    function new(string n="mem_b2b_raw_seq"); super.new(n); endfunction
    task body();
        mem_item #(AW, DW) wr_item;
        mem_item #(AW, DW) rd_item;
        `uvm_info("SEQ", $sformatf("B2B RAW: %0d tx", num_tx), UVM_MEDIUM)
        for (int i = 0; i < num_tx; i++) begin
            int a = i % depth;
            
            if (target_sram_type == SRAM_SP) begin
                // Sequential Write then Read for SP
                wr_item = mem_item #(AW, DW)::type_id::create("wr_item");
                start_item(wr_item);
                if (!wr_item.randomize() with { 
                    ce   == 1'b0; 
                    we   == 1'b0; 
                    addr == local::a; 
                    wem  == '0; 
                }) `uvm_error("SEQ", "RND FAIL")
                finish_item(wr_item);
                
                rd_item = mem_item #(AW, DW)::type_id::create("rd_item");
                start_item(rd_item);
                if (!rd_item.randomize() with { 
                    ce   == 1'b0; 
                    we   == 1'b1; 
                    addr == local::a; 
                }) `uvm_error("SEQ", "RND FAIL")
                finish_item(rd_item);
            end else begin
                // Concurrent Write and Read for Dual Port (RAW)
                if (rd_sqr == null) `uvm_fatal("SEQ", "rd_sqr must be set for Dual Port B2B RAW")
                fork
                    begin
                        wr_item = mem_item #(AW, DW)::type_id::create("wr_item");
                        start_item(wr_item);
                        if (!wr_item.randomize() with { 
                            ce   == 1'b0; 
                            we   == 1'b0; 
                            addr == local::a; 
                            wem  == '0; 
                        }) `uvm_error("SEQ", "RND FAIL")
                        finish_item(wr_item);
                    end
                    begin
                        rd_item = mem_item #(AW, DW)::type_id::create("rd_item");
                        start_item(rd_item, -1, rd_sqr);
                        if (!rd_item.randomize() with { 
                            ce   == 1'b0; 
                            we   == 1'b1; 
                            addr == local::a; 
                        }) `uvm_error("SEQ", "RND FAIL")
                        finish_item(rd_item);
                    end
                join
            end
        end
    endtask
endclass
