// ============================================================
// mem_test_pkg — SRAM Test Package (UVM 1.2)
// ============================================================
`ifndef MEM_TEST_PKG_SV
`define MEM_TEST_PKG_SV

package mem_test_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import mem_uvc_pkg::*;

    // ============================================================
    // mem_base_seq — Base sequence
    // ============================================================
    class mem_base_seq #(int AW=10, int DW=32) extends uvm_sequence #(mem_item #(AW, DW));
        `uvm_object_param_utils(mem_base_seq #(AW, DW))
        int num_tx = 200;
        function new(string name = "mem_base_seq"); super.new(name); endfunction
        virtual task body(); endtask
    endclass

    // ============================================================
    // mem_sp_seq — Single Port
    // ============================================================
    class mem_sp_seq #(int AW=10, int DW=32) extends mem_base_seq #(AW, DW);
        `uvm_object_param_utils(mem_sp_seq #(AW, DW))
        function new(string name = "mem_sp_seq"); super.new(name); endfunction
        task body();
            mem_item #(AW, DW) req;
            `uvm_info("SEQ", $sformatf("SP: %0d tx", num_tx), UVM_MEDIUM)
            for (int i = 0; i < num_tx; i++) begin
                req = mem_item #(AW, DW)::type_id::create("req");
                start_item(req);
                void\'(req.randomize());
                    `uvm_error("SEQ", "SP rand fail")
                finish_item(req);
            end
        endtask
    endclass

    // ============================================================
    // mem_sdp_seq — Simple Dual Port
    // ============================================================
    class mem_sdp_seq #(int AW=10, int DW=32) extends mem_base_seq #(AW, DW);
        `uvm_object_param_utils(mem_sdp_seq #(AW, DW))
        function new(string name = "mem_sdp_seq"); super.new(name); endfunction
        task body();
            mem_item #(AW, DW) req;
            `uvm_info("SEQ", $sformatf("SDP: %0d tx", num_tx), UVM_MEDIUM)
            for (int i = 0; i < num_tx; i++) begin
                req = mem_item #(AW, DW)::type_id::create("req");
                start_item(req);
                void\'(req.randomize());
                    `uvm_error("SEQ", "SDP rand fail")
                finish_item(req);
            end
        endtask
    endclass

    // ============================================================
    // mem_tdp_seq — True Dual Port
    // ============================================================
    class mem_tdp_seq #(int AW=10, int DW=32) extends mem_base_seq #(AW, DW);
        `uvm_object_param_utils(mem_tdp_seq #(AW, DW))
        function new(string name = "mem_tdp_seq"); super.new(name); endfunction
        task body();
            mem_item #(AW, DW) req;
            `uvm_info("SEQ", $sformatf("TDP: %0d tx", num_tx), UVM_MEDIUM)
            for (int i = 0; i < num_tx; i++) begin
                req = mem_item #(AW, DW)::type_id::create("req");
                start_item(req);
                void\'(req.randomize());
                    `uvm_error("SEQ", "TDP rand fail")
                finish_item(req);
            end
        endtask
    endclass

    // ============================================================
    // mem_wem_walking_seq — Write mask walking 0
    // ============================================================
    class mem_wem_walking_seq #(int AW=10, int DW=32) extends mem_base_seq #(AW, DW);
        `uvm_object_param_utils(mem_wem_walking_seq #(AW, DW))
        function new(string name = "mem_wem_walking_seq"); super.new(name); endfunction
        task body();
            mem_item #(AW, DW) req;
            `uvm_info("SEQ", $sformatf("WEM walking: %0d tx", num_tx), UVM_MEDIUM)
            for (int i = 0; i < num_tx; i++) begin
                req = mem_item #(AW, DW)::type_id::create("req");
                start_item(req);
                void\'(req.randomize()); `uvm_error("SEQ", "WEM rand fail")
                finish_item(req);
            end
        endtask
    endclass

    // ============================================================
    // mem_b2b_raw_seq — Back-to-back Read-After-Write
    // ============================================================
    class mem_b2b_raw_seq #(int AW=10, int DW=32) extends mem_base_seq #(AW, DW);
        `uvm_object_param_utils(mem_b2b_raw_seq #(AW, DW))
        function new(string name = "mem_b2b_raw_seq"); super.new(name); endfunction
        task body();
            mem_item #(AW, DW) req;
            `uvm_info("SEQ", $sformatf("B2B RAW: %0d tx", num_tx), UVM_MEDIUM)
            for (int i = 0; i < num_tx; i++) begin
                // Write
                req = mem_item #(AW, DW)::type_id::create("req");
                start_item(req);
                void\'(req.randomize()); `uvm_error("SEQ", "B2B write rand fail")
                finish_item(req);
                // Read same addr
                req = mem_item #(AW, DW)::type_id::create("req");
                start_item(req);
                void\'(req.randomize()); `uvm_error("SEQ", "B2B read rand fail")
                finish_item(req);
            end
        endtask
    endclass

    // ============================================================
    // mem_fill_verify_seq — Fill all, then read back all
    // ============================================================
    class mem_fill_verify_seq #(int AW=10, int DW=32) extends mem_base_seq #(AW, DW);
        `uvm_object_param_utils(mem_fill_verify_seq #(AW, DW))
        function new(string name = "mem_fill_verify_seq"); super.new(name); endfunction
        task body();
            mem_item #(AW, DW) req;
            int depth = 1 << AW;
            `uvm_info("SEQ", $sformatf("Fill+Verify: depth=%0d", depth), UVM_MEDIUM)
            // Fill
            for (int a = 0; a < depth; a++) begin
                req = mem_item #(AW, DW)::type_id::create("req");
                start_item(req);
                void\'(req.randomize());
                    `uvm_error("SEQ", "Fill rand fail")
                finish_item(req);
            end
            // Drain
            repeat (5) begin
                req = mem_item #(AW, DW)::type_id::create("req");
                start_item(req);
                void\'(req.randomize());
                    `uvm_error("SEQ", "Drain rand fail")
                finish_item(req);
            end
            // Verify
            for (int a = 0; a < depth; a++) begin
                req = mem_item #(AW, DW)::type_id::create("req");
                start_item(req);
                void\'(req.randomize());
                    `uvm_error("SEQ", "Verify rand fail")
                finish_item(req);
            end
        endtask
    endclass

    // ============================================================
    // mem_base_test
    // ============================================================
    class mem_base_test #(int AW=10, int DW=32) extends uvm_test;
        `uvm_component_param_utils(mem_base_test #(AW, DW))
        mem_env #(AW, DW) env;
        function new(string name, uvm_component p); super.new(name, p); endfunction
        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            env = mem_env #(AW, DW)::type_id::create("env", this);
        endfunction
    endclass

endpackage : mem_test_pkg

// ============================================================
// Concrete Tests (global scope for UVM factory)
// ============================================================
import mem_test_pkg::*;

class test_mem_sp extends mem_test_pkg::mem_base_test #(10, 32);
    `uvm_component_utils(test_mem_sp)
    function new(string n="test_mem_sp", uvm_component p=null); super.new(n,p); endfunction
    task run_phase(uvm_phase phase);
        mem_test_pkg::mem_sp_seq #(10, 32) seq;
        phase.raise_objection(this);
        seq = mem_test_pkg::mem_sp_seq #(10, 32)::type_id::create("seq");
        seq.num_tx = 200;
        seq.start(env.agent.sqr);
        phase.drop_objection(this);
    endtask
endclass

class test_mem_sdp extends mem_test_pkg::mem_base_test #(10, 32);
    `uvm_component_utils(test_mem_sdp)
    function new(string n="test_mem_sdp", uvm_component p=null); super.new(n,p); endfunction
    task run_phase(uvm_phase phase);
        mem_test_pkg::mem_sdp_seq #(10, 32) seq;
        phase.raise_objection(this);
        seq = mem_test_pkg::mem_sdp_seq #(10, 32)::type_id::create("seq");
        seq.num_tx = 200;
        seq.start(env.agent.sqr);
        phase.drop_objection(this);
    endtask
endclass

class test_mem_tdp extends mem_test_pkg::mem_base_test #(10, 32);
    `uvm_component_utils(test_mem_tdp)
    function new(string n="test_mem_tdp", uvm_component p=null); super.new(n,p); endfunction
    task run_phase(uvm_phase phase);
        mem_test_pkg::mem_tdp_seq #(10, 32) seq;
        phase.raise_objection(this);
        seq = mem_test_pkg::mem_tdp_seq #(10, 32)::type_id::create("seq");
        seq.num_tx = 200;
        seq.start(env.agent.sqr);
        phase.drop_objection(this);
    endtask
endclass

class test_mem_wem_walking extends mem_test_pkg::mem_base_test #(10, 32);
    `uvm_component_utils(test_mem_wem_walking)
    function new(string n="test_mem_wem_walking", uvm_component p=null); super.new(n,p); endfunction
    task run_phase(uvm_phase phase);
        mem_test_pkg::mem_wem_walking_seq #(10, 32) seq;
        phase.raise_objection(this);
        seq = mem_test_pkg::mem_wem_walking_seq #(10, 32)::type_id::create("seq");
        seq.num_tx = 128;
        seq.start(env.agent.sqr);
        phase.drop_objection(this);
    endtask
endclass

class test_mem_b2b_raw extends mem_test_pkg::mem_base_test #(10, 32);
    `uvm_component_utils(test_mem_b2b_raw)
    function new(string n="test_mem_b2b_raw", uvm_component p=null); super.new(n,p); endfunction
    task run_phase(uvm_phase phase);
        mem_test_pkg::mem_b2b_raw_seq #(10, 32) seq;
        phase.raise_objection(this);
        seq = mem_test_pkg::mem_b2b_raw_seq #(10, 32)::type_id::create("seq");
        seq.num_tx = 200;
        seq.start(env.agent.sqr);
        phase.drop_objection(this);
    endtask
endclass

class test_mem_fill_verify extends mem_test_pkg::mem_base_test #(10, 32);
    `uvm_component_utils(test_mem_fill_verify)
    function new(string n="test_mem_fill_verify", uvm_component p=null); super.new(n,p); endfunction
    task run_phase(uvm_phase phase);
        mem_test_pkg::mem_fill_verify_seq #(10, 32) seq;
        phase.raise_objection(this);
        seq = mem_test_pkg::mem_fill_verify_seq #(10, 32)::type_id::create("seq");
        seq.start(env.agent.sqr);
        phase.drop_objection(this);
    endtask
endclass

`endif
