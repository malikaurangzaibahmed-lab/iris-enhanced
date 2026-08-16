import os
import glob
import re
import json
import openpyxl

def split_combined_batches(raw):
    if not raw: return []
    s = str(raw).strip()
    if s == '' or s.lower() in ['none', 'date', 'time']: return []
    
    batch_matches = re.findall(r'(?:FA|SP)\d{2}-[A-Z0-9]+(?:-[A-Z0-9]+)*', s, re.I)
    if batch_matches:
        results = []
        for bm in batch_matches:
            sub = re.split(r'(?=(?:FA|SP)\d{2}-)', bm, flags=re.I)
            for b in sub:
                cleaned = re.sub(r'^[-/, ]+|[-/, ]+$', '', b).strip().upper()
                if cleaned: results.append(cleaned)
        return results
    return [b.strip().upper() for b in re.split(r'[/,]+', s) if b.strip()]

def clean_room_name(raw):
    if not raw: return ""
    r = str(raw).strip()
    r = re.sub(r'\s*\(\d+\)\s*', '', r)
    r = re.sub(r'\s*-\s*', '-', r)
    r = re.sub(r'\s+', '-', r)
    return r.strip()

def study_excel_files():
    print("=" * 80)
    print("DEEP CORPUS STUDY: ALL EXCEL EXAM DATE SHEETS")
    print("=" * 80)
    
    excel_files = [f for f in sorted(glob.glob("assets/documents/*.xlsx")) if not os.path.basename(f).startswith('~$')]
    
    excel_corpus = {}
    
    for ef in excel_files:
        name = os.path.basename(ef)
        print(f"\nAnalyzing Excel: {name}...")
        
        wb = openpyxl.load_workbook(ef, data_only=True)
        ws = wb.active
        rows = list(ws.iter_rows(values_only=True))
        
        # Header row
        header_row_idx = 2
        for r_idx in range(min(len(rows), 10)):
            dates = [c for c in rows[r_idx] if c and str(c).strip().lower() == 'date']
            if len(dates) >= 2:
                header_row_idx = r_idx
                break
                
        header_row = rows[header_row_idx]
        
        # 4 Building blocks
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
                
        block_names = ["Building A & Workshop", "Building B (Management)", "Building C (CS)", "Building D (Mech/Civil)"]
        all_venues = []
        for idx, b in enumerate(blocks):
            b_name = block_names[idx] if idx < len(block_names) else f"Block {idx+1}"
            b['name'] = b_name
            rooms = []
            for c in range(b['start_col'], b['end_col']):
                if header_row[c]:
                    r_clean = clean_room_name(header_row[c])
                    rooms.append({'col': c, 'name': r_clean})
                    all_venues.append(r_clean)
            b['rooms'] = rooms
            
        dates_found = set()
        slots_found = set()
        batches_found = set()
        courses_found = set()
        records = []
        
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
                    dates_found.add(date_str)
                    
                active_date = current_dates[b_idx] or current_dates[0] or "Unknown Date"
                if not time_str or time_str.lower() == 'time':
                    continue
                    
                slots_found.add(time_str)
                
                for room in b['rooms']:
                    b_cell = row[room['col']]
                    s_cell = next_row[room['col']]
                    
                    if b_cell is None: continue
                    b_str = str(b_cell).strip()
                    if not b_str or b_str.lower() in ['none', 'date', 'time']: continue
                    
                    s_str = str(s_cell).strip() if s_cell is not None else ""
                    if s_str and s_str.lower() not in ['none', 'date', 'time', 'exam']:
                        courses_found.add(s_str)
                        
                    batch_list = split_combined_batches(b_str)
                    for b_item in batch_list:
                        batches_found.add(b_item)
                        records.append({
                            'date': active_date,
                            'time': time_str,
                            'room': room['name'],
                            'building': b['name'],
                            'batch': b_item,
                            'subject': s_str
                        })
            r += 2
            
        excel_corpus[name] = {
            'total_records': len(records),
            'unique_exam_dates_count': len(dates_found),
            'unique_exam_dates': sorted(dates_found),
            'unique_exam_slots_count': len(slots_found),
            'unique_exam_slots': sorted(slots_found),
            'total_venues_count': len(all_venues),
            'venues_by_building': {b['name']: [rm['name'] for rm in b['rooms']] for b in blocks},
            'unique_batches_count': len(batches_found),
            'sample_batches': sorted(batches_found)[:20],
            'unique_courses_count': len(courses_found),
            'sample_courses': sorted(courses_found)[:20],
            'records': records
        }
        
        print(f"  -> Extracted {len(records)} Total Exam Records")
        print(f"  -> Exam Dates ({len(dates_found)}): {', '.join(sorted(dates_found)[:4])}...")
        print(f"  -> Exam Slots ({len(slots_found)}): {', '.join(sorted(slots_found))}")
        print(f"  -> Campus Venues ({len(all_venues)}): across 4 buildings")
        print(f"  -> Student Cohorts ({len(batches_found)} unique batches)")
        print(f"  -> Course Exams ({len(courses_found)} unique courses)")
        
    with open("tools/excel_date_sheet_corpus.json", "w", encoding="utf-8") as f:
        # Save summary without full records array for readability
        summary = {k: {sk: v[sk] for sk in v if sk != 'records'} for k, v in excel_corpus.items()}
        json.dump(summary, f, indent=2)
        
    print("\n" + "=" * 80)
    print("SAVED FULL EXCEL CORPUS TO: tools/excel_date_sheet_corpus.json")
    print("=" * 80)

if __name__ == '__main__':
    study_excel_files()
