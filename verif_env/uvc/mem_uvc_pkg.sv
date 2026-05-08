// ============================================================
// mem_uvc_pkg — SRAM UVC Package (UVM 1.2)
// ============================================================
// Components:
//   mem_item       — Transaction (carries both Port A & B)
//   mem_driver     — Drives mem_port_if port_a + port_b
//   mem_sequencer  — Standard sequencer
//   mem_agent      — Active agent (driver + sequencer)
//   mem_env        — Top-level environment
// ============================================================

`ifndef MEM_UVC_PKG_SV
`define MEM_UVC_PKG_SV

package mem_uvc_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"

    // ============================================================
    // Constants
    // ============================================================
    typedef enum logic [1:0] {
        MEM_NOP   = 2'b00,
        MEM_READ  = 2'b01,
        MEM_WRITE = 2'b10
    } mem_cmd_e;

    typedef enum int {
        SRAM_SP  = 0,
        SRAM_SDP = 1,
        SRAM_TDP = 2
    } sram_type_e;

    // ============================================================
    // mem_item — Transaction Item
    // ============================================================
    class mem_item #(
        parameter int ADDR_WIDTH = 10,
        parameter int DATA_WIDTH = 32
    ) extends uvm_sequence_item;

        // Port A
        rand mem_cmd_e              cmd_a;
        rand logic [ADDR_WIDTH-1:0] addr_a;
        rand logic [DATA_WIDTH-1:0] wdata_a;
        rand logic [DATA_WIDTH-1:0] wem_a;      // 0=write, 1=mask

        // Port B
        rand mem_cmd_e              cmd_b;
        rand logic [ADDR_WIDTH-1:0] addr_b;
        rand logic [DATA_WIDTH-1:0] wdata_b;
        rand logic [DATA_WIDTH-1:0] wem_b;      // 0=write, 1=mask

        // wem defaults to 0 (full-word write)
        // Constraints are set per-sequence via randomize() with {}

        `uvm_object_param_utils_begin(mem_item #(ADDR_WIDTH, DATA_WIDTH))
        `uvm_object_utils_end

        function new(string name = "mem_item");
            super.new(name);
        endfunction

        // ——— Inline do_* (GEMINI.md rule: NO extern, NO uvm_field macros) ———

        function void do_copy(uvm_object rhs);
            mem_item #(ADDR_WIDTH, DATA_WIDTH) rhs_;
            if (!$cast(rhs_, rhs)) begin
                `uvm_error(get_type_name(), "do_copy cast failed")
                return;
            end
            super.do_copy(rhs);
            this.cmd_a   = rhs_.cmd_a;
            this.cmd_b   = rhs_.cmd_b;
            this.addr_a  = rhs_.addr_a;
            this.addr_b  = rhs_.addr_b;
            this.wdata_a = rhs_.wdata_a;
            this.wdata_b = rhs_.wdata_b;
            this.wem_a   = rhs_.wem_a;
            this.wem_b   = rhs_.wem_b;
        endfunction

        function bit do_compare(uvm_object rhs, uvm_comparer comparer);
            mem_item #(ADDR_WIDTH, DATA_WIDTH) rhs_;
            if (!$cast(rhs_, rhs)) return 0;
            return (super.do_compare(rhs, comparer) &&
                    this.cmd_a   == rhs_.cmd_a   &&
                    this.cmd_b   == rhs_.cmd_b   &&
                    this.addr_a  == rhs_.addr_a  &&
                    this.addr_b  == rhs_.addr_b  &&
                    this.wdata_a == rhs_.wdata_a &&
                    this.wdata_b == rhs_.wdata_b &&
                    this.wem_a   == rhs_.wem_a   &&
                    this.wem_b   == rhs_.wem_b);
        endfunction

        function string convert2string();
            return $sformatf("cmd_a=%0d cmd_b=%0d  addr_a=0x%0h addr_b=0x%0h  wdata_a=0x%0h wdata_b=0x%0h  wem_a=0x%0h wem_b=0x%0h",
                             cmd_a, cmd_b, addr_a, addr_b, wdata_a, wdata_b, wem_a, wem_b);
        endfunction

        function void do_print(uvm_printer printer);
            super.do_print(printer);
            printer.print_field("cmd_a",   this.cmd_a,   2, UVM_BIN);
            printer.print_field("cmd_b",   this.cmd_b,   2, UVM_BIN);
            printer.print_field("addr_a",  this.addr_a,  ADDR_WIDTH, UVM_HEX);
            printer.print_field("addr_b",  this.addr_b,  ADDR_WIDTH, UVM_HEX);
            printer.print_field("wdata_a", this.wdata_a, DATA_WIDTH, UVM_HEX);
            printer.print_field("wdata_b", this.wdata_b, DATA_WIDTH, UVM_HEX);
            printer.print_field("wem_a",   this.wem_a,   DATA_WIDTH, UVM_HEX);
            printer.print_field("wem_b",   this.wem_b,   DATA_WIDTH, UVM_HEX);
        endfunction

    endclass : mem_item


    // ============================================================
    // mem_driver — Drives both port_a and port_b
    // ============================================================
    class mem_driver #(
        parameter int ADDR_WIDTH = 10,
        parameter int DATA_WIDTH = 32
    ) extends uvm_driver #(mem_item #(ADDR_WIDTH, DATA_WIDTH));

        `uvm_component_param_utils(mem_driver #(ADDR_WIDTH, DATA_WIDTH))

        // Virtual interfaces (set via config_db)
        virtual mem_port_if #(ADDR_WIDTH, DATA_WIDTH) port_a_vif;
        virtual mem_port_if #(ADDR_WIDTH, DATA_WIDTH) port_b_vif;

        // Runtime mask (set by env, per config)
        logic [ADDR_WIDTH-1:0] addr_mask;
        logic [DATA_WIDTH-1:0] data_mask;
        logic [DATA_WIDTH-1:0] wem_mask;

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            // Virtual interfaces set via config_db by tb_top
            void'(uvm_config_db #(virtual mem_port_if #(ADDR_WIDTH, DATA_WIDTH))::get(
                    this, "", "port_a_vif", port_a_vif));
            void'(uvm_config_db #(virtual mem_port_if #(ADDR_WIDTH, DATA_WIDTH))::get(
                    this, "", "port_b_vif", port_b_vif));
        endfunction

        function void set_masks(int cfg_aw, int cfg_dw);
            addr_mask = (1 << cfg_aw) - 1;
            data_mask = (1 << cfg_dw) - 1;
            wem_mask  = (1 << cfg_dw) - 1;
        endfunction

        // Drive both ports (sequential to avoid fork in Verilator)
        task run_phase(uvm_phase phase);
            mem_item #(ADDR_WIDTH, DATA_WIDTH) req;
            `uvm_info(get_type_name(), "Driver started", UVM_LOW)

            forever begin
                seq_item_port.get_next_item(req);

                // Drive Port A
                @(posedge port_a_vif.clk);
                port_a_vif.cmd   = req.cmd_a;
                port_a_vif.addr  = req.addr_a & addr_mask;
                port_a_vif.wdata = req.wdata_a & data_mask;
                port_a_vif.wem   = (req.wem_a & wem_mask) | ~wem_mask;

                // Drive Port B
                @(posedge port_b_vif.clk);
                port_b_vif.cmd   = req.cmd_b;
                port_b_vif.addr  = req.addr_b & addr_mask;
                port_b_vif.wdata = req.wdata_b & data_mask;
                port_b_vif.wem   = (req.wem_b & wem_mask) | ~wem_mask;

                seq_item_port.item_done();
            end
        endtask

    endclass : mem_driver


    // ============================================================
    // mem_sequencer — Standard sequencer
    // ============================================================
    class mem_sequencer #(
        parameter int ADDR_WIDTH = 10,
        parameter int DATA_WIDTH = 32
    ) extends uvm_sequencer #(mem_item #(ADDR_WIDTH, DATA_WIDTH));

        `uvm_component_param_utils(mem_sequencer #(ADDR_WIDTH, DATA_WIDTH))

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

    endclass : mem_sequencer


    // ============================================================
    // mem_agent — Active agent (driver + sequencer)
    // ============================================================
    class mem_agent #(
        parameter int ADDR_WIDTH = 10,
        parameter int DATA_WIDTH = 32
    ) extends uvm_agent;

        `uvm_component_param_utils(mem_agent #(ADDR_WIDTH, DATA_WIDTH))

        mem_driver    #(ADDR_WIDTH, DATA_WIDTH) drv;
        mem_sequencer #(ADDR_WIDTH, DATA_WIDTH) sqr;

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            drv = mem_driver    #(ADDR_WIDTH, DATA_WIDTH)::type_id::create("drv", this);
            sqr = mem_sequencer #(ADDR_WIDTH, DATA_WIDTH)::type_id::create("sqr", this);
        endfunction

        function void connect_phase(uvm_phase phase);
            super.connect_phase(phase);
            drv.seq_item_port.connect(sqr.seq_item_export);
        endfunction

    endclass : mem_agent


    // ============================================================
    // mem_env — Top-level environment
    // ============================================================
    class mem_env #(
        parameter int ADDR_WIDTH = 10,
        parameter int DATA_WIDTH = 32
    ) extends uvm_env;

        `uvm_component_param_utils(mem_env #(ADDR_WIDTH, DATA_WIDTH))

        mem_agent #(ADDR_WIDTH, DATA_WIDTH) agent;

        // Runtime configuration
        int cfg_addr_width = 10;
        int cfg_data_width = 32;
        int cfg_depth      = 1024;

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            agent = mem_agent #(ADDR_WIDTH, DATA_WIDTH)::type_id::create("agent", this);

            // Read config from plusargs or config_db
            void'($value$plusargs("ADDR_WIDTH=%d",  cfg_addr_width));
            void'($value$plusargs("DATA_WIDTH=%d",  cfg_data_width));
            cfg_depth = 1 << cfg_addr_width;

            // Pass masks to driver
            uvm_config_db #(int)::set(this, "agent.drv", "cfg_addr_width", cfg_addr_width);
            uvm_config_db #(int)::set(this, "agent.drv", "cfg_data_width", cfg_data_width);
        endfunction

        function void end_of_elaboration_phase(uvm_phase phase);
            super.end_of_elaboration_phase(phase);
            // Set driver masks after config is resolved
            agent.drv.set_masks(cfg_addr_width, cfg_data_width);
        endfunction

    endclass : mem_env

endpackage : mem_uvc_pkg

`endif // MEM_UVC_PKG_SV
