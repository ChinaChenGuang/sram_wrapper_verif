package mem_uvc_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"

    typedef enum logic [1:0] {
        MEM_NOP   = 2'b00,
        MEM_READ  = 2'b01,
        MEM_WRITE = 2'b10
    } mem_cmd_e;

    typedef enum {
        SRAM_SP,
        SRAM_SDP,
        SRAM_TDP
    } sram_type_e;

    class mem_item #(parameter int ADDR_WIDTH = 10, parameter int DATA_WIDTH = 32) extends uvm_sequence_item;
        rand mem_cmd_e cmd_a;
        rand logic [ADDR_WIDTH-1:0] addr_a;
        rand logic [DATA_WIDTH-1:0] wdata_a;
        rand logic [DATA_WIDTH-1:0] wem_a;

        rand mem_cmd_e cmd_b;
        rand logic [ADDR_WIDTH-1:0] addr_b;
        rand logic [DATA_WIDTH-1:0] wdata_b;
        rand logic [DATA_WIDTH-1:0] wem_b;

        sram_type_e sram_type; // For sequence constraint

        `uvm_object_param_utils(mem_item#(ADDR_WIDTH, DATA_WIDTH))

        function new(string name = "mem_item");
            super.new(name);
        endfunction

        // SP constraint
        constraint c_sp {
            if (sram_type == SRAM_SP) {
                cmd_b == MEM_NOP;
            }
        }

        // SDP constraint
        constraint c_sdp {
            if (sram_type == SRAM_SDP) {
                cmd_a != MEM_READ;
                cmd_b != MEM_WRITE;
            }
        }

        virtual function void do_copy(uvm_object rhs);
            mem_item#(ADDR_WIDTH, DATA_WIDTH) rhs_;
            super.do_copy(rhs);
            $cast(rhs_, rhs);
            this.cmd_a = rhs_.cmd_a;
            this.addr_a = rhs_.addr_a;
            this.wdata_a = rhs_.wdata_a;
            this.wem_a = rhs_.wem_a;
            this.cmd_b = rhs_.cmd_b;
            this.addr_b = rhs_.addr_b;
            this.wdata_b = rhs_.wdata_b;
            this.wem_b = rhs_.wem_b;
            this.sram_type = rhs_.sram_type;
        endfunction

        virtual function bit do_compare(uvm_object rhs, uvm_comparer comparer);
            mem_item#(ADDR_WIDTH, DATA_WIDTH) rhs_;
            if (!$cast(rhs_, rhs)) return 0;
            return (super.do_compare(rhs, comparer) &&
                    (this.cmd_a == rhs_.cmd_a) &&
                    (this.addr_a == rhs_.addr_a) &&
                    (this.wdata_a == rhs_.wdata_a) &&
                    (this.wem_a == rhs_.wem_a) &&
                    (this.cmd_b == rhs_.cmd_b) &&
                    (this.addr_b == rhs_.addr_b) &&
                    (this.wdata_b == rhs_.wdata_b) &&
                    (this.wem_b == rhs_.wem_b));
        endfunction

        virtual function void do_print(uvm_printer printer);
            super.do_print(printer);
            printer.print_string("cmd_a", cmd_a.name());
            printer.print_field("addr_a", addr_a, ADDR_WIDTH);
            printer.print_field("wdata_a", wdata_a, DATA_WIDTH);
            printer.print_field("wem_a", wem_a, DATA_WIDTH);
            printer.print_string("cmd_b", cmd_b.name());
            printer.print_field("addr_b", addr_b, ADDR_WIDTH);
            printer.print_field("wdata_b", wdata_b, DATA_WIDTH);
            printer.print_field("wem_b", wem_b, DATA_WIDTH);
        endfunction
    endclass

    class mem_sequencer #(parameter int ADDR_WIDTH = 10, parameter int DATA_WIDTH = 32) extends uvm_sequencer #(mem_item#(ADDR_WIDTH, DATA_WIDTH));
        `uvm_component_param_utils(mem_sequencer#(ADDR_WIDTH, DATA_WIDTH))
        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction
    endclass

    class mem_driver #(parameter int ADDR_WIDTH = 10, parameter int DATA_WIDTH = 32) extends uvm_driver #(mem_item#(ADDR_WIDTH, DATA_WIDTH));
        virtual mem_if#(ADDR_WIDTH, DATA_WIDTH) vif;

        `uvm_component_param_utils(mem_driver#(ADDR_WIDTH, DATA_WIDTH))

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        virtual function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            if (!uvm_config_db#(virtual mem_if#(ADDR_WIDTH, DATA_WIDTH))::get(this, "", "vif", vif)) begin
                `uvm_fatal("NOVIF", "virtual interface must be set for: vif")
            end
        endfunction

        virtual task run_phase(uvm_phase phase);
            vif.cmd_a <= MEM_NOP;
            vif.cmd_b <= MEM_NOP;
            @(posedge vif.rst_n); // wait for reset

            forever begin
                seq_item_port.get_next_item(req);
                @(posedge vif.clk);
                vif.cmd_a <= req.cmd_a;
                vif.addr_a <= req.addr_a;
                vif.wdata_a <= req.wdata_a;
                vif.wem_a <= req.wem_a;

                vif.cmd_b <= req.cmd_b;
                vif.addr_b <= req.addr_b;
                vif.wdata_b <= req.wdata_b;
                vif.wem_b <= req.wem_b;
                seq_item_port.item_done();
            end
        endtask
    endclass

    // No reference model or scoreboard needed according to spec, but we still need an agent
    class mem_agent #(parameter int ADDR_WIDTH = 10, parameter int DATA_WIDTH = 32) extends uvm_agent;
        mem_driver#(ADDR_WIDTH, DATA_WIDTH) driver;
        mem_sequencer#(ADDR_WIDTH, DATA_WIDTH) sequencer;

        `uvm_component_param_utils(mem_agent#(ADDR_WIDTH, DATA_WIDTH))

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        virtual function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            if (get_is_active() == UVM_ACTIVE) begin
                driver = mem_driver#(ADDR_WIDTH, DATA_WIDTH)::type_id::create("driver", this);
                sequencer = mem_sequencer#(ADDR_WIDTH, DATA_WIDTH)::type_id::create("sequencer", this);
            end
        endfunction

        virtual function void connect_phase(uvm_phase phase);
            super.connect_phase(phase);
            if (get_is_active() == UVM_ACTIVE) begin
                driver.seq_item_port.connect(sequencer.seq_item_export);
            end
        endfunction
    endclass

    class mem_env #(parameter int ADDR_WIDTH = 10, parameter int DATA_WIDTH = 32) extends uvm_env;
        mem_agent#(ADDR_WIDTH, DATA_WIDTH) agent;

        `uvm_component_param_utils(mem_env#(ADDR_WIDTH, DATA_WIDTH))

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        virtual function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            agent = mem_agent#(ADDR_WIDTH, DATA_WIDTH)::type_id::create("agent", this);
        endfunction
    endclass

    // Sequences
    class mem_base_seq #(parameter int ADDR_WIDTH = 10, parameter int DATA_WIDTH = 32) extends uvm_sequence #(mem_item#(ADDR_WIDTH, DATA_WIDTH));
        sram_type_e target_sram_type;

        `uvm_object_param_utils(mem_base_seq#(ADDR_WIDTH, DATA_WIDTH))

        function new(string name = "mem_base_seq");
            super.new(name);
        endfunction
    endclass

    class mem_sp_seq #(parameter int ADDR_WIDTH = 10, parameter int DATA_WIDTH = 32) extends mem_base_seq#(ADDR_WIDTH, DATA_WIDTH);
        `uvm_object_param_utils(mem_sp_seq#(ADDR_WIDTH, DATA_WIDTH))
        function new(string name="mem_sp_seq"); super.new(name); endfunction
        virtual task body();
            req = mem_item#(ADDR_WIDTH, DATA_WIDTH)::type_id::create("req");
            start_item(req);
            req.sram_type = target_sram_type;
            req.wem_a = 0;
            req.sram_type.rand_mode(0);
            req.wem_a.rand_mode(0);
            if (!req.randomize()) `uvm_error("SEQ", "RND FAIL")
            finish_item(req);
        endtask
    endclass

    class mem_sdp_seq #(parameter int ADDR_WIDTH = 10, parameter int DATA_WIDTH = 32) extends mem_base_seq#(ADDR_WIDTH, DATA_WIDTH);
        `uvm_object_param_utils(mem_sdp_seq#(ADDR_WIDTH, DATA_WIDTH))
        function new(string name="mem_sdp_seq"); super.new(name); endfunction
        virtual task body();
            req = mem_item#(ADDR_WIDTH, DATA_WIDTH)::type_id::create("req");
            start_item(req);
            req.sram_type = target_sram_type;
            req.wem_a = 0;
            req.wem_b = 0;
            req.cmd_a = MEM_WRITE;
            req.cmd_b = MEM_READ;
            req.sram_type.rand_mode(0);
            req.wem_a.rand_mode(0);
            req.wem_b.rand_mode(0);
            req.cmd_a.rand_mode(0);
            req.cmd_b.rand_mode(0);
            if (!req.randomize()) `uvm_error("SEQ", "RND FAIL")
            finish_item(req);
        endtask
    endclass

endpackage

