import pdfplumber
from pathlib import Path

pdf_path = Path(r"D:\Flutter\IRIS\assets\MS-2.pdf")

with pdfplumber.open(pdf_path) as pdf:
    page = pdf.pages[0]  # Check first page
    tables = page.extract_tables()
    
    if tables:
        for row_idx, row in enumerate(tables[0][:15]):  # First 15 rows
            if row and any('Saqib' in str(cell) for cell in row if cell):
                print(f"Row {row_idx}: {row}")
                for col_idx, cell in enumerate(row):
                    if cell and 'Saqib' in cell:
                        print(f"\nCell [{row_idx},{col_idx}] content:")
                        print(f"Raw: {repr(cell)}")
                        print(f"Lines: {cell.split(chr(10))}")
