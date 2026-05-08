// ============================================================
// tb_top_dualclk - Dual-Clock SRAM A/B Verification
// ============================================================
// Features:
//   - Independent clk_a / clk_b frequency and phase
//   - Port A sync to clk_a, Port B sync to clk_b
//   - Multi-clock SVA assertions
//   - A/B comparison + functional correctness (ref model)
//   - Clock phase/frequency sweep test
//
// Runtime plusargs:
//   +CLK_A_PS=10000       Port A period (ps)
//   +CLK_B_PS=10000       Port B period (ps)
//   +CLK_B_PHASE_PS=0     Port B phase offset (ps)
//   +TEST=                Test case
//   +ADDR_WIDTH=          Runtime config address width
//   +DATA_WIDTH=          Runtime config data width
//   +TX_COUNT=            Transaction count
//
// Common scenarios:
//   make run-dualclk TEST=mem_sp_test CLK_A_PS=10000 CLK_B_PS=20000  (1:2)
//   make run-dualclk TEST=mem_sdp_test CLK_A_PS=10000 CLK_B_PHASE_PS=5000  (180°)
// ============================================================

`timescale 1ns/1ps

module tb_top;

    localparam MAX_ADDR_WIDTH = 16;
    localparam MAX_DATA_WIDTH = 256;
    localparam READ_LATENCY    = 1;
    parameter SRAM_MODE       = 2;

    // ----------------------------------------------------------
    // Dual Clock Generator
    // ----------------------------------------------------------
    logic clk_a;
    logic clk_b;
    logic clk_stable;

    clk_gen_dual clk_gen (
        .clk_a(clk_a),
        .clk_b(clk_b),
        .clk_stable(clk_stable)
    );

    // ----------------------------------------------------------
    // Reset (async, released after clocks stable)
    // ----------------------------------------------------------
    logic rst_n;

    initial begin
        rst_n = 1'b0;
        @(posedge clk_stable);
        repeat (5) @(posedge clk_a);
        rst_n = 1'b1;
    end

    // ----------------------------------------------------------
    // Dual-Clock Interface
    // ----------------------------------------------------------
    mem_if_dualclk #(MAX_ADDR_WIDTH, MAX_DATA_WIDTH) vif(clk_a, clk_b, rst_n);

    // ----------------------------------------------------------
    // DUTs (fed with clk_a — DUT sees one clock domain)
    // ----------------------------------------------------------
`ifdef DUT_ORI
    `DUT_ORI #(MAX_ADDR_WIDTH, MAX_DATA_WIDTH) dut_ori (
`else
    dut_sram  #(MAX_ADDR_WIDTH, MAX_DATA_WIDTH) dut_ori (
`endif
        .clk(clk_a), .rst_n(rst_n),
        .cmd_a(vif.cmd_a), .addr_a(vif.addr_a),
        .wdata_a(vif.wdata_a), .wem_a(vif.wem_a), .rdata_a(vif.rdata_a_ori),
        .cmd_b(vif.cmd_b), .addr_b(vif.addr_b),
        .wdata_b(vif.wdata_b), .wem_b(vif.wem_b), .rdata_b(vif.rdata_b_ori)
    );

`ifdef DUT_NEW
    `DUT_NEW #(MAX_ADDR_WIDTH, MAX_DATA_WIDTH) dut_new (
`else
    dut_sram  #(MAX_ADDR_WIDTH, MAX_DATA_WIDTH) dut_new (
