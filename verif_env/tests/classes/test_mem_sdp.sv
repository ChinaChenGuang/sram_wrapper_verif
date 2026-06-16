// ============================================================
// test_mem_sdp — SDP test on write port
// ============================================================

class test_mem_sdp extends mem_base_test #(16, 256);
    `uvm_component_utils(test_mem_sdp);
    function new(string n="test_mem_sdp", uvm_component p=null); super.new(n,p); endfunction
    task run_phase(uvm_phase phase);
        mem_port_seq #(16, 256) wr_seq;
        mem_port_seq #(16, 256) rd_seq;
        super.run_phase(phase);
        phase.raise_objection(this);
        
        wr_seq = mem_port_seq #(16, 256)::type_id::create("wr_seq");
        wr_seq.num_tx = 200;
        wr_seq.target_sram_type = SRAM_SDP;
        wr_seq.role = SEQ_WR;
        
        rd_seq = mem_port_seq #(16, 256)::type_id::create("rd_seq");
        rd_seq.num_tx = 200;
        rd_seq.target_sram_type = SRAM_SDP;
        rd_seq.role = SEQ_RD;

        fork
            wr_seq.start(env.wr_agent.sqr);
            rd_seq.start(env.rd_agent.sqr);
        join
        
        phase.drop_objection(this);
    endtask
endclass
