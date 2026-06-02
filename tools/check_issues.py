import json

# Load timetable
with open('D:/Flutter/IRIS/assets/timetable_seed.json', 'r', encoding='utf-8') as f:
    data = json.load(f)

print("=" * 60)
print("TIMETABLE VALIDATION REPORT")
print("=" * 60)

# 1. Basic stats
print(f"\n1. BASIC STATS:")
print(f"   Total sessions: {len(data)}")
print(f"   Unique batches: {len(set(s['batch'] for s in data))}")

# 2. Check (1 hr) lecture durations
def parse_time(t):
    h, m = map(int, t.split(':'))
    return h + m / 60.0

hr_lectures = [s for s in data if '(1 hr)' in s['subject']]
durations = [(s, parse_time(s['end']) - parse_time(s['start'])) for s in hr_lectures]
invalid_durations = [d for d in durations if abs(d[1] - 1.0) > 0.05]

print(f"\n2. (1 HR) LECTURE DURATIONS:")
print(f"   Total (1 hr) lectures: {len(hr_lectures)}")
print(f"   Incorrect durations: {len(invalid_durations)}")
if invalid_durations:
    print(f"   ❌ ISSUE: Some (1 hr) lectures don't have 1.0 hour duration!")
    for s, dur in invalid_durations[:5]:
        print(f"      {s['subject'][:40]}: {dur:.2f} hours ({s['start']}-{s['end']})")
else:
    print(f"   ✅ All (1 hr) lectures have exactly 1.0 hour duration")

# 3. Check for break violations (12:00-1:00)
break_violations = [s for s in data if s['start'] == '12:00' and s['end'] > '1:00']
print(f"\n3. BREAK TIME VIOLATIONS (12:00-1:00):")
print(f"   Sessions spanning break: {len(break_violations)}")
if break_violations:
    print(f"   ❌ ISSUE: Sessions spanning across break time!")
    for s in break_violations[:5]:
        print(f"      {s['batch']}: {s['subject'][:40]} ({s['start']}-{s['end']})")
else:
    print(f"   ✅ No sessions span across break time")

# 4. Check for overlapping sessions per batch
overlaps = []
batches = {}
for s in data:
    batches.setdefault(s['batch'], []).append(s)

for batch, sessions in batches.items():
    for i, s1 in enumerate(sessions):
        for s2 in sessions[i+1:]:
            if s1['day'] == s2['day']:
                # Check if times overlap
                start1 = parse_time(s1['start'])
                end1 = parse_time(s1['end'])
                start2 = parse_time(s2['start'])
                end2 = parse_time(s2['end'])
                
                if not (end1 <= start2 or end2 <= start1):
                    overlaps.append((batch, s1, s2))

print(f"\n4. SCHEDULE OVERLAPS:")
print(f"   Overlapping sessions: {len(overlaps)}")
if overlaps:
    print(f"   ❌ ISSUE: Found scheduling conflicts!")
    for batch, s1, s2 in overlaps[:5]:
        print(f"      {batch}: {s1['day']}")
        print(f"         {s1['subject'][:35]} ({s1['start']}-{s1['end']})")
        print(f"         {s2['subject'][:35]} ({s2['start']}-{s2['end']})")
else:
    print(f"   ✅ No scheduling conflicts found")

# 5. Check lab sessions split across break
lab_groups = {}
for s in data:
    if 'Lab' in s['subject']:
        key = (s['batch'], s['day'], s['subject'].replace('(Lab)', '').strip())
        lab_groups.setdefault(key, []).append(s)

split_labs = []
merged_labs = []

for key, sessions in lab_groups.items():
    if len(sessions) > 1:
        # Check if any pair spans break
        for s1 in sessions:
            for s2 in sessions:
                if s1 != s2:
                    if s1['end'] == '12:00' and s2['start'] == '1:00':
                        split_labs.append((key, s1, s2))
                    elif s1['start'] == '11:00' and s1['end'] == '2:00':
                        merged_labs.append((key, s1))

print(f"\n5. LAB SESSION ANALYSIS:")
print(f"   Total lab groups: {len(lab_groups)}")
print(f"   Lab pairs split across break: {len(split_labs)}")
print(f"   Labs incorrectly merged: {len(merged_labs)}")
if merged_labs:
    print(f"   ❌ ISSUE: Some labs spanning 11:00-2:00 (should be split!)")
    for key, s in merged_labs[:5]:
        print(f"      {key[0]}: {key[2]} on {key[1]} ({s['start']}-{s['end']})")
else:
    print(f"   ✅ All labs correctly split or independent")

# 6. Check for missing required fields
missing_fields = []
required = ['batch', 'day', 'start', 'end', 'subject', 'teacher', 'room']
for i, s in enumerate(data):
    for field in required:
        if field not in s or not s[field]:
            missing_fields.append((i, field, s.get('subject', 'UNKNOWN')))

print(f"\n6. MISSING FIELDS:")
print(f"   Sessions with missing data: {len(missing_fields)}")
if missing_fields:
    print(f"   ❌ ISSUE: Some sessions have missing fields!")
    for idx, field, subj in missing_fields[:10]:
        print(f"      Session {idx}: Missing '{field}' in {subj[:40]}")
else:
    print(f"   ✅ All sessions have complete data")

# 7. Check for invalid time formats
invalid_times = []
for i, s in enumerate(data):
    try:
        parse_time(s['start'])
        parse_time(s['end'])
    except:
        invalid_times.append((i, s.get('subject', 'UNKNOWN'), s.get('start'), s.get('end')))

print(f"\n7. TIME FORMAT VALIDATION:")
print(f"   Invalid time formats: {len(invalid_times)}")
if invalid_times:
    print(f"   ❌ ISSUE: Some times are invalid!")
    for idx, subj, start, end in invalid_times[:5]:
        print(f"      Session {idx}: {subj[:40]} ({start}-{end})")
else:
    print(f"   ✅ All time formats valid")

# 8. Summary
print("\n" + "=" * 60)
print("SUMMARY:")
issues_found = (
    len(invalid_durations) +
    len(break_violations) +
    len(overlaps) +
    len(merged_labs) +
    len(missing_fields) +
    len(invalid_times)
)

if issues_found == 0:
    print("✅ NO ISSUES FOUND - Timetable is clean!")
else:
    print(f"⚠️  TOTAL ISSUES: {issues_found}")
    print(f"   - Invalid durations: {len(invalid_durations)}")
    print(f"   - Break violations: {len(break_violations)}")
    print(f"   - Scheduling overlaps: {len(overlaps)}")
    print(f"   - Merged labs: {len(merged_labs)}")
    print(f"   - Missing fields: {len(missing_fields)}")
    print(f"   - Invalid times: {len(invalid_times)}")
print("=" * 60)