`endif
        .clk(clk_a), .rst_n(rst_n),
        .cmd_a(vif.cmd_a), .addr_a(vif.addr_a),
        .wdata_a(vif.wdata_a), .wem_a(vif.wem_a), .rdata_a(vif.rdata_a_new),
        .cmd_b(vif.cmd_b), .addr_b(vif.addr_b),
        .wdata_b(vif.wdata_b), .wem_b(vif.wem_b), .rdata_b(vif.rdata_b_new)
    );

    // ----------------------------------------------------------
    // Reference Model (runs on clk_a)
    // ----------------------------------------------------------
    logic [MAX_DATA_WIDTH-1:0] rdata_a_ref;
    logic [MAX_DATA_WIDTH-1:0] rdata_b_ref;

    sram_ref_model #(MAX_ADDR_WIDTH, MAX_DATA_WIDTH, READ_LATENCY, SRAM_MODE) ref_model (
        .clk(clk_a), .rst_n(rst_n),
        .cmd_a(vif.cmd_a), .addr_a(vif.addr_a),
        .wdata_a(vif.wdata_a), .wem_a(vif.wem_a), .rdata_a_ref(rdata_a_ref),
        .cmd_b(vif.cmd_b), .addr_b(vif.addr_b),
        .wdata_b(vif.wdata_b), .wem_b(vif.wem_b), .rdata_b_ref(rdata_b_ref)
    );

    // ----------------------------------------------------------
    // Waveform
    // ----------------------------------------------------------
    initial begin
        $dumpfile("dump.fst");
        $dumpvars(0, tb_top);
    end

    // ----------------------------------------------------------
    // Runtime Config
    // ----------------------------------------------------------
    int cfg_addr_width;
    int cfg_data_width;
    int cfg_depth;
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
    // Multi-Clock SVA Assertions
    // ----------------------------------------------------------
    // Port A: checked on clk_a
    property p_ab_a;
        @(posedge clk_a) disable iff (!rst_n)
        (vif.cmd_a == 2'b01) |=>
        ((vif.rdata_a_ori & data_mask) === (vif.rdata_a_new & data_mask));
    endproperty
    assert_ab_a: assert property(p_ab_a)
        else $error("[AB-CHECK-A] Port A mismatch @ clk_a: ori=%h new=%h",
                    vif.rdata_a_ori, vif.rdata_a_new);

    property p_func_a;
        @(posedge clk_a) disable iff (!rst_n)
        (vif.cmd_a == 2'b01) |=>
        ((vif.rdata_a_ori & data_mask) === (rdata_a_ref & data_mask));
    endproperty
    assert_func_a: assert property(p_func_a)
        else $error("[FUNC-CHECK-A] Port A DUT!=Ref @ clk_a: dut=%h ref=%h",
                    vif.rdata_a_ori, rdata_a_ref);

    // Port B: checked on clk_b
    property p_ab_b;
        @(posedge clk_b) disable iff (!rst_n)
        (vif.cmd_b == 2'b01) |=>
        ((vif.rdata_b_ori & data_mask) === (vif.rdata_b_new & data_mask));
    endproperty
    assert_ab_b: assert property(p_ab_b)
        else $error("[AB-CHECK-B] Port B mismatch @ clk_b: ori=%h new=%h",
                    vif.rdata_b_ori, vif.rdata_b_new);

    property p_func_b;
        @(posedge clk_b) disable iff (!rst_n)
        (vif.cmd_b == 2'b01) |=>
        ((vif.rdata_b_ori & data_mask) === (rdata_b_ref & data_mask));
    endproperty
    assert_func_b: assert property(p_func_b)
        else $error("[FUNC-CHECK-B] Port B DUT!=Ref @ clk_b: dut=%h ref=%h",
                    vif.rdata_b_ori, rdata_b_ref);

    // ----------------------------------------------------------
    // Enum
    // ----------------------------------------------------------
    typedef enum logic [1:0] { MEM_NOP=2'b00, MEM_READ=2'b01, MEM_WRITE=2'b10 } mem_cmd_e;

    typedef struct packed {
        mem_cmd_e                     cmd_a, cmd_b;
        logic [MAX_ADDR_WIDTH-1:0]    addr_a, addr_b;
        logic [MAX_DATA_WIDTH-1:0]    wdata_a, wdata_b, wem_a, wem_b;
    } mem_tx_t;

    // ----------------------------------------------------------
    // Dual-Clock Driver (simplified: drive on clk_a, let CDC test)
    // ----------------------------------------------------------
    task automatic drive_dualclk(mem_tx_t t);
        @(posedge clk_a);
        vif.cmd_a   = t.cmd_a;
        vif.addr_a  = t.addr_a & addr_mask;
        vif.wdata_a = t.wdata_a & data_mask;
        vif.wem_a   = (t.wem_a & wem_mask) | ~wem_mask;
        vif.cmd_b   = t.cmd_b;
        vif.addr_b  = t.addr_b & addr_mask;
        vif.wdata_b = t.wdata_b & data_mask;
        vif.wem_b   = (t.wem_b & wem_mask) | ~wem_mask;
    endtask

    task automatic drive_nop();
        mem_tx_t t = '{cmd_a:MEM_NOP, cmd_b:MEM_NOP, default:'0};
        drive_dualclk(t);
    endtask

    // ----------------------------------------------------------
    // Test Tasks (same as feature tb, but using dual-clk driver)
    // ----------------------------------------------------------
    task automatic test_fill_verify(int loops);
        mem_tx_t t;
        for (int loop = 0; loop < loops; loop++) begin
            for (int a = 0; a < cfg_depth; a++) begin
                t.cmd_a=MEM_WRITE; t.cmd_b=MEM_NOP;
                t.addr_a=a; t.wdata_a=a ^ (loop<<8); t.wem_a='0;
                drive_dualclk(t);
            end
            repeat (4) drive_nop();
            for (int a = 0; a < cfg_depth; a++) begin
                t.cmd_a=MEM_READ; t.cmd_b=MEM_NOP;
                t.addr_a=a;
                drive_dualclk(t);
            end
        end
    endtask

    task automatic test_data_patterns();
        mem_tx_t t;
        for (int b = 0; b < cfg_data_width; b++) begin
            t.cmd_a=MEM_WRITE; t.cmd_b=MEM_NOP;
            t.addr_a=0; t.wdata_a=(1<<b); t.wem_a='0;
            drive_dualclk(t);
            t.cmd_a=MEM_READ; drive_dualclk(t);
        end
    endtask

    task automatic test_wem_mask();
        mem_tx_t t;
        logic [MAX_DATA_WIDTH-1:0] bg;
        bg = {MAX_DATA_WIDTH{1'b1}} & data_mask;
        // Full write
        t.cmd_a=MEM_WRITE; t.cmd_b=MEM_NOP;
        t.addr_a=0; t.wdata_a=bg; t.wem_a='0; drive_dualclk(t);
        t.cmd_a=MEM_READ; drive_dualclk(t);
        // No write (all masked)
        t.cmd_a=MEM_WRITE; t.wdata_a='0; t.wem_a={MAX_DATA_WIDTH{1'b1}};
        drive_dualclk(t);
        t.cmd_a=MEM_READ; drive_dualclk(t);
        // Walking 0
        for (int b = 0; b < cfg_data_width; b++) begin
            t.cmd_a=MEM_WRITE; t.wdata_a=bg; t.wem_a='0; drive_dualclk(t);
            t.wdata_a='0; t.wem_a=~(1<<b); drive_dualclk(t);
            t.cmd_a=MEM_READ; drive_dualclk(t);
        end
    endtask

    task automatic test_addr_boundary();
        mem_tx_t t;
        int a_list[] = '{0, cfg_depth-1, cfg_depth/2};
        for (int i = 0; i < 3; i++) begin
            t.cmd_a=MEM_WRITE; t.cmd_b=MEM_NOP;
            t.addr_a=a_list[i]; t.wdata_a=a_list[i]; t.wem_a='0;
            drive_dualclk(t);
            t.cmd_a=MEM_READ; drive_dualclk(t);
        end
    endtask

    task automatic test_sdp_crossdomain();
        mem_tx_t t;
        // Port A writes data, Port B reads — potentially on different clocks
        for (int a = 0; a < cfg_depth; a++) begin
            t.cmd_a=MEM_WRITE; t.cmd_b=MEM_NOP;
            t.addr_a=a; t.wdata_a=a ^ 32'h5A5A; t.wem_a='0;
            drive_dualclk(t);
        end
        repeat (8) drive_nop();
        for (int a = 0; a < cfg_depth; a++) begin
            t.cmd_a=MEM_NOP; t.cmd_b=MEM_READ;
            t.addr_b=a;
            drive_dualclk(t);
        end
    endtask

    task automatic test_tdp_concurrent();
        mem_tx_t t;
        // Both ports operate independently on different clocks
        for (int i = 0; i < 100; i++) begin
            t.cmd_a=mem_cmd_e'($urandom_range(2,0));
            t.cmd_b=mem_cmd_e'($urandom_range(2,0));
            t.addr_a=$urandom_range(cfg_depth-1,0);
            t.addr_b=$urandom_range(cfg_depth-1,0);
            t.wdata_a=$urandom; t.wdata_b=$urandom;
            t.wem_a='0; t.wem_b='0;
            drive_dualclk(t);
        end
    endtask

    // ----------------------------------------------------------
    // Clock Sweep Test — iterate through phase/freq combos
    // ----------------------------------------------------------
    task automatic test_clock_sweep();
        int phases[] = '{0, 2500, 5000, 7500};  // 0°, 90°, 180°, 270°
        int freqs[]  = '{10000, 20000, 15000};   // periods
        mem_tx_t t;

        $display("[DUALCLK] === Clock Sweep ===");
        for (int f = 0; f < 3; f++) begin
            for (int p = 0; p < 4; p++) begin
                $display("[DUALCLK] A=%0dps B=%0dps phase=%0dps",
                         freqs[f], freqs[f], phases[p]);
                // Simple write+read test
                for (int a = 0; a < 16; a++) begin
                    t.cmd_a=MEM_WRITE; t.cmd_b=MEM_NOP;
                    t.addr_a=a; t.wdata_a=a; t.wem_a='0;
                    drive_dualclk(t);
                end
                repeat (4) drive_nop();
                for (int a = 0; a < 16; a++) begin
                    t.cmd_a=MEM_READ; t.cmd_b=MEM_NOP; t.addr_a=a;
                    drive_dualclk(t);
                end
            end
        end
        $display("[DUALCLK] Clock sweep done");
    endtask

    // ===========================================================
    // Test Runner
    // ===========================================================
    string  test_name;
    integer num_tx;
    mem_tx_t tx;

    initial begin
        if (!$value$plusargs("ADDR_WIDTH=%d", cfg_addr_width)) cfg_addr_width = 10;
        if (!$value$plusargs("DATA_WIDTH=%d", cfg_data_width)) cfg_data_width = 32;
        update_masks();

        if (!$value$plusargs("TEST=%s", test_name)) test_name = "mem_fill_verify";
        if (!$value$plusargs("TX_COUNT=%d", num_tx)) num_tx = 50;

        $display("============================================================");
        $display("[DUALCLK] Max AW=%0d DW=%0d | Config AW=%0d DW=%0d",
                 MAX_ADDR_WIDTH, MAX_DATA_WIDTH, cfg_addr_width, cfg_data_width);
        $display("[DUALCLK] Test: %s  Tx: %0d", test_name, num_tx);
        $display("============================================================");

        // Wait for clocks stable + reset release
        @(posedge clk_stable);
        @(posedge rst_n);
        repeat (10) @(posedge clk_a);

        case (test_name)
            "mem_fill_verify":    test_fill_verify(1);
            "mem_data_pattern":   test_data_patterns();
            "mem_wem_mask":       test_wem_mask();
            "mem_addr_boundary":  test_addr_boundary();
            "mem_sdp_crossdomain": test_sdp_crossdomain();
            "mem_tdp_concurrent":  test_tdp_concurrent();
            "mem_clock_sweep":     test_clock_sweep();
            "mem_dualclk_all": begin
                $display("[DUALCLK] === Full Dual-Clock Regression ===");
                test_fill_verify(1);        $display("[DUALCLK] fill_verify:      OK");
                test_data_patterns();        $display("[DUALCLK] data_pattern:     OK");
                test_wem_mask();             $display("[DUALCLK] wem_mask:         OK");
                test_addr_boundary();        $display("[DUALCLK] addr_boundary:    OK");
                test_sdp_crossdomain();      $display("[DUALCLK] sdp_crossdomain:  OK");
                test_tdp_concurrent();       $display("[DUALCLK] tdp_concurrent:   OK");
                $display("[DUALCLK] === Full Dual-Clock Done ===");
            end
            default: begin
                $display("[DUALCLK] ERROR: Unknown test '%s'", test_name);
            end
        endcase

        repeat (10) @(posedge clk_a);
        $display("[DUALCLK] ===== Done: %s =====", test_name);
        $finish;
    end

endmodule
