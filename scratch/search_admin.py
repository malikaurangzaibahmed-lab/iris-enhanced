import re

with open("admin_portal/index.html", "r", encoding="utf-8", errors="ignore") as f:
    html = f.read()

with open("admin_portal/styles.css", "r", encoding="utf-8", errors="ignore") as f:
    css = f.read()

# Find classes or divs in html related to background, grid, radar, orbit, ring
print("=== HTML Background / Orbit elements ===")
for line_no, line in enumerate(html.splitlines()):
    if any(k in line.lower() for k in ["grid", "radar", "orbit", "ring", "glow", "ambient", "bg-", "background", "spin"]):
        print(f"Line {line_no+1}: {line.strip()}")

print("\n=== CSS Background / Orbit classes ===")
for line_no, line in enumerate(css.splitlines()):
    if any(k in line.lower() for k in ["grid", "radar", "orbit", "ring", "glow", "ambient", "bg-", "background", "spin", "radial", "concentric"]):
        print(f"Line {line_no+1}: {line.strip()}")
