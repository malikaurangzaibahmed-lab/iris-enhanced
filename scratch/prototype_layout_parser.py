import pdfplumber
import re
from pathlib import Path

# Match batch formats in Column 0
BATCH_RE = re.compile(r"\b[A-Z]{2}\d{2}-[A-Z0-9]+", re.IGNORECASE)

pdf_path = Path("assets/CS-12-1.pdf")
with pdfplumber.open(pdf_path) as pdf:
    page = pdf.pages[0]
    words = page.extract_words()
    
    # Let's find all time headers to define columns
    # In pdfplumber, top is y (starts at 0 at the top, increases downwards)
    # Let's find words that represent times: e.g. "8:00", "9:00", etc.
    time_words = []
    for w in words:
        if re.search(r"\b\d{1,2}:\d{2}\b", w["text"]):
            time_words.append(w)
            
    print(f"Found {len(time_words)} time words.")
    # Group time words that are on the same line (top within 3px)
    time_lines = {}
    for tw in time_words:
        top_rounded = round(tw["top"] / 5) * 5
        time_lines.setdefault(top_rounded, []).append(tw)
        
    # The header line will have the most time words
    header_top = max(time_lines.keys(), key=lambda k: len(time_lines[k]))
    header_words = sorted(time_lines[header_top], key=lambda w: w["x0"])
    
    # We want to identify the columns
    # Let's merge consecutive words that form a range (like "8:00", "-", "9:00")
    # Actually, we can just look at the distinct slots. Let's look at the x0 coordinates of the time words.
    # Let's print them
    print("Header time words:")
    for hw in header_words:
        print(f"  {hw['text']} at x={hw['x0']:.1f}")
        
    # Let's define the column centers based on the time header words
    # Column 0: x0 < 100 (for Batch names)
    # The other columns will be centered around the time slots.
    # In CE-1.pdf, we saw:
    # 8:00 - 9:00 at x ~ 146
    # 9:00 - 10:00 at x ~ 261
    # 10:00 - 11:00 at x ~ 376
    # 11:00 - 12:00 at x ~ 491
    # 12:00 - 1:00 at x ~ 607 (Break)
    # 1:00 - 2:00 at x ~ 722
    # Let's define column bounds:
    col_bounds = [
        (0, 100),       # Col 0 (Batch)
        (100, 204),     # Col 1 (8:00 - 9:00)
        (204, 319),     # Col 2 (9:00 - 10:00)
        (319, 434),     # Col 3 (10:00 - 11:00)
        (434, 549),     # Col 4 (11:00 - 12:00)
        (549, 664),     # Col 5 (12:00 - 1:00)
        (664, 780),     # Col 6 (1:00 - 2:00)
    ]
    
    # Find batch rows in Column 0
    # A batch row start is a word in Column 0 matching BATCH_RE
    row_starts = []
    for w in words:
        if w["x0"] < 100 and BATCH_RE.search(w["text"]):
            row_starts.append(w)
            
    # Sort row starts by top coordinate (top to bottom)
    row_starts.sort(key=lambda r: r["top"])
    
    print("\nDetected Rows:")
    for idx, rs in enumerate(row_starts):
        print(f"  Row {idx}: {rs['text']} at top={rs['top']:.1f}")
        
    # Group all words on the page into these rows
    # A word at coordinate 'top' belongs to Row i if:
    # row_starts[i]['top'] - 5 <= top < row_starts[i+1]['top'] - 5 (or bottom of page)
    reconstructed_rows = {i: {c: [] for c in range(len(col_bounds))} for i in range(len(row_starts))}
    
    for w in words:
        # Skip header words (top < row_starts[0]['top'] - 10)
        if w["top"] < row_starts[0]["top"] - 10:
            continue
            
        # Find which row it belongs to
        target_row_idx = -1
        for i in range(len(row_starts)):
            start_top = row_starts[i]["top"] - 8
            end_top = row_starts[i+1]["top"] - 8 if i + 1 < len(row_starts) else 9999
            if start_top <= w["top"] < end_top:
                target_row_idx = i
                break
                
        if target_row_idx == -1:
            continue
            
        # Find which column it belongs to
        target_col_idx = -1
        center_x = (w["x0"] + w["x1"]) / 2
        for col_idx, (x_min, x_max) in enumerate(col_bounds):
            if x_min <= center_x < x_max:
                target_col_idx = col_idx
                break
                
        if target_col_idx != -1:
            reconstructed_rows[target_row_idx][target_col_idx].append(w)
            
    # Print the reconstructed cells!
    print("\nReconstructed Cells:")
    for r_idx in range(len(row_starts)):
        batch_words = reconstructed_rows[r_idx][0]
        batch_text = " ".join(w["text"] for w in sorted(batch_words, key=lambda w: (w["top"], w["x0"])))
        print(f"\nRow {r_idx} Batch: {batch_text}")
        for c_idx in range(1, len(col_bounds)):
            cell_words = reconstructed_rows[r_idx][c_idx]
            # Group words that are on the same line (top within 3px)
            lines = {}
            for cw in cell_words:
                top_rounded = round(cw["top"] / 3) * 3
                lines.setdefault(top_rounded, []).append(cw)
            # Sort lines by top coordinate
            sorted_lines = []
            for t in sorted(lines.keys()):
                line_words = sorted(lines[t], key=lambda w: w["x0"])
                sorted_lines.append(" ".join(w["text"] for w in line_words))
            cell_text = " \\n ".join(sorted_lines)
            if cell_text:
                print(f"  Col {c_idx} ({col_bounds[c_idx]}): {cell_text}")
