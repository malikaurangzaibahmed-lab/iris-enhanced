import json

# Load timetable
with open('assets/timetable_seed.json', 'r', encoding='utf-8') as f:
    sessions = json.load(f)

print("="*80)
print("COMPREHENSIVE RAMADAN TIMETABLE CHECK")
print("="*80)

# Get all unique batches
all_batches = sorted(set(s['batch'] for s in sessions))
print(f"\nTotal batches: {len(all_batches)}")
print(f"Total sessions: {len(sessions)}")

# Day distribution
day_counts = {}
for s in sessions:
    day_counts[s['day']] = day_counts.get(s['day'], 0) + 1

print(f"\nSessions per day:")
for day in ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday']:
    print(f"  {day}: {day_counts.get(day, 0)}")

# Check specific batches thoroughly
test_batches = ["FA22-BCS-8-A", "FA23-BCS-6-A", "FA24-BCS-4-A", "FA25-BCS-2-A"]

issues_found = []
warnings_found = []

def to_decimal(time_str):
    """Convert HH:MM to decimal hours"""
    h, m = time_str.split(':')
    return int(h) + int(m) / 60.0

for target_batch in test_batches:
    print(f"\n{'='*80}")
    print(f"CHECKING BATCH: {target_batch}")
    print(f"{'='*80}")
    
    batch_sessions = [s for s in sessions if s['batch'] == target_batch]
    
    if not batch_sessions:
        print(f"  ⚠️  No sessions found for {target_batch}")
        continue
    
    # Group by day
    days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday']
    for day in days:
        day_sessions = [s for s in batch_sessions if s['day'] == day]
        if not day_sessions:
            print(f"\n{day}: No classes")
            continue
        
        # Sort by start time
        day_sessions.sort(key=lambda x: to_decimal(x['start']))
        
        print(f"\n{day}: ({len(day_sessions)} classes)")
        for s in day_sessions:
            subject_display = s['subject'][:35]
            if "(1 hr)" in s['subject'].lower() or "(1hr)" in s['subject'].lower():
                subject_display += " 🕐"
            print(f"  {s['start']:>5} - {s['end']:>5} | {subject_display:<40} | {s['room']:<8}")
        
        # Check for issues
        for i in range(len(day_sessions) - 1):
            curr = day_sessions[i]
            next_s = day_sessions[i + 1]
            
            curr_start = to_decimal(curr['start'])
            curr_end = to_decimal(curr['end'])
            next_start = to_decimal(next_s['start'])
            next_end = to_decimal(next_s['end'])
            
            gap = next_start - curr_end
            curr_duration = curr_end - curr_start
            
            # Issue 1: Check (1 hr) marker correctness
            has_1hr_marker = "(1 hr)" in curr['subject'].lower() or "(1hr)" in curr['subject'].lower()
            if has_1hr_marker:
                if abs(curr_duration - 1.0) > 0.05:
                    issue = f"❌ {target_batch} {day}: (1 hr) lecture has wrong duration: {curr['start']}-{curr['end']} = {curr_duration:.2f}h | {curr['subject'][:30]}"
                    issues_found.append(issue)
                    print(f"    {issue}")
            
            # Issue 2: Check for overlaps
            if gap < -0.01:  # Negative gap = overlap
                issue = f"❌ {target_batch} {day}: OVERLAP: {curr['start']}-{curr['end']} & {next_s['start']}-{next_s['end']} | {curr['subject'][:25]} / {next_s['subject'][:25]}"
                issues_found.append(issue)
                print(f"    {issue}")
            
            # Issue 3: Check if same class appears with gap (potential merge issue)
            same_class = (curr['subject'] == next_s['subject'] and 
                         curr['teacher'] == next_s['teacher'] and 
                         curr['room'] == next_s['room'])
            
            if same_class:
                # Is it across the break? (12:00 - 1:00)
                is_across_break = (curr_end <= 12.01 and next_start >= 12.99)  # 12:00 and 1:00
                
                if abs(gap) < 0.02:
                    # Consecutive - will merge (this is OK)
                    print(f"    ✓ Consecutive (will merge): {curr['start']}-{curr['end']} + {next_s['start']}-{next_s['end']} | {curr['subject'][:30]}")
                elif is_across_break and 0.8 < gap < 1.0:
                    # Across break - this might be intentional for labs
                    warning = f"⚠️  {target_batch} {day}: Class spanning break: {curr['start']}-{curr['end']} + {next_s['start']}-{next_s['end']} (break gap) | {curr['subject'][:30]}"
                    warnings_found.append(warning)
                    print(f"    {warning}")
                elif gap > 0.02:
                    # Same class with gap (not consecutive, not break) - problematic
                    issue = f"❌ {target_batch} {day}: Same class split with {gap*60:.0f}min gap: {curr['start']}-{curr['end']} + {next_s['start']}-{next_s['end']} | {curr['subject'][:30]}"
                    issues_found.append(issue)
                    print(f"    {issue}")

# Friday special check
print(f"\n{'='*80}")
print("FRIDAY SCHEDULE CHECK (Ramadan changes)")
print(f"{'='*80}")

friday_sessions = [s for s in sessions if s['day'] == 'Friday']
print(f"\nTotal Friday sessions across all batches: {len(friday_sessions)}")

# Check if Friday has different timings
friday_times = set()
for s in friday_sessions:
    friday_times.add((s['start'], s['end']))

print(f"Unique time slots on Friday: {len(friday_times)}")
print("\nFriday time slots used:")
for start, end in sorted(friday_times, key=lambda x: to_decimal(x[0])):
    count = len([s for s in friday_sessions if s['start'] == start and s['end'] == end])
    print(f"  {start} - {end} ({count} sessions)")

# Summary
print(f"\n\n{'='*80}")
print("SUMMARY")
print(f"{'='*80}")

if issues_found:
    print(f"\n❌ Found {len(issues_found)} CRITICAL issues:\n")
    for issue in issues_found:
        print(f"  {issue}")
else:
    print("\n✅ No critical issues found!")

if warnings_found:
    print(f"\n⚠️  Found {len(warnings_found)} warnings (may be intentional):\n")
    for warning in warnings_found:
        print(f"  {warning}")
else:
    print("\n✅ No warnings!")

print(f"\n{'='*80}")
print("Timetable check complete.")
print(f"{'='*80}\n")
