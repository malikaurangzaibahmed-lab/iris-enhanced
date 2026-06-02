import json

with open('assets/timetable_seed.json', 'r', encoding='utf-8') as f:
    data = json.load(f)

# Get all Unknown entries
unknowns = [d for d in data if d['subject'] == 'Unknown']

print("=" * 80)
print(f"UNKNOWN SUBJECTS ANALYSIS ({len(unknowns)} entries)")
print("=" * 80)

for i, u in enumerate(unknowns, 1):
    print(f"\n{i}. Department: {u['department']}, Batch: {u['batch']}")
    print(f"   Teacher: {u['teacher']}")
    print(f"   Day: {u['day']}, Time: {u['start']}-{u['end']}")
    print(f"   Room: {u['room']}")
    print(f"   Subject: {u['subject']}")

# Analyze teacher names
print("\n" + "=" * 80)
print("TEACHER NAME ANALYSIS")
print("=" * 80)
for u in unknowns:
    teacher = u['teacher']
    parts = teacher.split()
    print(f"\nTeacher: '{teacher}'")
    print(f"  Parts: {parts}")
    print(f"  Length: {len(teacher)}")
    # Check if 'App' or 'Grmr' is in it
    if 'App' in teacher or 'Grmr' in teacher:
        print(f"  ⚠️  Contains 'App' or 'Grmr' - likely subject fragments!")
