import pdfplumber
from pathlib import Path
import re

pdf_path = Path(r"D:\Flutter\IRIS\assets\FSn,BTY,BCH,HND,RBS.pdf")

BATCH_WITH_INTAKE_RE = re.compile(r"([A-Z]{2}\d{2})-([A-Z]+)-(\d+)-([A-Z]\d+|[A-Z]+)")
BATCH_NO_INTAKE_RE = re.compile(r"^([A-Z]+)-(\d+)-([A-Z]\d+|[A-Z]+)$")

def parse_batch_test(text):
    """Test version of parse_batch to see what's happening"""
    print(f"  Input: {repr(text)}")
    cleaned = re.sub(r"\(.*?\)", "", text).strip().replace(" ", "")
    print(f"  Cleaned: {repr(cleaned)}")
    
    m = BATCH_WITH_INTAKE_RE.search(cleaned)
    if m:
        print(f"  Match BATCH_WITH_INTAKE_RE: {m.groups()}")
        return
    
    m = BATCH_NO_INTAKE_RE.search(cleaned)
    if m:
        print(f"  Match BATCH_NO_INTAKE_RE: {m.groups()}")
        return
    
    # Handle 2-part batch formats
    parts = [p for p in cleaned.split("-") if p]
    print(f"  Parts: {parts}")
    if len(parts) == 2 and re.match(r"^[A-Z]{2}\d{2}$", parts[0]):
        print(f"  → 2-part format detected")
        intake, program = parts
        if program in {"RBS", "RHND", "RMS", "PMS", "PCS", "RCS"}:
            print(f"  → Research program, will add -01")
        else:
            print(f"  → Regular program, will add -01")
    else:
        print(f"  → Fallback path")

print("Testing batch parsing on RBS entries from PDF:")
print()

with pdfplumber.open(pdf_path) as pdf:
    page = pdf.pages[1]  # Page 2
    tables = page.extract_tables()
    
    if tables:
        for row in tables[0][:10]:  # First 10 rows
            if row:
                for cell in row:
                    if cell and 'RBS' in cell:
                        lines = cell.split('\n')
                        if lines:
                            batch = lines[0].strip()
                            if 'RBS' in batch:
                                print(f"Found batch cell:")
                                parse_batch_test(batch)
                                print()
                                break
