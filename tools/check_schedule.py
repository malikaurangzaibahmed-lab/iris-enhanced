import json

with open('assets/timetable_seed.json') as f:
    data = json.load(f)

# Get a sample batch to check
sample_batch = 'FA23-BCS-6-A'
classes = [s for s in data if s['batch'] == sample_batch]

# Check all days
for day in ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday']:
    day_classes = sorted([s for s in classes if s['day'] == day], key=lambda x: x['start'])
    if not day_classes:
        continue
        
    print(f"\n{sample_batch} {day} Schedule:")
    print("=" * 80)
    for s in day_classes:
        print(f"{s['start']:>5} - {s['end']:<5} | {s['subject'][:40]:<40} | {s['room']}")

    # Check for potential merge issues
    print(f"\nChecking for merge issues on {day}:")
    print("-" * 80)
    for i in range(len(day_classes) - 1):
        curr = day_classes[i]
        next_class = day_classes[i + 1]
        
        # Convert time to decimal
        def to_decimal(time_str):
            h, m = time_str.split(':')
            return int(h) + int(m) / 60.0
        
        curr_end = to_decimal(curr['end'])
        next_start = to_decimal(next_class['start'])
        gap = next_start - curr_end
        
        same_subject = curr['subject'] == next_class['subject']
        same_teacher = curr['teacher'] == next_class['teacher']
        same_room = curr['room'] == next_class['room']
        
        if abs(gap) < 0.01:
            if same_subject and same_teacher and same_room:
                print(f"✓ WILL MERGE (back-to-back same class):")
                print(f"  {curr['start']}-{curr['end']} {curr['subject'][:35]} @ {curr['room']}")
                print(f"  {next_class['start']}-{next_class['end']} {next_class['subject'][:35]} @ {next_class['room']}")
                print()
        elif gap > 0:
            if same_subject and same_teacher and same_room:
                print(f"⚠️  SHOULD NOT MERGE (has {gap*60:.0f} min break):")
                print(f"  {curr['start']}-{curr['end']} {curr['subject'][:35]} @ {curr['room']}")
                print(f"  [Break: {gap*60:.0f} minutes]")
                print(f"  {next_class['start']}-{next_class['end']} {next_class['subject'][:35]} @ {next_class['room']}")
                print()

