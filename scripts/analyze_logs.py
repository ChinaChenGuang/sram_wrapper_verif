#!/usr/bin/env python3
# ============================================================
# analyze_logs.py - 仿真日志分析器
# ============================================================
# Feature 4: 分析仿真 log 文件，提取测试结果、SVA 错误详情、
#            生成 Markdown/JSON 汇总报告。
#
# 用法:
#   python3 scripts/analyze_logs.py run_dir/logs/              # 分析目录下所有 log
#   python3 scripts/analyze_logs.py run_dir/logs/ --report md  # 生成 Markdown 报告
#   python3 scripts/analyze_logs.py run_dir/logs/ --report json --output report.json
#   python3 scripts/analyze_logs.py run_dir/logs/ --summary    # 只打印摘要
#   python3 scripts/analyze_logs.py single.log                 # 分析单个 log
# ============================================================

import os
import re
import sys
import json
import argparse
from pathlib import Path
from dataclasses import dataclass, field
from typing import List, Optional
from datetime import datetime
from collections import defaultdict


# ============================================================
# Data Structures
# ============================================================

@dataclass
class SvaError:
    """A single SVA assertion error"""
    line_num: int
    message: str
    time_ns: float = 0.0
    port: str = ""          # "A" or "B"
    ori_value: str = ""
    new_value: str = ""
    context_before: List[str] = field(default_factory=list)
    context_after: List[str] = field(default_factory=list)


@dataclass
class TestResult:
    """Result of a single test run"""
    test_name: str = ""
    file_path: Path = None
    status: str = "UNKNOWN"     # PASS | FAIL | BUILD_FAIL | TIMEOUT
    sva_errors: List[SvaError] = field(default_factory=list)
    error_count: int = 0
    warning_count: int = 0
    transaction_count: int = 0
    simulation_time_ns: float = 0.0
    config: dict = field(default_factory=dict)  # addr_width, data_width, etc.
    raw_errors: List[str] = field(default_factory=list)


# ============================================================
# Log Parser
# ============================================================

