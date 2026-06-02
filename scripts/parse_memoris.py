#!/usr/bin/env python3
# ============================================================
# parse_memoris.py — 解析 memory wrapper 目录，自动发现 SRAM 实例
# ============================================================
#
# 用法:
#   # 指定 orig/new 两个 symlink 目录
#   python3 scripts/parse_memoris.py \
#       --orig ./memory_wrapper_orig \
#       --new  ./memory_wrapper_new
#
#   # 只扫一个目录（orig=new 同文件时）
#   python3 scripts/parse_memoris.py --dir ./memoris
#
#   # 输出 YAML + 日志
#   python3 scripts/parse_memoris.py \
#       --orig ./memory_wrapper_orig --new ./memory_wrapper_new \
#       --output sram_instances.yaml --log gen/parse.log
# ============================================================

import os
import re
import sys
import math
import argparse
import datetime
from pathlib import Path

# ============================================================
# RTL 参数解析
# ============================================================

def parse_rtl_params(filepath: Path) -> dict:
    """从 RTL 文件解析 SRAM 参数"""
    if not filepath.exists():
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
    
    # 备选深度参数名
    if "num_word" not in params:
        m = re.search(r'\b(?:local)?parameter\s+(?:NUMWORD|NUM_WORD|WORDS|DEPTH|NUM_W|NW)\s*=\s*(\d+)', content)
        if m:
            params["num_word"] = int(m.group(1))

    # ADDR_WIDTH = $clog2(NUMWORD) 或显式值
    m = re.search(r'\blocalparam\s+ADDR_WIDTH\s*=\s*\$?clog2\s*\(\s*NUMWORD\s*\)', content)
    if m and "num_word" in params:
        params["addr_width"] = math.ceil(math.log2(params["num_word"]))
    m = re.search(r'\b(?:local)?parameter\s+ADDR_WIDTH\s*=\s*(\d+)', content)
    if m:
        params["addr_width"] = int(m.group(1))

    # 备选参数名
    if "data_width" not in params:
        m = re.search(r'\b(?:local)?parameter\s+(?:DATA_WIDTH|DW|DATA_W)\s*=\s*(\d+)', content)
        if m:
            params["data_width"] = int(m.group(1))
    if "addr_width" not in params:
        m = re.search(r'\b(?:local)?parameter\s+(?:ADDR_WIDTH|AW|ADDR_W)\s*=\s*(\d+)', content)
        if m:
            params["addr_width"] = int(m.group(1))

    return params


def find_wrapper_files(directory: Path) -> list:
    """查找目录中所有 *_mem_wrap.v 文件（递归）"""
    files = sorted(directory.rglob("*_mem_wrap.v"))
    files.extend(sorted(directory.rglob("*_mem_wrap.sv")))
    return files


def find_filelist(directory: Path) -> Path:
    """查找目录下的 filelist (.f) 文件"""
    for f in sorted(directory.rglob("*.f")):
        return f
    return None


def find_mem_lib_dir(directory: Path) -> Path:
    """查找 mem_lib 子目录"""
    for d in directory.iterdir():
        if d.is_dir() and "mem" in d.name.lower():
            return d
    return None


def parse_filelist(path: Path) -> list:
    """解析 filelist (.f) 文件"""
    if not path or not path.exists():
        return []
    lines = path.read_text().splitlines()
    files = []
    for line in lines:
        line = line.strip()
        if not line or line.startswith("#") or line.startswith("+") or line.startswith("-"):
            continue
        fpath = path.parent / line
        files.append(str(fpath))
    return files


def resolve_symlink(path: Path) -> str:
    """解析 symlink 到真实路径"""
    try:
        real = path.resolve()
        return str(real)
    except:
        return str(path.absolute())


# ============================================================
# 主函数
# ============================================================

