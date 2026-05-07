// ============================================================
// tb_top_unified - 统一最大位宽 + Mask 方案
// ============================================================
// 思路：
//   - 接口固定为最大位宽 (ADDR=16, DATA=256)
//   - DUT 也编译为最大位宽
//   - 运行时通过 +ADDR_WIDTH= +DATA_WIDTH= 配置实际位宽
//   - Driver 用 addr_mask / data_mask / wem_mask 控制有效位
//   - SVA checker 仅比对有效位
//
// 优点：
//   - 一次编译，运行时切任意配置
//   - 单接口、单 DUT 对、单波形
//   - 新增配置无需改代码
//
// 代价：
//   - DUT 内存固定最大 (64K×256 = 2MB per DUT)
//   - 需要 mask 逻辑
// ============================================================

`timescale 1ns/1ps

module tb_top;

    // ----------------------------------------------------------
    // 最大位宽参数 (可修改以适应项目需求)
    // ----------------------------------------------------------
    localparam MAX_ADDR_WIDTH = 16;
    localparam MAX_DATA_WIDTH = 256;
    localparam READ_LATENCY    = 1;

    // ----------------------------------------------------------
    // Clock and Reset
    // ----------------------------------------------------------
    logic clk;
    logic rst_n;

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    initial begin
        rst_n = 1'b0;
        #20 rst_n = 1'b1;
    end

    // ----------------------------------------------------------
    // 统一最大位宽 Interface
    // ----------------------------------------------------------
    mem_if #(MAX_ADDR_WIDTH, MAX_DATA_WIDTH) vif(clk, rst_n);

    // ----------------------------------------------------------
    // DUTs (固定最大位宽)
    // ----------------------------------------------------------
`ifdef DUT_ORI
    `DUT_ORI #(MAX_ADDR_WIDTH, MAX_DATA_WIDTH) dut_ori (
`else
    dut_sram  #(MAX_ADDR_WIDTH, MAX_DATA_WIDTH) dut_ori (
`endif
        .clk    (clk),
        .rst_n  (rst_n),
        .cmd_a  (vif.cmd_a),
        .addr_a (vif.addr_a),
        .wdata_a(vif.wdata_a),
        .wem_a  (vif.wem_a),
        .rdata_a(vif.rdata_a_ori),
        .cmd_b  (vif.cmd_b),
        .addr_b (vif.addr_b),
        .wdata_b(vif.wdata_b),
        .wem_b  (vif.wem_b),
        .rdata_b(vif.rdata_b_ori)
    );

`ifdef DUT_NEW
    `DUT_NEW #(MAX_ADDR_WIDTH, MAX_DATA_WIDTH) dut_new (
`else
    dut_sram  #(MAX_ADDR_WIDTH, MAX_DATA_WIDTH) dut_new (
