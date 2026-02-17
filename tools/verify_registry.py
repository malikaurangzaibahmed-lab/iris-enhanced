import json
import re
from collections import Counter

SEED_PATH = r"D:\Flutter\student_organizer\assets\timetable_seed.json"

with open(SEED_PATH, "r", encoding="utf-8") as f:
    data = json.load(f)

print(f"Total sessions: {len(data)}")
print()

# 1. Check required fields
REQUIRED = {"batch", "day", "start", "end", "subject", "teacher", "room"}
missing_fields = []
for i, item in enumerate(data):
    missing = REQUIRED - set(item.keys())
    if missing:
        missing_fields.append((i, missing))

if missing_fields:
    print(f"❌ {len(missing_fields)} entries missing fields:")
    for idx, m in missing_fields[:5]:
        print(f"   Entry {idx}: missing {m}")
else:
    print("✅ All entries have required fields (batch, day, start, end, subject, teacher, room)")

# 2. Check day values
VALID_DAYS = {"Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"}
day_counts = Counter()
bad_days = []
for i, item in enumerate(data):
    d = item.get("day", "")
    day_counts[d] += 1
    if d not in VALID_DAYS:
        bad_days.append((i, d))

print()
print("📅 Sessions per day:")
for d in ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]:
    if day_counts[d]:
        print(f"   {d}: {day_counts[d]}")
if bad_days:
    print(f"❌ {len(bad_days)} entries with invalid day values:")
    for idx, d in bad_days[:5]:
        print(f"   Entry {idx}: day='{d}' batch={data[idx].get('batch')}")
else:
    print("✅ All day values valid")

# 3. Check time format
TIME_RE = re.compile(r"^\d{1,2}:\d{2}$")
bad_times = []
for i, item in enumerate(data):
    for field in ("start", "end"):
        val = item.get(field, "")
        if not TIME_RE.match(val):
            bad_times.append((i, field, val))
print()
if bad_times:
    print(f"❌ {len(bad_times)} entries with invalid time format:")
    for idx, field, val in bad_times[:5]:
        print(f"   Entry {idx}: {field}='{val}' batch={data[idx].get('batch')}")
else:
    print("✅ All time values valid (H:MM or HH:MM)")

# 4. Check batch format (should be parseable by BatchKey)
BATCH_RE = re.compile(r"^[A-Z0-9]+-[A-Z]+-\d+-[A-Z]$")
bad_batches = []
for i, item in enumerate(data):
    b = item.get("batch", "")
    if not BATCH_RE.match(b):
        bad_batches.append((i, b))
print()
if bad_batches:
    print(f"❌ {len(bad_batches)} entries with non-standard batch format:")
    for idx, b in bad_batches[:5]:
        print(f"   Entry {idx}: batch='{b}'")
else:
    print("✅ All batches match INTAKE-PROGRAM-SEM-SECTION format")

# 5. Check for Unknown/TBD values
unknown_teacher = [i for i, item in enumerate(data) if item.get("teacher") == "Unknown"]
unknown_subject = [i for i, item in enumerate(data) if item.get("subject") == "Unknown"]
tbd_room = [i for i, item in enumerate(data) if item.get("room") == "TBD"]
print()
print(f"⚠️  Entries with teacher='Unknown': {len(unknown_teacher)}")
print(f"⚠️  Entries with subject='Unknown': {len(unknown_subject)}")
print(f"⚠️  Entries with room='TBD': {len(tbd_room)}")

# 6. Show all unique batches grouped by program
batches = sorted(set(item.get("batch", "") for item in data))
programs = {}
for b in batches:
    parts = b.split("-")
    if len(parts) >= 4:
        prog = parts[1]
        programs.setdefault(prog, []).append(b)

print()
print(f"📋 Unique batches: {len(batches)}")
for prog, blist in sorted(programs.items()):
    print(f"   {prog}: {len(blist)} batches → {', '.join(b.split('-',1)[1] for b in blist[:8])}")
    if len(blist) > 8:
        print(f"         ... and {len(blist) - 8} more")

# 7. Check for exact duplicates
seen = set()
dupes = 0
for item in data:
    key = (item["batch"], item["day"], item["start"], item["end"], item["subject"], item["teacher"], item["room"])
    if key in seen:
        dupes += 1
    seen.add(key)
print()
if dupes:
    print(f"❌ {dupes} exact duplicate entries found")
else:
    print("✅ No exact duplicate entries")

# 8. Check for suspicious near-duplicate (same batch, day, time but different data)
time_keys = {}
suspicious = []
for i, item in enumerate(data):
    k = (item["batch"], item["day"], item["start"])
    time_keys.setdefault(k, []).append(i)

multi_slots = {k: v for k, v in time_keys.items() if len(v) > 1}
print()
if multi_slots:
    print(f"⚠️  {len(multi_slots)} batch/day/time combos with multiple entries (may be valid lab blocks):")
    shown = 0
    for k, indices in sorted(multi_slots.items()):
        if shown >= 5:
            print(f"   ... and {len(multi_slots) - 5} more")
            break
        entries = [data[i] for i in indices]
        subjects = [e["subject"] for e in entries]
        print(f"   {k[0]} {k[1]} {k[2]}: {subjects}")
        shown += 1
else:
    print("✅ No conflicting time slots")

# 9. Spot-check a specific batch for sanity
print()
print("=" * 60)
print("🔍 SPOT CHECK: SP26-BCS-1-A (should be freshmen)")
sp26_1a = [item for item in data if item["batch"] == "SP26-BCS-1-A"]
if sp26_1a:
    for s in sorted(sp26_1a, key=lambda x: (x["day"], x["start"])):
        print(f"   {s['day']:10s} {s['start']:>5s}-{s['end']:>5s}  {s['subject'][:40]:40s}  {s['teacher'][:30]:30s}  {s['room']}")
else:
    print("   ⚠️  Not found in registry")

print()
print("🔍 SPOT CHECK: FA22-BCS-8-A (should be seniors)")
fa22_8a = [item for item in data if item["batch"] == "FA22-BCS-8-A"]
if fa22_8a:
    for s in sorted(fa22_8a, key=lambda x: (x["day"], x["start"])):
        print(f"   {s['day']:10s} {s['start']:>5s}-{s['end']:>5s}  {s['subject'][:40]:40s}  {s['teacher'][:30]:30s}  {s['room']}")
else:
    print("   ⚠️  Not found in registry")

print()
print("🔍 SPOT CHECK: SP25-BCS-3-A (mid-range)")
sp25_3a = [item for item in data if item["batch"] == "SP25-BCS-3-A"]
if sp25_3a:
    for s in sorted(sp25_3a, key=lambda x: (x["day"], x["start"])):
        print(f"   {s['day']:10s} {s['start']:>5s}-{s['end']:>5s}  {s['subject'][:40]:40s}  {s['teacher'][:30]:30s}  {s['room']}")
else:
    print("   ⚠️  Not found in registry")
