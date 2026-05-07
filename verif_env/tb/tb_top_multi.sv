// ============================================================
// tb_top_multi - Multi-Configuration SRAM A/B Testbench
// ============================================================
// Instantiates multiple sram_test_env instances via generate,
// each with a different SRAM configuration.
//
// Configurations (from sram_cfg_pkg):
//   [0] CFG_256x8   : ADDR=8,  DATA=8   (256 depth)
//   [1] CFG_1Kx32   : ADDR=10, DATA=32  (1K depth)  [default]
//   [2] CFG_4Kx64   : ADDR=12, DATA=64  (4K depth)
//   [3] CFG_64x256  : ADDR=6,  DATA=256 (64 depth)
//   [4] CFG_64Kx8   : ADDR=16, DATA=8   (64K depth)
//   [5] CFG_512x128 : ADDR=9,  DATA=128 (512 depth)
//
// Usage:
//   make build-multi                       # build
//   make run-multi INST=0 TEST=mem_sp_test # test config 0
//   make run-multi INST=all TEST=mem_sdp_test  # test all configs
//   make regress-multi                     # full regression
// ============================================================

`timescale 1ns/1ps

module tb_top;

    // ----------------------------------------------------------
    // Shared Clock and Reset
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
    // Waveform Dump
    // ----------------------------------------------------------
    initial begin
        $dumpfile("dump.fst");
        $dumpvars(0, tb_top);
    end

    // ----------------------------------------------------------
    // Configuration Table (compile-time constants)
    // ----------------------------------------------------------
    localparam int NUM_CFG = 6;

    // Array of {addr_width, data_width} pairs
    localparam int CFG_ADDR_WIDTH [0:NUM_CFG-1] = '{ 8, 10, 12, 6, 16, 9 };
    localparam int CFG_DATA_WIDTH [0:NUM_CFG-1] = '{ 8, 32, 64, 256, 8, 128 };
    localparam string CFG_NAME [0:NUM_CFG-1] = '{
        "256x8",
        "1Kx32",
        "4Kx64",
        "64x256",
        "64Kx8",
        "512x128"
    };

    // ----------------------------------------------------------
    // Generate: Instantiate one test environment per config
    // ----------------------------------------------------------
    genvar g;
    logic [NUM_CFG-1:0] env_done;

    generate
        for (g = 0; g < NUM_CFG; g++) begin : gen_env
            sram_test_env #(
                .INST_ID     (g),
                .ADDR_WIDTH  (CFG_ADDR_WIDTH[g]),
                .DATA_WIDTH  (CFG_DATA_WIDTH[g]),
                .READ_LATENCY(1),
                .NUM_INST    (NUM_CFG)
            ) env_inst (
                .clk  (clk),
                .rst_n(rst_n),
                .done (env_done[g])
            );
        end
    endgenerate

    // ----------------------------------------------------------
    // Termination: $finish when all selected envs are done
    // ----------------------------------------------------------
    integer inst_sel_val;
    integer has_inst_sel;
    logic   all_done;

    always @(posedge clk) begin
        if (rst_n) begin
            if (has_inst_sel) begin
                // Single instance mode: finish when that instance is done
                if (env_done[inst_sel_val]) begin
                    $display("[TB_MULTI] Instance %0d done, finishing.", inst_sel_val);
                    $finish;
                end
            end else begin
                // ALL mode: finish when all instances are done
                all_done = &env_done;
                if (all_done) begin
                    $display("[TB_MULTI] All instances done, finishing.");
                    $finish;
                end
            end
        end
    end

    // ----------------------------------------------------------
    // Summary Reporter
    // ----------------------------------------------------------
    initial begin
        @(posedge rst_n);
        $display("============================================================");
        $display("[TB_MULTI] SRAM Multi-Config Testbench Ready");
        $display("[TB_MULTI] %0d configurations instantiated:", NUM_CFG);
        for (int i = 0; i < NUM_CFG; i++) begin
            $display("[TB_MULTI]   [%0d] %s  ADDR=%0d  DATA=%0d  DEPTH=%0d",
                     i, CFG_NAME[i], CFG_ADDR_WIDTH[i], CFG_DATA_WIDTH[i],
                     1 << CFG_ADDR_WIDTH[i]);
        end
        $display("============================================================");
        $display("[TB_MULTI] Control with +INST_ID=<n> +TEST=<name> +TX_COUNT=<n>");
        $display("[TB_MULTI] Omit +INST_ID to run ALL configs");
        $display("============================================================");

        // Detect INST_ID for termination logic
        has_inst_sel = $value$plusargs("INST_ID=%d", inst_sel_val);
    end

endmodule
