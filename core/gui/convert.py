import json

def to_zig(data):
    lines = []
    lines.append("const Glyph = struct {")
    lines.append("    char: u32,")
    lines.append("    bitmap: []const u8,")
    lines.append("};\n")

    lines.append("const glyphs = [_]Glyph{")

    for char, bitmap in data.items():
        values = ", ".join(str(v) for v in bitmap)
        lines.append(f"    Glyph{{ .char = '{char}', .bitmap = &[_]u8{{ {values} }} }},")
    
    lines.append("};")
    return "\n".join(lines)

# paste your JSON here or load from file
with open("monogram-bitmap.json", encoding="utf-8") as f:
    data = json.load(f)
    
print(to_zig(data))