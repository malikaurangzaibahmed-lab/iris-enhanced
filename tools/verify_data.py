import json

with open('assets/timetable_seed.json', 'r', encoding='utf-8') as f:
    data = json.load(f)

print(f"✅ Total sessions: {len(data)}")
print()

# Check Unknown subjects
unknowns = [d for d in data if d['subject'] == 'Unknown']
print(f"📊 Unknown subjects: {len(unknowns)} ({len(unknowns)/len(data)*100:.1f}%)")

# Check RBS/RHND batches
rbs_rhnd = [d for d in data if 'RBS' in d['batch'] or 'RHND' in d['batch']]
print(f"🔬 RBS/RHND batches: {len(rbs_rhnd)} sessions")
if rbs_rhnd:
    print(f"   Sample: {rbs_rhnd[0]['batch']}")
    
    # Check if they have proper section
    proper_sections = [d for d in rbs_rhnd if '-01' in d['batch'] or '-02' in d['batch']]
    print(f"   With proper section: {len(proper_sections)}/{len(rbs_rhnd)}")

# Check CRM classes
crm = [d for d in data if d['subject'] == 'CRM']
print(f"📚 CRM classes: {len(crm)}")
if crm:
    print(f"   Sample: Teacher={crm[0]['teacher']}, Subject={crm[0]['subject']}")

# Check Chinese classes
chinese = [d for d in data if d['subject'] == 'Chinese']
print(f"🌏 Chinese classes: {len(chinese)}")
if chinese:
    print(f"   Sample: Teacher={chinese[0]['teacher']}, Subject={chinese[0]['subject']}")

# Check unique teachers
teachers = set(d['teacher'] for d in data)
print(f"\n👨‍🏫 Unique teachers: {len(teachers)}")

# Check unique departments
depts = set(d['department'] for d in data)
print(f"🏢 Departments: {', '.join(sorted(depts))}")

# Check unique batches
batches = set(d['batch'] for d in data)
print(f"🎓 Unique batches: {len(batches)}")

# Sample a few "Unknown" entries to see patterns
if unknowns:
    print(f"\n⚠️  Sample Unknown entries:")
    for i, u in enumerate(unknowns[:3]):
        print(f"   {i+1}. {u['batch']} - Teacher: {u['teacher']}, Room: {u['room']}, Day: {u['day']}")
