import json
from collections import Counter

with open('assets/timetable_seed.json', 'r', encoding='utf-8') as f:
    data = json.load(f)

unknowns = [d for d in data if d['subject'] == 'Unknown']

print(f"Analyzing {len(unknowns)} Unknown entries...\n")

# Analyze teacher name patterns
teacher_patterns = []
for u in unknowns:
    teacher = u['teacher']
    # Look for patterns
    words = teacher.split()
    if len(words) >= 2:
        # Check if last word looks like an abbreviation
        last_word = words[-1]
        if last_word[0].isupper() and '.' in last_word:
            teacher_patterns.append(f"{teacher} → {last_word} (period-separated)")
        elif len(last_word) <= 4 and last_word[0].isupper():
            teacher_patterns.append(f"{teacher} → {last_word} (short abbrev)")
        else:
            teacher_patterns.append(f"{teacher} → (complex)")

print("Top 15 Unknown subject patterns:")
for i, pattern in enumerate(teacher_patterns[:15], 1):
    print(f"  {i}. {pattern}")

# Check if there are cells with no subject line
print("\n\nSample entries:")
for i, u in enumerate(unknowns[:5], 1):
    print(f"{i}. Batch: {u['batch']}, Teacher: {u['teacher']}, Room: {u['room']}")
