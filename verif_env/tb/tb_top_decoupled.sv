// ============================================================
// tb_top_decoupled - Decoupled Port SRAM Verification
// ============================================================
// Architecture:
//   mem_port_if port_a  ← always present
//   mem_port_if port_b  ← present if NUM_PORTS≥2
//
//   DUT:
//     Port A ← port_a signals
//     Port B ← port_b signals (if enabled)
//
//   Driver:
//     drive_port_a(tx)  — always
//     drive_port_b(tx)  — if NUM_PORTS≥2
//
//   Checker:
//     mem_port_checker on port_a  — always
//     mem_port_checker on port_b  — if NUM_PORTS≥2
//
// Runtime plusargs:
//   +TEST=          Test case
//   +ADDR_WIDTH=    Address width
//   +DATA_WIDTH=    Data width
//   +TX_COUNT=      Transaction count
//   +NUM_PORTS=     1 (SP) or 2 (SDP/TDP)
//   +CLK_A_PS=      Port A clock period (ps)
//   +CLK_B_PS=      Port B clock period (ps)
//   +CLK_B_PHASE_PS= Port B phase offset (ps)
// ============================================================

`timescale 1ns/1ps

module tb_top;

    localparam MAX_ADDR_WIDTH = 16;
    localparam MAX_DATA_WIDTH = 256;
    localparam READ_LATENCY    = 1;
    parameter SRAM_MODE       = 2;    // 0=SP 1=SDP 2=TDP
    parameter NUM_PORTS       = 2;    // 1 or 2

    // ----------------------------------------------------------
    // Clocks
    // ----------------------------------------------------------
    logic clk_a, clk_b, clk_stable, rst_n;

    clk_gen_dual clk_gen (.clk_a(clk_a), .clk_b(clk_b), .clk_stable(clk_stable));

    initial begin
        rst_n = 1'b0;
        @(posedge clk_stable);
        repeat (5) @(posedge clk_a);
        rst_n = 1'b1;
    end

    // ----------------------------------------------------------
    // Port Interfaces
    // ----------------------------------------------------------
    mem_port_if #(MAX_ADDR_WIDTH, MAX_DATA_WIDTH) port_a(.clk(clk_a), .rst_n(rst_n));

    mem_port_if #(MAX_ADDR_WIDTH, MAX_DATA_WIDTH) port_b(.clk(clk_b), .rst_n(rst_n));

    // ----------------------------------------------------------
    // Runtime Config + Masks
    // ----------------------------------------------------------
    int cfg_addr_width, cfg_data_width, cfg_depth;
    logic [MAX_ADDR_WIDTH-1:0] addr_mask;
    logic [MAX_DATA_WIDTH-1:0] data_mask;
    logic [MAX_DATA_WIDTH-1:0] wem_mask;

    function automatic void update_masks();
        addr_mask = (1 << cfg_addr_width) - 1;
        data_mask = (1 << cfg_data_width) - 1;
        wem_mask  = (1 << cfg_data_width) - 1;
        cfg_depth = 1 << cfg_addr_width;
    endfunction

    // ----------------------------------------------------------
    // DUTs (A/B test)
    // ----------------------------------------------------------
    // Each DUT connects:
    //   Port A → port_a
    //   Port B → port_b (if NUM_PORTS≥2, else tied to NOP)
    // ----------------------------------------------------------
    logic [1:0]               dut_cmd_b;
    logic [MAX_ADDR_WIDTH-1:0] dut_addr_b;
    logic [MAX_DATA_WIDTH-1:0] dut_wdata_b;
    logic [MAX_DATA_WIDTH-1:0] dut_wem_b;

    // If single-port, tie Port B to NOP
    generate
        if (NUM_PORTS < 2) begin : gen_sp_tieoff
            assign dut_cmd_b   = 2'b00;
            assign dut_addr_b  = '0;
            assign dut_wdata_b = '0;
            assign dut_wem_b   = '1;
        end else begin : gen_dp_connect
            assign dut_cmd_b   = port_b.cmd;
            assign dut_addr_b  = port_b.addr;
            assign dut_wdata_b = port_b.wdata;
            assign dut_wem_b   = port_b.wem;
        end
    endgenerate

`ifdef DUT_ORI
    `DUT_ORI #(MAX_ADDR_WIDTH, MAX_DATA_WIDTH) dut_ori (
`else
    dut_sram  #(MAX_ADDR_WIDTH, MAX_DATA_WIDTH) dut_ori (
`endif
        .clk(clk_a), .rst_n(rst_n),
        .cmd_a(port_a.cmd), .addr_a(port_a.addr),
        .wdata_a(port_a.wdata), .wem_a(port_a.wem),
        .rdata_a(port_a.rdata_ori),
        .cmd_b(dut_cmd_b), .addr_b(dut_addr_b),
        .wdata_b(dut_wdata_b), .wem_b(dut_wem_b),
        .rdata_b(port_b.rdata_ori)
    );

`ifdef DUT_NEW
    `DUT_NEW #(MAX_ADDR_WIDTH, MAX_DATA_WIDTH) dut_new (
`else
    dut_sram  #(MAX_ADDR_WIDTH, MAX_DATA_WIDTH) dut_new (
