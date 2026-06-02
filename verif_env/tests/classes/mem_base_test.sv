// ============================================================
// mem_base_test — Base UVM Test
// ============================================================

class mem_base_test #(int AW=10, int DW=32, int MAX_AW=16, int MAX_DW=256) extends uvm_test;
    `uvm_component_param_utils(mem_base_test #(AW, DW, MAX_AW, MAX_DW));
    mem_env #(AW, DW, MAX_AW, MAX_DW) env;
    function new(string n, uvm_component p); super.new(n, p); endfunction
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        env = mem_env #(AW, DW, MAX_AW, MAX_DW)::type_id::create("env", this);
    endfunction

    task run_phase(uvm_phase phase);
        super.run_phase(phase);
        phase.get_objection().set_drain_time(this, 50ns);
    endtask

    function void report_phase(uvm_phase phase);
        uvm_report_server server;
        int err_num;
        super.report_phase(phase);
        
        server = uvm_report_server::get_server();
        err_num = server.get_severity_count(UVM_ERROR) + server.get_severity_count(UVM_FATAL);
        
        if (err_num == 0) begin
            $display("\n=======================================================");
            $display("    ____   ___    ____  ____ ");
            $display("   |  _ \\ / _ \\  / ___|/ ___|");
            $display("   | |_) | |_| |  \\___ \\\\___ \\ ");
            $display("   |  __/|  _  |   ___) |___) |");
            $display("   |_|   |_| |_|  |____/|____/ ");
            $display("=======================================================\n");
        end else begin
            $display("\n=======================================================");
            $display("    _____  _    ___ _     ");
            $display("   |  ___|/ \\  |_ _| |    ");
            $display("   | |_  / _ \\  | || |    ");
            $display("   |  _|/ ___ \\ | || |___ ");
            $display("   |_| /_/   \\_\\___|_____|");
            $display("=======================================================\n");
        end
    endfunction
endclass
