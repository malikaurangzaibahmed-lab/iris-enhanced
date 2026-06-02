import pdfplumber
from pathlib import Path

# Check different PDFs for the Unknown patterns
pdfs = [
    (Path(r"D:\Flutter\student_organizer\assets\HUM-1.pdf"), "BEN"),  # English dept
    (Path(r"D:\Flutter\student_organizer\assets\ME-1.pdf"), "BSME"),  # Mechanical
    (Path(r"D:\Flutter\student_organizer\assets\MS-2.pdf"), "BBA"),   # Business
]

for pdf_path, dept in pdfs:
    if not pdf_path.exists():
        continue
    
    print(f"\n=== Checking {pdf_path.name} ({dept}) ===")
    
    with pdfplumber.open(pdf_path) as pdf:
        for page_num, page in enumerate(pdf.pages[:3], 1):
            tables = page.extract_tables()
            if not tables:
                continue
            
            for table in tables:
                for row in table:
                    if not row:
                        continue
                    
                    # Look for cells with complex patterns
                    for cell in row:
                        if not cell:
                            continue
                        
                        # Check for specific patterns we saw
                        if any(pattern in cell for pattern in ['Stylstcs', 'Drama', 'Power Plants', 'IC Engines', 'Governance', 'Cell Biology']):
                            print(f"\nPage {page_num} - Found cell:")
                            lines = cell.split('\n')
                            for i, line in enumerate(lines):
                                print(f"  Line {i}: {repr(line)}")
                            break
