// ============================================================
// test_mem_b2b — Back-to-back RAW test on write port
// ============================================================

class test_mem_b2b extends mem_base_test #(16, 256);
    `uvm_component_utils(test_mem_b2b);
    function new(string n="test_mem_b2b", uvm_component p=null); super.new(n,p); endfunction
    task run_phase(uvm_phase phase);
        mem_b2b_raw_seq #(16, 256) seq;
        super.run_phase(phase);
        phase.raise_objection(this);
        seq = mem_b2b_raw_seq #(16, 256)::type_id::create("seq");
        seq.num_tx = 200;
        seq.rd_sqr = env.rd_agent.sqr;
        seq.start(env.wr_agent.sqr);
        phase.drop_objection(this);
    endtask
endclass
