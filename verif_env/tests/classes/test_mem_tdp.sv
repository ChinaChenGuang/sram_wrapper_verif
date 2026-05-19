// ============================================================
// test_mem_tdp — TDP: concurrent write (low addr) + read (high addr)
// ============================================================

class test_mem_tdp extends mem_base_test #(10, 32);
    `uvm_component_utils(test_mem_tdp);
    function new(string n="test_mem_tdp", uvm_component p=null); super.new(n,p); endfunction
    task run_phase(uvm_phase phase);
        mem_tdp_wr_seq #(10, 32) wr_seq;
        mem_tdp_rd_seq #(10, 32) rd_seq;
        phase.raise_objection(this);
        // Write to lower half on write port
        wr_seq = mem_tdp_wr_seq #(10, 32)::type_id::create("wr_seq");
        wr_seq.num_tx = 100;
        wr_seq.wr_sqr = env.wr_agent.sqr;
        wr_seq.start(env.wr_agent.sqr);
        // Read from upper half on read port
        rd_seq = mem_tdp_rd_seq #(10, 32)::type_id::create("rd_seq");
        rd_seq.num_tx = 100;
        rd_seq.rd_sqr = env.rd_agent.sqr;
        rd_seq.start(env.rd_agent.sqr);
        phase.drop_objection(this);
    endtask
endclass
