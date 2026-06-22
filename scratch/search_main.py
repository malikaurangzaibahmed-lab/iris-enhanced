with open(r"d:\Ai models\IRIS\lib\main.dart", "r", encoding="utf-8", errors="ignore") as f:
    lines = f.readlines()

search_words = ["NeuralAura", "neural_aura", "LinearGradient", "RadialGradient", "Background", "Aura", "ring", "Circle", "BoxDecoration"]
out_lines = []
for i, line in enumerate(lines):
    for word in search_words:
        if word.lower() in line.lower():
            out_lines.append(f"Line {i+1}: {line.strip()}")
            break

with open(r"d:\Ai models\IRIS\scratch\search_main.txt", "w", encoding="utf-8") as out_f:
    out_f.write("\n".join(out_lines))
