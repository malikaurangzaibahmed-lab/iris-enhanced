import pdfplumber
import glob
from pathlib import Path

out_dir = Path("d:/Iris Working backup/MOST RECENT/IRIS/tools/pdf_visuals")
out_dir.mkdir(parents=True, exist_ok=True)

for pdf_path in sorted(glob.glob('assets/documents/*.pdf')):
    if 'iouiouj.pdf' in pdf_path: continue
    stem = Path(pdf_path).stem.replace(",", "_").replace(" ", "_")
    with pdfplumber.open(pdf_path) as pdf:
        # Render page 1
        page = pdf.pages[0]
        img = page.to_image(resolution=150)
        img_path = out_dir / f"{stem}_page1.png"
        img.save(str(img_path))
        print(f"Saved visual: {img_path}")
