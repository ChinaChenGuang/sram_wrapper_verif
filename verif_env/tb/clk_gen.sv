// ============================================================
// clk_gen — Configurable Clock Generator
// ============================================================
// 特性:
//   - 频率可配:  +CLK_PERIOD_PS=<ps>   (default 10ns/100MHz)
//   - 占空比可配: +CLK_DUTY_CYCLE=<0-100> (default 50%)
//   - Jitter:     +CLK_JITTER_EN=1 +CLK_JITTER_PCT=5
//   - Gate 关断:  gate_en=0 时 clk 保持 0, 恢复后自动重同步
//
// 用法:
//   clk_gen #(.PERIOD_PS(10000), .DUTY(50), .SEED(42))
//       u_clk (.clk, .clk_stable, .gate_en);
//
// ============================================================

`timescale 1ps/1ps

module clk_gen #(
    parameter int PERIOD_PS = 10000,       // 时钟周期 (ps)
    parameter int DUTY      = 50,           // 占空比 (%)
    parameter int SEED       = 42
)(
    input  logic gate_en,                   // 时钟门控: 0=关断 1=正常
    output logic clk,
    output logic clk_stable
);

    int period_ps;
    int duty_pct;
    int jitter_en;
    int jitter_pct;
    string jitter_mode;

    int high_ps, low_ps;
    int jitter_range;
    int stable_count = 0;

    initial begin
        // ── 频率 ──
        if (!$value$plusargs("CLK_PERIOD_PS=%d", period_ps))
            period_ps = PERIOD_PS;

        // ── 占空比 (高电平占比, %) ──
        if (!$value$plusargs("CLK_DUTY_CYCLE=%d", duty_pct))
            duty_pct = DUTY;
        if (duty_pct < 1)  duty_pct = 1;
        if (duty_pct > 99) duty_pct = 99;

        // ── Jitter ──
        if (!$value$plusargs("CLK_JITTER_EN=%d", jitter_en))
            jitter_en = 0;
        if (!$value$plusargs("CLK_JITTER_PCT=%d", jitter_pct)) begin
            jitter_pct = 5;
            if (jitter_pct > 50) jitter_pct = 50;
        end
        if (!$value$plusargs("CLK_JITTER_MODE=%s", jitter_mode))
            jitter_mode = "uniform";

        high_ps      = (period_ps * duty_pct) / 100;
        low_ps       = period_ps - high_ps;
        jitter_range = (period_ps * jitter_pct) / 200;

        $display("[CLK_GEN] period=%0dps(%.2fMHz) duty=%0d%% jitter=%s±%0dps",
                 period_ps, 1e6/real'(period_ps), duty_pct,
                 jitter_mode, jitter_range);

        clk        = 1'b0;
        clk_stable = 1'b0;

        forever begin
            // ── Gate: 关断时 clk=0, 等待恢复 ──
            if (!gate_en) begin
                clk = 1'b0;
                stable_count = 0;
                @(posedge gate_en);
            end

            // ── 高电平段 ──
            #(apply_jitter(high_ps));
            clk = 1'b1;
            stable_count++;
            if (stable_count > 5) clk_stable = 1'b1;

            // ── Gate 关断 ──
            if (!gate_en) begin
                clk = 1'b0;
                stable_count = 0;
                @(posedge gate_en);
            end

            // ── 低电平段 ──
            #(apply_jitter(low_ps));
            clk = 1'b0;
        end
    end

    // ── Jitter ──
    function automatic int apply_jitter(int base_ps);
        int offset;
        int result;
        if (!jitter_en || jitter_range == 0)
            return base_ps;

        case (jitter_mode)
            "gaussian": begin
                real u1 = real'($urandom) / real'(32'hFFFFFFFF);
                real u2 = real'($urandom) / real'(32'hFFFFFFFF);
                if (u1 < 1e-9) u1 = 1e-9;
                offset = int'($sqrt(-2.0 * $ln(u1)) *
                              $cos(2.0 * 3.1415926536 * u2) *
                              real'(jitter_range) / 3.0);
            end
            default: begin
                offset = ($urandom % (2 * jitter_range + 1)) - jitter_range;
            end
        endcase

        result = base_ps + offset;
        if (result < period_ps / 20) result = period_ps / 20;
        return result;
    endfunction

endmodule
