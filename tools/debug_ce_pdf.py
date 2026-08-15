import pdfplumber

with pdfplumber.open('assets/documents/CE-1.pdf') as pdf:
    for p_idx, page in enumerate(pdf.pages):
        print(f"=== Page {p_idx+1} ===")
        words = page.extract_words()
        for w in words[:40]:
            print(f"{w['text']:<30} x0={w['x0']:<6.1f} x1={w['x1']:<6.1f} top={w['top']:<6.1f}")
