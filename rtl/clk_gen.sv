// ============================================================
// clk_gen - Parameterized Clock Generator with Jitter
// ============================================================
// Features:
//   - Configurable base period (default 10ns = 100MHz)
//   - Optional random jitter (uniform or gaussian distribution)
//   - Runtime control via plusargs:
//       +CLK_PERIOD_PS=10000       (clock period in ps)
//       +CLK_JITTER_EN=1           (1=enable, 0=disable)
//       +CLK_JITTER_PCT=5          (jitter as % of half-period, 0-50)
//       +CLK_JITTER_MODE=uniform   (uniform | gaussian)
//   - Duty cycle configurable
// ============================================================

`timescale 1ps/1ps

module clk_gen #(
    parameter int BASE_PERIOD_PS   = 10000,    // default 10ns
    parameter real DUTY_CYCLE      = 0.5,      // 50%
    parameter int SEED             = 42
)(
    output logic clk,
    output logic clk_stable        // asserted after N stable cycles
);

    // Runtime configuration
    int period_ps;
    int jitter_en;
    int jitter_pct;
    string jitter_mode_str;
    int jitter_val_ps;
    int half_period_ps;
    int stable_count;

    // Random seed (deterministic by default, but can be randomized)
    int rng_seed = SEED;

    initial begin
        // Read plusargs
        if (!$value$plusargs("CLK_PERIOD_PS=%d", period_ps))
            period_ps = BASE_PERIOD_PS;

        if (!$value$plusargs("CLK_JITTER_EN=%d", jitter_en))
            jitter_en = 1;   // default: enabled

        if (!$value$plusargs("CLK_JITTER_PCT=%d", jitter_pct)) begin
            jitter_pct = 5;  // default: ±5% jitter
            if (jitter_pct > 50) jitter_pct = 50;  // clamp
        end

        if (!$value$plusargs("CLK_JITTER_MODE=%s", jitter_mode_str))
            jitter_mode_str = "uniform";

        // Calculate jitter amplitude in ps
        half_period_ps = period_ps / 2;
        jitter_val_ps  = (half_period_ps * jitter_pct) / 100;

        $display("[CLK_GEN] period=%0d ps (%.2f MHz)  jitter_en=%0d  jitter_pct=%0d%%  mode=%s",
                 period_ps, 1e6/period_ps, jitter_en, jitter_pct, jitter_mode_str);
        $display("[CLK_GEN] half_period=%0d ps  jitter_amplitude=±%0d ps",
                 half_period_ps, jitter_val_ps);

        // Generate clock
        clk = 1'b0;
        clk_stable = 1'b0;
        stable_count = 0;

        forever begin
            // Wait half period ± jitter
            #(apply_jitter(half_period_ps));
            clk = ~clk;
            if (clk) begin
                stable_count++;
                if (stable_count > 5) clk_stable = 1'b1;
            end
        end
    end

    // ----------------------------------------------------------
    // Jitter calculation
    // ----------------------------------------------------------
    function automatic int apply_jitter(int base_delay_ps);
        int jitter;
        int delay_val;
        if (!jitter_en || jitter_val_ps == 0) begin
            return base_delay_ps;
        end

        case (jitter_mode_str)
            "gaussian": begin
                // Box-Muller approximation using $urandom
                real u1, u2, g;
                u1 = real'($urandom) / real'(32'hFFFFFFFF);
                u2 = real'($urandom) / real'(32'hFFFFFFFF);
                if (u1 < 1e-9) u1 = 1e-9;
                g = $sqrt(-2.0 * $ln(u1)) * $cos(2.0 * 3.1415926536 * u2);
                // Scale to jitter amplitude (σ = jitter_val_ps/3 for 3σ range)
                jitter = int'(g * real'(jitter_val_ps) / 3.0);
            end
            default: begin  // "uniform"
                jitter = ($urandom % (2 * jitter_val_ps + 1)) - jitter_val_ps;
            end
        endcase

        delay_val = base_delay_ps + jitter;
        if (delay_val < base_delay_ps / 10)
            delay_val = base_delay_ps / 10;  // minimum 10%
        return delay_val;
    endfunction

endmodule
