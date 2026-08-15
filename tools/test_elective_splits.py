import pdfplumber
import re

TIME_RANGE_RE = re.compile(r"(\d{1,2})[:.]?(\d{2})\s*-\s*(\d{1,2})[:.]?(\d{2})")

with pdfplumber.open('assets/documents/MS-2.pdf') as pdf:
    page = pdf.pages[0]
    tables = page.extract_tables()
    for table in tables:
        for row in table:
            if not row or not row[0]: continue
            batch = row[0].strip()
            if 'BBA-B34' in batch or 'BBA-B33' in batch:
                print(f"\nBatch: {batch}")
                for idx, cell in enumerate(row[1:]):
                    if cell and cell.strip():
                        print(f"  Slot {idx+1}:")
                        for l in cell.strip().split('\n'):
                            print(f"    {l}")
