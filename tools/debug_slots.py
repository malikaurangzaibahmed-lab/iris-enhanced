"""Diagnose single-slot labs: labs should span 2 consecutive slots but may show as only 1."""
import json
from collections import defaultdict

data = json.loads(open(r"D:\Flutter\student_organizer\assets\timetable_seed.json", encoding="utf-8").read())

# Standard time slots at CUI
SLOTS = ["8:30", "9:55", "11:20", "1:40", "3:05"]

# Group sessions by batch + day
by_batch_day = defaultdict(list)
for s in data:
    by_batch_day[(s["batch"], s["day"])].append(s)

# Check 1: List all lab sessions and their durations
print("=" * 70)
print("LAB SESSIONS — time ranges")
print("=" * 70)
labs = [s for s in data if "(Lab)" in s.get("subject", "") or "Lab)" in s.get("subject", "")]
labs.sort(key=lambda s: (s["batch"], s["day"], s["start"]))

# Parse time to minutes for duration calc
def to_minutes(t):
    parts = t.split(":")
    return int(parts[0]) * 60 + int(parts[1])

single_slot_labs = []
double_slot_labs = []
for s in labs:
    dur = to_minutes(s["end"]) - to_minutes(s["start"])
    if dur < 0:
        dur += 12 * 60  # handle PM wrap
    if dur <= 90:
        single_slot_labs.append(s)
    else:
        double_slot_labs.append(s)

print(f"\nTotal lab sessions: {len(labs)}")
print(f"Single-slot labs (<=90 min): {len(single_slot_labs)}")
print(f"Double-slot labs (>90 min):  {len(double_slot_labs)}")

# Check 2: Find consecutive duplicate labs (same batch, day, subject, teacher, room, adjacent times)
print("\n" + "=" * 70)
print("CONSECUTIVE DUPLICATE LABS (should be merged)")
print("=" * 70)
merge_candidates = 0
for (batch, day), sessions in sorted(by_batch_day.items()):
    sessions.sort(key=lambda s: s["start"])
    for i in range(len(sessions) - 1):
        a, b = sessions[i], sessions[i + 1]
        if (a["subject"] == b["subject"] and
            a["teacher"] == b["teacher"] and
            a["room"] == b["room"] and
            a["end"] == b["start"]):
            merge_candidates += 1
            print(f"  {batch:25} {day:12} {a['start']}-{a['end']} + {b['start']}-{b['end']}  →  {a['start']}-{b['end']}")
            print(f"    subject: {a['subject']}  teacher: {a['teacher']}  room: {a['room']}")

print(f"\nTotal merge candidates: {merge_candidates}")

# Check 3: Show some single-slot labs to see if they look wrong
print("\n" + "=" * 70)
print("SAMPLE SINGLE-SLOT LABS (may be missing their second slot)")
print("=" * 70)
for s in single_slot_labs[:20]:
    dur = to_minutes(s["end"]) - to_minutes(s["start"])
    print(f"  {s['batch']:25} {s['day']:12} {s['start']:>5}-{s['end']:<5} ({dur}min)  {s['subject'][:45]}  {s['room']}")

# Check 4: For single-slot labs, check if there's an adjacent empty slot
print("\n" + "=" * 70)
print("SINGLE-SLOT LABS WITH NO ADJACENT SESSION (potential missing slot)")
print("=" * 70)
slot_pairs = list(zip(SLOTS[:-1], SLOTS[1:]))
missing_count = 0
for s in single_slot_labs:
    batch, day, start, end = s["batch"], s["day"], s["start"], s["end"]
    siblings = by_batch_day[(batch, day)]
    sibling_starts = {ss["start"] for ss in siblings}
    # Check if the next slot has ANYTHING for this batch+day
    if end in [sl[0] for sl in slot_pairs] or end in SLOTS:
        if end not in sibling_starts:
            missing_count += 1
            if missing_count <= 15:
                print(f"  {batch:25} {day:12} {start}-{end}  next_slot={end} is EMPTY")
                print(f"    subject: {s['subject']}  room: {s['room']}")

print(f"\nSingle-slot labs with empty next slot: {missing_count}")
