"""Debug: show what text and tables pdfplumber sees on each page of the CS PDF."""
import pdfplumber
import re

PDF_PATH = r"D:\Flutter\student_organizer\assets\CS (1).pdf"

with pdfplumber.open(PDF_PATH) as pdf:
    print(f"Total pages: {len(pdf.pages)}")
    for i, page in enumerate(pdf.pages):
        text = page.extract_text() or ""
        first_200 = text[:200].replace("\n", "  |  ")
        tables = page.extract_tables()
        
        # Find day mentions
        day_match = re.search(
            r"\b(Mon|Monday|Tue|Tues|Tuesday|Wed|Wednesday|Thu|Thur|Thurs|Thursday|Fri|Friday|Sat|Saturday)\b",
            text, re.IGNORECASE
        )
        
        print(f"\n{'='*70}")
        print(f"PAGE {i+1}")
        print(f"  Text length: {len(text)} chars")
        print(f"  Day found: {day_match.group(0) if day_match else 'NONE'}")
        print(f"  Tables: {len(tables)}")
        if tables:
            for ti, table in enumerate(tables):
                print(f"  Table {ti}: {len(table)} rows x {len(table[0]) if table else 0} cols")
                if table and table[0]:
                    print(f"    Header cells: {[c[:30] if c else 'None' for c in table[0][:4]]}")
                if len(table) > 1 and table[1]:
                    print(f"    Row 1 cells:  {[c[:30] if c else 'None' for c in table[1][:4]]}")
        print(f"  First 200 chars: {first_200}")
