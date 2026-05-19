// ============================================================
// mem_env — SRAM Verification Environment
// ============================================================
// Contains two agents:
//   wr_agent — PORT_WRITE (drives wdata/wem)
//   rd_agent — PORT_READ  (drives read commands)
// ============================================================

class mem_env #(int AW=10, int DW=32, int MAX_AW=16, int MAX_DW=256) extends uvm_env;
    `uvm_component_param_utils(mem_env #(AW, DW, MAX_AW, MAX_DW));

    mem_agent #(AW, DW, MAX_AW, MAX_DW, PORT_WRITE) wr_agent;
    mem_agent #(AW, DW, MAX_AW, MAX_DW, PORT_READ)  rd_agent;
    int cfg_depth;

    function new(string n, uvm_component p); super.new(n, p); endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        wr_agent = mem_agent #(AW, DW, MAX_AW, MAX_DW, PORT_WRITE)::type_id::create("wr_agent", this);
        rd_agent = mem_agent #(AW, DW, MAX_AW, MAX_DW, PORT_READ) ::type_id::create("rd_agent", this);
        cfg_depth = 1 << AW;
    endfunction
endclass
