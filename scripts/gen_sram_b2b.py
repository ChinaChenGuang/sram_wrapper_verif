#!/usr/bin/env python3
# ============================================================
# gen_sram_b2b.py - SRAM Back-to-Back 文件生成器 v3
# ============================================================
# 读取 YAML 配置，扫描 RTL 文件，自动重命名所有 module 并生成
# ori+new+checker 的 B2B 对比 connect 文件。
#
# 用法:
#   python3 scripts/gen_sram_b2b.py --config sram_instances.yaml
#   python3 scripts/gen_sram_b2b.py --dry-run
# ============================================================

import os, re, sys, argparse, math
import datetime
import shutil
from pathlib import Path

try:
    import yaml
except ImportError:
    print("ERROR: PyYAML required: pip3 install pyyaml")
    sys.exit(1)

SCRIPT_DIR = Path(__file__).parent.resolve()
PROJ_ROOT = SCRIPT_DIR.parent
CONFIG_YAML = PROJ_ROOT / "sram_instances.yaml"

# ============================================================
# 日志
# ============================================================

class Logger:
    def __init__(self, log_path=None):
        self._lines = []
        self._log_path = log_path

    def write(self, msg=""):
        self._lines.append(msg)
        print(msg)

    def save(self):
        if self._log_path:
            self._log_path.parent.mkdir(parents=True, exist_ok=True)
            self._log_path.write_text("\n".join(self._lines) + "\n")

# ============================================================
# RTL 解析
# ============================================================

def parse_rtl_params(filepath: Path, log: Logger) -> dict:
    if not filepath.exists():
        log.write(f"  FAIL: parse_from 文件不存在: {filepath}")
        return {}
    content = filepath.read_text(encoding="utf-8", errors="replace")
    params = {}

    m = re.search(r'\bmodule\s+(\w+)', content)
    if m:
        params["module_name"] = m.group(1)

    m = re.search(r'\bparameter\s+(?:RUNIOBIT|BUNIOBIT)\s*=\s*(\d+)', content)
    if m:
        params["data_width"] = int(m.group(1))

    m = re.search(r'\bparameter\s+NUMWORD\s*=\s*(\d+)', content)
    if m:
        params["num_word"] = int(m.group(1))
    if "num_word" not in params:
        m = re.search(r'\b(?:local)?parameter\s+(?:NUMWORD|NUM_WORD|WORDS|DEPTH|NUM_W|NW)\s*=\s*(\d+)', content)
        if m:
            params["num_word"] = int(m.group(1))

    m = re.search(r'\blocalparam\s+ADDR_WIDTH\s*=\s*\$?clog2\s*\(\s*NUMWORD\s*\)', content)
    if m and "num_word" in params:
        params["addr_width"] = math.ceil(math.log2(params["num_word"]))

    m = re.search(r'\b(?:local)?parameter\s+ADDR_WIDTH\s*=\s*(\d+)', content)
    if m:
        params["addr_width"] = int(m.group(1))

    return params


def scan_module_names(file_paths: list) -> set:
    names = set()
    for fp in file_paths:
        p = Path(fp)
        if not p.exists():
            continue
        content = p.read_text(encoding="utf-8", errors="replace")
        for m in re.finditer(r'\bmodule\s+(\w+)', content):
            names.add(m.group(1))
    return names - {'endmodule', 'input', 'output', 'inout', 'parameter', 'localparam'}

