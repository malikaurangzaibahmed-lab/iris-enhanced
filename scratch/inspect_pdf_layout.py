import pdfplumber
from pathlib import Path

pdf_path = Path("assets/CE-1.pdf")
with pdfplumber.open(pdf_path) as pdf:
    page = pdf.pages[0]
    # Print words with their x0, y0
    print("Words in page 1:")
    for obj in page.extract_words()[:50]:
        print(f"Text: {obj['text']:<25} | x0: {obj['x0']:<6.1f} | x1: {obj['x1']:<6.1f} | top: {obj['top']:<6.1f} | bottom: {obj['bottom']:<6.1f}")
