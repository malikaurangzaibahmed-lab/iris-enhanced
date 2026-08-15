import pdfplumber
import re
import glob

TIME_RANGE_RE = re.compile(r"(\d{1,2})[:.]?(\d{2})\s*-\s*(\d{1,2})[:.]?(\d{2})")

for pdf_path in sorted(glob.glob('assets/documents/*.pdf')):
    if 'iouiouj.pdf' in pdf_path: continue
    print(f"\n==================== {pdf_path} ====================")
    with pdfplumber.open(pdf_path) as pdf:
        page = pdf.pages[0]
        words = page.extract_words()
        
        # Find time words
        time_words = [w for w in words if TIME_RANGE_RE.search(w['text']) or re.match(r'^\d{1,2}:\d{2}$', w['text']) or w['text'].lower() == 'break']
        
        # Cluster by top Y
        y_clusters = {}
        for w in time_words:
            top_y = round(w['top'] / 5) * 5
            y_clusters.setdefault(top_y, []).append(w)
            
        header_y = max(y_clusters.keys(), key=lambda y: len(y_clusters[y])) if y_clusters else None
        print(f"Header Y: {header_y}")
        
        if header_y is not None:
            hw = sorted([w for w in words if abs(w['top'] - header_y) <= 15], key=lambda w: w['x0'])
            
            # Group by X proximity
            col_groups = []
            cur_group = []
            for w in hw:
                if not cur_group:
                    cur_group.append(w)
                else:
                    if w['x0'] - cur_group[-1]['x1'] < 25:
                        cur_group.append(w)
                    else:
                        col_groups.append(cur_group)
                        cur_group = [w]
            if cur_group:
                col_groups.append(cur_group)
                
            print(f"Detected {len(col_groups)} header clusters:")
            for idx, cg in enumerate(col_groups):
                txt = " ".join(w['text'] for w in cg)
                x0 = min(w['x0'] for w in cg)
                x1 = max(w['x1'] for w in cg)
                print(f"  Col {idx}: x0={x0:.1f} x1={x1:.1f} -> '{txt}'")
