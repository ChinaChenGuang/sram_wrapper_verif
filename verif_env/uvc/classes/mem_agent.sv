// ============================================================
// mem_agent — Single Port SRAM Agent
// ============================================================

class mem_agent #(
    int AW=10, int DW=32,
    int MAX_AW=16, int MAX_DW=256
) extends uvm_agent;

    `uvm_component_param_utils(mem_agent #(AW, DW, MAX_AW, MAX_DW));

    mem_driver    #(AW, DW, MAX_AW, MAX_DW) drv;
    mem_sequencer #(AW, DW)                 sqr;

    function new(string n, uvm_component p); super.new(n, p); endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        drv = mem_driver    #(AW, DW, MAX_AW, MAX_DW)::type_id::create("drv", this);
        sqr = mem_sequencer #(AW, DW)::type_id::create("sqr", this);
    endfunction

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        drv.seq_item_port.connect(sqr.seq_item_export);
    endfunction
endclass
