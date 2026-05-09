class test_mem_fill_verify extends mem_test_pkg::mem_base_test #(10, 32);
    `uvm_component_utils(test_mem_fill_verify)
    function new(string n="test_mem_fill_verify", uvm_component p=null); super.new(n,p); endfunction
    task run_phase(uvm_phase phase);
        mem_test_pkg::mem_fill_verify_seq #(10, 32) seq;
        phase.raise_objection(this);
        seq = mem_test_pkg::mem_fill_verify_seq #(10, 32)::type_id::create("seq");
        seq.start(env.wr_agent.sqr);
        phase.drop_objection(this);
    endtask
endclass
