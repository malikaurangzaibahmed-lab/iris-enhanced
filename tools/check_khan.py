import json

data = json.loads(open(r"D:\Flutter\IRIS\assets\timetable_seed.json", encoding="utf-8").read())
print("=== Entries with 'Khan' in subject ===")
for s in data:
    sub = s.get("subject", "")
    if "Khan" in sub:
        print(f"  batch={s['batch']}  day={s['day']}  {s['start']}-{s['end']}")
        print(f"    subject : {sub}")
        print(f"    teacher : {s['teacher']}")
        print(f"    room    : {s['room']}")
        print()

print(f"\n=== All unique subjects (sorted) ===")
subjects = sorted({s["subject"] for s in data})
for sub in subjects:
    print(f"  {sub}")
