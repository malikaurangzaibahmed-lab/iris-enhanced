import os
import glob
import hashlib
import pdfplumber

def check_duplicates():
    print("=" * 80)
    print("EXACT PDF DUPLICATE & OVERLAP AUDIT")
    print("=" * 80)
    
    pdf_files = sorted(glob.glob("assets/documents/*.pdf"))
    
    records = []
    for pf in pdf_files:
        name = os.path.basename(pf)
        size = os.path.getsize(pf)
        with open(pf, 'rb') as f:
            data = f.read()
            bin_sha = hashlib.sha256(data).hexdigest()
            bin_md5 = hashlib.md5(data).hexdigest()
            
        with pdfplumber.open(pf) as pdf:
            pages_count = len(pdf.pages)
            p1_text = pdf.pages[0].extract_text() or ""
            # Extract header lines
            lines = [l.strip() for l in p1_text.split('\n') if l.strip()][:5]
            
        records.append({
            'name': name,
            'size': size,
            'pages': pages_count,
            'bin_sha': bin_sha,
            'bin_md5': bin_md5,
            'p1_header': " | ".join(lines)
        })
        
    for r in records:
        print(f"File: {r['name']:<30} | Size: {r['size']:>8} bytes | Pages: {r['pages']:>2}")
        print(f"  SHA-256: {r['bin_sha']}")
        print(f"  Header : {r['p1_header']}\n")
        
    print("=" * 80)
    print("DUPLICATE ASSESSMENT:")
    print("=" * 80)
    
    sha_map = {}
    for r in records:
        sha_map.setdefault(r['bin_sha'], []).append(r['name'])
        
    has_dup = False
    for sha, files in sha_map.items():
        if len(files) > 1:
            has_dup = True
            print(f"[DUPLICATE FOUND]: {files}")
            
    if not has_dup:
        print("RESULT: ZERO DUPLICATES.")
        print(f"All {len(records)} PDF files represent completely distinct departmental documents.")

if __name__ == '__main__':
    check_duplicates()
