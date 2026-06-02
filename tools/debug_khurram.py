import pdfplumber
from pathlib import Path

pdf_path = Path(r"D:\Flutter\IRIS\assets\MS-2.pdf")

with pdfplumber.open(pdf_path) as pdf:
    for page in pdf.pages[:5]:  # Check first 5 pages
        tables = page.extract_tables()
        
        if tables:
            for table in tables:
                for row_idx, row in enumerate(table):
                    if row and any('Khurram' in str(cell) for cell in row if cell):
                        print(f"Found Khurram in row:")
                        for col_idx, cell in enumerate(row):
                            if cell and 'Khurram' in cell:
                                print(f"\nCell content:")
                                print(f"Raw: {repr(cell)}")
                                print(f"Lines:")
                                for i, line in enumerate(cell.split('\n')):
                                    print(f"  {i}: {repr(line)}")
