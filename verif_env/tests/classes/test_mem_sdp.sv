// ============================================================
// test_mem_sdp — SDP test on write port
// ============================================================

class test_mem_sdp extends mem_base_test #(10, 32);
    `uvm_component_utils(test_mem_sdp);
    function new(string n="test_mem_sdp", uvm_component p=null); super.new(n,p); endfunction
    task run_phase(uvm_phase phase);
        mem_sdp_seq #(10, 32) seq;
        phase.raise_objection(this);
        seq = mem_sdp_seq #(10, 32)::type_id::create("seq");
        seq.num_tx = 200;
        seq.wr_sqr = env.wr_agent.sqr;
        seq.start(env.wr_agent.sqr);
        phase.drop_objection(this);
    endtask
endclass