class LogParser:
    """Parse a single simulation log file"""

    # Detects test name
    RE_TEST = re.compile(r'\[TB\].*Test:\s*(\S+)|Running test:\s*(\S+)|Test Start:\s*(\S+)', re.IGNORECASE)

    # Config info
    RE_CONFIG = re.compile(r'(?:ADDR_WIDTH|AW)\s*[=:]\s*(\d+).*?(?:DATA_WIDTH|DW)\s*[=:]\s*(\d+)', re.IGNORECASE)
    RE_MAX_CONFIG = re.compile(r'Max:\s*AW\s*=\s*(\d+)\s*DW\s*=\s*(\d+).*?Config:\s*AW\s*=\s*(\d+)\s*DW\s*=\s*(\d+)')

    # Transaction count
    RE_TX_COUNT = re.compile(r'(?:Transactions executed|Tx count)\s*[=:]\s*(\d+)', re.IGNORECASE)

    # Simulation time
    RE_SIM_TIME = re.compile(r'(?:Simulation time|sim time)\s*[=:]\s*([\d.]+)\s*(ns|us|ms|ps)?', re.IGNORECASE)
    RE_FINISH_AT = re.compile(r'-\s*(?:Info|Note).*?:?\s*(\d+)\s*(ns|us|ms|ps)', re.IGNORECASE)

    # Error detection
    RE_SVA_ERROR = re.compile(r'SVA ERROR:\s*(.*)', re.IGNORECASE)
    RE_SVA_DETAIL = re.compile(r'(?:Port\s*([AB]))\s*(?:read data\s*)?mismatch.*?ori\s*=\s*(\S+).*?new\s*=\s*(\S+)', re.IGNORECASE)
    RE_ERROR = re.compile(r'(?:ERROR|FATAL)(?!.*SVA ERROR)', re.IGNORECASE)
    RE_WARNING = re.compile(r'WARNING', re.IGNORECASE)
    RE_BUILD_FAIL = re.compile(r'(?:Build failed|compilation error|syntax error)', re.IGNORECASE)

    # End of test
    RE_TEST_END = re.compile(r'(?:Test End|Done:|Finishing)', re.IGNORECASE)
    RE_FINISH = re.compile(r'\$finish', re.IGNORECASE)

    CONTEXT_LINES = 3  # lines before/after an error for context

    @classmethod
    def parse_file(cls, filepath: Path) -> TestResult:
        """Parse a single simulation log file"""
        if not filepath.exists():
            return TestResult(file_path=filepath, status="MISSING")

        result = TestResult(file_path=filepath)
        lines = filepath.read_text(encoding="utf-8", errors="replace").splitlines()

        test_name = filepath.stem

        for i, line in enumerate(lines):
            # Test name
            m = cls.RE_TEST.search(line)
            if m:
                result.test_name = next(s for s in m.groups() if s) or test_name

            # Config
            m = cls.RE_MAX_CONFIG.search(line)
            if m:
                result.config = {
                    'max_aw': int(m.group(1)), 'max_dw': int(m.group(2)),
                    'aw': int(m.group(3)), 'dw': int(m.group(4))
                }
            else:
                m = cls.RE_CONFIG.search(line)
                if m and not result.config:
                    result.config = {'aw': int(m.group(1)), 'dw': int(m.group(2))}

            # Transaction count
            m = cls.RE_TX_COUNT.search(line)
            if m:
                result.transaction_count = max(result.transaction_count, int(m.group(1)))

            # Simulation time
            m = cls.RE_SIM_TIME.search(line)
            if m:
                result.simulation_time_ns = cls._to_ns(float(m.group(1)), m.group(2))

            # SVA Errors
            m = cls.RE_SVA_ERROR.search(line)
            if m:
                err = SvaError(line_num=i + 1, message=m.group(1))
                # Extract detail
                dm = cls.RE_SVA_DETAIL.search(m.group(1))
                if dm:
                    err.port = dm.group(1)
                    err.ori_value = dm.group(2)
                    err.new_value = dm.group(3)

                err.context_before = lines[max(0, i - cls.CONTEXT_LINES):i]
                err.context_after = lines[i + 1:min(len(lines), i + 1 + cls.CONTEXT_LINES)]
                result.sva_errors.append(err)

            # Other errors
            if cls.RE_ERROR.search(line) and not cls.RE_SVA_ERROR.search(line):
                result.raw_errors.append(line)
                result.error_count += 1

            # Warnings
            if cls.RE_WARNING.search(line):
                result.warning_count += 1

            # Build failure
            if cls.RE_BUILD_FAIL.search(line):
                result.status = "BUILD_FAIL"

        # Determine final status
        if result.status != "BUILD_FAIL":
            sva_fail_count = len(result.sva_errors)
            if sva_fail_count > 0 or result.error_count > 0:
                result.status = "FAIL"
            elif any(cls.RE_FINISH.search(l) for l in lines[-20:]):
                result.status = "PASS"
            elif any(cls.RE_TEST_END.search(l) for l in lines):
                result.status = "PASS"
            else:
                result.status = "INCOMPLETE"

        if not result.test_name:
            result.test_name = test_name

        return result

    @classmethod
    def _to_ns(cls, value: float, unit: Optional[str]) -> float:
        if not unit:
            return value
        unit = unit.lower().strip()
        if unit == 'ps': return value / 1000.0
        if unit == 'ns': return value
        if unit == 'us': return value * 1000.0
        if unit == 'ms': return value * 1_000_000.0
        return value


# ============================================================
# Report Generators
# ============================================================

