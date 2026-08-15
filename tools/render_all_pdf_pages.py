import pdfplumber
import glob
from pathlib import Path

out_dir = Path("d:/Iris Working backup/MOST RECENT/IRIS/tools/pdf_visuals")
out_dir.mkdir(parents=True, exist_ok=True)

for pdf_path in sorted(glob.glob('assets/documents/*.pdf')):
    if 'iouiouj.pdf' in pdf_path: continue
    stem = Path(pdf_path).stem.replace(",", "_").replace(" ", "_")
    with pdfplumber.open(pdf_path) as pdf:
        # Render up to 2 pages for each PDF
        for p_idx in range(min(2, len(pdf.pages))):
            page = pdf.pages[p_idx]
            img = page.to_image(resolution=150)
            img_path = out_dir / f"{stem}_p{p_idx+1}.png"
            img.save(str(img_path))
            print(f"Rendered: {img_path.name}")
