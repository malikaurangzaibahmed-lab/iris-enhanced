import openpyxl
import os
import re

def split_combined_batches(raw):
    if not raw: return []
    s = str(raw).strip()
    if s == '' or s.lower() == 'none' or s.lower() == 'date' or s.lower() == 'time': return []
    
    # Check if contains standard batch pattern like FA24-BCS-A, SP23-FSN
    batch_matches = re.findall(r'(?:FA|SP)\d{2}-[A-Z0-9]+(?:-[A-Z0-9]+)*', s, re.I)
    if batch_matches:
        results = []
        for bm in batch_matches:
            # Split on secondary FA/SP if chained e.g. FA25-BME-FA24-BME-FA22-BEE
            sub = re.split(r'(?=(?:FA|SP)\d{2}-)', bm, flags=re.I)
            for b in sub:
                cleaned = re.sub(r'^[-/, ]+|[-/, ]+$', '', b).strip()
                if cleaned: results.append(cleaned)
        return results
    return [b.strip() for b in re.split(r'[/,]+', s) if b.strip()]

def clean_room_name(raw):
    if not raw: return ""
    r = str(raw).strip()
    r = re.sub(r'\s*\(\d+\)\s*', '', r)
    r = re.sub(r'\s*-\s*', '-', r)
    r = re.sub(r'\s+', '-', r)
    return r.strip()

def format_exam_time(raw):
    if not raw: return ""
    t = str(raw).strip()
    m = re.match(r'^(\d{2})(\d{2})\s*-\s*(\d{2})(\d{2})$', t)
    if m:
        sh, sm, eh, em = int(m.group(1)), m.group(2), int(m.group(3)), m.group(4)
        s_period = "AM" if 8 <= sh <= 11 else "PM"
        e_period = "AM" if 8 <= eh <= 11 else "PM"
        if sh in [1, 2, 3, 4, 5]: s_period = "PM"
        if eh in [1, 2, 3, 4, 5, 12]: e_period = "PM"
        return f"{sh:02d}:{sm} {s_period} - {eh:02d}:{em} {e_period}"
    return t

def parse_excel_quad(file_path):
    print("=" * 80)
    print(f"VERIFYING QUAD-MATRIX PARSER ON: {os.path.basename(file_path)}")
    print("=" * 80)
    
    wb = openpyxl.load_workbook(file_path, data_only=True)
    sheet = wb.active
    rows = list(sheet.iter_rows(values_only=True))
    
    header_row_idx = -1
    for r_idx in range(min(len(rows), 10)):
        row = rows[r_idx]
        dates = [c for c in row if c and str(c).strip().lower() == 'date']
        if len(dates) >= 2:
            header_row_idx = r_idx
            break
    if header_row_idx == -1: header_row_idx = 2
    
    header_row = rows[header_row_idx]
    
    blocks = []
    for c_idx, val in enumerate(header_row):
        if val and str(val).strip().lower() == 'date':
            blocks.append({
                'date_col': c_idx,
                'time_col': c_idx + 1,
                'start_col': c_idx + 2,
                'end_col': len(header_row)
            })
    for i in range(len(blocks)):
        if i + 1 < len(blocks):
            blocks[i]['end_col'] = blocks[i+1]['date_col']
            
    for idx, b in enumerate(blocks):
        rooms = []
        for c in range(b['start_col'], b['end_col']):
            if header_row[c]:
                rooms.append({'col_idx': c, 'name': clean_room_name(header_row[c])})
        b['rooms'] = rooms
        print(f"  Block {idx+1} (Cols {b['date_col']}..{b['end_col']-1}): {len(rooms)} rooms -> {[r['name'] for r in rooms[:4]]}")
        
    parsed_exams = []
    current_dates = [None] * len(blocks)
    
    r = header_row_idx + 1
    while r < len(rows):
        row = rows[r]
        next_row = rows[r + 1] if r + 1 < len(rows) else [None] * len(row)
        
        if not any(row) and not any(next_row):
            r += 1
            continue
            
        for b_idx, b in enumerate(blocks):
            raw_date = row[b['date_col']]
            raw_time = row[b['time_col']]
            
            date_str = str(raw_date).strip() if raw_date is not None else ""
            time_str = str(raw_time).strip() if raw_time is not None else ""
            
            if date_str and date_str.lower() != 'date':
                current_dates[b_idx] = date_str
                
            active_date = current_dates[b_idx] or current_dates[0] or "Unknown Date"
            active_time = format_exam_time(time_str)
            
            if not time_str or time_str.lower() == 'time':
                continue
                
            for room in b['rooms']:
                b_cell = row[room['col_idx']]
                s_cell = next_row[room['col_idx']]
                
                if b_cell is None: continue
                b_str = str(b_cell).strip()
                if not b_str or b_str.lower() in ['none', 'date', 'time']: continue
                
                s_str = str(s_cell).strip() if s_cell is not None else ""
                batches = split_combined_batches(b_str)
                if not batches: continue
                
                for batch in batches:
                    parsed_exams.append({
                        'date': active_date,
                        'time': active_time,
                        'room': room['name'],
                        'batch': batch,
                        'subject': s_str or "EXAM"
                    })
        r += 2
        
    print(f"\nExtracted {len(parsed_exams)} Individual Cohort Exam Slots!")
    batches_set = set(e['batch'] for e in parsed_exams)
    print(f"Total Unique Batches: {len(batches_set)} (e.g. {list(batches_set)[:6]})")
    print("Sample Output Records:")
    for item in parsed_exams[:4]:
        print(f"  {item}")

if __name__ == '__main__':
    parse_excel_quad("assets/documents/Date_Sheet_FINAL_Term_Exam_FALL_2025 - Version I - 08-12-25.xlsx")
    parse_excel_quad("assets/documents/Version I of Date Sheet Mid Term Exam SPRING 2026 25-03-2026.xlsx")
