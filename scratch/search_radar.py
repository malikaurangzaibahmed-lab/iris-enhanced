with open("admin_portal/styles.css", "r", encoding="utf-8", errors="ignore") as f:
    lines = f.readlines()

keywords = ["radar", "pulse", "orbit", "glow"]
for i, line in enumerate(lines):
    if any(k in line.lower() for k in keywords):
        print(f"Line {i+1}: {line.strip()}")
