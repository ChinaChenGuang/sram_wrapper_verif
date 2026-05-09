// mem_wr_driver
    class mem_wr_driver #(int AW=10, int DW=32) extends uvm_driver #(mem_wr_item #(AW, DW));
        `uvm_component_param_utils(mem_wr_driver #(AW, DW))

        virtual mem_port_if #(16, 256) vif;
        logic [15:0] addr_mask;
        logic [255:0] data_mask, wem_mask;

        function new(string name, uvm_component parent); super.new(name, parent); endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            vif = global_wr_vif;
            if (vif == null) `uvm_fatal(get_type_name(), "global_wr_vif is null")
            addr_mask = (1 << AW) - 1;
            data_mask = (1 << DW) - 1;
            wem_mask  = (1 << DW) - 1;
        endfunction

        task run_phase(uvm_phase phase);
            mem_wr_item #(AW, DW) req;
            `uvm_info(get_type_name(), "Write driver started", UVM_LOW)
            forever begin
                seq_item_port.get_next_item(req);
                @(posedge vif.clk);
                vif.cmd   = req.cmd;
                vif.addr  = req.addr & addr_mask;
                vif.wdata = req.wdata & data_mask;
                vif.wem   = (req.wem & wem_mask) | ~wem_mask;
                seq_item_port.item_done();
            end
        endtask
    endclass
