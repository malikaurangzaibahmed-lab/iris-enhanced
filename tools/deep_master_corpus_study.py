import os
import glob
import re
import json
import pdfplumber
import openpyxl

def build_master_corpus():
    print("=" * 80)
    print("EXTRACTING COMPREHENSIVE UNIVERSITY CORPUS (ALL ASSETS)")
    print("=" * 80)
    
    departments = set()
    courses = set()
    instructors = set()
    locations = set()
    batches = set()
    slots = set()
    days = set()
    
    # Track statistics per source document
    doc_stats = {}
    
    # -------------------------------------------------------------
    # 1. PARSE ALL 8 PDF TIMETABLES
    # -------------------------------------------------------------
    pdf_files = sorted(glob.glob("assets/documents/*.pdf"))
    
    for pf in pdf_files:
        name = os.path.basename(pf)
        doc_stats[name] = {'type': 'PDF Timetable', 'sessions': 0, 'pages': 0}
        
        with pdfplumber.open(pf) as pdf:
            doc_stats[name]['pages'] = len(pdf.pages)
            
            for p_idx, page in enumerate(pdf.pages):
                text = page.extract_text() or ""
                tables = page.extract_tables()
                
                # Check for day names
                for d in ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]:
                    if re.search(r'\b' + d + r'\b', text, re.I):
                        days.add(d)
                        
                # Extract time slots from header
                slot_matches = re.findall(r'\d{1,2}:\d{2}\s*-\s*\d{1,2}:\d{2}', text)
                for sm in slot_matches:
                    slots.add(sm)
                    
                # Extract instructors & courses & rooms from cell contents
                for table in tables:
                    if not table or len(table) < 2: continue
                    # Header row has timeslots/periods
                    header = table[0]
                    for r_idx, row in enumerate(table[1:], start=1):
                        if not row or len(row) < 2: continue
                        # Column 0 is often Batch / Class
                        batch_col = row[0]
                        if batch_col:
                            for b_match in re.findall(r'(?:FA|SP)\d{2}-[A-Z0-9]+(?:-[A-Z0-9]+)*', str(batch_col), re.I):
                                batches.add(b_match.upper().strip())
                                
                        for c_idx, cell in enumerate(row[1:], start=1):
                            if not cell: continue
                            cell_str = str(cell).strip()
                            if not cell_str or cell_str.lower() in ['break', 'none', '']: continue
                            
                            doc_stats[name]['sessions'] += 1
                            
                            # Extract Instructor (e.g. "CS Mr. Fayez Afzaal", "EE Dr. Saqlain", "VS Alia Ikram")
                            inst_matches = re.findall(r'\b(CS|EE|ME|MS|HUM|CVE|CE|MT|VS|BI|SE)\s+([A-Za-z\.\s]+)', cell_str)
                            for dept, full_name in inst_matches:
                                departments.add(dept.upper())
                                clean_name = full_name.split('\n')[0].strip()
                                # Clean trailing words that belong to course
                                clean_name = re.sub(r'\s+(Applications|Programming|Digital|Linear|Calculus|Data|Software|Introduction|Advanced|Human|Civics|Fnctnl|Intro2|Fund|Principles).*$', '', clean_name, flags=re.I)
                                if clean_name and len(clean_name) > 2:
                                    instructors.add(f"{dept.upper()} {clean_name}")
                                    
                            # Extract Room/Location (e.g. "A3 (63)", "CLab-8", "DLD Lab", "B13 (70)", "MOM Lab")
                            room_matches = re.findall(r'\b([A-D]\d*(?:\.\d+)?\s*\(\d+\)|CLab-\d+|[A-Z0-9\s]+Lab|Workshop|Auditorium)\b', cell_str, re.I)
                            for rm in room_matches:
                                rm_clean = rm.strip()
                                if len(rm_clean) >= 2 and not any(k in rm_clean.lower() for k in ['department', 'university', 'technology', 'science', 'application']):
                                    locations.add(rm_clean)
                                    
                            # Extract Course Name
                            lines = [l.strip() for l in cell_str.split('\n') if l.strip()]
                            for l in lines:
                                if not re.match(r'^(?:CS|EE|ME|MS|HUM|CVE|CE|MT|VS|BI|SE)\b', l) and not re.search(r'\b[A-D]\d*\s*\(\d+\)\b|Lab', l):
                                    if len(l) > 3 and not re.match(r'^\d+$', l):
                                        courses.add(l)

    # -------------------------------------------------------------
    # 2. PARSE BOTH EXCEL MASTER DATE SHEETS
    # -------------------------------------------------------------
    excel_files = [f for f in sorted(glob.glob("assets/documents/*.xlsx")) if not os.path.basename(f).startswith('~$')]
    
    for ef in excel_files:
        name = os.path.basename(ef)
        doc_stats[name] = {'type': 'Excel Date Sheet', 'slots': 0, 'venues': 0}
        
        wb = openpyxl.load_workbook(ef, data_only=True)
        ws = wb.active
        rows = list(ws.iter_rows(values_only=True))
        
        # Locate header row
        header_row_idx = 2
        for r_idx in range(min(len(rows), 10)):
            dates = [c for c in rows[r_idx] if c and str(c).strip().lower() == 'date']
            if len(dates) >= 2:
                header_row_idx = r_idx
                break
                
        header_row = rows[header_row_idx]
        
        # Rooms in header row
        excel_rooms = []
        for c_idx, cell in enumerate(header_row):
            if cell:
                c_str = str(cell).strip()
                if c_str.lower() not in ['date', 'time', 'none', '']:
                    locations.add(c_str)
                    excel_rooms.append((c_idx, c_str))
                    
        doc_stats[name]['venues'] = len(excel_rooms)
        
        # Rows
        r = header_row_idx + 1
        while r < len(rows):
            row = rows[r]
            next_row = rows[r+1] if r+1 < len(rows) else [None]*len(row)
            
            # Times
            for c_idx in [1, 13, 27, 42]:
                if c_idx < len(row) and row[c_idx]:
                    t = str(row[c_idx]).strip()
                    if t and t.lower() != 'time':
                        slots.add(t)
                        
            # Exam batches and subjects
            for c_idx, r_name in excel_rooms:
                b_val = row[c_idx] if c_idx < len(row) else None
                s_val = next_row[c_idx] if c_idx < len(next_row) else None
                
                if b_val:
                    b_str = str(b_val).strip()
                    if b_str and b_str.lower() not in ['none', 'date', 'time']:
                        doc_stats[name]['slots'] += 1
                        for bm in re.findall(r'(?:FA|SP)\d{2}-[A-Z0-9]+(?:-[A-Z0-9]+)*', b_str, re.I):
                            for sub in re.split(r'(?=(?:FA|SP)\d{2}-)', bm, flags=re.I):
                                sub_clean = re.sub(r'^[-/, ]+|[-/, ]+$', '', sub).strip().upper()
                                if sub_clean: batches.add(sub_clean)
                                
                if s_val:
                    s_str = str(s_val).strip()
                    if s_str and s_str.lower() not in ['none', 'date', 'time', 'exam']:
                        courses.add(s_str)
                        
            r += 2

    # -------------------------------------------------------------
    # GENERATE MASTER KNOWLEDGE ARTIFACT
    # -------------------------------------------------------------
    corpus_summary = {
        'total_departments': len(departments),
        'departments': sorted(departments),
        'total_instructors': len(instructors),
        'total_courses': len(courses),
        'total_locations': len(locations),
        'total_batches': len(batches),
        'total_slots': len(slots),
        'doc_stats': doc_stats
    }
    
    print("\n" + "=" * 80)
    print("MASTER UNIVERSITY CORPUS SUMMARY")
    print("=" * 80)
    print(f"Total Academic Departments: {len(departments)} -> {', '.join(sorted(departments))}")
    print(f"Total Unique Faculty / Instructors: {len(instructors)}")
    print(f"Total Unique Courses & Subjects:    {len(courses)}")
    print(f"Total Campus Venues, Rooms & Labs:  {len(locations)}")
    print(f"Total Unique Student Batches:       {len(batches)}")
    print(f"Total Time Slots / Periods:         {len(slots)}")
    
    # Save full structured json
    full_data = {
        'departments': sorted(departments),
        'instructors': sorted(instructors),
        'courses': sorted(courses),
        'locations': sorted(locations),
        'batches': sorted(batches),
        'slots': sorted(slots),
        'days': sorted(days),
        'doc_stats': doc_stats
    }
    
    with open("tools/master_university_corpus.json", "w", encoding="utf-8") as f:
        json.dump(full_data, f, indent=2)
    print("\nSaved full corpus dataset to: tools/master_university_corpus.json")

if __name__ == '__main__':
    build_master_corpus()
