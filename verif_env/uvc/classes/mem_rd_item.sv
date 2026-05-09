// mem_rd_item
    class mem_rd_item #(int AW=10, int DW=32) extends uvm_sequence_item;
        `uvm_object_param_utils(mem_rd_item #(AW, DW))

        rand mem_cmd_e              cmd;       // MEM_READ or MEM_NOP
        rand logic [AW-1:0]         addr;

        constraint c_default { cmd == MEM_READ; }

        function new(string name = "mem_rd_item"); super.new(name); endfunction

        function void do_copy(uvm_object rhs);
            mem_rd_item #(AW, DW) rhs_;
            if (!$cast(rhs_, rhs)) begin `uvm_error("mem_rd_item","cast fail"); return; end
            super.do_copy(rhs);
            this.cmd = rhs_.cmd; this.addr = rhs_.addr;
        endfunction

        function bit do_compare(uvm_object rhs, uvm_comparer c);
            mem_rd_item #(AW, DW) rhs_;
            if (!$cast(rhs_, rhs)) return 0;
            return (super.do_compare(rhs, c) && cmd == rhs_.cmd && addr == rhs_.addr);
        endfunction

        function void do_print(uvm_printer p);
            super.do_print(p);
            p.print_field("cmd", cmd, 2, UVM_BIN);
            p.print_field("addr", addr, AW, UVM_HEX);
        endfunction
    endclass
