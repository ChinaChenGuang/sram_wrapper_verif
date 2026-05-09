// mem_rd_only_seq — Read-only helper sequence
class mem_rd_only_seq #(int AW=10, int DW=32) extends mem_base_seq #(AW, DW);
    `uvm_object_param_utils(mem_rd_only_seq #(AW, DW))
    function new(string n="mem_rd_only_seq"); super.new(n); endfunction
    task body();
        mem_rd_item #(AW, DW) rd;
        for (int i = 0; i < num_tx; i++) begin
            rd = mem_rd_item #(AW, DW)::type_id::create("rd");
            start_item(rd);
            void'(rd.randomize() with { addr == (i*2+1) % depth; });
            finish_item(rd);
        end
    endtask
endclass
