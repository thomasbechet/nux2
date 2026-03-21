import json

# paste your JSON here or load from file
with open("monogram-bitmap.json") as f:
    data = json.load(f)

def rows_to_u60(rows):
    value = 0
    for row in rows:
        value <<= 5          # 5 pixels per row
        value |= (row & 0x1F)  # keep only 5 bits
    return value

print("const monogram_glyphs: []struct {")
print("    char: u8,")
print("    bitmap: u60,")
print("} = .{")

for ch, rows in data.items():
    bitmap = rows_to_u60(rows)
    
    # escape characters for Zig
    if ch == "'":
        zig_char = "'\\''"
    elif ch == "\\":
        zig_char = "'\\\\'"
    elif ch == "\n":
        zig_char = "'\\n'"
    else:
        zig_char = f"'{ch}'"
    
    print(f"    .{{ .char = {zig_char}, .bitmap = 0x{bitmap:015x} }},")
    
print("};")