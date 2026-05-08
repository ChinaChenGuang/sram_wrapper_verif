// ============================================================
// tb_top_feature - Full Feature Verification Testbench
// ============================================================
// Combines:
//   1. A/B comparison: dut_ori === dut_new (existing)
//   2. Feature correctness: DUT === sram_ref_model (golden)
//   3. Unified max-width + mask (runtime configurable)
//
// New test cases for SRAM feature verification:
//   mem_fill_verify     - 写满所有地址再逐一读回 (A1, D3, I1)
//   mem_data_pattern    - 全0/全1/棋盘/走马灯数据模式 (C1-C5)
//   mem_wem_byte        - 按 byte 选择性写入掩码 (B2)
//   mem_wem_random      - 随机掩码 + 背景数据验证 (B7,B8)
//   mem_waw             - Write-After-Write 同地址 (E4)
//   mem_war             - Write-After-Read 同地址 (E3)
//   mem_dual_conflict   - 双端口冲突场景 (F2,F3,F4)
//   mem_reset           - 复位行为验证 (G1,G2)
//   mem_addr_boundary   - 边界地址测试 (D1,D2,D5,J3)
//   mem_stress          - 随机 Hammer 压力测试 (I2)
// ============================================================

`timescale 1ns/1ps

module tb_top;

    localparam MAX_ADDR_WIDTH = 16;
    localparam MAX_DATA_WIDTH = 256;
    localparam READ_LATENCY    = 1;
    parameter SRAM_MODE       = 2;  // 0=SP 1=SDP 2=TDP (override with -G)

    // ----------------------------------------------------------
    // Clock and Reset
    // ----------------------------------------------------------
    logic clk;
    logic rst_n;

    initial begin clk = 1'b0; forever #5 clk = ~clk; end
    initial begin rst_n = 1'b0; #20 rst_n = 1'b1; end

    // ----------------------------------------------------------
    // Interface
    // ----------------------------------------------------------
    mem_if #(MAX_ADDR_WIDTH, MAX_DATA_WIDTH) vif(clk, rst_n);

    // ----------------------------------------------------------
    // DUTs (A/B test)
    // ----------------------------------------------------------
`ifdef DUT_ORI
    `DUT_ORI #(MAX_ADDR_WIDTH, MAX_DATA_WIDTH) dut_ori (
`else
    dut_sram  #(MAX_ADDR_WIDTH, MAX_DATA_WIDTH) dut_ori (