def strip_latches_from_content(content: str) -> str:
    def replacer(match):
        chunk = match.group(0)
        m_first_mod = re.search(r'\bmodule\s+(\w+)\b', chunk)
        if not m_first_mod: return chunk
        mod_name = m_first_mod.group(1)
        
        # DO NOT PROCESS core module (or any module ending in _core)
        if mod_name.endswith("_core"):
            return chunk
        
        # Extract ports for instantiation
        ports = []
        def extract_ports_from_decl(decl_body):
            body = re.sub(r'\[[^\]]*\]', '', decl_body)
            body = re.sub(r'\b(?:wire|reg|logic)\b', '', body)
            for p in body.split(','):
                p = p.strip()
                m_id = re.search(r'\b([A-Za-z_]\w*)\b', p)
                if m_id: ports.append(m_id.group(1))

        for m in re.finditer(r'\b(?:input|output|inout)\b([^;]+);', chunk):
            extract_ports_from_decl(m.group(1))
            
        for m_mod in re.finditer(r'\bmodule\s+\w+\b([\s\S]*?);', chunk):
            m_paren = re.search(r'\(([\s\S]*)\)', m_mod.group(1))
            if m_paren:
                inner = m_paren.group(1)
                for port_def in inner.split(','):
                    if re.search(r'\b(?:input|output|inout)\b', port_def):
                        clean_def = re.sub(r'\b(?:input|output|inout)\b', '', port_def)
                        extract_ports_from_decl(clean_def)

        unique_ports = []
        for p in ports:
            if p not in unique_ports:
                unique_ports.append(p)

        # Find submodule instance
        keywords = {"module", "endmodule", "input", "output", "inout", "wire", "reg", "logic", "assign", "always", "always_comb", "always_ff", "always_latch", "parameter", "localparam", "if", "else", "generate", "endgenerate", "for", "begin", "end", "integer", "genvar", "case", "endcase", "initial"}
        
        inst_pattern = re.compile(r'\b([A-Za-z_]\w*)\s*(?:#\s*\([\s\S]*?\))?\s+([A-Za-z_]\w*)\s*\([\s\S]*?\)\s*;')
        submodule_name = None
        for m in inst_pattern.finditer(chunk):
            if m.group(1) not in keywords:
                submodule_name = m.group(1)
                break

        if not submodule_name:
            lines = chunk.split(';')
            for stmt in lines:
                stmt = stmt.strip()
                if not stmt: continue
                words = re.findall(r'\b[A-Za-z_]\w*\b', stmt)
                if words and words[0] not in keywords:
                    if len(words) >= 2 and '(' in stmt and ')' in stmt:
                        submodule_name = words[0]
                        break

        if not submodule_name:
            return chunk # fallback

        # Extract items to keep from the entire chunk
        keep_pattern = re.compile(r'^\s*(?:(`ifdef\b|`ifndef\b|`else\b|`elsif\b|`endif\b)[^\n]*|(\binput\b|\boutput\b|\binout\b|\bparameter\b|\blocalparam\b|\bmodule\b)[^;]*;?)', re.MULTILINE)
        
        kept_items = []
        body = chunk[:chunk.rfind('endmodule')]
        for m in keep_pattern.finditer(body):
            text = m.group(0).strip()
            if text.startswith("`") or text.startswith("module"):
                kept_items.append(text)
            else:
                kept_items.append("  " + text)

        out_lines = []
        out_lines.append("// AUTO-GENERATED: Latch removed, kept IO, directives and submodule instance")
        for d in kept_items:
            out_lines.append(d)
        out_lines.append("")
        out_lines.append(f"  {submodule_name} u_inst_{submodule_name} (")
        conn_lines = []
        for p in unique_ports:
            conn_lines.append(f"    .{p}({p})")
        out_lines.append(",\n".join(conn_lines))
        out_lines.append("  );")
        out_lines.append("endmodule")
        return "\n".join(out_lines)

    # Use re.sub to process only module blocks
    new_content = re.sub(r'(?s)\bmodule\s+\w+\b.*?\bendmodule\b', replacer, content)
    return new_content


def rename_modules_in_file(src_path: Path, rename_map: dict, dst_path: Path, log: Logger, strip_latches: bool = False) -> bool:
    if not src_path.exists():
        log.write(f"  FAIL: 源文件不存在: {src_path}")
        return False

    content = src_path.read_text(encoding="utf-8", errors="replace")

    if strip_latches and ("_syn.v" in src_path.name or "_syn.sv" in src_path.name):
        content = strip_latches_from_content(content)

    for old_name in sorted(rename_map.keys(), key=len, reverse=True):
        new_name = rename_map[old_name]
        if old_name == new_name:
            continue
        content = re.sub(r'\b' + re.escape(old_name) + r'\b', new_name, content)

    header = (f"// AUTO-GENERATED by gen_sram_b2b.py\n"
              f"// Source: {src_path}\n"
              f"// Renames: {', '.join(f'{k}→{v}' for k,v in rename_map.items() if k != v)}\n")
    dst_path.parent.mkdir(parents=True, exist_ok=True)
    dst_path.write_text(header + content, encoding="utf-8")
    return True


def load_filelist(path: Path) -> list:
    if not path.exists():
        return []
    lines = path.read_text().splitlines()
    result = []
    for line in lines:
        line = line.strip()
        if not line or line.startswith('#') or line.startswith('+') or line.startswith('-'):
            continue
        result.append(line)
    return result


