// test_mem_tdp
class test_mem_tdp extends mem_test_pkg::mem_base_test #(10, 32);
    `uvm_component_utils(test_mem_tdp)
    function new(string n="test_mem_tdp", uvm_component p=null); super.new(n,p); endfunction
    task run_phase(uvm_phase phase);
        mem_test_pkg::mem_tdp_wr_seq #(10, 32) wr_seq;
        mem_test_pkg::mem_tdp_rd_seq #(10, 32) rd_seq;
        phase.raise_objection(this);
        fork
            begin
                wr_seq = mem_test_pkg::mem_tdp_wr_seq #(10, 32)::type_id::create("wr_seq");
                wr_seq.num_tx = 200;
                wr_seq.start(env.wr_agent.sqr);
            end
            begin
                rd_seq = mem_test_pkg::mem_tdp_rd_seq #(10, 32)::type_id::create("rd_seq");
                rd_seq.num_tx = 200;
                rd_seq.start(env.rd_agent.sqr);
            end
        join
        phase.drop_objection(this);
    endtask
endclass
