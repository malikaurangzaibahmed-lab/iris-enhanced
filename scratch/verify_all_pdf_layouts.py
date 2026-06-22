import pdfplumber
import re
from pathlib import Path

pdf_files = [
    Path("assets/CE-1.pdf"),
    Path("assets/CS-12-1.pdf"),
    Path("assets/EE.pdf"),
    Path("assets/FSn,BTY,BCH,HND,RBS.pdf"),
    Path("assets/HUM-1.pdf"),
    Path("assets/ME-1.pdf"),
    Path("assets/MS-2.pdf"),
]

for pdf_path in pdf_files:
    if not pdf_path.exists():
        continue
    with pdfplumber.open(pdf_path) as pdf:
        page = pdf.pages[0]
        words = page.extract_words()
        # Find time words
        time_words = [w for w in words if re.search(r"\b\d{1,2}:\d{2}\b", w["text"])]
        
        # Group time words by line
        time_lines = {}
        for tw in time_words:
            top_rounded = round(tw["top"] / 5) * 5
            time_lines.setdefault(top_rounded, []).append(tw)
            
        header_top = max(time_lines.keys(), key=lambda k: len(time_lines[k]))
        header_words = sorted(time_lines[header_top], key=lambda w: w["x0"])
        
        print(f"File: {pdf_path.name}")
        print(f"  Time words: {' '.join(hw['text'] for hw in header_words)}")
        # Print x0 ranges
        print(f"  Coordinates: {', '.join(f'{hw.get(chr(120)+str(0)):.1f}' for hw in header_words)}")
