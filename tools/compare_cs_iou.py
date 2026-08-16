import pdfplumber

def compare_cs_and_iouiouj():
    f1 = "assets/documents/CS-12-1.pdf"
    f2 = "assets/documents/iouiouj.pdf"
    
    with pdfplumber.open(f1) as pdf1, pdfplumber.open(f2) as pdf2:
        diff_count = 0
        print(f"Comparing CS-12-1.pdf ({len(pdf1.pages)} pages) vs iouiouj.pdf ({len(pdf2.pages)} pages):\n")
        
        for i in range(len(pdf1.pages)):
            t1 = pdf1.pages[i].extract_text() or ""
            t2 = pdf2.pages[i].extract_text() or ""
            
            c1 = "".join(t1.split())
            c2 = "".join(t2.split())
            
            if c1 != c2:
                diff_count += 1
                print(f"Page {i+1} differs:")
                print(f"  CS-12-1:  {t1[:100]}...")
                print(f"  iouiouj:  {t2[:100]}...\n")
                
        print(f"Total Pages with Differences: {diff_count} / {len(pdf1.pages)}")

if __name__ == '__main__':
    compare_cs_and_iouiouj()
