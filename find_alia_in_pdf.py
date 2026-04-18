import pdfplumber
import re
import json

# Look for entries with "Alia Ikram"
pdf_file = 'CS_extracted_new.txt'

try:
    with open(pdf_file, 'r', encoding='utf-8') as f:
        content = f.read()
    
    print("Searching for 'Alia Ikram' in extracted PDF...\n")
    lines = content.split('\n')
    
    for i, line in enumerate(lines):
        if 'Alia Ikram' in line or 'App. Grmr' in line or 'App.Grmr' in line:
            # Show context
            start = max(0, i-2)
            end = min(len(lines), i+3)
            print(f"Found at line {i}:")
            for j in range(start, end):
                prefix = ">>> " if j == i else "    "
                print(f"{prefix}{j}: {lines[j]}")
            print()
except FileNotFoundError:
    print(f"File not found: {pdf_file}")
