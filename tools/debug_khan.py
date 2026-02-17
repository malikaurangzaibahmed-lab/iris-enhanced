"""Debug raw PDF cells that produce 'Khan' or 'Yousaf' prefix in subjects."""
import pdfplumber
import re
from pathlib import Path

PDF_PATH = Path(r"D:\Flutter\student_organizer\assets\CS (1).pdf")
BATCH_RE = re.compile(r"(FA\d{2}|SP\d{2})-?(BCS|BSE|PCS|RCS)-(\d+)-([A-Z])")

targets = {
    "FA22-BCS-8-A",
    "FA23-BCS-6-D",
    "FA23-BSE-6-B",
    "FA25-BSE-2-A",
}

with pdfplumber.open(PDF_PATH) as pdf:
    for page in pdf.pages:
        tables = page.extract_tables()
        if not tables:
            continue
        for table in tables:
            for row in table:
                if not row or not row[0]:
                    continue
                cell0 = row[0].replace(" ", "").replace("\n", "")
                m = BATCH_RE.search(cell0)
                if not m:
                    continue
                batch = f"{m.group(1)}-{m.group(2)}-{m.group(3)}-{m.group(4)}"
                if batch not in targets:
                    continue
                print(f"\n{'='*60}")
                print(f"BATCH: {batch}  (page {page.page_number})")
                print(f"{'='*60}")
                for col_idx, cell in enumerate(row):
                    if cell and cell.strip():
                        print(f"\n  [col {col_idx}] raw lines:")
                        for line in cell.split("\n"):
                            print(f"    | {line!r}")