def generate_summary(results: List[TestResult]) -> str:
    """Generate plain-text summary"""
    lines = []
    total = len(results)
    passed = sum(1 for r in results if r.status == "PASS")
    failed = sum(1 for r in results if r.status == "FAIL")
    build_fail = sum(1 for r in results if r.status == "BUILD_FAIL")
    other = total - passed - failed - build_fail
    total_sva = sum(len(r.sva_errors) for r in results)

    lines.append("=" * 70)
    lines.append(f"SIMULATION LOG ANALYSIS SUMMARY")
    lines.append(f"Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    lines.append("=" * 70)
    lines.append(f"")
    lines.append(f"  Total logs:       {total}")
    lines.append(f"  ✅ PASS:           {passed}")
    lines.append(f"  ❌ FAIL:           {failed}  (SVA errors: {total_sva})")
    lines.append(f"  🔧 BUILD_FAIL:     {build_fail}")
    if other:
        lines.append(f"  ⚠  OTHER:          {other}")
    lines.append(f"  Pass rate:         {passed/max(total,1)*100:.1f}%")
    lines.append(f"")

    # Per-instance summary
    by_instance = defaultdict(list)
    for r in results:
        key = r.config.get('aw', '?')
        by_instance[f"AW={key}"].append(r) if key != '?' else None

    if len(by_instance) > 1:
        lines.append("-" * 70)
        lines.append("  Per-Configuration Breakdown:")
        for cfg, cfg_results in sorted(by_instance.items()):
            p = sum(1 for r in cfg_results if r.status == "PASS")
            f = sum(1 for r in cfg_results if r.status == "FAIL")
            lines.append(f"    {cfg:8s}  ✅ {p}  ❌ {f}")
        lines.append("")

    # Failure details
    if failed > 0:
        lines.append("-" * 70)
        lines.append("  FAILURE DETAILS:")
        lines.append("")
        for r in results:
            if r.status == "FAIL":
                lines.append(f"  [{r.test_name}]  ({r.file_path.name})")
                lines.append(f"    Config: AW={r.config.get('aw','?')} DW={r.config.get('dw','?')}")
                lines.append(f"    SVA Errors: {len(r.sva_errors)}  |  Other Errors: {r.error_count}")
                for err in r.sva_errors[:5]:  # show first 5
                    lines.append(f"    ├─ Line {err.line_num}: Port {err.port} mismatch")
                    lines.append(f"    │  ori={err.ori_value}  new={err.new_value}")
                if len(r.sva_errors) > 5:
                    lines.append(f"    └─ ... and {len(r.sva_errors)-5} more SVA errors")
                lines.append("")

    lines.append("=" * 70)
    return "\n".join(lines)


def generate_markdown(results: List[TestResult]) -> str:
    """Generate Markdown report"""
    lines = []
    total = len(results)
    passed = sum(1 for r in results if r.status == "PASS")
    failed = sum(1 for r in results if r.status == "FAIL")
    build_fail = sum(1 for r in results if r.status == "BUILD_FAIL")
    total_sva = sum(len(r.sva_errors) for r in results)
    pass_rate = passed / max(total, 1) * 100

    lines.append(f"# SRAM B2B Regression Report")
    lines.append(f"")
    lines.append(f"**Generated:** {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    lines.append(f"")
    lines.append(f"## Summary")
    lines.append(f"")
    lines.append(f"| Metric | Value |")
    lines.append(f"|--------|-------|")
    lines.append(f"| Total Tests | {total} |")
    lines.append(f"| ✅ Passed | {passed} |")
    lines.append(f"| ❌ Failed | {failed} |")
    lines.append(f"| 🔧 Build Fail | {build_fail} |")
    lines.append(f"| SVA Errors | {total_sva} |")
    lines.append(f"| **Pass Rate** | **{pass_rate:.1f}%** |")
    lines.append(f"")

    if build_fail > 0:
        lines.append(f"## Build Failures")
        lines.append(f"")
        for r in results:
            if r.status == "BUILD_FAIL":
                lines.append(f"- `{r.file_path.name}`: {r.test_name}")
        lines.append(f"")

    if failed > 0:
        lines.append(f"## Failures")
        lines.append(f"")
        lines.append(f"| Test | Config | SVA Err | Other Err | Log |")
        lines.append(f"|------|--------|---------|-----------|-----|")
        for r in results:
            if r.status == "FAIL":
                cfg = f"AW={r.config.get('aw','?')} DW={r.config.get('dw','?')}" if r.config else "-"
                lines.append(f"| {r.test_name} | {cfg} | {len(r.sva_errors)} | {r.error_count} | {r.file_path.name} |")
        lines.append(f"")

        lines.append(f"### SVA Error Details")
        lines.append(f"")
        for r in results:
            if r.sva_errors:
                lines.append(f"#### {r.test_name}")
                lines.append(f"")
                for i, err in enumerate(r.sva_errors[:10]):
                    lines.append(f"**Error {i+1}** (line {err.line_num}):")
                    lines.append(f"```")
                    lines.append(f"  Port: {err.port}")
                    lines.append(f"  ori:  {err.ori_value}")
                    lines.append(f"  new:  {err.new_value}")
                    lines.append(f"  msg:  {err.message}")
                    lines.append(f"```")
                    lines.append(f"")
                if len(r.sva_errors) > 10:
                    lines.append(f"*... and {len(r.sva_errors)-10} more SVA errors*")
                    lines.append(f"")

    if passed > 0:
        lines.append(f"## Passed Tests")
        lines.append(f"")
        lines.append(f"| Test | Config | Tx Count | Sim Time |")
        lines.append(f"|------|--------|----------|----------|")
        for r in results:
            if r.status == "PASS":
                cfg = f"AW={r.config.get('aw','?')} DW={r.config.get('dw','?')}" if r.config else "-"
                stime = f"{r.simulation_time_ns:.1f}ns" if r.simulation_time_ns else "-"
                lines.append(f"| {r.test_name} | {cfg} | {r.transaction_count} | {stime} |")
        lines.append(f"")

    return "\n".join(lines)


def generate_json(results: List[TestResult]) -> str:
    """Generate JSON report"""
    data = {
        "generated": datetime.now().isoformat(),
        "summary": {
            "total": len(results),
            "passed": sum(1 for r in results if r.status == "PASS"),
            "failed": sum(1 for r in results if r.status == "FAIL"),
            "build_fail": sum(1 for r in results if r.status == "BUILD_FAIL"),
            "total_sva_errors": sum(len(r.sva_errors) for r in results),
        },
        "results": []
    }
    for r in results:
        entry = {
            "test": r.test_name,
            "file": str(r.file_path),
            "status": r.status,
            "config": r.config,
            "tx_count": r.transaction_count,
            "sim_time_ns": r.simulation_time_ns,
            "sva_error_count": len(r.sva_errors),
            "other_error_count": r.error_count,
            "sva_errors": [
                {
                    "line": e.line_num,
                    "port": e.port,
                    "ori_value": e.ori_value,
                    "new_value": e.new_value,
                    "message": e.message,
                }
                for e in r.sva_errors
            ]
        }
        data["results"].append(entry)
    return json.dumps(data, indent=2, ensure_ascii=False)


# ============================================================
# Main
# ============================================================

def main():
    parser = argparse.ArgumentParser(
        description="Simulation Log Analyzer - parse, summarize, report"
    )
    parser.add_argument("input", help="Log file or directory of logs")
    parser.add_argument("--report", "-r", choices=["text", "md", "json"], default="text",
                        help="Report format (default: text)")
    parser.add_argument("--output", "-o", default=None, help="Output file (default: stdout)")
    parser.add_argument("--summary", "-s", action="store_true",
                        help="Show only summary, no details")
    parser.add_argument("--pattern", "-p", default="*.log",
                        help="Log file pattern when scanning directory (default: *.log)")
    args = parser.parse_args()

    input_path = Path(args.input)

    # Collect log files
    log_files = []
    if input_path.is_dir():
        log_files = sorted(input_path.rglob(args.pattern))
    elif input_path.is_file():
        log_files = [input_path]
    else:
        print(f"ERROR: Input not found: {input_path}")
        sys.exit(1)

    if not log_files:
        print(f"No log files found matching '{args.pattern}' in {input_path}")
        sys.exit(1)

    # Parse all logs
    print(f"Analyzing {len(log_files)} log file(s)...", file=sys.stderr)
    results = []
    for f in log_files:
        r = LogParser.parse_file(f)
        results.append(r)

    # Sort by test name then config
    results.sort(key=lambda r: (r.test_name, str(r.config)))

    # Generate report
    if args.report == "md":
        report = generate_markdown(results)
    elif args.report == "json":
        report = generate_json(results)
    else:
        report = generate_summary(results)

    # Output
    if args.output:
        Path(args.output).write_text(report, encoding="utf-8")
        print(f"Report written to: {args.output}", file=sys.stderr)
    else:
        print(report)

    # Exit code
    failed = sum(1 for r in results if r.status == "FAIL")
    sys.exit(min(failed, 255))


if __name__ == "__main__":
    main()