`endif
        .clk    (clk),
        .rst_n  (rst_n),
        .cmd_a  (vif.cmd_a),
        .addr_a (vif.addr_a),
        .wdata_a(vif.wdata_a),
        .wem_a  (vif.wem_a),
        .rdata_a(vif.rdata_a_new),
        .cmd_b  (vif.cmd_b),
        .addr_b (vif.addr_b),
        .wdata_b(vif.wdata_b),
        .wem_b  (vif.wem_b),
        .rdata_b(vif.rdata_b_new)
    );

    // ----------------------------------------------------------
    // 运行时配置
    // ----------------------------------------------------------
    int cfg_addr_width;
    int cfg_data_width;
    int cfg_depth;

    logic [MAX_ADDR_WIDTH-1:0] addr_mask;   // 1 = valid addr bit
    logic [MAX_DATA_WIDTH-1:0] data_mask;   // 1 = valid data bit
    logic [MAX_DATA_WIDTH-1:0] wem_mask;    // 1 = valid wem bit (0=write)

    // Derive masks from config
    function automatic void update_masks();
        addr_mask = (1 << cfg_addr_width) - 1;
        data_mask = (1 << cfg_data_width) - 1;
        wem_mask  = (1 << cfg_data_width) - 1;
        cfg_depth = 1 << cfg_addr_width;
    endfunction

    // ----------------------------------------------------------
    // Waveform Dump
    // ----------------------------------------------------------
    initial begin
        $dumpfile("dump.fst");
        $dumpvars(0, tb_top);
    end

    // ----------------------------------------------------------
    // Enum
    // ----------------------------------------------------------
    typedef enum logic [1:0] {
        MEM_NOP   = 2'b00,
        MEM_READ  = 2'b01,
        MEM_WRITE = 2'b10
    } mem_cmd_e;

    // ----------------------------------------------------------
    // Transaction (max-width, masked at drive time)
    // ----------------------------------------------------------
    typedef struct packed {
        mem_cmd_e                     cmd_a;
        mem_cmd_e                     cmd_b;
        logic [MAX_ADDR_WIDTH-1:0]    addr_a;
        logic [MAX_ADDR_WIDTH-1:0]    addr_b;
        logic [MAX_DATA_WIDTH-1:0]    wdata_a;
        logic [MAX_DATA_WIDTH-1:0]    wdata_b;
        logic [MAX_DATA_WIDTH-1:0]    wem_a;
        logic [MAX_DATA_WIDTH-1:0]    wem_b;
    } mem_transaction_t;

    // ----------------------------------------------------------
    // Random Generator (uses cfg_* not MAX_* for range)
    // ----------------------------------------------------------
    function automatic mem_transaction_t gen_sp_transaction();
        mem_transaction_t t;
        t.cmd_a   = mem_cmd_e'($urandom_range(2, 0));
        t.cmd_b   = MEM_NOP;
        t.addr_a  = $urandom_range(cfg_depth - 1, 0);
        t.addr_b  = '0;
        t.wdata_a = $urandom_range((1 << cfg_data_width) - 1, 0);
        t.wdata_b = '0;
        t.wem_a   = '0;
        t.wem_b   = '0;
        return t;
    endfunction

    function automatic mem_transaction_t gen_sdp_transaction();
        mem_transaction_t t;
        t.cmd_a   = MEM_WRITE;
        t.cmd_b   = MEM_READ;
        t.addr_a  = $urandom_range(cfg_depth - 1, 0);
        t.addr_b  = $urandom_range(cfg_depth - 1, 0);
        t.wdata_a = $urandom_range((1 << cfg_data_width) - 1, 0);
        t.wdata_b = '0;
        t.wem_a   = '0;
        t.wem_b   = '0;
        return t;
    endfunction

    function automatic mem_transaction_t gen_tdp_transaction();
        mem_transaction_t t;
        t.cmd_a   = mem_cmd_e'($urandom_range(2, 0));
        t.cmd_b   = mem_cmd_e'($urandom_range(2, 0));
        t.addr_a  = $urandom_range(cfg_depth - 1, 0);
        t.addr_b  = $urandom_range(cfg_depth - 1, 0);
        t.wdata_a = $urandom_range((1 << cfg_data_width) - 1, 0);
        t.wdata_b = $urandom_range((1 << cfg_data_width) - 1, 0);
        t.wem_a   = '0;
        t.wem_b   = '0;
        return t;
    endfunction

    // ----------------------------------------------------------
    // Driver (applies masks)
    // ----------------------------------------------------------
    task automatic drive_transaction(mem_transaction_t t);
        @(posedge clk);
        vif.cmd_a   = t.cmd_a;
        vif.addr_a  = t.addr_a & addr_mask;               // mask addr
        vif.wdata_a = t.wdata_a & data_mask;              // mask data
        vif.wem_a   = (t.wem_a & wem_mask) | ~wem_mask;   // upper→1(masked)
        vif.cmd_b   = t.cmd_b;
        vif.addr_b  = t.addr_b & addr_mask;
        vif.wdata_b = t.wdata_b & data_mask;
        vif.wem_b   = (t.wem_b & wem_mask) | ~wem_mask;
    endtask

    // ----------------------------------------------------------
    // Mask-Aware SVA Checker (inline)
    // ----------------------------------------------------------
    // Only compare bits within data_mask
    property p_rdata_a_match;
        @(posedge clk) disable iff (!rst_n)
        (vif.cmd_a == 2'b01)
        |=>
        ((vif.rdata_a_ori & data_mask) === (vif.rdata_a_new & data_mask));
    endproperty

    property p_rdata_b_match;
        @(posedge clk) disable iff (!rst_n)
        (vif.cmd_b == 2'b01)
        |=>
        ((vif.rdata_b_ori & data_mask) === (vif.rdata_b_new & data_mask));
    endproperty

    assert_rdata_a_match: assert property(p_rdata_a_match)
        else $error("SVA ERROR: Port A mismatch! ori=%h new=%h mask=%h",
                    vif.rdata_a_ori, vif.rdata_a_new, data_mask);

    assert_rdata_b_match: assert property(p_rdata_b_match)
        else $error("SVA ERROR: Port B mismatch! ori=%h new=%h mask=%h",
                    vif.rdata_b_ori, vif.rdata_b_new, data_mask);

    // ----------------------------------------------------------
    // Test Runner
    // ----------------------------------------------------------
    string  test_name;
    integer num_transactions;
    integer tx_count;
    mem_transaction_t tx;

    initial begin
        // === 读取运行时配置 ===
        if (!$value$plusargs("ADDR_WIDTH=%d", cfg_addr_width))
            cfg_addr_width = 10;

        if (!$value$plusargs("DATA_WIDTH=%d", cfg_data_width))
            cfg_data_width = 32;

        update_masks();

        $display("============================================================");
        $display("[UNIFIED] Max: AW=%0d DW=%0d | Config: AW=%0d DW=%0d",
                 MAX_ADDR_WIDTH, MAX_DATA_WIDTH,
                 cfg_addr_width, cfg_data_width);
        $display("[UNIFIED] addr_mask=%h data_mask=%h",
                 addr_mask, data_mask);
        $display("============================================================");

        // === 读取测试配置 ===
        if ($value$plusargs("TEST=%s", test_name)) begin
            $display("[UNIFIED] Test: %s", test_name);
        end else begin
            test_name = "mem_sp_test";
            $display("[UNIFIED] Default test: %s", test_name);
        end

        if ($value$plusargs("TX_COUNT=%d", num_transactions)) begin
            $display("[UNIFIED] Tx count: %0d", num_transactions);
        end else begin
            num_transactions = 200;
            $display("[UNIFIED] Default tx: %0d", num_transactions);
        end

        // === 等复位 ===
        @(posedge rst_n);
        repeat (5) @(posedge clk);

        $display("[UNIFIED] ===== Test Start: %s (cfg: %0dx%0d) =====",
                 test_name, cfg_depth, cfg_data_width);

        case (test_name)
            "mem_sp_test": begin
                for (tx_count = 0; tx_count < num_transactions; tx_count++) begin
                    tx = gen_sp_transaction();
                    drive_transaction(tx);
                end
            end

            "mem_sdp_test": begin
                for (tx_count = 0; tx_count < num_transactions; tx_count++) begin
                    tx = gen_sdp_transaction();
                    drive_transaction(tx);
                end
            end

            "mem_tdp_test": begin
                for (tx_count = 0; tx_count < num_transactions; tx_count++) begin
                    tx = gen_tdp_transaction();
                    drive_transaction(tx);
                end
            end

            "mem_wem_walking_test": begin
                for (tx_count = 0; tx_count < num_transactions; tx_count++) begin
                    tx.cmd_a   = MEM_WRITE;
                    tx.cmd_b   = MEM_NOP;
                    tx.addr_a  = $urandom_range(cfg_depth - 1, 0);
                    tx.addr_b  = '0;
                    tx.wdata_a = $urandom_range((1 << cfg_data_width) - 1, 0);
                    tx.wdata_b = '0;
                    tx.wem_a   = ~(1 << (tx_count % cfg_data_width));
                    tx.wem_b   = '0;
                    drive_transaction(tx);
                end
            end

            "mem_b2b_raw_test": begin
                for (tx_count = 0; tx_count < num_transactions; tx_count++) begin
                    tx.cmd_a   = MEM_WRITE;
                    tx.cmd_b   = MEM_NOP;
                    tx.addr_a  = tx_count % cfg_depth;
                    tx.addr_b  = '0;
                    tx.wdata_a = $urandom_range((1 << cfg_data_width) - 1, 0);
                    tx.wdata_b = '0;
                    tx.wem_a   = '0;
                    tx.wem_b   = '0;
                    drive_transaction(tx);
                    tx.cmd_a   = MEM_READ;
                    drive_transaction(tx);
                end
            end

            // === Config Sweep: 遍历所有配置 ===
            "mem_sweep_all": begin
                int sweep_aw[] = '{8, 10, 12, 6, 16, 9};
                int sweep_dw[] = '{8, 32, 64, 256, 8, 128};
                string sweep_nm[] = '{"256x8","1Kx32","4Kx64","64x256","64Kx8","512x128"};
                $display("[UNIFIED] === Config Sweep Mode ===");
                for (int c = 0; c < 6; c++) begin
                    cfg_addr_width = sweep_aw[c];
                    cfg_data_width = sweep_dw[c];
                    update_masks();
                    $display("[UNIFIED] --- Sweep [%0d/%0d]: %s (AW=%0d DW=%0d) ---",
                             c, 5, sweep_nm[c], cfg_addr_width, cfg_data_width);
                    for (tx_count = 0; tx_count < num_transactions; tx_count++) begin
                        tx = gen_sdp_transaction();
                        drive_transaction(tx);
                    end
                    repeat (2) @(posedge clk);
                end
            end

            default: begin
                $display("[UNIFIED] ERROR: Unknown test '%s'", test_name);
            end
        endcase

        // Drain
        repeat (READ_LATENCY + 2) @(posedge clk);
        vif.cmd_a = MEM_NOP;
        vif.cmd_b = MEM_NOP;
        repeat (5) @(posedge clk);

        $display("[UNIFIED] ===== Test End: %s (%0d tx) =====",
                 test_name, tx_count);
        $finish;
    end

endmodule
