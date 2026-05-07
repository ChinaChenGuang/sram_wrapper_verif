#!/usr/bin/env python3
# ============================================================
# gen_sram_wrapper.py - SRAM Wrapper 生成器 (增强版)
# ============================================================
# Feature 2: 扫描给定目录，自动发现 SRAM 文件并配对
# Feature 3: 解析 module 端口，自动生成 sram_instance.sv 连线
#
# 用法:
#   python3 scripts/gen_sram_wrapper.py scan --orig rtl/orig --new rtl/new
#   python3 scripts/gen_sram_wrapper.py wrap rtl/orig/cpu_sys_256x182.sv
#   python3 scripts/gen_sram_wrapper.py full --orig rtl/orig --new rtl/new
# ============================================================

import re
import sys
import argparse
from pathlib import Path
from dataclasses import dataclass, field
from typing import Optional, List, Dict, Tuple


# ============================================================
# Data Structures
# ============================================================

@dataclass
class SramPort:
    name: str
    direction: str      # input | output | inout
    width_expr: str     # e.g., "ADDR_WIDTH-1:0" or ""
    type_: str = "logic"

    @property
    def width_str(self) -> str:
        return self.width_expr if self.width_expr else ""


@dataclass
class SramModule:
    name: str
    filepath: Path
    ports: List[SramPort] = field(default_factory=list)
    parameters: Dict[str, str] = field(default_factory=dict)
    raw_text: str = ""


# ============================================================
# Verilog Parser (lightweight, regex-based)
# ============================================================

class VerilogParser:
    RE_MODULE = re.compile(
        r'\bmodule\s+(\w+)\s*'
        r'(?:#\s*\((.*?)\)\s*)?'
        r'\s*\((.*?)\)\s*;',
        re.DOTALL
    )
    RE_PARAM = re.compile(
        r'\bparameter\s+(?:int\s+|integer\s+|logic\s+|bit\s+)?'
        r'(\w+)\s*=\s*([^,;)]+)',
        re.DOTALL
    )
    RE_PORT = re.compile(
        r'(input|output|inout)\s+'
        r'(?:(\w+)\s+)?'
        r'(?:\[([^\]]+)\]\s+)?'
        r'(\w+)'
    )

    @classmethod
    def parse_file(cls, filepath: Path) -> Optional[SramModule]:
        if not filepath.exists():
            return None
        content = filepath.read_text(encoding="utf-8", errors="replace")
        content = cls._strip_comments(content)
        m = cls.RE_MODULE.search(content)
        if not m:
            return None
        module_name = m.group(1)
        param_str = m.group(2) or ""
        port_str = m.group(3)
        params = {}
        if param_str:
            for pm in cls.RE_PARAM.finditer(param_str):
                params[pm.group(1)] = pm.group(2).strip()
        ports = cls._parse_ports(port_str)
        return SramModule(name=module_name, filepath=filepath, ports=ports, parameters=params, raw_text=content)

    @classmethod
    def _parse_ports(cls, port_str: str) -> List[SramPort]:
        ports = []
        for part in cls._split_ports(port_str):
            part = part.strip()
            if not part:
                continue
            m = cls.RE_PORT.match(part)
            if m:
                ports.append(SramPort(
                    name=m.group(4), direction=m.group(1),
                    width_expr=m.group(3) or "", type_=m.group(2) or "logic"
                ))
            else:
                if 'input' in part:
                    d = 'input'
                elif 'output' in part:
                    d = 'output'
                elif 'inout' in part:
                    d = 'inout'
                else:
                    continue
                words = part.replace(',', '').split()
                ports.append(SramPort(name=words[-1] if words else f"unk_{len(ports)}", direction=d))
        return ports

    @classmethod
    def _split_ports(cls, port_str: str) -> List[str]:
        parts, depth, current = [], 0, []
        for ch in port_str:
            if ch in '([{': depth += 1
            elif ch in ')]}': depth -= 1
            if ch == ',' and depth == 0:
                parts.append(''.join(current)); current = []
            else:
                current.append(ch)
        if current: parts.append(''.join(current))
        return parts

    @classmethod
    def _strip_comments(cls, content: str) -> str:
        content = re.sub(r'/\*.*?\*/', '', content, flags=re.DOTALL)
        content = re.sub(r'//.*$', '', content, flags=re.MULTILINE)
        return content


