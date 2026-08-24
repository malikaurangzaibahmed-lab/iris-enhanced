# Verification test for exam batch matching and date parsing

import re
from datetime import datetime

def normalize_program(prog):
    p = (prog or '').upper().strip()
    if p in ['CS', 'BCS', 'BSCS']:
        return 'BCS'
    if p in ['SE', 'BSE', 'BSSE']:
        return 'BSE'
    if p in ['EE', 'BEE', 'BSEE']:
        return 'BEE'
    if p in ['ME', 'BME', 'BSME']:
        return 'BME'
    if p in ['CE', 'BCE', 'CVE']:
        return 'CVE'
    return p

def calculate_semester(intake, now=None):
    current = now or datetime(2025, 6, 1)
    if len(intake) < 4:
        return 1
    term = intake[:2].upper()
    try:
        year_short = int(intake[2:4])
    except:
        return 1
    intake_year = 2000 + year_short
    intake_index = (intake_year * 2) + (1 if term == 'FA' else 0)

    current_year = current.year
    current_month = current.month

    if current_month >= 9:
        is_fall = True
        academic_year = current_year
    elif current_month <= 2:
        is_fall = True
        academic_year = current_year - 1
    else:
        is_fall = False
        academic_year = current_year

    current_index = (academic_year * 2) + (1 if is_fall else 0)
    sem = current_index - intake_index + 1
    return max(1, min(8, sem))

def parse_batch_key(batch):
    raw = batch.strip()
    parts = raw.split('-')
    if len(parts) == 1:
        return {'batch': raw, 'intake': '', 'program': normalize_program(parts[0]), 'semester': 0, 'section': ''}
    elif len(parts) == 2:
        # e.g. BCS-6A or BCS-A or FA21-BCS
        p0, p1 = parts[0].upper(), parts[1].upper()
        if re.match(r'^(FA|SP)\d{2}$', p0):
            # FA21-BCS
            return {'batch': raw, 'intake': p0, 'program': normalize_program(p1), 'semester': calculate_semester(p0), 'section': ''}
        else:
            # BCS-6A or BCS-A
            m = re.match(r'^(\d+)?([A-Za-z0-9]+)?$', p1)
            sem = int(m.group(1)) if m and m.group(1) else 0
            sec = m.group(2) if m and m.group(2) else ''
            return {'batch': raw, 'intake': '', 'program': normalize_program(p0), 'semester': sem, 'section': sec}
    elif len(parts) == 3:
        # e.g. FA21-BCS-6A or FA21-BCS-A
        intake = parts[0].upper()
        prog = normalize_program(parts[1])
        last = parts[2].upper()
        m = re.match(r'^(\d+)?([A-Za-z0-9]+)?$', last)
        sem = int(m.group(1)) if m and m.group(1) else calculate_semester(intake)
        sec = m.group(2) if m and m.group(2) else 'A'
        return {'batch': raw, 'intake': intake, 'program': prog, 'semester': sem, 'section': sec}
    elif len(parts) >= 4:
        # e.g. FA21-BCS-6-A
        intake = parts[0].upper()
        prog = normalize_program(parts[1])
        try:
            sem = int(parts[2])
        except:
            sem = calculate_semester(intake)
        sec = parts[3].upper()
        return {'batch': raw, 'intake': intake, 'program': prog, 'semester': sem, 'section': sec}
    return {'batch': raw, 'intake': '', 'program': 'UNKNOWN', 'semester': 0, 'section': ''}

def expand_batch_sections(batch_str):
    results = []
    chunks = [c.strip() for c in batch_str.split(',') if c.strip()]
    for chunk in chunks:
        if '/' in chunk:
            slash_parts = chunk.split('/')
            base = slash_parts[0].strip()
            results.append(base)
            base_m = re.match(r'^(.*[-_])?([A-Za-z0-9]+)$', base)
            if base_m:
                prefix = base_m.group(1) or ''
                for extra in slash_parts[1:]:
                    e = extra.strip()
                    if e:
                        results.append(f"{prefix}{e}")
        else:
            results.append(chunk)
    return results

def is_batch_match(student_batch, exam_batch):
    if not student_batch or not exam_batch:
        return False
    if student_batch.lower() == exam_batch.lower() or student_batch.lower() == 'all' or exam_batch.lower() == 'all':
        return True

    expanded_exams = expand_batch_sections(exam_batch)
    expanded_students = expand_batch_sections(student_batch)

    for eb in expanded_exams:
        for sb in expanded_students:
            if eb.lower() == sb.lower():
                return True
            s_key = parse_batch_key(sb)
            e_key = parse_batch_key(eb)

            if s_key['program'] != e_key['program']:
                continue

            # Section matching
            s_sec = s_key['section']
            e_sec = e_key['section']
            sec_match = not s_sec or not e_sec or s_sec == e_sec

            # Semester matching
            s_sem = s_key['semester']
            e_sem = e_key['semester']
            sem_match = s_sem == 0 or e_sem == 0 or s_sem == e_sem

            # Intake matching
            s_in = s_key['intake']
            e_in = e_key['intake']
            if s_in and e_in:
                intake_match = (s_in == e_in)
            else:
                intake_match = True

            if sec_match and sem_match and intake_match:
                return True
    return False

# Test test cases
cases = [
    ("BCS-6A", "FA21-BCS-6A", True),
    ("BCS-6A", "BCS-6A", True),
    ("BCS-6A", "BCS-6A, BCS-6B", True),
    ("BCS-6B", "BCS-6A, BCS-6B", True),
    ("BCS-6A", "BCS-6A/B", True),
    ("BCS-6B", "BCS-6A/B", True),
    ("BCS-6A", "BSCS-6A", True),
    ("BCS-6A", "BCS-6B", False),
    ("BCS-6A", "BCS-4A", False),
    ("BCS-6A", "BSE-6A", False),
    ("BSE-4A", "SP23-BSE-4A", True),
    ("FA21-BCS-6A", "BCS-6A", True),
]

all_passed = True
for s, e, expected in cases:
    res = is_batch_match(s, e)
    passed = (res == expected)
    if not passed:
        all_passed = False
        print(f"FAILED: student='{s}', exam='{e}' => got {res}, expected {expected}")
    else:
        print(f"PASSED: '{s}' vs '{e}' => {res}")

if all_passed:
    print("ALL 12 TEST CASES PASSED PERFECTLY!")
