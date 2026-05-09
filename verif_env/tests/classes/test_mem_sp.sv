// test_mem_sp
class test_mem_sp extends mem_test_pkg::mem_base_test #(10, 32);
    `uvm_component_utils(test_mem_sp)
    function new(string n="test_mem_sp", uvm_component p=null); super.new(n,p); endfunction
    task run_phase(uvm_phase phase);
        mem_test_pkg::mem_sp_seq #(10, 32) seq;
        phase.raise_objection(this);
        seq = mem_test_pkg::mem_sp_seq #(10, 32)::type_id::create("seq");
        seq.num_tx = 200;
        seq.wr_sqr = env.wr_agent.sqr;
        seq.rd_sqr = env.rd_agent.sqr;
        seq.wr_sqr = env.wr_agent.sqr;
        seq.rd_sqr = env.rd_agent.sqr;
        seq.wr_sqr = env.wr_agent.sqr;
        seq.rd_sqr = env.rd_agent.sqr;
        seq.wr_sqr = env.wr_agent.sqr;
        seq.rd_sqr = env.rd_agent.sqr;
        seq.start(env.wr_agent.sqr);  // SP: only write sequencer
        phase.drop_objection(this);
    endtask
endclass
