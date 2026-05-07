package mem_test_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"
    
    import mem_uvc_pkg::*;

    class mem_base_test #(parameter int ADDR_WIDTH = 10, parameter int DATA_WIDTH = 32) extends uvm_test;
        mem_env#(ADDR_WIDTH, DATA_WIDTH) env;

        `uvm_component_param_utils(mem_base_test#(ADDR_WIDTH, DATA_WIDTH))

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        virtual function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            env = mem_env#(ADDR_WIDTH, DATA_WIDTH)::type_id::create("env", this);
        endfunction
        
        virtual task run_phase(uvm_phase phase);
            super.run_phase(phase);
            phase.phase_done.set_drain_time(this, 100);
        endtask
    endclass

    class mem_sp_test extends mem_base_test#(10, 32);
        `uvm_component_utils(mem_sp_test)
        function new(string name="mem_sp_test", uvm_component parent=null); super.new(name, parent); endfunction
        virtual task run_phase(uvm_phase phase);
            mem_sp_seq#(10, 32) seq;
            phase.raise_objection(this);
            super.run_phase(phase);
            seq = mem_sp_seq#(10, 32)::type_id::create("seq");
            seq.target_sram_type = SRAM_SP;
            seq.start(env.agent.sequencer);
            phase.drop_objection(this);
        endtask
    endclass

    class mem_sdp_test extends mem_base_test#(10, 32);
        `uvm_component_utils(mem_sdp_test)
        function new(string name="mem_sdp_test", uvm_component parent=null); super.new(name, parent); endfunction
        virtual task run_phase(uvm_phase phase);
            mem_sdp_seq#(10, 32) seq;
            phase.raise_objection(this);
            super.run_phase(phase);
            seq = mem_sdp_seq#(10, 32)::type_id::create("seq");
            seq.target_sram_type = SRAM_SDP;
            seq.start(env.agent.sequencer);
            phase.drop_objection(this);
        endtask
    endclass

endpackage

