"""Deep-dive into parsing failures: show exactly which cells produce Unknown/TBD."""
import json
import re
import pdfplumber
from collections import Counter

PDF_PATH = r"D:\Flutter\student_organizer\assets\CS (1).pdf"
SEED_PATH = r"D:\Flutter\student_organizer\assets\timetable_seed.json"

TEACHER_PREFIX_RE = re.compile(r"\b(Dr\.?|Prof\.?|Engr\.?|Mr\.?|Ms\.?|Mrs\.?|Sir|Mam)\b", re.IGNORECASE)
ROOM_RE = re.compile(r"\b(?:[A-Z]\d+(?:\.\d)?|[A-Z]{2,3}Lab-?\d*|CLab-?\d+|Physics\s+Lab|MOM\s*Lab|EFM\s*Lab)\b")

with open(SEED_PATH, "r", encoding="utf-8") as f:
    data = json.load(f)

print("=" * 70)
print("ENTRIES WITH teacher='Unknown':")
print("=" * 70)
for item in data:
    if item["teacher"] == "Unknown":
        print(f"  {item['batch']:20s} {item['day']:10s} {item['start']:>5s}-{item['end']:>5s}  sub='{item['subject']}'  room='{item['room']}'")

print()
print("=" * 70)
print("ENTRIES WITH room='TBD':")
print("=" * 70)
for item in data:
    if item["room"] == "TBD":
        print(f"  {item['batch']:20s} {item['day']:10s} {item['start']:>5s}-{item['end']:>5s}  sub='{item['subject']}'  teacher='{item['teacher']}'")

print()
print("=" * 70)
print("SUBJECT SAMPLES (check for dept prefix leaking):")
print("=" * 70)
subjects = Counter(item["subject"] for item in data)
for sub, count in subjects.most_common(30):
    print(f"  [{count:2d}x] {sub}")

print()
print("=" * 70)
print("TEACHER SAMPLES (check formatting):")
print("=" * 70)
teachers = Counter(item["teacher"] for item in data)
for teacher, count in teachers.most_common(30):
    print(f"  [{count:2d}x] {teacher}")

# Now look at raw cells that produce Unknown teacher
print()
print("=" * 70)
print("RAW PDF CELLS producing Unknown teacher:")
print("=" * 70)
DAY_NAMES = {"mon": "Monday", "monday": "Monday", "tue": "Tuesday", "tues": "Tuesday",
    "tuesday": "Tuesday", "wed": "Wednesday", "wednesday": "Wednesday",
    "thu": "Thursday", "thur": "Thursday", "thursday": "Thursday",
    "fri": "Friday", "friday": "Friday", "sat": "Saturday", "saturday": "Saturday"}
BATCH_RE = re.compile(r"([A-Z]{2}\d{2})-([A-Z]{2,4})-(\d+)-([A-Z])")
TIME_RANGE_RE = re.compile(r"(\d{1,2})[:.]?(\d{2})\s*-\s*(\d{1,2})[:.]?(\d{2})")

current_day = None
with pdfplumber.open(PDF_PATH) as pdf:
    for pi, page in enumerate(pdf.pages):
        text = page.extract_text() or ""
        day_match = re.search(r"\b(Monday|Tuesday|Wednesday|Thursday|Friday|Saturday)\b", text, re.IGNORECASE)
        if day_match:
            current_day = day_match.group(0).capitalize()

        tables = page.extract_tables()
        if not tables:
            continue
        for table in tables:
            header_idx = None
            time_cols = {}
            for idx, row in enumerate(table):
                if not row:
                    continue
                for ci, cell in enumerate(row):
                    if cell and TIME_RANGE_RE.search(cell):
                        header_idx = idx
                        break
                if header_idx is not None:
                    for ci, cell in enumerate(row):
                        m = TIME_RANGE_RE.search(cell or "")
                        if m:
                            time_cols[ci] = True
                    break
            if header_idx is None:
                continue
            for row in table[header_idx+1:]:
                if not row or not row[0]:
                    continue
                if not BATCH_RE.search(row[0]):
                    continue
                batch = row[0]
                for ci, cell in enumerate(row):
                    if ci not in time_cols or not cell or not cell.strip():
                        continue
                    if "Break" in cell or "Prayer" in cell or "kaerB" in cell:
                        continue
                    lines = [l.strip() for l in cell.split("\n") if l.strip()]
                    has_teacher = any(TEACHER_PREFIX_RE.search(l) for l in lines)
                    has_room = any(ROOM_RE.search(l) for l in lines)
                    if not has_teacher:
                        print(f"\n  Page {pi+1}, {current_day}, batch={batch.strip()[:25]}")
                        print(f"  Raw cell lines:")
                        for l in lines:
                            print(f"    '{l}'")
