// ============================================================
// mem_item — Single Port SRAM Transaction
// ============================================================

class mem_item #(int AW=10, int DW=32) extends uvm_sequence_item;
    `uvm_object_param_utils(mem_item #(AW, DW));

    rand logic          ce;
    rand logic          we;
    rand logic [AW-1:0] addr;
    rand logic [DW-1:0] wdata;
    rand logic [DW-1:0] wem;
    logic      [DW-1:0] rdata;

    function new(string name = "mem_item"); super.new(name); endfunction

    // -------------------------------------------------------
    // Manual UVM Methods (No uvm_field macros)
    // -------------------------------------------------------
    function void do_copy(uvm_object rhs);
        mem_item #(AW, DW) rhs_;
        if (!$cast(rhs_, rhs)) begin `uvm_error("mem_item", "cast fail"); return; end
        super.do_copy(rhs);
        this.ce    = rhs_.ce;
        this.we    = rhs_.we;
        this.addr  = rhs_.addr;
        this.wdata = rhs_.wdata;
        this.wem   = rhs_.wem;
        this.rdata = rhs_.rdata;
    endfunction

    function bit do_compare(uvm_object rhs, uvm_comparer comparer);
        mem_item #(AW, DW) rhs_;
        if (!$cast(rhs_, rhs)) return 0;
        return (super.do_compare(rhs, comparer) &&
                ce    == rhs_.ce    &&
                we    == rhs_.we    &&
                addr  == rhs_.addr  &&
                wdata == rhs_.wdata &&
                wem   == rhs_.wem   &&
                rdata == rhs_.rdata);
    endfunction

    function void do_print(uvm_printer printer);
        super.do_print(printer);
        printer.print_field("ce",    ce,    1,  UVM_BIN);
        printer.print_field("we",    we,    1,  UVM_BIN);
        printer.print_field("addr",  addr,  AW, UVM_HEX);
        printer.print_field("wdata", wdata, DW, UVM_HEX);
        printer.print_field("wem",   wem,   DW, UVM_HEX);
        printer.print_field("rdata", rdata, DW, UVM_HEX);
    endfunction

    function string convert2string();
        return $sformatf("CE:%b WE:%b A:0x%0h WD:0x%0h WM:0x%0h RD:0x%0h",
                         ce, we, addr, wdata, wem, rdata);
    endfunction
endclass