# ============================================================
# Port Name Mapping
# ============================================================

STANDARD_PORTS = {
    'clk':     {'direction': 'input',  'width': '1:0' if False else '', 'required': True},
    'rst_n':   {'direction': 'input',  'width': '',   'required': True},
    'cmd_a':   {'direction': 'input',  'width': '1:0', 'required': True},
    'addr_a':  {'direction': 'input',  'width': 'ADDR_WIDTH-1:0', 'required': True},
    'wdata_a': {'direction': 'input',  'width': 'DATA_WIDTH-1:0', 'required': True},
    'wem_a':   {'direction': 'input',  'width': 'DATA_WIDTH-1:0', 'required': True},
    'rdata_a': {'direction': 'output', 'width': 'DATA_WIDTH-1:0', 'required': True},
    'cmd_b':   {'direction': 'input',  'width': '1:0', 'required': False},
    'addr_b':  {'direction': 'input',  'width': 'ADDR_WIDTH-1:0', 'required': False},
    'wdata_b': {'direction': 'input',  'width': 'DATA_WIDTH-1:0', 'required': False},
    'wem_b':   {'direction': 'input',  'width': 'DATA_WIDTH-1:0', 'required': False},
    'rdata_b': {'direction': 'output', 'width': 'DATA_WIDTH-1:0', 'required': False},
}

PORT_ALIASES = {
    'clk':     [r'^clk$', r'^clock$', r'^clk_i$', r'^clk_in$'],
    'rst_n':   [r'^rst_n$', r'^rstn$', r'^reset_n$', r'^rst_ni$', r'^nreset$'],
    'cmd_a':   [r'^cmd_a$', r'^cena$', r'^ce_a$', r'^cs_a$', r'^chip_en_a$'],
    'addr_a':  [r'^addr_a$', r'^a_addr$', r'^addr_a_i$'],
    'wdata_a': [r'^wdata_a$', r'^din_a$', r'^d_a$', r'^data_in_a$'],
    'wem_a':   [r'^wem_a$', r'^we_a$', r'^bweb_a$', r'^bw_a$', r'^write_mask_a$'],
    'rdata_a': [r'^rdata_a$', r'^dout_a$', r'^q_a$', r'^data_out_a$'],
    'cmd_b':   [r'^cmd_b$', r'^cenb$', r'^ce_b$', r'^cs_b$', r'^chip_en_b$'],
    'addr_b':  [r'^addr_b$', r'^b_addr$', r'^addr_b_i$'],
    'wdata_b': [r'^wdata_b$', r'^din_b$', r'^d_b$', r'^data_in_b$'],
    'wem_b':   [r'^wem_b$', r'^we_b$', r'^bweb_b$', r'^bw_b$', r'^write_mask_b$'],
    'rdata_b': [r'^rdata_b$', r'^dout_b$', r'^q_b$', r'^data_out_b$'],
}


def map_ports(actual_ports: List[SramPort]) -> Dict[str, SramPort]:
    mapping = {}
    for std_name, aliases in PORT_ALIASES.items():
        for port in actual_ports:
            for alias_re in aliases:
                if re.match(alias_re, port.name, re.IGNORECASE):
                    mapping[std_name] = port
                    break
            if std_name in mapping:
                break
    return mapping


# ============================================================
# Width normalization helper
# ============================================================

def _norm_width(w: str) -> str:
    """Normalize width expression for comparison: strip outer [], whitespace"""
    w = w.strip()
    if w.startswith('[') and w.endswith(']'):
        w = w[1:-1]
    return w.replace(' ', '')