def main():
    parser = argparse.ArgumentParser(
        description="解析 memory wrapper 目录，生成 B2B 验证配置"
    )
    parser.add_argument("--orig", type=str, default=None,
                        help="orig wrapper 目录 (如 ./memory_wrapper_orig)")
    parser.add_argument("--new", type=str, default=None,
                        help="new wrapper 目录 (如 ./memory_wrapper_new)")
    parser.add_argument("--emu", type=str, default=None,
                        help="emu wrapper 目录 (可选, 如 ./memory_wrapper_emu)")
    parser.add_argument("--dir", type=str, default=None,
                        help="单目录模式 (orig=new)")
    parser.add_argument("--lib", type=str, default=None,
                        help="外部 lib 目录路径 (可选，用于覆盖默认的相对 lib 目录)")
    parser.add_argument("--output", type=str, default="",
                        help="输出 YAML 路径 (默认: stdout)")
    parser.add_argument("--log", type=str, default="",
                        help="日志文件路径")
    parser.add_argument("--dry-run", action="store_true",
                        help="预览模式")
    args = parser.parse_args()

    # ── 确定目录 ──
    emu_dir = None
    if args.orig and args.new:
        orig_dir = Path(args.orig).resolve()
        new_dir  = Path(args.new).resolve()
        if args.emu:
            emu_dir = Path(args.emu).resolve()
    elif args.dir:
        orig_dir = Path(args.dir).resolve()
        new_dir  = orig_dir
        # emu_dir = orig_dir if they want to use one dir for all, but let's keep it None unless specified via --emu, or we can just set it to orig_dir if they want to test identicals.
        if args.emu:
            emu_dir = Path(args.emu).resolve()
    else:
        parser.print_help()
        print("\n错误: 请指定 --orig + --new, 或 --dir")
        sys.exit(1)
        
    user_lib_dir = Path(args.lib).resolve() if args.lib else None

    # ── 日志 ──
    log_lines = []
    def log(msg="", echo=True):
        log_lines.append(msg)
        if echo:
            print(msg)

    log(f"parse_memoris.py — {datetime.datetime.now()}")
    log(f"  orig → {orig_dir}  ({resolve_symlink(orig_dir)})")
    log(f"  new  → {new_dir}  ({resolve_symlink(new_dir)})")
    if emu_dir:
        log(f"  emu  → {emu_dir}  ({resolve_symlink(emu_dir)})")
    if user_lib_dir:
        log(f"  lib  → {user_lib_dir}  ({resolve_symlink(user_lib_dir)})")
    log()

    dirs_to_check = [(orig_dir, "orig"), (new_dir, "new")]
    if emu_dir:
        dirs_to_check.append((emu_dir, "emu"))

    for d, label in dirs_to_check:
        if not d.exists():
            log(f"错误: {label} 目录不存在: {d}")
            sys.exit(1)
        is_link = d.is_symlink()
        log(f"  {label} 目录: {d}" +
            (f" → {os.readlink(str(d))}" if is_link else ""))

    # ── 扫描 wrapper 文件 ──
    all_orig_files = find_wrapper_files(orig_dir)
    all_new_files  = find_wrapper_files(new_dir)
    all_emu_files  = find_wrapper_files(emu_dir) if emu_dir else []

    # 只解析顶层 _mem_wrap.v（非 _low_ / _sub_），子模块不需要解析参数
    orig_top_files = [f for f in all_orig_files
                      if "_low_" not in f.stem and not f.stem.startswith("sub_") and "_sub_" not in f.stem]
    new_top_files  = [f for f in all_new_files
                      if "_low_" not in f.stem and not f.stem.startswith("sub_") and "_sub_" not in f.stem]
    emu_top_files  = [f for f in all_emu_files
                      if "_low_" not in f.stem and not f.stem.startswith("sub_") and "_sub_" not in f.stem]

    log(f"\n找到 {len(all_orig_files)} 个 orig 文件 ({len(orig_top_files)} 个顶层), "
        f"{len(all_new_files)} 个 new 文件 ({len(new_top_files)} 个顶层), "
        f"{len(all_emu_files)} 个 emu 文件 ({len(emu_top_files)} 个顶层)")

    if not orig_top_files and not new_top_files:
        log("未找到任何顶层 *_mem_wrap.v 文件（不含 _low_/_sub_）")
        sys.exit(1)

    # ── 按文件名匹配 orig/new 顶层文件 ──
    # 构建映射: {filename_stem: {"orig": Path, "new": Path}}
    matched_files = {}
    for f in orig_top_files:
        matched_files.setdefault(f.stem, {"orig": None, "new": None})["orig"] = f
    for f in new_top_files:
        matched_files.setdefault(f.stem, {"orig": None, "new": None})["new"] = f

    # ── 解析参数 ──
    log("\n解析顶层 _mem_wrap.v 参数:")
    instances = []
    seen_modules = set()

    for stem in sorted(matched_files):
        entry = matched_files[stem]
        orig_f = entry.get("orig")
        new_f = entry.get("new")

        # 检查两侧是否都有文件
        if not orig_f or not new_f:
            missing_side = "new" if not new_f else "orig"
            log(f"  {stem}.v (⚠ {missing_side} 侧缺失，跳过)")
            continue

        # 解析参数：优先用 orig 侧，否则 new 侧
        parse_f = orig_f or new_f
        params = parse_rtl_params(parse_f)
        mod = params.get("module_name", "?")
        dw = params.get("data_width", "-")
        nw = params.get("num_word", "-")
        aw = params.get("addr_width", "-")
        has_both = "data_width" in params and "num_word" in params

        tag = ""
        if has_both:
            tag = " ← TOP"
        else:
            missing = []
            if "data_width" not in params: missing.append("data_width(BUNIOBIT/RUNIOBIT)")
            if "num_word" not in params: missing.append("num_word(NUMWORD)")
            tag = f" (缺少参数: {', '.join(missing)})"

        log(f"  {stem}.v{tag}")
        log(f"    module={mod}, 数据位宽={dw}, 深度={nw}, ADDR_WIDTH={aw}")
        if orig_f:
            log(f"    orig: {orig_f}")
        if new_f:
            log(f"    new:  {new_f}")

        if mod in seen_modules:
            log(f"    (重复 module 名，跳过)")
            continue
        if not has_both:
            if not orig_f:
                log(f"    尝试用 new 侧解析参数...")
                params2 = parse_rtl_params(new_f)
                if "data_width" in params2 and "num_word" in params2:
                    params = params2
                    has_both = True
                    log(f"    → 从 new 侧解析成功")
            if not has_both:
                log(f"    → 跳过（参数不完整）")
                continue

        seen_modules.add(mod)
        instances.append((orig_f, params))

    # ── 生成 YAML 配置 ──
    results = []
    for orig_f, params in instances:
        mod = params.get("module_name", orig_f.stem)
        stem = orig_f.stem
        new_f = new_dir / orig_f.name if (new_dir / orig_f.name).exists() else None
        if not new_f:
            for nf in all_new_files:
                if nf.name == orig_f.name:
                    new_f = nf
                    break
        
        # 查找 filelist / 自动发现 low_mem_wrap.v
        prefix = stem.removesuffix("_mem_wrap") if stem.endswith("_mem_wrap") else stem
        low_glob = f"{prefix}_low_mem_wrap.*"

        def discover_extra_files(base_dir, exclude_name, mod_name, custom_lib_dir=None, find_syn=False):
            """优先 filelist，否则只收集 {prefix}_low_mem_wrap.* 和 base libs """
            fl = find_filelist(base_dir)
            if fl:
                return parse_filelist(fl)
            extras = []
            for ext in ["v", "sv"]:
                pattern = f"{prefix}_low_mem_wrap.{ext}"
                for vf in sorted(base_dir.glob(pattern)):
                    extras.append(str(vf))
            
            # Discover base memory macro files
            search_dirs = [base_dir]
            if custom_lib_dir and custom_lib_dir.exists():
                search_dirs.append(custom_lib_dir)
            elif (base_dir / "lib").exists():
                search_dirs.append(base_dir / "lib")
            
            for sd in search_dirs:
                for ext in ["v", "sv"]:
                    names_to_check = [f"{prefix}.{ext}", f"{mod_name}.{ext}"]
                    if find_syn:
                        names_to_check = [f"{prefix}_syn.{ext}", f"{mod_name}_syn.{ext}"]
                    
                    for fn in names_to_check:
                        # 直接检查当前目录
                        p1 = sd / fn
                        if p1.exists() and str(p1) not in extras and p1.name != exclude_name:
                            extras.append(str(p1))
                            log(f"      [Lib Found] {p1}", echo=False)
                        # 检查 lib/{mod_name}/{mod_name}.v 结构
                        p2 = sd / mod_name / fn
                        if p2.exists() and str(p2) not in extras and p2.name != exclude_name:
                            extras.append(str(p2))
                            log(f"      [Lib Found] {p2}", echo=False)
                        # 检查 lib/{prefix}/{prefix}.v 结构
                        p3 = sd / prefix / fn
                        if p3.exists() and str(p3) not in extras and p3.name != exclude_name:
                            extras.append(str(p3))
                            log(f"      [Lib Found] {p3}", echo=False)
            
            return extras

        orig_extra = discover_extra_files(orig_f.parent, orig_f.name, mod, user_lib_dir)
        new_extra  = discover_extra_files(new_f.parent if new_f else new_dir, new_f.name if new_f else "", mod, user_lib_dir)

        # Find emu file
        emu_f = None
        emu_extra = []
        if emu_dir:
            emu_f = emu_dir / orig_f.name if (emu_dir / orig_f.name).exists() else None
            if not emu_f:
                for ef in all_emu_files:
                    if ef.name == orig_f.name:
                        emu_f = ef
                        break
            emu_extra = discover_extra_files(emu_f.parent if emu_f else emu_dir, emu_f.name if emu_f else "", mod, user_lib_dir)
        else:
            # Auto-discover emulation models from new side
            has_syn = False
            
            # 1. 继承 new_extra 里的 wrapper 文件
            for nx in new_extra:
                nx_p = Path(nx)
                if "low_mem_wrap" in nx_p.name:
                    emu_extra.append(nx)
            
            # 2. 显式查找 _syn 库文件
            emu_libs = discover_extra_files(new_f.parent if new_f else new_dir, new_f.name if new_f else "", mod, user_lib_dir, find_syn=True)
            for lib in emu_libs:
                lib_p = Path(lib)
                if "low_mem_wrap" not in lib_p.name and str(lib_p) not in emu_extra:
                    emu_extra.append(str(lib_p))
                    has_syn = True
                    log(f"      [Syn Found] {lib_p}", echo=False)
            if has_syn:
                emu_f = new_f
            else:
                emu_extra = []
                log(f"      [Info] No _syn.v found, skipping EMU side.", echo=False)

        inst = {
            "name": orig_f.stem,
            "module_name": mod,
            "data_width": params.get("data_width", "?"),
            "addr_width": params.get("addr_width", "?"),
            "num_word": params.get("num_word", "?"),
            "orig_path": str(orig_f),
            "new_path": str(new_f) if new_f else str(new_dir / orig_f.name),
            "emu_path": str(emu_f) if emu_f else (str(emu_dir / orig_f.name) if emu_dir else ""),
            "orig_extra": orig_extra,
            "new_extra": new_extra,
            "emu_extra": emu_extra,
        }
        results.append(inst)
    instances = results  # replace tuples with dicts

    # ── 输出 ──
    log(f"\n发现 {len(instances)} 个顶层实例:\n")
    if not instances:
        log("(无)")
        sys.exit(0)

    for inst in instances:
        op = Path(inst["orig_path"])
        np = Path(inst["new_path"])
        
        # Symlink tag
        link_tag_o = f" → {os.readlink(str(op))}" if op.is_symlink() else ""
        link_tag_n = f" → {os.readlink(str(np))}" if np.is_symlink() else ""

        log(f"  [{inst['name']}]")
        log(f"    module:  {inst['module_name']}")
        log(f"    config:  {inst['data_width']}x{1<<inst['addr_width'] if inst['addr_width'] != '?' else '?'} "
              f"(DW={inst['data_width']}, DEPTH={inst['num_word']}, AW={inst['addr_width']})")
        log(f"    orig:    {inst['orig_path']}{link_tag_o}")
        if inst.get("orig_extra"):
            for x in inst["orig_extra"][:5]:
                log(f"      + {Path(x).name}")
            if len(inst["orig_extra"]) > 5:
                log(f"      ... +{len(inst['orig_extra'])-5} more")
        log(f"    new:     {inst['new_path']}{link_tag_n}")
        if inst.get("new_extra"):
            for x in inst["new_extra"][:5]:
                log(f"      + {Path(x).name}")
            if len(inst["new_extra"]) > 5:
                log(f"      ... +{len(inst['new_extra'])-5} more")
        log()

    # ── 生成 YAML ──
    yaml_lines = ["# AUTO-GENERATED by parse_memoris.py",
                  f"# orig: {orig_dir}  ({resolve_symlink(orig_dir)})",
                  f"# new:  {new_dir}   ({resolve_symlink(new_dir)})",
                  "",
                  "instances:"]

    for inst in instances:
        op = Path(inst["orig_path"])
        np = Path(inst["new_path"])
        # Relative paths for YAML
        try:
            o_rel = op.relative_to(Path.cwd())
        except:
            o_rel = op
        try:
            n_rel = np.relative_to(Path.cwd())
        except:
            n_rel = np

        yaml_lines.append(f"\n  - name: {inst['name']}")
        yaml_lines.append(f"    module_name: {inst['module_name']}")
        yaml_lines.append(f"    parse_from: {o_rel}")
        yaml_lines.append(f"    orig_path:  {o_rel}")
        yaml_lines.append(f"    new_path:   {n_rel}")
        if inst.get("emu_path"):
            try:
                ep = Path(inst["emu_path"])
                e_rel = ep.relative_to(Path.cwd())
            except:
                e_rel = inst["emu_path"]
            yaml_lines.append(f"    emu_path:   {e_rel}")
        
        # Auto-discovered extra files (relative to CWD)
        cwd = Path.cwd()
        if inst.get("orig_extra"):
            yaml_lines.append(f"    orig_extra:")
            for x in inst["orig_extra"]:
                try:
                    x_rel = Path(x).relative_to(cwd)
                except ValueError:
                    x_rel = Path(x)
                yaml_lines.append(f"      - {x_rel}")
        if inst.get("new_extra"):
            yaml_lines.append(f"    new_extra:")
            for x in inst["new_extra"]:
                try:
                    x_rel = Path(x).relative_to(cwd)
                except ValueError:
                    x_rel = Path(x)
                yaml_lines.append(f"      - {x_rel}")
        if inst.get("emu_extra"):
            yaml_lines.append(f"    emu_extra:")
            for x in inst["emu_extra"]:
                try:
                    x_rel = Path(x).relative_to(cwd)
                except ValueError:
                    x_rel = Path(x)
                yaml_lines.append(f"      - {x_rel}")
        yaml_lines.append(f"    data_width: {inst['data_width']}  # auto-parsed")
        yaml_lines.append(f"    addr_width: {inst['addr_width']}  # auto-parsed")
        yaml_lines.append(f"    enabled: true")

    yaml_output = "\n".join(yaml_lines) + "\n"

    # ── 写 YAML ──
    if args.output:
        out_path = Path(args.output)
        out_path.parent.mkdir(parents=True, exist_ok=True)
        if not args.dry_run:
            out_path.write_text(yaml_output)
            log(f"YAML 输出: {out_path}")
    else:
        log(f"\n{'='*60}")
        log("YAML 配置:")
        log(f"{'='*60}")
        log(yaml_output)

    # ── 写日志 ──
    if args.log:
        log_path = Path(args.log)
        log_path.parent.mkdir(parents=True, exist_ok=True)
        if not args.dry_run:
            log_path.write_text("\n".join(log_lines) + "\n")
            print(f"日志输出: {log_path}")

    # ── 总结 ──
    print(f"\n{'='*50}")
    print(f"解析完成: {len(instances)} 个实例")
    if instances:
        print(f"\n下一步:")
        print(f"  python3 scripts/gen_sram_b2b.py")
        print(f"  make build \\")
        print(f"    DUT_ORI={instances[0]['name']}_ori DUT_NEW={instances[0]['name']}_new")
        print(f"    ADDR_WIDTH={instances[0]['addr_width']} DATA_WIDTH={instances[0]['data_width']}")


if __name__ == "__main__":
    main()
