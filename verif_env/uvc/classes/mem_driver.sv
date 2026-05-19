// ============================================================
// mem_driver — Unified SRAM Driver
// ============================================================
// PORT_WRITE: drives ceb/web/addr/wdata/wem
// PORT_READ:  drives ceb/web/addr only
// ============================================================

class mem_driver #(
    int AW=10, int DW=32,
    int MAX_AW=16, int MAX_DW=256,
    port_type_e PORT_TYPE = PORT_WRITE
) extends uvm_driver #(mem_item #(AW, DW));

    `uvm_component_param_utils(mem_driver #(AW, DW, MAX_AW, MAX_DW, PORT_TYPE));

    virtual mem_port_if #(MAX_AW, MAX_DW) vif;
    logic [MAX_AW-1:0] addr_mask;
    logic [MAX_DW-1:0] data_mask, wem_mask;

    function new(string name, uvm_component parent); super.new(name, parent); endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (PORT_TYPE == PORT_WRITE) begin
            if (!uvm_config_db #(virtual mem_port_if #(MAX_AW,MAX_DW))::get(this, "", "port_a_vif", vif))
                `uvm_fatal(get_type_name(), "port_a_vif not found in config_db")
        end else begin
            if (!uvm_config_db #(virtual mem_port_if #(MAX_AW,MAX_DW))::get(this, "", "port_b_vif", vif))
                `uvm_fatal(get_type_name(), "port_b_vif not found in config_db")
        end
        addr_mask = (1 << AW) - 1;
        data_mask = (1 << DW) - 1;
        wem_mask  = (1 << DW) - 1;
    endfunction

    task run_phase(uvm_phase phase);
        mem_item #(AW, DW) req;
        string ps = (PORT_TYPE == PORT_WRITE) ? "WRITE" : "READ";
        `uvm_info(get_type_name(), $sformatf("Driver started (port=%s)", ps), UVM_LOW)
        forever begin
            seq_item_port.get_next_item(req);
            @(posedge vif.clk);
            // ceb=0 enable, web=0 write, web=1 read
            vif.ceb = 1'b0;
            if (PORT_TYPE == PORT_WRITE) begin
                vif.web  = 1'b0;  // write
                vif.addr = req.addr & addr_mask;
                vif.wdata = req.wdata & data_mask;
                vif.wem   = (req.wem & wem_mask) | ~wem_mask;
            end else begin
                vif.web  = 1'b1;  // read
                vif.addr = req.addr & addr_mask;
                vif.wdata = '0;
                vif.wem   = '1;  // all masked
            end
            seq_item_port.item_done();
        end
    endtask
endclass