# ============================================================
# 主函数
# ============================================================

def parse_module_ports(filepath: Path, LOG: Logger):
    """Parse a Verilog module file, return ([ports], [params]).
    Each port: {"name": str, "dir": "input"|"output"|"inout", "width": int}
    Each param: {"name": str, "default": str or None}
    """
    if not filepath or not filepath.exists():
        return [], []
    content = filepath.read_text(encoding="utf-8", errors="replace")

    # Find module body
    m = re.search(r'module\s+\w+\s*(?:#[^)]*\))?\s*\(([^)]*)\)', content, re.DOTALL)
    if not m:
        LOG.write(f"  WARNING: 无法解析模块端口: {filepath.name}")
        return [], []

    ports_text = m.group(1)

    # Parse parameters
    params = []
    for pm in re.finditer(r'parameter\s+(\w+)\s*=\s*([^,;\)]+)', content):
        params.append({"name": pm.group(1), "default": pm.group(2).strip()})

    # Parse ports
    ports = []
    # Remove comments
    ports_text_clean = re.sub(r'//[^\n]*', '', ports_text)
    # Split by comma, then parse each
    port_entries = re.split(r'\s*,\s*', ports_text_clean)
    for entry in port_entries:
        entry = entry.strip()
        if not entry:
            continue
        # Determine direction
        direction = "input"
        if entry.startswith("output"):
            direction = "output"
        elif entry.startswith("inout"):
            direction = "inout"

        # Extract name
        name_m = re.search(r'(\w+)\s*$', entry)
        if name_m:
            ports.append({"name": name_m.group(1), "dir": direction})

    LOG.write(f"  Parsed ports from {filepath.name}: {len(ports)} ports, {len(params)} params")
    return ports, params


def map_port_to_tb(port: dict, postfix: str, all_ports: list, inst_name: str) -> str:
    """Map a module port to tb_top signal.
    all_ports is used to detect 1P vs 2P mode.
    """
    name = port["name"]
    direction = port["dir"]

    # Detect 1P vs 2P by looking for dual-port specific signals
    port_names = {p["name"] for p in all_ports}
    is_2p = "CLKW" in port_names or "CLKR" in port_names

    # === 2P (Dual Port) ===
    if is_2p:
        if name == "CLKW":  return "clk_a"
        if name == "CLKR":  return "clk_b"
        if name == "RSTNW": return "rst_n"
        if name == "RSTNR": return "rst_n"
        if name == "WEB":   return "wr_if.we"
        if name == "REB":   return "rd_if.ce"
        if name == "CEB":   return "wr_if.ce"
        if name == "AA":    return "wr_if.addr"
        if name == "AB":    return "rd_if.addr"
        if name == "D":     return "wr_if.wdata"
        if name == "Q":     return f"rdata_b{postfix}_{inst_name}"

    # === 1P (Single Port) ===
    if not is_2p:
        if name == "CLK":   return "clk_a"
        if name == "rstn":  return "rst_n"
        if name == "CEB":   return "wr_if.ce"
        if name == "WEB":   return "wr_if.we"
        if name == "BWEB":  return "wr_if.wem"
        if name == "A":     return "wr_if.addr"
        if name == "D":     return "wr_if.wdata"
        if name == "Q":     return f"rdata_a{postfix}_{inst_name}"

    # === Common (legacy + lowercase port names) ===
    name_map = {
        "clk": "clk_a", "clk_a": "clk_a", "clk_b": "clk_b",
        "rst_n": "rst_n", "rst": "rst_n", "reset_n": "rst_n",
        "ceb": "wr_if.ce",
        "web": "wr_if.we",
        "addr": "wr_if.addr",
        "wdata": "wr_if.wdata",
        "wem": "wr_if.wem",
        "cmd_a": "cmd_a", "cmd_b": "cmd_b",
        "addr_a": "wr_if.addr", "addr_b": "rd_if.addr",
        "wdata_a": "wr_if.wdata", "wdata_b": "rd_if.wdata",
        "wem_a": "wr_if.wem", "wem_b": "rd_if.wem",
        "rdata_a": f"rdata_a{postfix}_{inst_name}", "rdata_b": f"rdata_b{postfix}_{inst_name}",
    }
    if name in name_map:
        return name_map[name]

    # === ECC / config ===
    if name == "mem_cfg":
        if postfix == "_ori":
            return "18'b11_0011_0_0011"
        else:
            return "40'h7738"
    ecc_outputs = {"ecc_encoder_parity_out", "ecc_decoder_parity_out",
                   "ecc_error_type", "latent_err", "mission_err"}
    if name in ecc_outputs:
        return "/* */"
    
    # Specific ECC inputs tying rules
    if name == "ecc_encoder_bypass":
        return "1'b1"
    if name == "ecc_encoder_parity_in":
        return "1'b0"
    if name == "ecc_decoder_bypass":
        return "1'b1"
    if name == "fault_injection_enable":
        return "1'b0"
    if name == "fault_injection_value":
        return "1'b0"

    # === Default ===
    if direction == "output" or direction == "inout":
        return "/* */"
    return "1'b0"


