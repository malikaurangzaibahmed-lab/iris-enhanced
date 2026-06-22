with open("lib/screens/portal_screen.dart", "r", encoding="utf-8", errors="ignore") as f:
    for i, line in enumerate(f):
        if "_buildContextAwareHeaderActions" in line or "AcademicsHubScreen" in line or "Academics" in line:
            print(f"Line {i+1}: {line.strip()}")
