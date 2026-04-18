import json
import re

with open('assets/timetable_seed.json', 'r', encoding='utf-8') as f:
    data = json.load(f)

print("=" * 80)
print("COMPREHENSIVE DATA QUALITY AUDIT")
print("=" * 80)

# 1. MISSING/UNKNOWN VALUES
print("\n1. MISSING OR UNKNOWN VALUES:")
missing_subjects = [d for d in data if not d['subject'] or d['subject'].lower() == 'unknown']
missing_teachers = [d for d in data if not d['teacher'] or d['teacher'].lower() == 'unknown']
missing_rooms = [d for d in data if not d['room'] or d['room'].lower() == 'unknown' or d['room'].lower() == 'tbd']
missing_batches = [d for d in data if not d['batch']]
missing_depts = [d for d in data if not d['department']]

print(f"   Unknown/Missing Subjects: {len(missing_subjects)}")
if missing_subjects:
    for i, m in enumerate(missing_subjects[:3]):
        print(f"      {i+1}. {m}")

print(f"   Unknown/Missing Teachers: {len(missing_teachers)}")
if missing_teachers:
    for i, m in enumerate(missing_teachers[:3]):
        print(f"      {i+1}. {m}")

print(f"   Unknown/Missing Rooms: {len(missing_rooms)}")
if missing_rooms:
    for i, m in enumerate(missing_rooms[:3]):
        print(f"      {i+1}. {m}")

print(f"   Missing Batches: {len(missing_batches)}")
print(f"   Missing Departments: {len(missing_depts)}")

# 2. DATA COMPLETENESS BY DEPARTMENT
print("\n2. COMPLETENESS BY DEPARTMENT:")
depts = {}
for d in data:
    dept = d['department']
    if dept not in depts:
        depts[dept] = {'count': 0, 'subjects': set(), 'teachers': set(), 'batches': set(), 'rooms': set()}
    depts[dept]['count'] += 1
    depts[dept]['subjects'].add(d['subject'])
    depts[dept]['teachers'].add(d['teacher'])
    depts[dept]['batches'].add(d['batch'])
    depts[dept]['rooms'].add(d['room'])

for dept in sorted(depts.keys()):
    info = depts[dept]
    print(f"\n   {dept}:")
    print(f"      Sessions: {info['count']}")
    print(f"      Unique subjects: {len(info['subjects'])}")
    print(f"      Unique teachers: {len(info['teachers'])}")
    print(f"      Unique batches: {len(info['batches'])}")
    print(f"      Unique rooms: {len(info['rooms'])}")
    
    # Check for unknown in this dept
    dept_unknown = [d for d in data if d['department'] == dept and (not d['subject'] or d['subject'].lower() == 'unknown')]
    if dept_unknown:
        print(f"      ⚠️  UNKNOWN SUBJECTS: {len(dept_unknown)}")

# 3. TIME COVERAGE
print("\n3. TIME SLOT COVERAGE:")
times = set()
for d in data:
    times.add(d['start'])
    times.add(d['end'])

print(f"   Unique start times: {len(set(d['start'] for d in data))}")
print(f"   Unique end times: {len(set(d['end'] for d in data))}")
print(f"   Sample times: {sorted(list(set(d['start'] for d in data)))[:10]}")

# 4. DAY COVERAGE
print("\n4. DAY COVERAGE:")
day_count = {}
for d in data:
    day = d['day']
    day_count[day] = day_count.get(day, 0) + 1

for day in ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday']:
    count = day_count.get(day, 0)
    print(f"   {day}: {count} sessions")

# 5. SUBJECT VALIDITY
print("\n5. SUBJECT QUALITY:")
all_subjects = set(d['subject'] for d in data)
suspicious_subjects = [s for s in all_subjects if len(s) < 2 or s.lower() in ['unknown', 'tbd', 'n/a', 'na']]
print(f"   Total unique subjects: {len(all_subjects)}")
print(f"   Suspicious/Empty subjects: {len(suspicious_subjects)}")
if suspicious_subjects:
    for s in suspicious_subjects[:10]:
        count = len([d for d in data if d['subject'] == s])
        print(f"      '{s}' - {count} occurrences")

# 6. TEACHER QUALITY
print("\n6. TEACHER QUALITY:")
all_teachers = set(d['teacher'] for d in data)
short_teachers = [t for t in all_teachers if len(t) < 2]
numeric_teachers = [t for t in all_teachers if any(c.isdigit() for c in t) and t.count(' ') == 0]
print(f"   Total unique teachers: {len(all_teachers)}")
print(f"   Suspiciously short names (<2 chars): {len(short_teachers)}")
if short_teachers:
    print(f"      Examples: {short_teachers[:10]}")

# 7. BATCH PATTERNS
print("\n7. BATCH NAMING PATTERNS:")
semester_patterns = {}
for d in data:
    batch = d['batch']
    match = re.match(r'(FA|SP)(\d+)', batch)
    if match:
        sem = f"{match.group(1)}{match.group(2)}"  # FA25, SP26, etc.
        semester_patterns[sem] = semester_patterns.get(sem, 0) + 1

print(f"   Semesters found: {len(semester_patterns)}")
for sem in sorted(semester_patterns.keys()):
    print(f"      {sem}: {semester_patterns[sem]} sessions")

# 8. ROOM PATTERNS
print("\n8. ROOM PATTERNS:")
all_rooms = set(d['room'] for d in data)
room_prefixes = {}
for room in all_rooms:
    prefix = re.match(r'^([A-Za-z]+)', room)
    if prefix:
        p = prefix.group(1)
        room_prefixes[p] = room_prefixes.get(p, 0) + 1

print(f"   Total unique rooms: {len(all_rooms)}")
print(f"   Room type prefixes:")
for prefix in sorted(room_prefixes.keys(), key=lambda x: -room_prefixes[x])[:10]:
    print(f"      {prefix}: {room_prefixes[prefix]} rooms")

# 9. TOTAL COUNTS
print("\n9. FINAL TOTALS:")
print(f"   Total sessions: {len(data)}")
print(f"   Unique subjects: {len(set(d['subject'] for d in data))}")
print(f"   Unique teachers: {len(set(d['teacher'] for d in data))}")
print(f"   Unique batches: {len(set(d['batch'] for d in data))}")
print(f"   Unique departments: {len(set(d['department'] for d in data))}")
print(f"   Unique rooms: {len(set(d['room'] for d in data))}")

print("\n" + "=" * 80)
