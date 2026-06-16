// ============================================================
// mem_base_seq — Base Sequence (uses unified mem_item)
// ============================================================

class mem_base_seq #(int AW=16, int DW=256) extends uvm_sequence #(mem_item #(AW, DW));
    `uvm_object_param_utils(mem_base_seq #(AW, DW));

    int num_tx = 200;
    int cfg_addr_width = 10;
    int depth;
    sram_type_e target_sram_type = SRAM_TDP;

    function new(string name = "mem_base_seq"); 
        super.new(name); 
        void'($value$plusargs("ADDR_WIDTH=%d", cfg_addr_width));
        depth = 1 << cfg_addr_width;
    endfunction

    // -------------------------------------------------------
    // Standard 4-step Generation (Safe & Parameterized)
    // -------------------------------------------------------
    task send_item(mem_item #(AW, DW) item);
        start_item(item);
        if (!item.randomize()) `uvm_error("SEQ", "Randomization failed")
        finish_item(item);
    endtask

    virtual task body(); endtask
endclass
