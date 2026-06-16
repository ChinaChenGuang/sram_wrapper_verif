// ============================================================
// mem_port_seq — Unified Sequence for Generic Port
// ============================================================

typedef enum { SEQ_WR, SEQ_RD, SEQ_NOP } seq_role_e;

class mem_port_seq #(int AW=16, int DW=256) extends mem_base_seq #(AW, DW);
    `uvm_object_param_utils(mem_port_seq #(AW, DW));
    
    seq_role_e role = SEQ_NOP;

    bit confine_addr = 0;
    bit addr_lower_half = 1;

    function new(string name="mem_port_seq"); super.new(name); endfunction

    task body();
        mem_item #(AW, DW) item;
        for (int i = 0; i < num_tx; i++) begin
            item = mem_item #(AW, DW)::type_id::create("item");
            start_item(item);
            if (!item.randomize() with {
                if (role == SEQ_WR) {
                    ce == 1'b0; // active low
                    we == 1'b0; // write
                } else if (role == SEQ_RD) {
                    ce == 1'b0; // active low
                    we == 1'b1; // read
                } else {
                    ce == 1'b1; // NOP (inactive)
                    we == 1'b1;
                }

                if (confine_addr) {
                    if (addr_lower_half) addr < (depth/2);
                    else addr >= (depth/2);
                }
            }) `uvm_error("SEQ", "RND FAIL")
            finish_item(item);
        end
    endtask
endclass