# ============================================================
# Wrapper Generator
# ============================================================

def generate_wrapper(module: SramModule, port_map: Dict[str, SramPort],
                     addr_width: int = 10, data_width: int = 32,
                     with_b2b_suffix: bool = False,
                     b2b_suffix: str = "_ori") -> str:
    """Generate a standardized wrapper module for the given SRAM"""

    wrapper_name = f"{module.name}{b2b_suffix if with_b2b_suffix else ''}_wrap"
    inner_name = f"{module.name}{b2b_suffix if with_b2b_suffix else ''}"

    lines = []
    lines.append("// ============================================================")
    lines.append(f"// AUTO-GENERATED by gen_sram_wrapper.py - DO NOT EDIT")
    lines.append(f"// Wraps: {module.name}")
    lines.append(f"// Source: {module.filepath}")
    lines.append(f"// Ports mapped: {len(port_map)}/{len(module.ports)}")
    lines.append("// ============================================================")
    lines.append("")
    lines.append("`timescale 1ns/1ps")
    lines.append("")

    # Module declaration
    lines.append(f"module {wrapper_name} #(")
    lines.append(f"    parameter ADDR_WIDTH = {addr_width},")
    lines.append(f"    parameter DATA_WIDTH = {data_width}")
    lines.append(")(")
    lines.append("    input  logic                       clk,")
    lines.append("    input  logic                       rst_n,")
    lines.append("")
    lines.append("    input  logic [1:0]                 cmd_a,")
    lines.append(f"    input  logic [ADDR_WIDTH-1:0]      addr_a,")
    lines.append(f"    input  logic [DATA_WIDTH-1:0]      wdata_a,")
    lines.append(f"    input  logic [DATA_WIDTH-1:0]      wem_a,")
    lines.append(f"    output logic [DATA_WIDTH-1:0]      rdata_a,")
    lines.append("")
    lines.append("    input  logic [1:0]                 cmd_b,")
    lines.append(f"    input  logic [ADDR_WIDTH-1:0]      addr_b,")
    lines.append(f"    input  logic [DATA_WIDTH-1:0]      wdata_b,")
    lines.append(f"    input  logic [DATA_WIDTH-1:0]      wem_b,")
    lines.append(f"    output logic [DATA_WIDTH-1:0]      rdata_b")
    lines.append(");")
    lines.append("")

    # Width-adaptive wiring
    lines.append("    // --------------------------------------------------------")
    lines.append("    // Width-adaptive wiring")
    lines.append("    // --------------------------------------------------------")

    for std_name in ['cmd_a', 'addr_a', 'wdata_a', 'wem_a', 'rdata_a',
                      'cmd_b', 'addr_b', 'wdata_b', 'wem_b', 'rdata_b']:
        if std_name not in port_map:
            continue
        actual = port_map[std_name]
        actual_w = _norm_width(actual.width_expr) if actual.width_expr else ""
        std_w = _norm_width(STANDARD_PORTS[std_name]['width'])

        if actual_w and actual_w != std_w:
            dir_ = actual.direction
            if dir_ == 'input':
                lines.append(f"    // Width adapt: {std_name} (std=[{std_w}]) -> (actual=[{actual_w}])")
                lines.append(f"    wire {actual.type_} [{actual_w}] {std_name}_adapted;")
                lines.append(f"    assign {std_name}_adapted = {std_name}[{actual_w}];")
            elif dir_ == 'output':
                lines.append(f"    // Width adapt: {std_name} output (actual=[{actual_w}]) -> (std=[{std_w}])")
                lines.append(f"    wire {actual.type_} [{actual_w}] {std_name}_adapted;")
                lines.append(f"    assign {std_name}[{actual_w}] = {std_name}_adapted;")
            lines.append("")

    # DUT instantiation
    lines.append("    // --------------------------------------------------------")
    lines.append(f"    // DUT: {inner_name}")
    lines.append("    // --------------------------------------------------------")

    param_overrides = []
    for pname, pdefault in module.parameters.items():
        if pname in ('ADDR_WIDTH', 'ADDRW', 'AW', 'A_WIDTH', 'ADDR_W'):
            param_overrides.append(f"        .{pname}(ADDR_WIDTH)")
        elif pname in ('DATA_WIDTH', 'DATAW', 'DW', 'D_WIDTH', 'DATA_W'):
            param_overrides.append(f"        .{pname}(DATA_WIDTH)")
        else:
            param_overrides.append(f"        .{pname}({pdefault})")

    if param_overrides:
        lines.append(f"    {inner_name} #(")
        lines.append(",\n".join(param_overrides))
        lines.append("    ) u_sram (")
    else:
        lines.append(f"    {inner_name} u_sram (")

    # Port connections
    port_connections = []
    if 'clk' in port_map:
        port_connections.append(f"        .{port_map['clk'].name}(clk)")
    if 'rst_n' in port_map:
        port_connections.append(f"        .{port_map['rst_n'].name}(rst_n)")

    def _needs_adapt(std_name, actual):
        if not actual.width_expr:
            return False
        return _norm_width(actual.width_expr) != _norm_width(STANDARD_PORTS[std_name]['width'])

    for std_name in ['cmd_a', 'addr_a', 'wdata_a', 'wem_a', 'rdata_a',
                      'cmd_b', 'addr_b', 'wdata_b', 'wem_b', 'rdata_b']:
        if std_name in port_map:
            actual = port_map[std_name]
            conn_sig = f"{std_name}_adapted" if _needs_adapt(std_name, actual) else std_name
            port_connections.append(f"        .{actual.name}({conn_sig})")

    # Tie off unconnected ports
    for port in module.ports:
        if port.name not in [port_map[k].name for k in port_map if k in port_map]:
            if port.direction == 'input':
                port_connections.append(f"        .{port.name}(1'b0)  // unconnected")
            else:
                port_connections.append(f"        .{port.name}()  // unconnected")

    lines.append(",\n".join(port_connections))
    lines.append("    );")
    lines.append("")
    lines.append("endmodule")
    lines.append("")

    return "\n".join(lines)


