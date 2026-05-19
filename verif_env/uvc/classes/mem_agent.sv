// ============================================================
// mem_agent — Unified SRAM Agent
// ============================================================
// Parameterized by port_type:
//   PORT_WRITE → drives cmd/addr/wdata/wem
//   PORT_READ  → drives cmd/addr only
// ============================================================

class mem_agent #(
    int AW=10, int DW=32,
    int MAX_AW=16, int MAX_DW=256,
    port_type_e PORT_TYPE = PORT_WRITE
) extends uvm_agent;

    `uvm_component_param_utils(mem_agent #(AW, DW, MAX_AW, MAX_DW, PORT_TYPE));

    mem_driver    #(AW, DW, MAX_AW, MAX_DW, PORT_TYPE) drv;
    mem_sequencer #(AW, DW)            sqr;

    function new(string n, uvm_component p); super.new(n, p); endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        drv = mem_driver    #(AW, DW, MAX_AW, MAX_DW, PORT_TYPE)::type_id::create("drv", this);
        sqr = mem_sequencer #(AW, DW)::type_id::create("sqr", this);
    endfunction

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        drv.seq_item_port.connect(sqr.seq_item_export);
    endfunction
endclass
