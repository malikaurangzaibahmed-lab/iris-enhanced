import pdfplumber
import glob
import re

print("==================== DEEP COMPREHENSIVE TIMETABLE STUDY ====================")

room_pattern = re.compile(
    r'\b(?:'
    r'[A-Z]\d+(?:\.\d+)?|'
    r'B\d{1,2}|C\d+(?:\.\d+)?|A\d+(?:\.\d+)?|D\d{1,2}|EE-\d{2}|ME-\d{2}|CE-\d{2}|'
    r'CLab-\d{1,2}|DLD\s+Lab|DSP\s+Lab|Embedded\s+Lab|CS\s+Lab|'
    r'Networking\s+Lab|Power\s+Lab|Machines\s+Lab|Survey\s+Lab|Fluid\s+Lab|'
    r'Thermodynamics\s+Lab|CAD\s+Lab|Mechanics\s+Lab|Drawing\s+Hall|'
    r'Seminar\s+Room|D\s+Block\s+Seminar\s+Room|Audi|Auditorium|'
    r'Library|Sports\s+Complex|Ground'
    r')\b',
    re.IGNORECASE
)

all_unique_teachers = set()
all_unique_rooms = set()
all_unique_subjects = set()
edge_case_cells = []

for pdf_path in sorted(glob.glob('assets/documents/*.pdf')):
    if 'iouiouj.pdf' in pdf_path: continue
    print(f"\nScanning: {pdf_path}")
    with pdfplumber.open(pdf_path) as pdf:
        for p_idx, page in enumerate(pdf.pages):
            tables = page.extract_tables()
            for t_idx, table in enumerate(tables):
                for r_idx, row in enumerate(table):
                    if not row or len(row) < 2: continue
                    batch_cell = (row[0] or '').strip()
                    if not batch_cell or re.match(r'^(?:CUI|Timetable|1|2|3|4|5|6|Break|Date|Time)', batch_cell, re.IGNORECASE):
                        continue
                    
                    for c_idx, cell in enumerate(row[1:]):
                        if not cell or not str(cell).strip(): continue
                        cell_str = str(cell).strip()
                        if re.search(r'break|kaerb|prayer|fehm', cell_str, re.IGNORECASE): continue
                        
                        lines = [l.strip() for l in cell_str.split('\n') if l.strip()]
                        
                        # Look for potential edge cases: multiple slash-separated items, strange tokens
                        if '/' in cell_str and not re.search(r'\b(?:and|or)\b', cell_str, re.IGNORECASE):
                            edge_case_cells.append((pdf_path, p_idx+1, batch_cell, cell_str))
                            
                        # Extract room
                        rm = room_pattern.findall(cell_str)
                        for r in rm:
                            all_unique_rooms.add(r.strip())

print("\n--- Edge Case Cells Detected (Slash / Multi-section) ---")
for ec in edge_case_cells[:15]:
    print(f"[{ec[0]} P{ec[1]} | {ec[2]}]: {ec[3]}")

print(f"\nTotal Unique Rooms Detected: {len(all_unique_rooms)}")
print(sorted(list(all_unique_rooms))[:30])
