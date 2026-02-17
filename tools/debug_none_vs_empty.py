"""Check if pdfplumber distinguishes merged cells (None) from empty cells ('')."""
import pdfplumber
import re
from pathlib import Path

PDF_PATH = Path(r"D:\Flutter\student_organizer\assets\CS (1).pdf")
TIME_RE = re.compile(r"(\d{1,2})[:.]?(\d{2})\s*-\s*(\d{1,2})[:.]?(\d{2})")
BATCH_RE = re.compile(r"(FA\d{2}|SP\d{2})-?(BCS|BSE|PCS|RCS)-(\d+)-([A-Z])")

# Check specific batches with known issues
targets = {"SP25-BCS-3-A", "FA22-BCS-8-A", "SP26-BCS-1-A", "FA23-BCS-6-A", "FA25-BCS-2-C"}

with pdfplumber.open(PDF_PATH) as pdf:
    for page in pdf.pages:
        tables = page.extract_tables()
        if not tables:
            continue
        for table in tables:
            # Find header
            header_idx = None
            time_cols = {}
            for idx, row in enumerate(table):
                if not row:
                    continue
                found = False
                for ci, cell in enumerate(row):
                    if cell and TIME_RE.search(cell):
                        found = True
                        m = TIME_RE.search(cell)
                        if m:
                            time_cols[ci] = f"{int(m.group(1))}:{m.group(2)}-{int(m.group(3))}:{m.group(4)}"
                if found:
                    header_idx = idx
                    break
            if header_idx is None:
                continue

            for row in table[header_idx + 1:]:
                if not row or not row[0]:
                    continue
                cell0 = (row[0] or "").replace(" ", "").replace("\n", "")
                m = BATCH_RE.search(cell0)
                if not m:
                    continue
                batch = f"{m.group(1)}-{m.group(2)}-{m.group(3)}-{m.group(4)}"
                if batch not in targets:
                    continue

                print(f"\nPage {page.page_number} | {batch}")
                for ci in range(len(row)):
                    cell = row[ci]
                    time_label = time_cols.get(ci, "---")
                    if cell is None:
                        cell_type = "None"
                    elif cell.strip() == "":
                        cell_type = "empty-str"
                    elif "Break" in cell or "Prayer" in cell:
                        cell_type = "BREAK"
                    else:
                        preview = cell.replace("\n", "|")[:50]
                        cell_type = f"content: {preview!r}"
                    print(f"  col[{ci}] ({time_label:>15}) → {cell_type}")
