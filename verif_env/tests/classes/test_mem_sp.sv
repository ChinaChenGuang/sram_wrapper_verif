// ============================================================
// test_mem_sp — SP test on write port
// ============================================================

class test_mem_sp extends mem_base_test #(16, 256);
    `uvm_component_utils(test_mem_sp);
    function new(string n="test_mem_sp", uvm_component p=null); super.new(n,p); endfunction
    task run_phase(uvm_phase phase);
        mem_port_seq #(16, 256) seq;
        super.run_phase(phase);
        phase.raise_objection(this);
        seq = mem_port_seq #(16, 256)::type_id::create("seq");
        seq.num_tx = 200;
        seq.target_sram_type = SRAM_SP;
        seq.role = SEQ_WR; // Uses port A
        seq.start(env.wr_agent.sqr);
        phase.drop_objection(this);
    endtask
endclass
