// ============================================================
// test_mem_tdp — TDP: concurrent write (low addr) + read (high addr)
// ============================================================

class test_mem_tdp extends mem_base_test #(16, 256);
    `uvm_component_utils(test_mem_tdp);
    function new(string n="test_mem_tdp", uvm_component p=null); super.new(n,p); endfunction
    task run_phase(uvm_phase phase);
        mem_port_seq #(16, 256) wr_seq;
        mem_port_seq #(16, 256) rd_seq;
        super.run_phase(phase);
        phase.raise_objection(this);
        // Write to lower half on write port
        wr_seq = mem_port_seq #(16, 256)::type_id::create("wr_seq");
        wr_seq.target_sram_type = SRAM_TDP;
        wr_seq.role = SEQ_WR;
        wr_seq.confine_addr = 1;
        wr_seq.addr_lower_half = 1;
        wr_seq.num_tx = 100;
        wr_seq.start(env.wr_agent.sqr);

        // Read from upper half on read port
        rd_seq = mem_port_seq #(16, 256)::type_id::create("rd_seq");
        rd_seq.target_sram_type = SRAM_TDP;
        rd_seq.role = SEQ_RD;
        rd_seq.confine_addr = 1;
        rd_seq.addr_lower_half = 0;
        rd_seq.num_tx = 100;
        rd_seq.start(env.rd_agent.sqr);
        phase.drop_objection(this);
    endtask
endclass
