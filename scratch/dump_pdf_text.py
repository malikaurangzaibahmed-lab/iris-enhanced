import pdfplumber
from pathlib import Path

pdf_path = Path("assets/CE-1.pdf")
with pdfplumber.open(pdf_path) as pdf:
    print(f"Total pages: {len(pdf.pages)}")
    first_page = pdf.pages[0]
    print("--- RAW TEXT ---")
    print(first_page.extract_text()[:2000])
    
    print("\n--- TABLES ---")
    tables = first_page.extract_tables()
    print(f"Found {len(tables)} tables")
    if tables:
        for idx, row in enumerate(tables[0][:5]):
            print(f"Row {idx}: {row[:6]}")
