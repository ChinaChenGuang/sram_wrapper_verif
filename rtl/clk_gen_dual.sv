// ============================================================
// clk_gen_dual - Dual Independent Clock Generator
// ============================================================
// Generates two clocks with independent frequency and phase.
//
// Runtime plusargs:
//   +CLK_A_PS=10000       Port A clock period (ps), default 10ns
//   +CLK_B_PS=10000       Port B clock period (ps), default 10ns
//   +CLK_B_PHASE_PS=0     Port B phase offset from clk_a (ps)
//   +CLK_A_JITTER=0       A jitter enable (1/0)
//   +CLK_B_JITTER=0       B jitter enable (1/0)
//   +CLK_JITTER_PCT=5     Jitter as % of half-period
//
// Common scenarios:
//   Same freq, 90° phase:  CLK_B_PHASE_PS=2500  (for 10ns period)
//   Same freq, 180° phase: CLK_B_PHASE_PS=5000
//   1:2 ratio:             CLK_A_PS=10000 CLK_B_PS=20000
//   2:1 ratio:             CLK_A_PS=20000 CLK_B_PS=10000
//   3:2 ratio:             CLK_A_PS=15000 CLK_B_PS=10000
// ============================================================

`timescale 1ps/1ps

module clk_gen_dual (
    output logic clk_a,
    output logic clk_b,
    output logic clk_stable        // asserted after both clocks stable
);

    int period_a_ps, period_b_ps;
    int phase_b_ps;
    int jitter_a_en, jitter_b_en;
    int jitter_pct;
    int jitter_val_a, jitter_val_b;
    int half_a_ps, half_b_ps;
    int stable_cnt;

    // Random seed for jitter
    int rng_a = 42;
    int rng_b = 137;

    initial begin
        // Read clock periods
        if (!$value$plusargs("CLK_A_PS=%d", period_a_ps))
            period_a_ps = 10000;
        if (!$value$plusargs("CLK_B_PS=%d", period_b_ps))
            period_b_ps = 10000;
        if (!$value$plusargs("CLK_B_PHASE_PS=%d", phase_b_ps))
            phase_b_ps = 0;
        if (!$value$plusargs("CLK_A_JITTER=%d", jitter_a_en)) jitter_a_en = 0;
        if (!$value$plusargs("CLK_B_JITTER=%d", jitter_b_en)) jitter_b_en = 0;
        if (!$value$plusargs("CLK_JITTER_PCT=%d", jitter_pct)) jitter_pct = 5;

        half_a_ps = period_a_ps / 2;
        half_b_ps = period_b_ps / 2;
        jitter_val_a = (half_a_ps * jitter_pct) / 100;
        jitter_val_b = (half_b_ps * jitter_pct) / 100;

        $display("[CLK_DUAL] clk_a: %0d ps (%.1f MHz)  clk_b: %0d ps (%.1f MHz)  phase: %0d ps",
                 period_a_ps, 1e6/period_a_ps,
                 period_b_ps, 1e6/period_b_ps,
                 phase_b_ps);
    end

    // Clock A
    initial begin
        clk_a = 1'b0;
        #(half_a_ps);  // first half
        forever begin
            clk_a = ~clk_a;
            #(apply_jitter(half_a_ps, jitter_a_en, jitter_val_a, rng_a));
        end
    end

    // Clock B (phase offset from clk_a)
    initial begin
        clk_b = 1'b0;
        #(phase_b_ps);
        #(half_b_ps);
        forever begin
            clk_b = ~clk_b;
            #(apply_jitter(half_b_ps, jitter_b_en, jitter_val_b, rng_b));
        end
    end

    // Stability monitor
    initial begin
        clk_stable = 1'b0;
        stable_cnt = 0;
        repeat (15) @(posedge clk_a);
        clk_stable = 1'b1;
    end

    // Simple jitter function
    function automatic int apply_jitter(int base, int en, int amp, inout int seed);
        int jit;
        if (!en || amp == 0) return base;
        jit = (seed % (2*amp + 1)) - amp;
        seed = seed * 1103515245 + 12345;  // LCG
        if (base + jit < base/10) return base/10;
        return base + jit;
    endfunction

endmodule