# ============================================================
# Directory Scanner
# ============================================================

def scan_directory(dirpath: Path) -> List[SramModule]:
    """Scan a directory and parse all Verilog module files"""
    modules = []
    for f in sorted(list(dirpath.glob("*.sv")) + list(dirpath.glob("*.v"))):
        mod = VerilogParser.parse_file(f)
        if mod:
            modules.append(mod)
            print(f"  Found: {mod.name} ({len(mod.ports)} ports) in {f.name}")
        else:
            print(f"  Skipped: {f.name} (no module declaration)")
    return modules


def pair_modules(orig_modules: List[SramModule],
                 new_modules: List[SramModule]) -> List[Tuple[SramModule, SramModule]]:
    """Pair original and new SRAM modules by filename stem"""
    pairs = []
    orig_by_stem = {m.filepath.stem: m for m in orig_modules}
    new_by_stem = {m.filepath.stem: m for m in new_modules}
    matched = set()

    for stem, new_mod in new_by_stem.items():
        if stem in orig_by_stem:
            pairs.append((orig_by_stem[stem], new_mod))
            matched.add(stem)

    unmatched_orig = [m for m in orig_modules if m.filepath.stem not in matched]
    unmatched_new = [m for m in new_modules if m.filepath.stem not in matched]
    if unmatched_orig:
        print(f"\n  Unmatched orig: {[m.name for m in unmatched_orig]}")
    if unmatched_new:
        print(f"  Unmatched new:  {[m.name for m in unmatched_new]}")
    return pairs


