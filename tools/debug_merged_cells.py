"""Check how pdfplumber handles merged cells for labs in the PDF."""
import pdfplumber
import re
from pathlib import Path

PDF_PATH = Path(r"D:\Flutter\student_organizer\assets\CS (1).pdf")
TIME_RE = re.compile(r"(\d{1,2})[:.]?(\d{2})\s*-\s*(\d{1,2})[:.]?(\d{2})")
BATCH_RE = re.compile(r"(FA\d{2}|SP\d{2})-?(BCS|BSE|PCS|RCS)-(\d+)-([A-Z])")

# Check specific batches that have the problem
targets = {"FA22-BCS-8-A", "FA23-BCS-6-A", "SP25-BCS-3-A", "SP24-BCS-4-A"}

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

                # Show ALL cells in this row
                has_lab = any("Lab" in (row[ci] or "") for ci in range(len(row)))
                if not has_lab:
                    continue

                print(f"\nPage {page.page_number} | {batch}")
                print(f"  Time header: {time_cols}")
                for ci in range(len(row)):
                    cell = row[ci]
                    time_label = time_cols.get(ci, "???")
                    if cell and cell.strip():
                        preview = cell.replace("\n", " | ")[:60]
                        print(f"  col[{ci}] ({time_label:>15}): {preview!r}")
                    else:
                        print(f"  col[{ci}] ({time_label:>15}): <EMPTY>")
