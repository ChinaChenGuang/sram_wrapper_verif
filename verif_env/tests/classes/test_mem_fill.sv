// ============================================================
// test_mem_fill — Fill all addresses + verify by reading back
// ============================================================

class test_mem_fill_verify extends mem_base_test #(10, 32);
    `uvm_component_utils(test_mem_fill_verify);
    function new(string n="test_mem_fill_verify", uvm_component p=null); super.new(n,p); endfunction
    task run_phase(uvm_phase phase);
        mem_fill_verify_seq #(10, 32) seq;
        phase.raise_objection(this);
        seq = mem_fill_verify_seq #(10, 32)::type_id::create("seq");
        seq.num_tx = 200;
        seq.wr_sqr = env.wr_agent.sqr;
        seq.start(env.wr_agent.sqr);
        phase.drop_objection(this);
    endtask
endclass