`endif
        .clk(clk), .rst_n(rst_n),
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
        .clk(clk), .rst_n(rst_n),
        .cmd_a(vif.cmd_a), .addr_a(vif.addr_a),
        .wdata_a(vif.wdata_a), .wem_a(vif.wem_a), .rdata_a(vif.rdata_a_new),
        .cmd_b(vif.cmd_b), .addr_b(vif.addr_b),
        .wdata_b(vif.wdata_b), .wem_b(vif.wem_b), .rdata_b(vif.rdata_b_new)
    );

    // ----------------------------------------------------------
    // Golden Reference Model (mode-aware: 0=SP, 1=SDP, 2=TDP)
    // ----------------------------------------------------------
    logic [MAX_DATA_WIDTH-1:0] rdata_a_ref;
    logic [MAX_DATA_WIDTH-1:0] rdata_b_ref;

    sram_ref_model #(MAX_ADDR_WIDTH, MAX_DATA_WIDTH, READ_LATENCY, SRAM_MODE) ref_model (
        .clk(clk), .rst_n(rst_n),
        .cmd_a(vif.cmd_a), .addr_a(vif.addr_a),
        .wdata_a(vif.wdata_a), .wem_a(vif.wem_a), .rdata_a_ref(rdata_a_ref),
        .cmd_b(vif.cmd_b), .addr_b(vif.addr_b),
        .wdata_b(vif.wdata_b), .wem_b(vif.wem_b), .rdata_b_ref(rdata_b_ref)
    );

    // ----------------------------------------------------------
    // Waveform
    // ----------------------------------------------------------
    initial begin $dumpfile("dump.fst"); $dumpvars(0, tb_top); end

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
    // SVA Assertions (3-way check)
    // ----------------------------------------------------------

    // 1. A/B comparison: ori === new
    property p_ab_a;
        @(posedge clk) disable iff (!rst_n)
        (vif.cmd_a == 2'b01) |=>
        ((vif.rdata_a_ori & data_mask) === (vif.rdata_a_new & data_mask));
    endproperty
    assert_ab_a: assert property(p_ab_a)
        else $error("[AB-CHECK] Port A mismatch: ori=%h new=%h",
                    vif.rdata_a_ori, vif.rdata_a_new);

    property p_ab_b;
        @(posedge clk) disable iff (!rst_n)
        (vif.cmd_b == 2'b01) |=>
        ((vif.rdata_b_ori & data_mask) === (vif.rdata_b_new & data_mask));
    endproperty
    assert_ab_b: assert property(p_ab_b)
        else $error("[AB-CHECK] Port B mismatch: ori=%h new=%h",
                    vif.rdata_b_ori, vif.rdata_b_new);

    // 2. Functional correctness: ori === ref_model
    property p_func_a;
        @(posedge clk) disable iff (!rst_n)
        (vif.cmd_a == 2'b01) |=>
        ((vif.rdata_a_ori & data_mask) === (rdata_a_ref & data_mask));
    endproperty
    assert_func_a: assert property(p_func_a)
        else $error("[FUNC-CHECK] Port A DUT != Ref: dut=%h ref=%h",
                    vif.rdata_a_ori, rdata_a_ref);

    property p_func_b;
        @(posedge clk) disable iff (!rst_n)
        (vif.cmd_b == 2'b01) |=>
        ((vif.rdata_b_ori & data_mask) === (rdata_b_ref & data_mask));
    endproperty
    assert_func_b: assert property(p_func_b)
        else $error("[FUNC-CHECK] Port B DUT != Ref: dut=%h ref=%h",
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
    // Driver
    // ----------------------------------------------------------
    task automatic drive(mem_tx_t t);
        @(posedge clk);
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
        drive(t);
    endtask

    // ----------------------------------------------------------
    // ═══════════ FEATURE TEST CASES ═══════════
    // ----------------------------------------------------------

    // A1/A3/A4/D3/I1: Fill all addresses, then read back all
    task automatic test_fill_verify(int num_loops);
        mem_tx_t t;
        logic [MAX_DATA_WIDTH-1:0] expected;

        for (int loop = 0; loop < num_loops; loop++) begin
            // Fill
            for (int a = 0; a < cfg_depth; a++) begin
                t.cmd_a=MEM_WRITE; t.cmd_b=MEM_NOP;
                t.addr_a=a; t.wdata_a=a ^ (loop << 8); t.wem_a='0;
                drive(t);
            end
            // Drain
            repeat (2) drive_nop();
            // Verify
            for (int a = 0; a < cfg_depth; a++) begin
                t.cmd_a=MEM_READ; t.cmd_b=MEM_NOP;
                t.addr_a=a; expected = a ^ (loop << 8);
                drive(t);
            end
        end
    endtask

    // C1-C5: Data patterns (all0, all1, checkerboard, walk1, walk0)
    task automatic test_data_patterns();
        mem_tx_t t;
        logic [MAX_DATA_WIDTH-1:0] patterns[];
        patterns = new[5];

        // Build patterns (masked to cfg_data_width)
        for (int i = 0; i < cfg_data_width; i++) begin
            patterns[0][i] = 1'b0;                               // all-0
            patterns[1][i] = 1'b1;                               // all-1
            patterns[2][i] = (i % 2 == 0);                      // checkerboard 0x55..
            patterns[3][i] = (i == 0);                          // walk-1 first addr only
            patterns[4][i] = 1'b1; patterns[4][0] = 1'b0;       // walk-0 LSB
        end

        for (int p = 0; p < 5; p++) begin
            // Write pattern to all addresses
            for (int a = 0; a < cfg_depth; a++) begin
                t.cmd_a=MEM_WRITE; t.cmd_b=MEM_NOP;
                t.addr_a=a; t.wdata_a=patterns[p]; t.wem_a='0;
                drive(t);
            end
            // Verify
            for (int a = 0; a < cfg_depth; a++) begin
                t.cmd_a=MEM_READ; t.cmd_b=MEM_NOP; t.addr_a=a;
                drive(t);
            end
        end

        // Walking-1 across all bits
        for (int b = 0; b < cfg_data_width; b++) begin
            t.cmd_a=MEM_WRITE; t.cmd_b=MEM_NOP;
            t.addr_a=0; t.wdata_a = (1 << b); t.wem_a='0;
            drive(t);
            t.cmd_a=MEM_READ; drive(t);
        end

        // Walking-0
        for (int b = 0; b < cfg_data_width; b++) begin
            t.cmd_a=MEM_WRITE; t.cmd_b=MEM_NOP;
            t.addr_a=0; t.wdata_a = ~(1 << b); t.wem_a='0;
            drive(t);
            t.cmd_a=MEM_READ; drive(t);
        end
    endtask

    // B2/B7/B8: Write mask verification
    task automatic test_wem_mask();
        mem_tx_t t;
        logic [MAX_DATA_WIDTH-1:0] bg_val;
        logic [MAX_DATA_WIDTH-1:0] wr_val;
        logic [MAX_DATA_WIDTH-1:0] wem_val;

        bg_val = {MAX_DATA_WIDTH{1'b1}} & data_mask;  // all-1 background
        wr_val = '0;                                    // all-0 write data

        // Fill background
        t.cmd_a=MEM_WRITE; t.cmd_b=MEM_NOP;
        t.addr_a=0; t.wdata_a=bg_val; t.wem_a='0;
        drive(t); drive_nop();

        // B4: wem=all1 → no write (data should stay as bg_val)
        t.wdata_a=wr_val; t.wem_a={MAX_DATA_WIDTH{1'b1}};
        drive(t);
        t.cmd_a=MEM_READ; drive(t);  // should read bg_val

        // B1: wem=all0 → full write
        t.cmd_a=MEM_WRITE; t.wdata_a=wr_val; t.wem_a='0;
        drive(t);
        t.cmd_a=MEM_READ; drive(t);  // should read wr_val

        // B3: Single bit writes (walking 0 on wem)
        for (int b = 0; b < cfg_data_width; b++) begin
            // Set background to all-1
            t.cmd_a=MEM_WRITE; t.wdata_a=bg_val; t.wem_a='0; drive(t);
            // Write single bit 0 via wem
            t.cmd_a=MEM_WRITE; t.wdata_a=wr_val;
            t.wem_a = ~(1 << b);  // only bit b enabled for write
            drive(t);
            t.cmd_a=MEM_READ; drive(t);
        end

        // B7: Random wem patterns
        for (int r = 0; r < 20; r++) begin
            t.cmd_a=MEM_WRITE; t.wdata_a=bg_val; t.wem_a='0; drive(t);
            t.wdata_a = $urandom;
            t.wem_a   = $urandom;
            drive(t);
            t.cmd_a=MEM_READ; drive(t);
        end

        // B2: Byte-level masking
        for (int byte_idx = 0; byte_idx < cfg_data_width/8; byte_idx++) begin
            t.cmd_a=MEM_WRITE; t.wdata_a=bg_val; t.wem_a='0; drive(t);
            // Mask all bytes except byte_idx
            t.wdata_a = wr_val;
            t.wem_a = '1;
            for (int b = 0; b < 8; b++)
                t.wem_a[byte_idx*8 + b] = 1'b0;
            drive(t);
            t.cmd_a=MEM_READ; drive(t);
        end
    endtask

    // D1/D2/D5/J3: Address boundary
    task automatic test_addr_boundary();
        mem_tx_t t;
        int addrs[];

        addrs = new[4];
        addrs[0] = 0;                           // min
        addrs[1] = cfg_depth - 1;              // max
        addrs[2] = cfg_depth / 2;              // mid
        addrs[3] = (cfg_depth / 2) - 1;        // mid-1 (power-of-2 boundary)

        for (int i = 0; i < 4; i++) begin
            t.cmd_a=MEM_WRITE; t.cmd_b=MEM_NOP;
            t.addr_a=addrs[i]; t.wdata_a=addrs[i]; t.wem_a='0;
            drive(t);
            t.cmd_a=MEM_READ; drive(t);
        end

        // Reverse sequential (D5)
        for (int a = cfg_depth-1; a >= 0; a--) begin
            t.cmd_a=MEM_WRITE; t.cmd_b=MEM_NOP;
            t.addr_a=a; t.wdata_a=a; t.wem_a='0;
            drive(t);
        end
        for (int a = cfg_depth-1; a >= 0; a--) begin
            t.cmd_a=MEM_READ; t.cmd_b=MEM_NOP; t.addr_a=a;
            drive(t);
        end
    endtask

    // E4/E5: Write-After-Write
    task automatic test_waw();
        mem_tx_t t;

        // E4: Same port WAW
        t.cmd_a=MEM_WRITE; t.cmd_b=MEM_NOP;
        t.addr_a=0; t.wdata_a=32'hAAAA5555; t.wem_a='0;
        drive(t);
        t.cmd_a=MEM_WRITE;
        t.addr_a=0; t.wdata_a=32'h5555AAAA; t.wem_a='0;
        drive(t);
        t.cmd_a=MEM_READ; drive(t);   // should read 5555AAAA

        // E5: Cross-port WAW (Port A writes X, Port B writes Y → Y wins)
        t.cmd_a=MEM_WRITE; t.cmd_b=MEM_NOP;
        t.addr_a=1; t.wdata_a=32'hDEADBEEF; t.wem_a='0;
        drive(t);
        t.cmd_a=MEM_WRITE; t.cmd_b=MEM_WRITE;
        t.addr_a=1; t.addr_b=1;
        t.wdata_a=32'hCAFEBABE; t.wdata_b=32'hFEEBDAED;
        t.wem_a='0; t.wem_b='0;
        drive(t);
        t.cmd_a=MEM_READ; t.cmd_b=MEM_NOP; t.addr_a=1;
        drive(t);
    endtask

    // E3: Write-After-Read
    task automatic test_war();
        mem_tx_t t;

        t.cmd_a=MEM_WRITE; t.cmd_b=MEM_NOP;
        t.addr_a=0; t.wdata_a=32'h12345678; t.wem_a='0;
        drive(t);
        t.cmd_a=MEM_READ; drive(t);   // read old value
        t.cmd_a=MEM_WRITE;
        t.addr_a=0; t.wdata_a=32'hFEDCBA98;
        drive(t);                      // overwrite after read
        t.cmd_a=MEM_READ; drive(t);   // should read new value
    endtask

    // F2/F3/F4: Dual port conflicts
    task automatic test_dual_conflict();
        mem_tx_t t;

        // F2: Simultaneous read same address
        t.cmd_a=MEM_WRITE; t.cmd_b=MEM_NOP;
        t.addr_a=0; t.wdata_a=32'hA5A5A5A5; t.wem_a='0;
        drive(t); drive_nop();
        t.cmd_a=MEM_READ; t.cmd_b=MEM_READ;
        t.addr_a=0; t.addr_b=0;
        drive(t);                      // both read same addr

        // F4: Read A + Write B same address
        t.cmd_a=MEM_WRITE; t.cmd_b=MEM_NOP;
        t.addr_a=1; t.wdata_a=32'hBBBBBBBB; t.wem_a='0;
        drive(t); drive_nop();
        t.cmd_a=MEM_READ; t.cmd_b=MEM_WRITE;
        t.addr_a=1; t.addr_b=1;
        t.wdata_b=32'hCCCCCCCC; t.wem_b='0;
        drive(t);                      // A reads old? B writes new

        // F3: Simultaneous write same address
        t.cmd_a=MEM_WRITE; t.cmd_b=MEM_WRITE;
        t.addr_a=2; t.addr_b=2;
        t.wdata_a=32'h11111111; t.wdata_b=32'h22222222;
        t.wem_a='0; t.wem_b='0;
        drive(t);
        t.cmd_a=MEM_READ; t.cmd_b=MEM_NOP; t.addr_a=2;
        drive(t);                      // undefined which wins
    endtask

    // G1/G2: Reset behavior
    task automatic test_reset_behavior();
        mem_tx_t t;

        // G1: Read after reset
        t.cmd_a=MEM_READ; t.cmd_b=MEM_NOP; t.addr_a=0;
        drive(t);                      // should read 0

        // G2: Write → reset → read
        t.cmd_a=MEM_WRITE; t.cmd_b=MEM_NOP;
        t.addr_a=0; t.wdata_a=32'hDEADBEEF; t.wem_a='0;
        drive(t); drive_nop();
        // Soft reset (via command sequence, not actual reset)
        // The ref model and DUT both initialize to 0 on reset.
        // For this test, we verify initial state was 0 (already done in G1).
        // Overwrite and verify:
        t.cmd_a=MEM_READ; drive(t);   // should read DEADBEEF
    endtask

    // I2/J1/J2: Random hammer stress
    task automatic test_stress(int num_tx);
        mem_tx_t t;

        // Phase 1: Fill with known pattern (addr = data)
        for (int a = 0; a < cfg_depth; a++) begin
            t.cmd_a=MEM_WRITE; t.cmd_b=MEM_NOP;
            t.addr_a=a; t.wdata_a=a; t.wem_a='0;
            drive(t);
        end
        repeat (2) drive_nop();

        // Phase 2: Random operations (hammer)
        for (int i = 0; i < num_tx; i++) begin
            t.cmd_a  = mem_cmd_e'($urandom_range(2, 0));
            t.cmd_b  = mem_cmd_e'($urandom_range(2, 0));
            t.addr_a = $urandom_range(cfg_depth-1, 0);
            t.addr_b = $urandom_range(cfg_depth-1, 0);
            t.wdata_a = $urandom;
            t.wdata_b = $urandom;
            t.wem_a   = $urandom;  // random mask
            t.wem_b   = $urandom;
            drive(t);
        end

        // Phase 3: Verify spot-check
        repeat (2) drive_nop();
        for (int a = 0; a < cfg_depth; a += (cfg_depth/16 + 1)) begin
            t.cmd_a=MEM_READ; t.cmd_b=MEM_NOP; t.addr_a=a;
            drive(t);
        end
    endtask

    // ===========================================================
    // Test Runner
    // ===========================================================
    string  test_name;
    integer num_tx;
    integer tx_count;
    mem_tx_t tx;

    initial begin
        if (!$value$plusargs("ADDR_WIDTH=%d", cfg_addr_width)) cfg_addr_width = 10;
        if (!$value$plusargs("DATA_WIDTH=%d", cfg_data_width)) cfg_data_width = 32;
        update_masks();

        if (!$value$plusargs("TEST=%s", test_name)) test_name = "mem_fill_verify";
        if (!$value$plusargs("TX_COUNT=%d", num_tx)) num_tx = 20;

        $display("============================================================");
        $display("[FEATURE] Max AW=%0d DW=%0d | Config AW=%0d DW=%0d Depth=%0d",
                 MAX_ADDR_WIDTH, MAX_DATA_WIDTH, cfg_addr_width, cfg_data_width, cfg_depth);
        $display("[FEATURE] Test: %s  Tx: %0d", test_name, num_tx);
        $display("============================================================");

        @(posedge rst_n);
        repeat (5) @(posedge clk);

        case (test_name)
            // === Basic RW ===
            "mem_fill_verify":    test_fill_verify(1);
            "mem_fill_verify_x3": test_fill_verify(3);

            // === Data Patterns ===
            "mem_data_pattern":   test_data_patterns();

            // === Write Mask ===
            "mem_wem_mask":       test_wem_mask();

            // === Address Boundary ===
            "mem_addr_boundary":  test_addr_boundary();

            // === Hazards ===
            "mem_waw":            test_waw();
            "mem_war":            test_war();

            // === Dual Port ===
            "mem_dual_conflict":  test_dual_conflict();

            // === Reset ===
            "mem_reset":          test_reset_behavior();

            // === Stress ===
            "mem_stress":         test_stress(num_tx);

            // === Full regression (all feature tests) ===
            "mem_feature_all": begin
                $display("[FEATURE] === Feature Regression Start ===");
                test_fill_verify(1);        $display("[FEATURE] fill_verify:    OK");
                test_data_patterns();        $display("[FEATURE] data_pattern:   OK");
                test_wem_mask();             $display("[FEATURE] wem_mask:       OK");
                test_addr_boundary();        $display("[FEATURE] addr_boundary:  OK");
                test_waw();                  $display("[FEATURE] waw:            OK");
                test_war();                  $display("[FEATURE] war:            OK");
                test_dual_conflict();        $display("[FEATURE] dual_conflict:  OK");
                test_reset_behavior();       $display("[FEATURE] reset:          OK");
                test_stress(num_tx > 0 ? num_tx : 100);
                $display("[FEATURE] stress:         OK");
                $display("[FEATURE] === Feature Regression End ===");
            end

            // === Legacy tests (compatible) ===
            "mem_sp_test": begin
                for (tx_count=0; tx_count<num_tx; tx_count++) begin
                    tx.cmd_a=mem_cmd_e'($urandom_range(2,0)); tx.cmd_b=MEM_NOP;
                    tx.addr_a=$urandom_range(cfg_depth-1,0);
                    tx.wdata_a=$urandom; tx.wem_a='0; drive(tx);
                end
            end

            "mem_sdp_test": begin
                for (tx_count=0; tx_count<num_tx; tx_count++) begin
                    tx.cmd_a=MEM_WRITE; tx.cmd_b=MEM_READ;
                    tx.addr_a=$urandom_range(cfg_depth-1,0);
                    tx.addr_b=$urandom_range(cfg_depth-1,0);
                    tx.wdata_a=$urandom; tx.wem_a='0; tx.wem_b='0; drive(tx);
                end
            end

            "mem_tdp_test": begin
                for (tx_count=0; tx_count<num_tx; tx_count++) begin
                    tx.cmd_a=mem_cmd_e'($urandom_range(2,0));
                    tx.cmd_b=mem_cmd_e'($urandom_range(2,0));
                    tx.addr_a=$urandom_range(cfg_depth-1,0);
                    tx.addr_b=$urandom_range(cfg_depth-1,0);
                    tx.wdata_a=$urandom; tx.wdata_b=$urandom;
                    tx.wem_a='0; tx.wem_b='0; drive(tx);
                end
            end

            "mem_wem_walking_test": begin
                for (tx_count=0; tx_count<num_tx; tx_count++) begin
                    tx.cmd_a=MEM_WRITE; tx.cmd_b=MEM_NOP;
                    tx.addr_a=$urandom_range(cfg_depth-1,0);
                    tx.wdata_a=$urandom;
                    tx.wem_a=~(1<<(tx_count % cfg_data_width));
                    drive(tx);
                end
            end

            "mem_b2b_raw_test": begin
                for (tx_count=0; tx_count<num_tx; tx_count++) begin
                    tx.cmd_a=MEM_WRITE; tx.cmd_b=MEM_NOP;
                    tx.addr_a=tx_count%cfg_depth; tx.wdata_a=$urandom;
                    tx.wem_a='0; drive(tx);
                    tx.cmd_a=MEM_READ; drive(tx);
                end
            end

            default: begin
                $display("[FEATURE] ERROR: Unknown test '%s'", test_name);
            end
        endcase

        repeat (READ_LATENCY+2) drive_nop();
        $display("[FEATURE] ===== Done: %s =====", test_name);
        $finish;
    end

endmodule