def _extract_param(params: dict, names: list, default: int) -> int:
    for n in names:
        if n in params:
            try: return int(params[n])
            except ValueError: pass
    return default


def generate_yaml_from_scan(pairs: List[Tuple[SramModule, SramModule]],
                            orig_dir: Path, new_dir: Path, output_path: Path):
    """Generate sram_instances.yaml from directory scan"""
    lines = [
        "# AUTO-GENERATED from directory scan",
        f"#   Orig: {orig_dir}",
        f"#   New:  {new_dir}",
        "",
        "instances:"
    ]
    for orig, new in pairs:
        name = orig.filepath.stem
        aw = _extract_param(orig.parameters, ['ADDR_WIDTH', 'ADDRW', 'AW', 'A_WIDTH'], 10)
        dw = _extract_param(orig.parameters, ['DATA_WIDTH', 'DATAW', 'DW', 'D_WIDTH'], 32)
        lines += [
            f"  - name: {name}",
            f"    module_name: {orig.name}",
            f"    orig_path: {orig_dir.name}/{orig.filepath.name}",
            f"    new_path: {new_dir.name}/{new.filepath.name}",
            f"    addr_width: {aw}",
            f"    data_width: {dw}",
            f"    enabled: true",
            ""
        ]
    lines += ["global:", "  output_dir: gen", "  ori_suffix: _ori", "  new_suffix: _new"]
    output_path.write_text("\n".join(lines), encoding="utf-8")
    print(f"\n  YAML config generated: {output_path}")


# ============================================================
# CLI Commands
# ============================================================

def cmd_scan(args):
    orig_dir = Path(args.orig_dir)
    new_dir = Path(args.new_dir)
    print("=" * 60)
    print(f"SRAM Directory Scanner: {orig_dir} <-> {new_dir}")
    print("=" * 60)

    print(f"\n[Scanning {orig_dir}/]")
    orig_modules = scan_directory(orig_dir)
    print(f"\n[Scanning {new_dir}/]")
    new_modules = scan_directory(new_dir)

    print(f"\n[Pairing...]")
    pairs = pair_modules(orig_modules, new_modules)

    print(f"\n{'='*60}")
    print(f"Results: {len(pairs)} paired, {len(orig_modules)-len(pairs)} unmatched orig, {len(new_modules)-len(pairs)} unmatched new")
    for orig, new in pairs:
        pm = map_ports(orig.ports)
        req = {k for k, v in STANDARD_PORTS.items() if v['required']}
        missing = req - set(pm.keys())
        status = "✓" if not missing else f"⚠ missing: {missing}"
        print(f"  {orig.name} <-> {new.name}  | {len(pm)}/{len(STANDARD_PORTS)} ports mapped {status}")
    print(f"{'='*60}")

    if args.gen_yaml:
        out = Path(args.gen_yaml) if args.gen_yaml != "auto" else Path("sram_instances_auto.yaml")
        generate_yaml_from_scan(pairs, orig_dir, new_dir, out)


def cmd_wrap(args):
    filepath = Path(args.sram_file)
    print("=" * 60)
    print(f"SRAM Wrapper Generator: {filepath}")
    print("=" * 60)

    module = VerilogParser.parse_file(filepath)
    if not module:
        print("ERROR: Failed to parse module"); sys.exit(1)

    print(f"\n  Module: {module.name}")
    print(f"  Params: {module.parameters}")
    print(f"  Ports ({len(module.ports)}):")
    for p in module.ports:
        print(f"    {p.direction:6s} [{p.width_str:20s}] {p.name}")

    port_map = map_ports(module.ports)
    print(f"\n  Port Mapping ({len(port_map)}/{len(STANDARD_PORTS)}):")
    for std_name, std_info in STANDARD_PORTS.items():
        if std_name in port_map:
            print(f"    ✓  {std_name:10s} -> {port_map[std_name].name}")
        elif std_info['required']:
            print(f"    ✗  {std_name:10s} -> NOT FOUND (REQUIRED!)")
        else:
            print(f"    -  {std_name:10s} -> (optional, not present)")

    wrapper = generate_wrapper(module, port_map)
    out_dir = Path(args.output_dir) if args.output_dir else Path("gen")
    out_dir.mkdir(parents=True, exist_ok=True)
    out_path = out_dir / f"{module.name}_wrap.sv"
    out_path.write_text(wrapper, encoding="utf-8")
    print(f"\n✓  Wrapper: {out_path}")

    if args.show:
        print(f"\n{'='*60}")
        print(wrapper)