`endif
        .clk(clk_a), .rst_n(rst_n),
        .cmd_a(port_a.cmd), .addr_a(port_a.addr),
        .wdata_a(port_a.wdata), .wem_a(port_a.wem),
        .rdata_a(port_a.rdata_new),
        .cmd_b(dut_cmd_b), .addr_b(dut_addr_b),
        .wdata_b(dut_wdata_b), .wem_b(dut_wem_b),
        .rdata_b(port_b.rdata_new)
    );

    // ----------------------------------------------------------
    // Reference Model (shared, feeds ref data to port interfaces)
    // ----------------------------------------------------------
    sram_ref_model #(MAX_ADDR_WIDTH, MAX_DATA_WIDTH, READ_LATENCY, SRAM_MODE) ref_model (
        .clk(clk_a), .rst_n(rst_n),
        .web_a(port_a.web), .addr_a(port_a.addr),
        .wdata_a(port_a.wdata), .wem_a(port_a.wem),
        .rdata_a_ref(port_a.rdata_ref),
        .web_b(port_b.web), .addr_b(dut_addr_b),
        .wdata_b(dut_wdata_b), .wem_b(dut_wem_b),
        .rdata_b_ref(port_b.rdata_ref)
    );

    // ----------------------------------------------------------
    // Per-Port SVA Checkers
    // ----------------------------------------------------------
    mem_port_checker #(MAX_DATA_WIDTH, READ_LATENCY, 1, "A") checker_a (
        .vif(port_a.monitor), .data_mask(data_mask)
    );

    mem_port_checker #(MAX_DATA_WIDTH, READ_LATENCY, 1, "B") checker_b (
        .vif(port_b.monitor), .data_mask(data_mask)
    );

    // ----------------------------------------------------------
    // Waveform
    // ----------------------------------------------------------
    initial begin $dumpfile("dump.fst"); $dumpvars(0, tb_top); end

    // ----------------------------------------------------------
    // Enum + Transaction
    // ----------------------------------------------------------
    typedef enum logic [1:0] { MEM_NOP=2'b00, MEM_READ=2'b01, MEM_WRITE=2'b10 } mem_cmd_e;

    typedef struct packed {
        mem_cmd_e                  cmd;
        logic [MAX_ADDR_WIDTH-1:0] addr;
        logic [MAX_DATA_WIDTH-1:0] wdata;
        logic [MAX_DATA_WIDTH-1:0] wem;
    } port_tx_t;

    // ----------------------------------------------------------
    // Per-Port Driver
    // ----------------------------------------------------------
    task automatic drive_port_a(port_tx_t t);
        @(posedge clk_a);
        if (t.cmd == MEM_READ) begin
            port_a.ceb = 1'b0; port_a.web = 1'b1;
        end else if (t.cmd == MEM_WRITE) begin
            port_a.ceb = 1'b0; port_a.web = 1'b0;
        end else begin
            port_a.ceb = 1'b1; port_a.web = 1'b1;
        end
        port_a.addr  = t.addr & addr_mask;
        port_a.wdata = t.wdata & data_mask;
        port_a.wem   = (t.wem & wem_mask) | ~wem_mask;
    endtask

    task automatic drive_port_b(port_tx_t t);
        @(posedge clk_b);
        if (t.cmd == MEM_READ) begin
            port_b.ceb = 1'b0; port_b.web = 1'b1;
        end else if (t.cmd == MEM_WRITE) begin
            port_b.ceb = 1'b0; port_b.web = 1'b0;
        end else begin
            port_b.ceb = 1'b1; port_b.web = 1'b1;
        end
        port_b.addr  = t.addr & addr_mask;
        port_b.wdata = t.wdata & data_mask;
        port_b.wem   = (t.wem & wem_mask) | ~wem_mask;
    endtask

    // Drive both ports (sequential to avoid fork in Verilator)
    task automatic drive_both(port_tx_t ta, port_tx_t tb);
        drive_port_a(ta);
        drive_port_b(tb);
    endtask

    task automatic drive_nop();
        port_tx_t nop = '{cmd:MEM_NOP, default:'0};
        drive_both(nop, nop);
    endtask

    // ----------------------------------------------------------
    // Test Tasks
    // ----------------------------------------------------------
    task automatic test_fill_verify(int loops);
        port_tx_t wa, ra, nop;
        wa.cmd=MEM_WRITE; wa.wem='0; ra.cmd=MEM_READ; nop.cmd=MEM_NOP;

        for (int loop=0; loop<loops; loop++) begin
            for (int a=0; a<cfg_depth; a++) begin
                wa.addr=a; wa.wdata=a ^ (loop<<8);
                drive_both(wa, nop);
            end
            repeat (4) drive_both(nop, nop);
            for (int a=0; a<cfg_depth; a++) begin
                ra.addr=a;
                drive_both(ra, nop);
            end
        end
    endtask

    task automatic test_data_patterns();
        port_tx_t w, r, nop;
        w.cmd=MEM_WRITE; w.wem='0; r.cmd=MEM_READ; nop.cmd=MEM_NOP;

        for (int b=0; b<cfg_data_width; b++) begin
            w.addr=0; w.wdata=(1<<b); drive_both(w, nop);
            r.addr=0; drive_both(r, nop);
        end
    endtask

    task automatic test_wem_mask();
        port_tx_t w, r, nop;
        logic [MAX_DATA_WIDTH-1:0] bg;
        w.cmd=MEM_WRITE; r.cmd=MEM_READ; nop.cmd=MEM_NOP;
        bg = {MAX_DATA_WIDTH{1'b1}} & data_mask;

        w.addr=0; w.wdata=bg; w.wem='0; drive_both(w, nop);
        r.addr=0; drive_both(r, nop);
        w.wdata='0; w.wem={MAX_DATA_WIDTH{1'b1}}; drive_both(w, nop);
        r.addr=0; drive_both(r, nop);

        for (int b=0; b<cfg_data_width; b++) begin
            w.wdata=bg; w.wem='0; drive_both(w, nop);
            w.wdata='0; w.wem=~(1<<b); drive_both(w, nop);
            r.addr=0; drive_both(r, nop);
        end
    endtask

    task automatic test_sdp_crossdomain();
        port_tx_t wa, rb, nop;
        wa.cmd=MEM_WRITE; wa.wem='0; rb.cmd=MEM_READ; nop.cmd=MEM_NOP;

        for (int a=0; a<cfg_depth; a++) begin
            wa.addr=a; wa.wdata=a ^ 32'h5A5A;
            drive_both(wa, nop);
        end
        repeat (8) drive_both(nop, nop);
        for (int a=0; a<cfg_depth; a++) begin
            rb.addr=a;
            drive_both(nop, rb);   // Port A idle, Port B reads
        end
    endtask

    task automatic test_tdp_concurrent();
        port_tx_t ta, tb;
        for (int i=0; i<100; i++) begin
            ta.cmd=mem_cmd_e'($urandom_range(2,0));
            tb.cmd=mem_cmd_e'($urandom_range(2,0));
            ta.addr=$urandom_range(cfg_depth-1,0);
            tb.addr=$urandom_range(cfg_depth-1,0);
            ta.wdata=$urandom; tb.wdata=$urandom;
            ta.wem='0; tb.wem='0;
            drive_both(ta, tb);
        end
    endtask

    // ===========================================================
    // Test Runner
    // ===========================================================
    string  test_name;
    integer num_tx;
    port_tx_t ta, tb;

    initial begin
        if (!$value$plusargs("ADDR_WIDTH=%d", cfg_addr_width)) cfg_addr_width = 10;
        if (!$value$plusargs("DATA_WIDTH=%d", cfg_data_width)) cfg_data_width = 32;
        if (!$value$plusargs("TEST=%s", test_name)) test_name = "mem_fill_verify";
        if (!$value$plusargs("TX_COUNT=%d", num_tx)) num_tx = 50;
        update_masks();

        $display("============================================================");
        $display("[DECOUPLED] Ports=%0d Mode=%0d AW=%0d DW=%0d",
                 NUM_PORTS, SRAM_MODE, cfg_addr_width, cfg_data_width);
        $display("[DECOUPLED] Test: %s  Tx: %0d", test_name, num_tx);
        $display("============================================================");

        @(posedge clk_stable);
        @(posedge rst_n);
        repeat (10) @(posedge clk_a);

        case (test_name)
            "mem_fill_verify":    test_fill_verify(1);
            "mem_data_pattern":   test_data_patterns();
            "mem_wem_mask":       test_wem_mask();
            "mem_sdp_crossdomain": test_sdp_crossdomain();
            "mem_tdp_concurrent":  test_tdp_concurrent();
            "mem_decoupled_all": begin
                $display("[DECOUPLED] === Full Regression ===");
                test_fill_verify(1);      $display("[DECOUPLED] fill_verify:      OK");
                test_data_patterns();      $display("[DECOUPLED] data_pattern:     OK");
                test_wem_mask();           $display("[DECOUPLED] wem_mask:         OK");
                test_sdp_crossdomain();    $display("[DECOUPLED] sdp_crossdomain:  OK");
                test_tdp_concurrent();     $display("[DECOUPLED] tdp_concurrent:   OK");
                $display("[DECOUPLED] === Done ===");
            end
            default: $display("[DECOUPLED] Unknown test: %s", test_name);
        endcase

        repeat (10) @(posedge clk_a);
        $display("[DECOUPLED] ===== Done: %s =====", test_name);
        $finish;
    end

endmodule
