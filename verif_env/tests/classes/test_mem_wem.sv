// test_mem_wem_walking
class test_mem_wem_walking extends mem_test_pkg::mem_base_test #(10, 32);
    `uvm_component_utils(test_mem_wem_walking)
    function new(string n="test_mem_wem_walking", uvm_component p=null); super.new(n,p); endfunction
    task run_phase(uvm_phase phase);
        mem_test_pkg::mem_wem_walking_seq #(10, 32) seq;
        phase.raise_objection(this);
        seq = mem_test_pkg::mem_wem_walking_seq #(10, 32)::type_id::create("seq");
        seq.num_tx = 128;
        seq.wr_sqr = env.wr_agent.sqr;
        seq.rd_sqr = env.rd_agent.sqr;
        seq.wr_sqr = env.wr_agent.sqr;
        seq.rd_sqr = env.rd_agent.sqr;
        seq.wr_sqr = env.wr_agent.sqr;
        seq.rd_sqr = env.rd_agent.sqr;
        seq.wr_sqr = env.wr_agent.sqr;
        seq.rd_sqr = env.rd_agent.sqr;
        seq.start(env.wr_agent.sqr);
        phase.drop_objection(this);
    endtask
endclass