def cmd_full(args):
    orig_dir = Path(args.orig_dir)
    new_dir = Path(args.new_dir)
    out_dir = Path(args.output_dir) if args.output_dir else Path("gen")

    print("=" * 60)
    print(f"SRAM B2B Full Pipeline: {orig_dir} <-> {new_dir} -> {out_dir}")
    print("=" * 60)

    print("\n[1/4] Scanning...")
    orig_mods = scan_directory(orig_dir)
    new_mods = scan_directory(new_dir)
    pairs = pair_modules(orig_mods, new_mods)

    if not pairs:
        print("ERROR: No matching SRAM pairs found!"); sys.exit(1)

    print(f"\n[2/4] Generating YAML...")
    yaml_path = out_dir / "sram_instances_auto.yaml"
    generate_yaml_from_scan(pairs, orig_dir, new_dir, yaml_path)

    print(f"\n[3/4] Generating wrappers...")
    for orig, new in pairs:
        aw = _extract_param(orig.parameters, ['ADDR_WIDTH', 'ADDRW', 'AW'], 10)
        dw = _extract_param(orig.parameters, ['DATA_WIDTH', 'DATAW', 'DW'], 32)
        for mod in [orig, new]:
            pm = map_ports(mod.ports)
            w = generate_wrapper(mod, pm, aw, dw)
            p = out_dir / f"{mod.name}_wrap.sv"
            p.write_text(w, encoding="utf-8")
            print(f"  ✓  {p.name}")

    print(f"\n[4/4] Generating B2B files...")
    print(f"  Run: python3 scripts/gen_sram_b2b.py --config {yaml_path}")
    if Path("scripts/gen_sram_b2b.py").exists():
        import subprocess
        r = subprocess.run(["python3", "scripts/gen_sram_b2b.py", "--config", str(yaml_path)], capture_output=True, text=True)
        print(r.stdout)
        if r.returncode != 0: print(r.stderr)
    print(f"\nDone. Next: make gen-b2b")


# ============================================================
# Main
# ============================================================

def main():
    parser = argparse.ArgumentParser(description="SRAM Wrapper Generator")
    sub = parser.add_subparsers(dest="cmd")

    p = sub.add_parser("scan", help="Scan directories, auto-pair SRAM modules")
    p.add_argument("--orig", dest="orig_dir", required=True)
    p.add_argument("--new", dest="new_dir", required=True)
    p.add_argument("--gen-yaml", dest="gen_yaml", default=None, nargs="?", const="auto")

    p = sub.add_parser("wrap", help="Generate wrapper for single SRAM module")
    p.add_argument("sram_file")
    p.add_argument("-o", "--output-dir", dest="output_dir", default="gen")
    p.add_argument("--show", action="store_true")

    p = sub.add_parser("full", help="Full pipeline: scan + wrap + B2B")
    p.add_argument("--orig", dest="orig_dir", required=True)
    p.add_argument("--new", dest="new_dir", required=True)
    p.add_argument("-o", "--output-dir", dest="output_dir", default="gen")

    args = parser.parse_args()
    if args.cmd == "scan": cmd_scan(args)
    elif args.cmd == "wrap": cmd_wrap(args)
    elif args.cmd == "full": cmd_full(args)
    else: parser.print_help()


if __name__ == "__main__":
    main()