# ============================================================
# 主函数
# ============================================================

def main():
    parser = argparse.ArgumentParser(description="SRAM B2B Generator v3")
    parser.add_argument("--config", type=str, default=str(CONFIG_YAML))
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--instance", type=str, default=None)
    parser.add_argument("--log", type=str, default="")
    args = parser.parse_args()

    config_path = Path(args.config)
    log_path = Path(args.log) if args.log else None
    LOG = Logger(log_path)

    LOG.write(f"gen_sram_b2b.py — config: {config_path}")
    LOG.write()

    if not config_path.exists():
        LOG.write(f"FAIL: 配置文件不存在: {config_path}")
        LOG.write(f"  请先运行: python3 scripts/parse_memoris.py")
        sys.exit(1)

    with open(config_path) as f:
        cfg = yaml.safe_load(f)

    instances = cfg.get("instances", [])
    if not instances:
        LOG.write("FAIL: YAML 中没有 instances 配置")
        sys.exit(1)

    global_cfg = cfg.get("global", {})
    out_dir = PROJ_ROOT / global_cfg.get("output_dir", "gen")
    ori_sfx = global_cfg.get("ori_suffix", "_ori")
    new_sfx = global_cfg.get("new_suffix", "_bm")
    emu_sfx = global_cfg.get("emu_suffix", "_em")

    if args.instance:
        instances = [i for i in instances if args.instance in i["name"]]
        if not instances:
            LOG.write(f"FAIL: 没有匹配 '--instance {args.instance}' 的实例")
            sys.exit(1)

    enabled = [i for i in instances if i.get("enabled", True)]
    disabled = [i for i in instances if not i.get("enabled", True)]

    LOG.write(f"Instances: {len(enabled)} enabled, {len(disabled)} disabled")
    LOG.write(f"Output:    {out_dir}/")
    if args.dry_run:
        LOG.write(">>> DRY RUN <<<")
    else:
        if out_dir.exists():
            shutil.rmtree(out_dir)
            LOG.write(f"Cleaned previous output directory.")
        out_dir.mkdir(parents=True, exist_ok=True)

    wrapper_srcs = set()
    lib_srcs = {"bm": set(), "em": set(), "orig": set(), "mod": set()}
    ok = fail = 0
    failures = []  # track failure reasons per instance

    for inst in enabled:
        name = inst["name"]
        inst_fails = []
        LOG.write(f"\n{'─'*50}")
        LOG.write(f"── {name}")
        LOG.write(f"{'─'*50}")

        # ── 解析参数 ──
        parse_from = inst.get("parse_from") or inst.get("orig_path") or f"rtl/orig/{name}.v"
        parse_path = (PROJ_ROOT / parse_from) if not Path(parse_from).is_absolute() else Path(parse_from)

        params = parse_rtl_params(parse_path, LOG)
        if not params or "module_name" not in params:
            reason = f"参数解析失败: parse_from={parse_path}"
            LOG.write(f"  FAIL: {reason}")
            inst_fails.append(reason)
            fail += 1
            failures.append((name, inst_fails))
            continue

        mod_name = params.get("module_name", name)
        dw = params.get("data_width", inst.get("data_width", "?"))
        aw = params.get("addr_width", inst.get("addr_width", "?"))

        LOG.write(f"  Module:   {mod_name}")
        LOG.write(f"  Params:   数据位宽={dw}  深度={1<<aw if isinstance(aw,int) else '?'}  AW={aw}")

        # ── 收集文件 ──
        inst_data = {}
        sides_to_process = [("orig", ori_sfx), ("new", new_sfx)]
        if inst.get("emu_path"):
            sides_to_process.append(("emu", emu_sfx))

        for side, sfx in sides_to_process:
            files = []

            # 1) Primary wrapper
            primary = inst.get(f"{side}_path", f"rtl/{side}/{name}.v")
            p = str(PROJ_ROOT / primary) if not Path(primary).is_absolute() else primary
            files.append(p)

            # 2) Filelist
            fl_path = inst.get(f"{side}_filelist", "")
            if fl_path:
                fl_abs = str(PROJ_ROOT / fl_path) if not Path(fl_path).is_absolute() else fl_path
                mem_files = load_filelist(Path(fl_abs))
                if not mem_files:
                    reason = f"[{side}] filelist 为空或不存在: {fl_path}"
                    LOG.write(f"  WARNING: {reason}")
                for mf in mem_files:
                    mf_path = str(PROJ_ROOT / mf) if not Path(mf).is_absolute() else mf
                    files.append(mf_path)

            # 3) Extra files (auto-discovered by parse_memoris.py)
            for xf in inst.get(f"{side}_extra", []):
                xf_path = str(PROJ_ROOT / xf) if not Path(xf).is_absolute() else xf
                files.append(xf_path)

            # 4) Resolve
            file_paths = []
            missing = []
            for f in files:
                p = Path(f)
                if p.exists():
                    file_paths.append(p)
                else:
                    missing.append(f)
            if missing:
                reason = f"[{side}] 文件不存在:\n    " + "\n    ".join(str(m) for m in missing[:5])
                if len(missing) > 5:
                    reason += f"\n    ... +{len(missing)-5} more"
                LOG.write(f"  FAIL: {reason}")
                inst_fails.append(reason)

            if not file_paths:
                LOG.write(f"  FAIL: [{side}] 无可用文件")
                inst_fails.append(f"[{side}] 无可用文件")
                fail += 1
                continue

            # 5) Scan modules
            all_mods = scan_module_names(file_paths)
            if not all_mods:
                reason = f"[{side}] 未找到任何 module 声明（文件可能不是 RTL）"
                LOG.write(f"  FAIL: {reason}")
                LOG.write(f"    文件列表: {','.join(p.name for p in file_paths[:10])}")
                inst_fails.append(reason)
                fail += 1
                continue

            rename_map = {}
            for m in all_mods:
                is_syn_lib = any(f.name == f"{m}_syn.v" or f.name == f"{m}_syn.sv" for f in file_paths)
                if side == "emu" and is_syn_lib:
                    rename_map[m] = f"{m}_emu"
                elif side == "mod":
                    rename_map[m] = m
                else:
                    rename_map[m] = f"{m}{sfx}"
            LOG.write(f"  [{side}] {len(file_paths)} files, {len(rename_map)} modules")
            for k, v in sorted(rename_map.items()):
                if k != v:
                    LOG.write(f"    {k} → {v}")

            inst_data[side] = (file_paths, rename_map)

        # ── 检查两侧都成功 ──
        if "orig" not in inst_data or "new" not in inst_data:
            reason = f"缺少 {'new' if 'orig' in inst_data else 'orig'} 侧数据"
            LOG.write(f"  FAIL: {reason}")
            inst_fails.append(reason)
            fail += 1
            failures.append((name, inst_fails))
            continue

        if "emu" in inst_data:
            mod_file_paths = inst_data["emu"][0]
            mod_rename_map = {m: m for m in inst_data["emu"][1].keys()}
            inst_data["mod"] = (mod_file_paths, mod_rename_map)
            sides_to_process.append(("mod", ""))

        # ── 生成重命名文件 ──
        for side, sfx in sides_to_process:
            file_paths, rename_map = inst_data[side]
            side_lib_dir = "bm" if side == "new" else ("em" if side == "emu" else ("mod" if side == "mod" else "orig"))
            
            for src_path in file_paths:
                stem = src_path.stem
                is_wrapper = "_mem_wrap" in src_path.name
                
                if is_wrapper:
                    dst_name = f"{stem}{sfx}.v"
                    dst_path = out_dir / dst_name
                else:
                    dst_name = src_path.name
                    dst_path = out_dir / "lib" / side_lib_dir / dst_name

                if args.dry_run:
                    LOG.write(f"  → {dst_path}")
                    ok += 1
                else:
                    if rename_modules_in_file(src_path, rename_map, dst_path, LOG, strip_latches=(side=="mod")):
                        if is_wrapper:
                            LOG.write(f"  ✓ {dst_name}")
                            wrapper_srcs.add(dst_path)
                        else:
                            LOG.write(f"  ✓ {dst_name} -> lib/{side_lib_dir}/")
                            lib_srcs[side_lib_dir].add(dst_path)
                        ok += 1
                    else:
                        reason = f"重命名失败: {src_path.name}"
                        LOG.write(f"  FAIL: {reason}")
                        inst_fails.append(reason)
                        fail += 1

        # ── 生成 connect snippet (parse real wrapper ports) ──
        ori_top = f"{mod_name}{ori_sfx}"
        new_top = f"{mod_name}{new_sfx}"
        emu_top = f"{mod_name}{emu_sfx}" if "emu" in inst_data else ""

        wrapper_file = Path(inst.get("orig_path", f"rtl/orig/{name}.v"))
        if not wrapper_file.exists():
            wrapper_file = inst_data.get("orig") and inst_data["orig"][0][0]
        if wrapper_file and wrapper_file.exists():
            ports, params = parse_module_ports(wrapper_file, LOG)
        else:
            ports, params = [], []
            LOG.write(f"  WARNING: 无法解析 wrapper 端口，使用默认模板")

        connect_lines = [
            "// AUTO-GENERATED B2B connect",
            f"// {ori_top} vs {new_top}",
            "",
            f"// Usage: compile with +define+SIM_{name} to enable this instance",
            f"//        or +define+SIM_ALL to enable all instances",
            f"`ifdef SIM_{name}",
            f"`ifndef SIM_ALL",
            f"    `define SIM_ALL  // also enable ALL flag",
            f"`endif",
            f"`endif",
            f"`ifdef SIM_ALL",
            "",
            f"// Instance-specific data mask ({dw} bits) and localized wires",
            f"logic [{dw}-1:0] data_mask_{name} = '1;",
            f"logic [{dw}-1:0] rdata_a_ori_{name}, rdata_b_ori_{name};",
            f"logic [{dw}-1:0] rdata_a_new_{name}, rdata_b_new_{name};",
            f"logic [{dw}-1:0] rdata_a_emu_{name}, rdata_b_emu_{name};",
            f"logic [{dw}-1:0] rdata_a_mod_{name}, rdata_b_mod_{name};",
            "",
            f"`ifndef RDATA_DRIVEN",
            f"    `define RDATA_DRIVEN",
            f"    assign rdata_a_ori = rdata_a_ori_{name};",
            f"    assign rdata_b_ori = rdata_b_ori_{name};",
            f"    assign rdata_a_new = rdata_a_new_{name};",
            f"    assign rdata_b_new = rdata_b_new_{name};",
            f"`endif",
            ""]
        if "emu" not in inst_data:
            connect_lines.extend([
                f"    assign rdata_a_emu_{name} = '0;",
                f"    assign rdata_b_emu_{name} = '0;",
                f"    assign rdata_a_mod_{name} = '0;",
                f"    assign rdata_b_mod_{name} = '0;"
            ])

        instances_to_connect = [("ori", ori_top, "_ori"), ("new", new_top, "_new")]
        if "emu" in inst_data:
            instances_to_connect.append(("emu", emu_top, "_emu"))
            instances_to_connect.append(("mod", mod_name, "_mod"))

        for side, top_mod, postfix in instances_to_connect:
            tag = f"DUT {side.upper()}"
            connect_lines.append(f"  // {tag}: {top_mod}")
            # Parameter list — use known values, fallback to default from RTL
            if params:
                pvals = []
                for p in params:
                    pname = p['name']
                    # Use parsed value if available
                    if pname in ('ADDR_WIDTH', 'AW', 'ADDR_W'):
                        val = str(aw) if isinstance(aw, int) else p.get('default', '?')
                    elif pname in ('DATA_WIDTH', 'DW', 'DATA_W'):
                        val = str(dw) if isinstance(dw, int) else p.get('default', '?')
                    else:
                        val = p.get('default', '?')
                    pvals.append(f"    .{pname} ({val})")
                connect_lines.append(f"{top_mod} #(")
                connect_lines.append(",\n".join(pvals))
                connect_lines.append(f") u_dut_{side}_{name} (")
            else:
                connect_lines.append(f"{top_mod} u_dut_{side}_{name} (")
            # Port list - map to tb signals
            pconnects = []
            for p in ports:
                tb_signal = map_port_to_tb(p, postfix, ports, name)
                pconnects.append(f"    .{p['name']} ({tb_signal})")
            connect_lines.append(",\n".join(pconnects))
            connect_lines.append(f");\n")

        # Checker — uses instance-specific data_mask
        has_emu = "1'b1" if "emu" in inst_data else "1'b0"
        connect_lines.append(f"// ── Checker: {name} ──")
        connect_lines.append(f"mem_sva_checker #({dw}, 1, \"{name.upper()}\") u_chk_{name} (")
        connect_lines.append(f"    .clk       (clk_a),")
        connect_lines.append(f"    .rst_n     (rst_n),")
        connect_lines.append(f"    .cmd       (cmd_a),")
        connect_lines.append(f"    .rdata_ori (rdata_a_ori_{name}),")
        connect_lines.append(f"    .rdata_new (rdata_a_new_{name}),")
        connect_lines.append(f"    .rdata_emu (rdata_a_emu_{name}),")
        connect_lines.append(f"    .rdata_mod (rdata_a_mod_{name}),")
        connect_lines.append(f"    .has_emu   ({has_emu}),")
        connect_lines.append(f"    .data_mask (data_mask_{name})")
        connect_lines.append(f");")
        connect_lines.append(f"`endif  // SIM_ALL / SIM_{name}")
        connect_lines.append("")

        connect_path = out_dir / f"{name}_connect.sv"
        if not args.dry_run:
            connect_path.write_text("\n".join(connect_lines))
            LOG.write(f"  ✓ {name}_connect.sv")
        else:
            LOG.write(f"  → {name}_connect.sv")

        if inst_fails:
            failures.append((name, inst_fails))

    # ── Generate all_connect.sv summary ──
    connect_files = sorted(f for f in out_dir.glob("*_connect.sv") if f.name != "all_connect.sv")
    if not args.dry_run and connect_files:
        summary_path = out_dir / "all_connect.sv"
        lines = ["// AUTO-GENERATED by gen_sram_b2b.py",
                 "// Include this file in tb_top.sv to instantiate all DUT pairs",
                 "// Usage: `include \"gen/all_connect.sv\"",
                 ""]
        for cf in connect_files:
            lines.append(f'`include "{cf.name}"')
        summary_path.write_text("\n".join(lines))
        LOG.write(f"\n✓ all_connect.sv (includes {len(connect_files)} connect files)")

    # ── 生成 filelist ──
    if not args.dry_run:
        for s_dir, srcs in lib_srcs.items():
            if srcs:
                fl_name = f"{s_dir}_lib.f"
                fl_path = out_dir / "lib" / s_dir / fl_name
                fl_path.parent.mkdir(parents=True, exist_ok=True)
                with open(fl_path, "w") as f:
                    for src in sorted(srcs):
                        f.write(f"{src}\n")
                LOG.write(f"\n✓ Lib Filelist: {fl_path}")
                
        main_fl_path = out_dir / "gen_sram_b2b.f"
        if wrapper_srcs:
            with open(main_fl_path, "w") as f:
                for s_dir, srcs in lib_srcs.items():
                    if srcs:
                        out_rel = out_dir.relative_to(PROJ_ROOT)
                        f.write(f"-f ./{out_rel}/lib/{s_dir}/{s_dir}_lib.f\n")
                for src in sorted(wrapper_srcs):
                    f.write(f"{src}\n")
            LOG.write(f"\n✓ Main Filelist: {main_fl_path}")

    # ── 总结 ──
    LOG.write(f"\n{'='*50}")
    LOG.write(f"结果: {ok} 成功, {fail} 失败")

    if failures:
        LOG.write(f"\n失败详情:")
        for name, reasons in failures:
            LOG.write(f"  [{name}]")
            for r in reasons:
                LOG.write(f"    - {r}")

    if enabled and ok > 0:
        e = enabled[0]
        LOG.write(f"\n下一步:")
        LOG.write(f"  make build DUT_ORI={e['name']}_ori DUT_NEW={e['name']}_new \\\n")
        LOG.write(f"    ADDR_WIDTH={e.get('addr_width','auto')} DATA_WIDTH={e.get('data_width','auto')}")

    LOG.save()


if __name__ == "__main__":
    main()
