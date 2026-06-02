import pdfplumber
from pathlib import Path

pdf_path = Path(r"D:\Flutter\IRIS\assets\FSn,BTY,BCH,HND,RBS.pdf")

print("Searching for RBS and RHND batch codes in PDF...")
print()

with pdfplumber.open(pdf_path) as pdf:
    for page_num, page in enumerate(pdf.pages, 1):
        text = page.extract_text() or ""
        tables = page.extract_tables()
        
        if tables:
            for table in tables:
                for row in table:
                    if row:
                        row_text = ' '.join([str(cell) for cell in row if cell])
                        if 'RBS' in row_text or 'RHND' in row_text:
                            # Find cells with RBS/RHND
                            for cell in row:
                                if cell and ('RBS' in cell or 'RHND' in cell):
                                    lines = cell.split('\n')
                                    # First line is usually the batch code
                                    if lines:
                                        batch_line = lines[0].strip()
                                        if 'RBS' in batch_line or 'RHND' in batch_line:
                                            print(f"Page {page_num}: {batch_line}")
                                            break
