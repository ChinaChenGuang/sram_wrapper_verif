// mem_rd_driver
    class mem_rd_driver #(int AW=10, int DW=32) extends uvm_driver #(mem_rd_item #(AW, DW));
        `uvm_component_param_utils(mem_rd_driver #(AW, DW))

        virtual mem_port_if #(16, 256) vif;
        logic [15:0] addr_mask;

        function new(string name, uvm_component parent); super.new(name, parent); endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            vif = global_rd_vif;
            if (vif == null) `uvm_fatal(get_type_name(), "global_rd_vif is null")
            addr_mask = (1 << AW) - 1;
        endfunction

        task run_phase(uvm_phase phase);
            mem_rd_item #(AW, DW) req;
            `uvm_info(get_type_name(), "Read driver started", UVM_LOW)
            forever begin
                seq_item_port.get_next_item(req);
                @(posedge vif.clk);
                vif.cmd  = req.cmd;
                vif.addr = req.addr & addr_mask;
                seq_item_port.item_done();
            end
        endtask
    endclass
