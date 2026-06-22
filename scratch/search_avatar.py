with open("lib/main.dart", "r", encoding="utf-8") as f:
    for i, line in enumerate(f):
        if '"AM"' in line or "'AM'" in line or 'avatar' in line.lower():
            if 'import' not in line:
                print(f"Line {i+1}: {line.strip()}")
