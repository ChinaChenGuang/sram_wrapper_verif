// ============================================================
// sram_test_env - Parameterized SRAM A/B Test Environment
// ============================================================
// Encapsulates one complete test setup:
//   - Interface (mem_if)
//   - Two DUTs (dut_ori + dut_new, same stimulus)
//   - SVA checker (rdata_ori === rdata_new)
//   - Test runner (transaction generation + driving)
//
// Designed for use with generate in multi-config testbenches.
// Each instance has a unique INST_ID for plusarg-based selection.
// ============================================================

`timescale 1ns/1ps

module sram_test_env #(
    parameter int INST_ID      = 0,
    parameter int ADDR_WIDTH   = 10,
    parameter int DATA_WIDTH   = 32,
    parameter int READ_LATENCY = 1,
    parameter int NUM_INST     = 1
)(
    input  logic clk,
    input  logic rst_n,
    output logic done
);

    // ----------------------------------------------------------
    // Enum and Constants (per-instance scope)
    // ----------------------------------------------------------
    typedef enum logic [1:0] {
        MEM_NOP   = 2'b00,
        MEM_READ  = 2'b01,
        MEM_WRITE = 2'b10
    } mem_cmd_e;

    // ----------------------------------------------------------
    // Transaction Type (width-dependent struct)
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
    // Interface
    // ----------------------------------------------------------
    mem_if #(ADDR_WIDTH, DATA_WIDTH) vif(clk, rst_n);

    // ----------------------------------------------------------
    // DUT Instances (A/B Test)
    // ----------------------------------------------------------
    // DUT module names are selected via compile-time defines:
    //   +define+DUT_ORI=<module>   (default: dut_sram)
    //   +define+DUT_NEW=<module>   (default: dut_sram)
    //
    // When both have the SAME module name:
    //   Both defines point to the same module - just works.
    //
    // When they have DIFFERENT module names:
    //   +define+DUT_ORI=dut_sram +define+DUT_NEW=dut_sram_v2
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
    // Random Transaction Generators
    // ----------------------------------------------------------
    function automatic mem_transaction_t gen_sp_transaction();
        mem_transaction_t t;
        t.cmd_a   = mem_cmd_e'($urandom_range(2, 0));
        t.cmd_b   = MEM_NOP;
        t.addr_a  = $urandom_range((1 << ADDR_WIDTH) - 1, 0);
        t.addr_b  = '0;
        t.wdata_a = $urandom_range((1 << DATA_WIDTH) - 1, 0);
        t.wdata_b = '0;
        t.wem_a   = '0;
        t.wem_b   = '0;
        return t;
    endfunction

    function automatic mem_transaction_t gen_sdp_transaction();
        mem_transaction_t t;
        t.cmd_a   = MEM_WRITE;
        t.cmd_b   = MEM_READ;
        t.addr_a  = $urandom_range((1 << ADDR_WIDTH) - 1, 0);
        t.addr_b  = $urandom_range((1 << ADDR_WIDTH) - 1, 0);
        t.wdata_a = $urandom_range((1 << DATA_WIDTH) - 1, 0);
        t.wdata_b = '0;
        t.wem_a   = '0;
        t.wem_b   = '0;
        return t;
    endfunction

    function automatic mem_transaction_t gen_tdp_transaction();
        mem_transaction_t t;
        t.cmd_a   = mem_cmd_e'($urandom_range(2, 0));
        t.cmd_b   = mem_cmd_e'($urandom_range(2, 0));
        t.addr_a  = $urandom_range((1 << ADDR_WIDTH) - 1, 0);
        t.addr_b  = $urandom_range((1 << ADDR_WIDTH) - 1, 0);
        t.wdata_a = $urandom_range((1 << DATA_WIDTH) - 1, 0);
        t.wdata_b = $urandom_range((1 << DATA_WIDTH) - 1, 0);
        t.wem_a   = '0;
        t.wem_b   = '0;
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
    // Test Runner
    // ----------------------------------------------------------
    // Runs inside an initial block in each generate instance.
    // Controlled by plusargs:
    //   +INST_ID=<n>     : which instance to run (default: run ALL)
    //   +TEST=<name>     : test case name
    //   +TX_COUNT=<n>    : number of transactions
    // ----------------------------------------------------------
    string  test_name;
    integer num_transactions;
    integer inst_sel;
    integer tx_count;
    integer run_this;
    mem_transaction_t tx;

    initial begin
        done = 1'b0;

        // Determine if this instance should run
        run_this = 1;  // default: run all instances
        if ($value$plusargs("INST_ID=%d", inst_sel)) begin
            run_this = (inst_sel == INST_ID);
        end

        if (!run_this) begin
            vif.cmd_a = MEM_NOP;
            vif.cmd_b = MEM_NOP;
            @(posedge rst_n);
            repeat (5) @(posedge clk);
            done = 1'b1;
        end else begin
            // Get test name
            if ($value$plusargs("TEST=%s", test_name)) begin
                $display("[ENV-%0d] Running test: %s (W=%0d D=%0d)",
                         INST_ID, test_name, ADDR_WIDTH, DATA_WIDTH);
            end else begin
                test_name = "mem_sp_test";
                $display("[ENV-%0d] No +TEST= specified, default: %s (W=%0d D=%0d)",
                         INST_ID, test_name, ADDR_WIDTH, DATA_WIDTH);
            end

            // Get transaction count
            if ($value$plusargs("TX_COUNT=%d", num_transactions)) begin
                $display("[ENV-%0d] Transaction count: %0d", INST_ID, num_transactions);
            end else begin
                num_transactions = 200;
                $display("[ENV-%0d] Default tx count: %0d", INST_ID, num_transactions);
            end

            // Wait for reset release
            @(posedge rst_n);
            repeat (5) @(posedge clk);

            $display("[ENV-%0d] ===== Test Start: %s (cfg: %0dx%0d) =====",
                     INST_ID, test_name, 1<<ADDR_WIDTH, DATA_WIDTH);

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
                        tx.addr_a  = $urandom_range((1 << ADDR_WIDTH) - 1, 0);
                        tx.addr_b  = '0;
                        tx.wdata_a = $urandom_range((1 << DATA_WIDTH) - 1, 0);
                        tx.wdata_b = '0;
                        tx.wem_a   = ~(1 << (tx_count % DATA_WIDTH));
                        tx.wem_b   = '0;
                        drive_transaction(tx);
                    end
                end

                "mem_b2b_raw_test": begin
                    for (tx_count = 0; tx_count < num_transactions; tx_count++) begin
                        // Write
                        tx.cmd_a   = MEM_WRITE;
                        tx.cmd_b   = MEM_NOP;
                        tx.addr_a  = tx_count % (1 << ADDR_WIDTH);
                        tx.addr_b  = '0;
                        tx.wdata_a = $urandom_range((1 << DATA_WIDTH) - 1, 0);
                        tx.wdata_b = '0;
                        tx.wem_a   = '0;
                        tx.wem_b   = '0;
                        drive_transaction(tx);
                        // Read back same address
                        tx.cmd_a   = MEM_READ;
                        drive_transaction(tx);
                    end
                end

                default: begin
                    $display("[ENV-%0d] ERROR: Unknown test '%s'", INST_ID, test_name);
                end
            endcase

            // Drain pipeline
            repeat (READ_LATENCY + 2) @(posedge clk);

            // Idle
            vif.cmd_a = MEM_NOP;
            vif.cmd_b = MEM_NOP;
            repeat (5) @(posedge clk);

            $display("[ENV-%0d] ===== Test End: %s (%0d tx) =====",
                     INST_ID, test_name, tx_count);
            done = 1'b1;
        end
    end

endmodule
