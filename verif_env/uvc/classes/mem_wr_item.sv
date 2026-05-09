// mem_wr_item
    class mem_wr_item #(int AW=10, int DW=32) extends uvm_sequence_item;
        `uvm_object_param_utils(mem_wr_item #(AW, DW))

        rand mem_cmd_e              cmd;       // MEM_WRITE or MEM_NOP
        rand logic [AW-1:0]         addr;
        rand logic [DW-1:0]         wdata;
        rand logic [DW-1:0]         wem;       // 0=write, 1=mask

        // Constraint: default to write with full-word mask
        constraint c_default {
            cmd == MEM_WRITE;
            wem == '0;
        }

        function new(string name = "mem_wr_item"); super.new(name); endfunction

        function void do_copy(uvm_object rhs);
            mem_wr_item #(AW, DW) rhs_;
            if (!$cast(rhs_, rhs)) begin `uvm_error("mem_wr_item","cast fail"); return; end
            super.do_copy(rhs);
            this.cmd = rhs_.cmd; this.addr = rhs_.addr;
            this.wdata = rhs_.wdata; this.wem = rhs_.wem;
        endfunction

        function bit do_compare(uvm_object rhs, uvm_comparer c);
            mem_wr_item #(AW, DW) rhs_;
            if (!$cast(rhs_, rhs)) return 0;
            return (super.do_compare(rhs, c) &&
                    cmd == rhs_.cmd && addr == rhs_.addr &&
                    wdata == rhs_.wdata && wem == rhs_.wem);
        endfunction

        function void do_print(uvm_printer p);
            super.do_print(p);
            p.print_field("cmd", cmd, 2, UVM_BIN);
            p.print_field("addr", addr, AW, UVM_HEX);
            p.print_field("wdata", wdata, DW, UVM_HEX);
            p.print_field("wem", wem, DW, UVM_HEX);
        endfunction
    endclass
