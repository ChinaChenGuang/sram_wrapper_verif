// ============================================================
// mem_driver — Single Port SRAM Driver
// ============================================================

class mem_driver #(
    int AW=10, int DW=32,
    int MAX_AW=16, int MAX_DW=256
) extends uvm_driver #(mem_item #(AW, DW));

    `uvm_component_param_utils(mem_driver #(AW, DW, MAX_AW, MAX_DW));

    virtual mem_if #(MAX_AW, MAX_DW) vif;

    function new(string name, uvm_component parent); super.new(name, parent); endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db #(virtual mem_if #(MAX_AW, MAX_DW))::get(this, "", "vif", vif))
            `uvm_fatal(get_type_name(), "vif not found in config_db")
    endfunction

    task run_phase(uvm_phase phase);
        mem_item #(AW, DW) req;
        `uvm_info(get_type_name(), "Driver started", UVM_LOW)
        
        // Initial state (Inactive)
        vif.ce    <= 1'b1; // Active low
        vif.we    <= 1'b1; // Active low
        vif.addr  <= '0;
        vif.wdata <= '0;
        vif.wem   <= '1;

        // Wait for reset to deassert and wait a few clocks
        wait (vif.rst_n === 1'b1);
        repeat (5) @(posedge vif.clk);

        forever begin
            seq_item_port.get_next_item(req);
            @(posedge vif.clk);
            
            vif.ce    <= req.ce;
            vif.we    <= req.we;
            vif.addr  <= req.addr;
            vif.wdata <= req.wdata;
            vif.wem   <= req.wem;

`ifdef ENV_DEBUG
            if (req.ce == 1'b0) begin
                `uvm_info("DRV_DEBUG", $sformatf("Driving Port -> CE:%b WE:%b ADDR:0x%0h WDATA:0x%0h WEM:0x%0h", 
                                                 req.ce, req.we, req.addr, req.wdata, req.wem), UVM_NONE)
            end
`endif

            seq_item_port.item_done();
        end
    endtask
endclass
