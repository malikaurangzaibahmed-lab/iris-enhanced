import os
import glob
import re
import openpyxl
import pdfplumber

def deep_audit():
    print("================================================================================")
    print("DETAILED SYSTEMATIC STUDY: PARSER SHORTCOMINGS & EDGE CASES")
    print("================================================================================")
    
    # 1. Study Excel Date Sheet Parser Shortcomings
    print("\n--- [PART 1: EXCEL DATE SHEETS SHORTCOMINGS] ---")
    excel_files = glob.glob('assets/**/*.xlsx', recursive=True)
    
    for ef in excel_files:
        fname = os.path.basename(ef)
        wb = openpyxl.load_workbook(ef, data_only=True)
        sheet = wb.active
        rows = list(sheet.iter_rows(values_only=True))
        
        # Check room headers in row 3
        room_row = rows[2] # 0-indexed row 2 is row 3
        # Look for multi-block pattern
        date_cols = [idx for idx, val in enumerate(room_row) if val and str(val).strip().lower() == 'date']
        time_cols = [idx for idx, val in enumerate(room_row) if val and str(val).strip().lower() == 'time']
        
        print(f"\nFile: {fname}")
        print(f"  Total Rows: {len(rows)}, Total Cols: {len(room_row)}")
        print(f"  Parallel Date/Time Blocks detected: {len(date_cols)} (at col indices: {date_cols})")
        
        # Check multi-batch compound tokens in exam cells
        compound_batches = []
        slash_batches = []
        comma_batches = []
        unrecognized_batches = []
        
        for r_idx in range(3, len(rows)):
            row = rows[r_idx]
            for c_idx, val in enumerate(row):
                if c_idx in date_cols or c_idx in time_cols or val is None:
                    continue
                sval = str(val).strip()
                if not sval or sval.lower() == 'none': continue
                
                # Check for hyphen-connected compound batches e.g. "FA25-BME-FA24-BME-FA22-BEE"
                if re.search(r'(?:FA|SP)\d{2}-[A-Z]{2,4}-(?:FA|SP)\d{2}-[A-Z]{2,4}', sval):
                    compound_batches.append(sval)
                elif '/' in sval:
                    slash_batches.append(sval)
                elif ',' in sval:
                    comma_batches.append(sval)
                elif not re.match(r'^(?:FA|SP)\d{2}-[A-Z0-9]+', sval, re.I):
                    unrecognized_batches.append(sval)
                    
        print(f"  Compound Hyphenated Batches (e.g. FA25-BME-FA24-BME): {len(compound_batches)} occurrences")
        print(f"    Samples: {compound_batches[:5]}")
        print(f"  Slash Separated Batches (e.g. FA24-BCS-A / BSE-A): {len(slash_batches)} occurrences")
        print(f"    Samples: {slash_batches[:5]}")
        print(f"  Comma Separated Batches (e.g. FA24-BCS-A, B): {len(comma_batches)} occurrences")
        print(f"    Samples: {comma_batches[:5]}")
        print(f"  Unrecognized / Special Tokens: {len(unrecognized_batches)} occurrences")
        print(f"    Samples: {unrecognized_batches[:5]}")

    # 2. Study PDF Timetable Parser Shortcomings
    print("\n\n--- [PART 2: PDF TIMETABLES SHORTCOMINGS] ---")
    pdf_files = glob.glob('assets/**/*.pdf', recursive=True)
    
    for pf in pdf_files:
        fname = os.path.basename(pf)
        print(f"\nFile: {fname}")
        with pdfplumber.open(pf) as pdf:
            print(f"  Pages: {len(pdf.pages)}")
            
            # Check slot header structure
            p1 = pdf.pages[0]
            words = p1.extract_words()
            p1_text = p1.extract_text()
            
            # Find times in header
            time_matches = re.findall(r'\b\d{1,2}[:.]\d{2}\s*-\s*\d{1,2}[:.]\d{2}\b', p1_text)
            print(f"  Header Time Slots Detected: {time_matches[:6]}")
            
            # Check days distribution
            day_counts = {}
            for day in ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday']:
                matches = re.findall(r'\b' + day + r'\b', p1_text, re.I)
                if matches: day_counts[day] = len(matches)
            print(f"  Days Mentioned on Page 1: {day_counts}")

            # Check special cases in all pages:
            single_line_cells = []
            orphan_teachers = []
            fused_room_subject = []
            course_codes = set()
            
            for p_idx, page in enumerate(pdf.pages):
                tables = page.extract_tables()
                for table in tables:
                    for r_idx, row in enumerate(table):
                        if r_idx == 0: continue
                        for c_idx, cell in enumerate(row):
                            if c_idx == 0 or not cell: continue
                            lines = [l.strip() for l in cell.split("\n") if l.strip()]
                            
                            # Check single line cells that are not breaks
                            if len(lines) == 1 and not re.search(r'\b(break|prayer|fehm|kaerb)\b', lines[0], re.I):
                                single_line_cells.append((p_idx+1, lines[0]))
                                
                            # Check fused room in subject lines
                            for l in lines:
                                if re.search(r'\b[A-D]\d(?:\.\d)?\s*\(\d+\)', l) and not re.match(r'^[A-D]\d(?:\.\d)?\s*\(\d+\)$', l):
                                    fused_room_subject.append((p_idx+1, l))
                                    
                            # Check course codes
                            for l in lines:
                                codes = re.findall(r'\b[A-Z]{2,4}\d{3}[A-Z]?\b', l)
                                for c in codes: course_codes.add(c)
                                
            print(f"  Single-line Content Cells (Potential missing instructor/room): {len(single_line_cells)}")
            if single_line_cells:
                print(f"    Samples: {single_line_cells[:4]}")
            print(f"  Fused Room in Subject Line: {len(fused_room_subject)}")
            if fused_room_subject:
                print(f"    Samples: {fused_room_subject[:4]}")
            print(f"  Sample Extracted Course Codes ({len(course_codes)}): {list(course_codes)[:6]}")

if __name__ == '__main__':
    deep_audit()
