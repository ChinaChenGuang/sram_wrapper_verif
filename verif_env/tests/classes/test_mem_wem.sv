// ============================================================
// test_mem_wem — Write mask walking test
// ============================================================

class test_mem_wem extends mem_base_test #(10, 32);
    `uvm_component_utils(test_mem_wem);
    function new(string n="test_mem_wem", uvm_component p=null); super.new(n,p); endfunction
    task run_phase(uvm_phase phase);
        mem_wem_walking_seq #(10, 32) seq;
        super.run_phase(phase);
        phase.raise_objection(this);
        seq = mem_wem_walking_seq #(10, 32)::type_id::create("seq");
        seq.num_tx = 200;
        // seq.wr_sqr = env.wr_agent.sqr; // Optional depending on if sequence needs it
        seq.start(env.wr_agent.sqr);
        phase.drop_objection(this);
    endtask
endclass
