import sys
import re
import os

def process_file(filepath):
    with open(filepath, 'r') as f:
        content = f.read()

    # 1. Find module declaration
    m_decl = re.search(r'\bmodule\s+(\w+)\b[\s\S]*?;', content)
    if not m_decl:
        print(f"Error: No module declaration found in {filepath}")
        return
    module_name = m_decl.group(1)
    module_decl_str = m_decl.group(0)

    # 2. Extract port names to build the submodule connection
    ports = []
    
    def extract_ports_from_decl(decl_body):
        body = re.sub(r'\[[^\]]*\]', '', decl_body)
        body = re.sub(r'\b(?:wire|reg|logic)\b', '', body)
        for p in body.split(','):
            p = p.strip()
            m_id = re.search(r'\b([A-Za-z_]\w*)\b', p)
            if m_id:
                ports.append(m_id.group(1))

    for m in re.finditer(r'\b(?:input|output|inout)\b([^;]+);', content):
        extract_ports_from_decl(m.group(1))
        
    m_paren = re.search(r'\(([\s\S]*)\)', module_decl_str)
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

    # 3. Find the submodule instance
    keywords = {"module", "endmodule", "input", "output", "inout", "wire", "reg", "logic", "assign", "always", "always_comb", "always_ff", "always_latch", "parameter", "localparam", "if", "else", "generate", "endgenerate", "for", "begin", "end", "integer", "genvar", "case", "endcase", "initial"}
    
    inst_pattern = re.compile(r'\b([A-Za-z_]\w*)\s*(?:#\s*\([\s\S]*?\))?\s+([A-Za-z_]\w*)\s*\([\s\S]*?\)\s*;')
    submodule_name = None
    for m in inst_pattern.finditer(content):
        mod = m.group(1)
        if mod not in keywords:
            submodule_name = mod
            break

    if not submodule_name:
        print(f"Warning: Could not find submodule instance using strict regex. Attempting fallback...")
        lines = content.split(';')
        for stmt in lines:
            stmt = stmt.strip()
            if not stmt: continue
            words = re.findall(r'\b[A-Za-z_]\w*\b', stmt)
            if words and words[0] not in keywords:
                if len(words) >= 2 and '(' in stmt and ')' in stmt:
                    submodule_name = words[0]
                    break

    if not submodule_name:
        print(f"Error: Could not determine submodule instance in {filepath}")
        return

    # 4. Extract all parameter and Non-ANSI declarations
    decls_to_keep = []
    for m in re.finditer(r'\b(?:input|output|inout|parameter|localparam)\b[\s\S]*?;', content):
        if m.start() > m_decl.end():
            decls_to_keep.append(m.group(0))

    # 5. Reconstruct the file
    out_lines = []
    out_lines.append("// AUTO-GENERATED: Latch removed, kept only IO and submodule instance")
    out_lines.append(module_decl_str)
    out_lines.append("")
    
    for d in decls_to_keep:
        out_lines.append("  " + d.strip())
        
    out_lines.append("")
    out_lines.append(f"  {submodule_name} u_inst_{submodule_name} (")
    
    conn_lines = []
    for p in unique_ports:
        conn_lines.append(f"    .{p}({p})")
    
    out_lines.append(",\n".join(conn_lines))
    out_lines.append("  );")
    out_lines.append("")
    out_lines.append("endmodule")

    filename = os.path.basename(filepath)
    with open(filename, 'w') as f:
        f.write("\n".join(out_lines) + "\n")
    
    print(f"Processed {filepath} -> {filename}")
    return filename, module_name, submodule_name, unique_ports

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python3 process_syn.py <path_to_syn_file.v>")
        sys.exit(1)
    
    for filepath in sys.argv[1:]:
        process_file(filepath)
