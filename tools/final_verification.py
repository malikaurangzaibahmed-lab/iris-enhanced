import json
from datetime import datetime, timedelta

# Load timetable
with open('assets/timetable_seed.json', 'r', encoding='utf-8') as f:
    sessions = json.load(f)

print("="*80)
print("FINAL VERIFICATION REPORT - (1 HR) LECTURES")
print("="*80)

# Find all (1 hr) lectures
one_hr_lectures = [s for s in sessions if '(1 hr)' in s['subject'].lower() or '(1hr)' in s['subject'].lower()]

print(f"\nTotal (1 hr) lectures found: {len(one_hr_lectures)}")

# Check each one
correct = 0
incorrect = 0

def to_decimal(time_str):
    h, m = time_str.split(':')
    return int(h) + int(m) / 60.0

for lecture in one_hr_lectures[:20]:  # Show first 20
    start = to_decimal(lecture['start'])
    end = to_decimal(lecture['end'])
    duration = end - start
    
    status = "✅" if abs(duration - 1.0) < 0.05 else "❌"
    if abs(duration - 1.0) < 0.05:
        correct += 1
    else:
        incorrect += 1
    
    print(f"{status} {lecture['batch']:15} {lecture['day']:9} {lecture['start']}-{lecture['end']} ({duration:.2f}h) | {lecture['subject'][:35]}")

print(f"\n{'='*80}")
print(f"Summary of all {len(one_hr_lectures)} (1 hr) lectures:")
# Count all
total_correct = sum(1 for s in one_hr_lectures if abs(to_decimal(s['end']) - to_decimal(s['start']) - 1.0) < 0.05)
total_incorrect = len(one_hr_lectures) - total_correct

print(f"  ✅ Correct (1.0h): {total_correct}")
print(f"  ❌ Incorrect: {total_incorrect}")

if total_incorrect == 0:
    print("\n🎉 ALL (1 HR) LECTURES HAVE CORRECT DURATIONS!")
else:
    print(f"\n⚠️  {total_incorrect} lectures need fixing")

# Check Friday specifically
print(f"\n{'='*80}")
print("FRIDAY SCHEDULE SUMMARY")
print(f"{'='*80}")

friday_sessions = [s for s in sessions if s['day'] == 'Friday']
print(f"\nTotal Friday sessions: {len(friday_sessions)}")

# Group by batch
friday_batches = {}
for s in friday_sessions:
    if s['batch'] not in friday_batches:
        friday_batches[s['batch']] = []
    friday_batches[s['batch']].append(s)

print(f"Batches with Friday classes: {len(friday_batches)}")

# Show sample Friday schedules
sample_batches = list(friday_batches.keys())[:3]
for batch in sample_batches:
    print(f"\n{batch} Friday:")
    batch_sessions = sorted(friday_batches[batch], key=lambda x: to_decimal(x['start']))
    for s in batch_sessions:
        print(f"  {s['start']}-{s['end']} | {s['subject'][:40]:<40} | {s['room']}")

print(f"\n{'='*80}")
print("VERIFICATION COMPLETE ✓")
print(f"{'='*80}\n")
