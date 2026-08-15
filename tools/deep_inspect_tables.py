import pdfplumber
import glob
import re

for pdf_path in sorted(glob.glob('assets/documents/*.pdf')):
    if 'iouiouj.pdf' in pdf_path: continue
    print(f"\n==================== {pdf_path} ====================")
    with pdfplumber.open(pdf_path) as pdf:
        for p_idx, page in enumerate(pdf.pages):
            tables = page.extract_tables()
            print(f"Page {p_idx+1}: {len(tables)} tables")
            for t_idx, table in enumerate(tables):
                for row_idx, row in enumerate(table[:10]):
                    clean_row = [re.sub(r'\s+', ' ', str(c or '')).strip() for c in row]
                    if any(clean_row):
                        print(f"  Row {row_idx}: {clean_row[:7]}")
