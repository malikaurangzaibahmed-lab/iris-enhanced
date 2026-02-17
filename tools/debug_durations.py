"""Check for over-extended sessions and break absorption issues."""
import json

data = json.loads(open(r"D:\Flutter\student_organizer\assets\timetable_seed.json", encoding="utf-8").read())

def to_minutes(t):
    parts = t.split(":")
    return int(parts[0]) * 60 + int(parts[1])

# Standard slot duration = 85 min, double = 170 min
print("=" * 70)
print("SESSION DURATION ANALYSIS")
print("=" * 70)

durations = {}
for s in data:
    dur = to_minutes(s["end"]) - to_minutes(s["start"])
    if dur < 0:
        dur += 12 * 60
    bucket = f"{dur}min"
    if bucket not in durations:
        durations[bucket] = []
    durations[bucket].append(s)

for dur_label in sorted(durations.keys(), key=lambda x: int(x.replace("min",""))):
    count = len(durations[dur_label])
    print(f"  {dur_label:>8}: {count} sessions")
    # Show examples of unusual durations
    dur_val = int(dur_label.replace("min",""))
    if dur_val not in (85, 170):  # standard single or double slot
        for s in durations[dur_label][:5]:
            print(f"    {s['batch']:25} {s['day']:12} {s['start']}-{s['end']}  {s['subject'][:40]}")

# Check if any sessions cross the break
print("\n" + "=" * 70)
print("SESSIONS CROSSING BREAK (12:45-1:40)")
print("=" * 70)
for s in data:
    start_m = to_minutes(s["start"])
    end_m = to_minutes(s["end"])
    break_start = to_minutes("12:45")
    break_end = to_minutes("1:40")
    # A session crosses break if it starts before 12:45 and ends after 1:40
    if start_m < break_start and end_m > break_end:
        print(f"  {s['batch']:25} {s['day']:12} {s['start']}-{s['end']}  {s['subject'][:40]}  {s['room']}")
    # A session that absorbed break 
    if s["end"] == "1:40" and start_m < break_start:
        print(f"  [absorbed break] {s['batch']:25} {s['day']:12} {s['start']}-{s['end']}  {s['subject'][:40]}")

# Check for triple-slot (or more) sessions
print("\n" + "=" * 70)
print("SESSIONS > 170 MIN (over-extended?)")
print("=" * 70)
count = 0
for s in data:
    dur = to_minutes(s["end"]) - to_minutes(s["start"])
    if dur < 0:
        dur += 12 * 60
    if dur > 170:
        count += 1
        print(f"  {s['batch']:25} {s['day']:12} {s['start']}-{s['end']} ({dur}min)")
        print(f"    {s['subject'][:50]}  | {s['teacher'][:30]}  | {s['room']}")
if count == 0:
    print("  None found ✅")
