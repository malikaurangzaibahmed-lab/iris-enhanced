import json

with open('assets/timetable_seed.json', 'r', encoding='utf-8') as f:
    data = json.load(f)

# Find all unique RBS/RHND batch formats
rbs_batches = set()
for entry in data:
    batch = entry.get('batch', '')
    if 'RBS' in batch or 'RHND' in batch or 'RMS' in batch or 'PMS' in batch or 'PCS' in batch or 'RCS' in batch:
        rbs_batches.add(batch)

print("All RBS/RHND/RMS/PMS/PCS/RCS batch formats in timetable:")
for batch in sorted(rbs_batches):
    count = len([d for d in data if d['batch'] == batch])
    print(f"  {batch:20} → {count:3} sessions")
