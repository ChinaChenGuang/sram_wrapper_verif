// ============================================================
// Non-UVM Testbench for SRAM Wrapper A/B Verification
// ============================================================
// Replaces UVM infrastructure with simple SystemVerilog
// while preserving the same verification strategy:
//   - Two identical DUTs share the same stimulus
//   - mem_sva_checker asserts rdata_ori === rdata_new
// ============================================================

`timescale 1ns/1ps

module tb_top;

    parameter ADDR_WIDTH = 10;
    parameter DATA_WIDTH = 32;
    parameter READ_LATENCY = 1;

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
    // Interface
    // ----------------------------------------------------------
    mem_if #(ADDR_WIDTH, DATA_WIDTH) vif(clk, rst_n);

    // ----------------------------------------------------------
    // DUT Instances (A/B Test)
    // Select modules via +define+DUT_ORI / +define+DUT_NEW
    // ----------------------------------------------------------
`ifdef DUT_ORI
    `DUT_ORI #(ADDR_WIDTH, DATA_WIDTH) dut_ori (
`else
    dut_sram #(ADDR_WIDTH, DATA_WIDTH) dut_ori (
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
    `DUT_NEW #(ADDR_WIDTH, DATA_WIDTH) dut_new (
`else
    dut_sram #(ADDR_WIDTH, DATA_WIDTH) dut_new (
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
    // SVA Checker
    // ----------------------------------------------------------
    mem_sva_checker #(ADDR_WIDTH, DATA_WIDTH, READ_LATENCY) checker_inst(vif);

    // ----------------------------------------------------------
    // Waveform Dump
    // ----------------------------------------------------------
    initial begin
        $dumpfile("dump.fst");
        $dumpvars(0, tb_top);
    end

    // ----------------------------------------------------------
    // Enum and Constants
    // ----------------------------------------------------------
    typedef enum logic [1:0] {
        MEM_NOP   = 2'b00,
        MEM_READ  = 2'b01,
        MEM_WRITE = 2'b10
    } mem_cmd_e;

    typedef enum {
        SRAM_SP,
        SRAM_SDP,
        SRAM_TDP
    } sram_type_e;

    // ----------------------------------------------------------
    // Transaction Type
    // ----------------------------------------------------------
    typedef struct packed {
        mem_cmd_e cmd_a;
        mem_cmd_e cmd_b;
        logic [ADDR_WIDTH-1:0] addr_a;
        logic [ADDR_WIDTH-1:0] addr_b;
        logic [DATA_WIDTH-1:0] wdata_a;
        logic [DATA_WIDTH-1:0] wdata_b;
        logic [DATA_WIDTH-1:0] wem_a;
        logic [DATA_WIDTH-1:0] wem_b;
    } mem_transaction_t;

    // ----------------------------------------------------------
    // Random Transaction Generator
    // ----------------------------------------------------------
    function automatic mem_transaction_t gen_sp_transaction();
        mem_transaction_t t;
        t.cmd_a = mem_cmd_e'($urandom_range(2, 0));  // 0=NOP, 1=READ, 2=WRITE
        t.cmd_b = MEM_NOP;                             // SP: port B always NOP
        t.addr_a = $urandom_range((1 << ADDR_WIDTH) - 1, 0);
        t.addr_b = '0;
        t.wdata_a = $urandom_range((1 << DATA_WIDTH) - 1, 0);
        t.wdata_b = '0;
        t.wem_a = '0;  // Full word write (all bits enabled)
        t.wem_b = '0;
        return t;
    endfunction

    function automatic mem_transaction_t gen_sdp_transaction();
        mem_transaction_t t;
        t.cmd_a = MEM_WRITE;                   // SDP: Port A write-only
        t.cmd_b = MEM_READ;                    // Port B read-only
        t.addr_a = $urandom_range((1 << ADDR_WIDTH) - 1, 0);
        t.addr_b = $urandom_range((1 << ADDR_WIDTH) - 1, 0);
        t.wdata_a = $urandom_range((1 << DATA_WIDTH) - 1, 0);
        t.wdata_b = '0;
        t.wem_a = '0;  // Full word write
        t.wem_b = '0;
        return t;
    endfunction

    function automatic mem_transaction_t gen_tdp_transaction();
        mem_transaction_t t;
        t.cmd_a = mem_cmd_e'($urandom_range(2, 0));
        t.cmd_b = mem_cmd_e'($urandom_range(2, 0));
        t.addr_a = $urandom_range((1 << ADDR_WIDTH) - 1, 0);
        t.addr_b = $urandom_range((1 << ADDR_WIDTH) - 1, 0);
        t.wdata_a = $urandom_range((1 << DATA_WIDTH) - 1, 0);
        t.wdata_b = $urandom_range((1 << DATA_WIDTH) - 1, 0);
        t.wem_a = '0;
        t.wem_b = '0;
        return t;
    endfunction

    // ----------------------------------------------------------
    // Driver Task
    // ----------------------------------------------------------
    task automatic drive_transaction(mem_transaction_t t);
        @(posedge clk);
        vif.cmd_a   = t.cmd_a;
        vif.addr_a  = t.addr_a;
        vif.wdata_a = t.wdata_a;
        vif.wem_a   = t.wem_a;
        vif.cmd_b   = t.cmd_b;
        vif.addr_b  = t.addr_b;
        vif.wdata_b = t.wdata_b;
        vif.wem_b   = t.wem_b;
    endtask

    // ----------------------------------------------------------
    // Test Execution
    // ----------------------------------------------------------
    string test_name;
    integer num_transactions;
    integer tx_count;
    integer error_count;
    mem_transaction_t tx;

    initial begin
        // Get test name from command line
        if ($value$plusargs("TEST=%s", test_name)) begin
            $display("[TB] Running test: %s", test_name);
        end else begin
            test_name = "mem_sp_test";
            $display("[TB] No +TEST= specified, defaulting to: %s", test_name);
        end

        // Get transaction count from command line
        if ($value$plusargs("TX_COUNT=%d", num_transactions)) begin
            $display("[TB] Transaction count: %0d", num_transactions);
        end else begin
            num_transactions = 200;
            $display("[TB] Default transaction count: %0d", num_transactions);
        end

        // Wait for reset release
        @(posedge rst_n);
        repeat (5) @(posedge clk); // Wait a few cycles after reset

        $display("[TB] ========== Test Start ==========");
        error_count = 0;

        case (test_name)
            "mem_sp_test": begin
                $display("[TB] SP Test: Single Port Mode");
                for (tx_count = 0; tx_count < num_transactions; tx_count++) begin
                    tx = gen_sp_transaction();
                    drive_transaction(tx);
                end
            end

            "mem_sdp_test": begin
                $display("[TB] SDP Test: Simple Dual Port Mode");
                for (tx_count = 0; tx_count < num_transactions; tx_count++) begin
                    tx = gen_sdp_transaction();
                    drive_transaction(tx);
                end
            end

            "mem_tdp_test": begin
                $display("[TB] TDP Test: True Dual Port Mode");
                for (tx_count = 0; tx_count < num_transactions; tx_count++) begin
                    tx = gen_tdp_transaction();
                    drive_transaction(tx);
                end
            end

            "mem_wem_walking_test": begin
                $display("[TB] WEM Walking Test: Walking write mask");
                for (tx_count = 0; tx_count < num_transactions; tx_count++) begin
                    tx.cmd_a = MEM_WRITE;
                    tx.cmd_b = MEM_NOP;
                    tx.addr_a = $urandom_range((1 << ADDR_WIDTH) - 1, 0);
                    tx.addr_b = '0;
                    tx.wdata_a = $urandom_range((1 << DATA_WIDTH) - 1, 0);
                    tx.wdata_b = '0;
                    // Walking 0 pattern on wem
                    tx.wem_a = ~(1 << (tx_count % DATA_WIDTH));
                    tx.wem_b = '0;
                    drive_transaction(tx);
                end
            end

            "mem_b2b_raw_test": begin
                $display("[TB] B2B RAW Test: Back-to-back read-after-write");
                for (tx_count = 0; tx_count < num_transactions; tx_count++) begin
                    // Write to address
                    tx.cmd_a = MEM_WRITE;
                    tx.cmd_b = MEM_NOP;
                    tx.addr_a = tx_count % (1 << ADDR_WIDTH);
                    tx.addr_b = '0;
                    tx.wdata_a = $urandom_range((1 << DATA_WIDTH) - 1, 0);
                    tx.wdata_b = '0;
                    tx.wem_a = '0;
                    tx.wem_b = '0;
                    drive_transaction(tx);
                    // Read back same address
                    tx.cmd_a = MEM_READ;
                    drive_transaction(tx);
                end
            end

            default: begin
                $display("[TB] ERROR: Unknown test '%s'", test_name);
                $finish;
            end
        endcase

        // Drain pipeline (wait for pending reads)
        repeat (READ_LATENCY + 2) @(posedge clk);

        // Idle a few cycles
        vif.cmd_a = MEM_NOP;
        vif.cmd_b = MEM_NOP;
        repeat (5) @(posedge clk);

        $display("[TB] ========== Test End ==========");
        $display("[TB] Transactions executed: %0d", tx_count);
        $finish;
    end

    // ----------------------------------------------------------
    // Error Counter (triggered by SVA assertion failures)
    // ----------------------------------------------------------
    // The SVA checker prints $error on mismatch.
    // We track errors from the checker.
    integer sva_error_count = 0;

    always @(posedge clk) begin
        // SVA assertions will print to stderr automatically
        // This block just provides a hook for post-processing
    end

endmodule
