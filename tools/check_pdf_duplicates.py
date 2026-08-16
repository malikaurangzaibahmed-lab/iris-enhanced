import os
import glob
import hashlib
import pdfplumber

def check_pdf_duplicates():
    print("=" * 80)
    print("CHECKING FOR DUPLICATE PDFS IN ASSETS/DOCUMENTS")
    print("=" * 80)
    
    pdf_files = sorted(glob.glob("assets/documents/*.pdf"))
    
    file_info = []
    
    for pf in pdf_files:
        name = os.path.basename(pf)
        size = os.path.getsize(pf)
        
        # 1. Binary SHA-256
        with open(pf, 'rb') as f:
            raw_bytes = f.read()
            sha256_binary = hashlib.sha256(raw_bytes).hexdigest()
            md5_binary = hashlib.md5(raw_bytes).hexdigest()
            
        # 2. Text content & page count
        with pdfplumber.open(pf) as pdf:
            pages = len(pdf.pages)
            full_text = ""
            for p in pdf.pages:
                txt = p.extract_text() or ""
                full_text += txt + "\n---PAGE---\n"
                
            text_cleaned = "".join(full_text.split())
            text_sha256 = hashlib.sha256(text_cleaned.encode('utf-8')).hexdigest()
            
        file_info.append({
            'name': name,
            'size': size,
            'pages': pages,
            'raw_bytes_len': len(raw_bytes),
            'text_len': len(full_text),
            'cleaned_text_len': len(text_cleaned),
            'binary_sha256': sha256_binary,
            'binary_md5': md5_binary,
            'text_sha256': text_sha256,
            'first_100_chars': full_text[:120].replace('\n', ' ')
        })
        
    print(f"\nFound {len(file_info)} PDF Files in assets/documents/:\n")
    for f in file_info:
        print(f"File: {f['name']}")
        print(f"  Size: {f['size']} bytes | Pages: {f['pages']} | Clean Text Chars: {f['cleaned_text_len']}")
        print(f"  Binary SHA-256: {f['binary_sha256']}")
        print(f"  Text SHA-256:   {f['text_sha256']}")
        print(f"  Sample Text:    {f['first_100_chars']}...")
        print("-" * 60)
        
    # Pairwise comparison
    print("\n" + "=" * 80)
    print("PAIRWISE DUPLICATE ANALYSIS")
    print("=" * 80)
    
    duplicate_pairs = []
    for i in range(len(file_info)):
        for j in range(i + 1, len(file_info)):
            f1 = file_info[i]
            f2 = file_info[j]
            
            is_exact_binary = f1['binary_sha256'] == f2['binary_sha256']
            is_exact_text = f1['text_sha256'] == f2['text_sha256']
            
            if is_exact_binary:
                print(f"[EXACT BINARY DUPLICATE]: {f1['name']} == {f2['name']}")
                duplicate_pairs.append((f1['name'], f2['name'], 'EXACT_BINARY_MATCH'))
            elif is_exact_text:
                print(f"[EXACT TEXT CONTENT DUPLICATE]: {f1['name']} == {f2['name']}")
                duplicate_pairs.append((f1['name'], f2['name'], 'EXACT_TEXT_MATCH'))
            else:
                # Check character overlap ratio
                common = len(set(f1['first_100_chars'].split()) & set(f2['first_100_chars'].split()))
                
    if not duplicate_pairs:
        print("No duplicate PDFs found (Neither binary nor text content). All files are unique.")
    else:
        print(f"\nSummary: Found {len(duplicate_pairs)} duplicate pair(s):")
        for p in duplicate_pairs:
            print(f"  - {p[0]} and {p[1]} -> {p[2]}")

if __name__ == '__main__':
    check_pdf_duplicates()
