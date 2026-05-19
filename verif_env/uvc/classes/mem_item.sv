// ============================================================
// mem_item — Unified SRAM Transaction
// ============================================================
// web: 0=写, 1=读
// ============================================================

class mem_item #(int AW=10, int DW=32) extends uvm_sequence_item;
    `uvm_object_param_utils(mem_item #(AW, DW));

    rand logic [AW-1:0]         addr;
    rand logic [DW-1:0]         wdata;
    rand logic [DW-1:0]         wem;       // 0=write bit, 1=mask

    logic [DW-1:0]              rdata;     // read data (non-rand)

    constraint c_default { wem == '0; }

    function new(string name = "mem_item"); super.new(name); endfunction

    function void do_copy(uvm_object rhs);
        mem_item #(AW, DW) rhs_;
        if (!$cast(rhs_, rhs)) begin `uvm_error("mem_item","cast fail"); return; end
        super.do_copy(rhs);
        this.addr = rhs_.addr; this.wdata = rhs_.wdata;
        this.wem = rhs_.wem; this.rdata = rhs_.rdata;
    endfunction

    function bit do_compare(uvm_object rhs, uvm_comparer c);
        mem_item #(AW, DW) rhs_;
        if (!$cast(rhs_, rhs)) return 0;
        return (super.do_compare(rhs, c) &&
                addr == rhs_.addr && wdata == rhs_.wdata &&
                wem == rhs_.wem && rdata == rhs_.rdata);
    endfunction

    function string convert2string();
        return $sformatf("addr=0x%0h wdata=0x%0h wem=0x%0h rdata=0x%0h",
                         addr, wdata, wem, rdata);
    endfunction

    function void do_print(uvm_printer p);
        super.do_print(p);
        p.print_field("addr",  addr,  AW, UVM_HEX);
        p.print_field("wdata", wdata, DW, UVM_HEX);
        p.print_field("wem",   wem,   DW, UVM_HEX);
        p.print_field("rdata", rdata, DW, UVM_HEX);
    endfunction
endclass
