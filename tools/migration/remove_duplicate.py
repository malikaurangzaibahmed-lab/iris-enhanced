import os

file_path = r"d:\Iris Working backup\MOST RECENT\IRIS\lib\main.dart"

with open(file_path, "r", encoding="utf-8") as f:
    lines = f.readlines()

# Lines to remove: 2194 to 4884 (1-indexed)
# In 0-indexed list, that's lines[2193 : 4884]
start_idx = 2193
end_idx = 4884

print(f"First line to remove: {lines[start_idx].strip()}")
print(f"Last line to remove: {lines[end_idx-1].strip()}")

del lines[start_idx:end_idx]

with open(file_path, "w", encoding="utf-8") as f:
    f.writelines(lines)

print("Duplicate FacultyDashboard successfully removed from lib/main.dart!")
