import os
import openpyxl
from PIL import Image, ImageDraw, ImageFont

artifact_dir = r"C:\Users\MALIK\.gemini\antigravity-ide\brain\83f6734c-1364-4521-80ff-f595797d00c4"

def render_excel_pillow(excel_path, out_name):
    wb = openpyxl.load_workbook(excel_path, data_only=True)
    sheet = wb.active
    rows = list(sheet.iter_rows(values_only=True))
    
    # 4 Quad Blocks:
    blocks = [
        ("Block 1: Building A & WCR (Cols 0-11)", 0, 12, "#38bdf8"),
        ("Block 2: Building B (Cols 12-25)", 12, 26, "#818cf8"),
        ("Block 3: Building C (Cols 26-40)", 26, 41, "#2dd4bf"),
        ("Block 4: Building D (Cols 41-52)", 41, 53, "#f43f5e")
    ]
    
    # Create an image 2400 x 2800
    img = Image.new('RGB', (2500, 2600), color=(10, 15, 29))
    draw = ImageDraw.Draw(img)
    
    # Try default font
    try:
        font_title = ImageFont.truetype("arial.ttf", 22)
        font_header = ImageFont.truetype("arial.ttf", 15)
        font_cell = ImageFont.truetype("arial.ttf", 13)
        font_sub = ImageFont.truetype("arial.ttf", 11)
    except:
        font_title = ImageFont.load_default()
        font_header = ImageFont.load_default()
        font_cell = ImageFont.load_default()
        font_sub = ImageFont.load_default()
        
    y_offset = 30
    draw.text((40, y_offset), f"IRIS EXCEL VISUAL AUDIT: {os.path.basename(excel_path)}", fill=(255, 255, 255), font=font_title)
    y_offset += 50
    
    for b_title, c_start, c_end, accent_hex in blocks:
        draw.rectangle([40, y_offset, 2460, y_offset + 35], fill=(20, 30, 55), outline=(50, 70, 120))
        draw.text((50, y_offset + 6), b_title, fill=(255, 255, 255), font=font_header)
        y_offset += 42
        
        # Header row (row 2 in 0-indexed)
        header_row = rows[2][c_start:c_end]
        col_width = (2420) // max(1, (c_end - c_start))
        
        # Draw header cells
        for idx, h_val in enumerate(header_row):
            x1 = 40 + idx * col_width
            x2 = x1 + col_width
            draw.rectangle([x1, y_offset, x2, y_offset + 32], fill=(30, 45, 80), outline=(60, 80, 140))
            text = str(h_val) if h_val is not None else ""
            draw.text((x1 + 6, y_offset + 8), text[:18], fill=(56, 189, 248), font=font_header)
        y_offset += 32
        
        # Draw data rows (first 10 pairs: row 3 to 13)
        for r_idx in range(3, min(15, len(rows)), 2):
            batch_row = rows[r_idx][c_start:c_end]
            sub_row = rows[r_idx + 1][c_start:c_end] if r_idx + 1 < len(rows) else [None] * len(batch_row)
            
            # Draw paired row container
            row_h = 56
            for idx in range(len(batch_row)):
                x1 = 40 + idx * col_width
                x2 = x1 + col_width
                
                b_val = str(batch_row[idx]).strip() if batch_row[idx] is not None else ""
                s_val = str(sub_row[idx]).strip() if sub_row[idx] is not None else ""
                
                # Highlight compound/multiple batches in amber
                is_compound = '-' in b_val and ('FA' in b_val or 'SP' in b_val) and b_val.count('-') >= 3
                bg_color = (40, 25, 25) if is_compound else ((22, 33, 62) if idx % 2 == 0 else (15, 23, 42))
                
                draw.rectangle([x1, y_offset, x2, y_offset + row_h], fill=bg_color, outline=(40, 55, 95))
                
                if idx < 2: # Date and Time
                    draw.text((x1 + 6, y_offset + 8), b_val[:18], fill=(255, 255, 255), font=font_cell)
                    draw.text((x1 + 6, y_offset + 30), s_val[:18], fill=(148, 163, 184), font=font_sub)
                else:
                    draw.text((x1 + 6, y_offset + 6), b_val[:20], fill=(251, 191, 36) if is_compound else (129, 140, 248), font=font_cell)
                    draw.text((x1 + 6, y_offset + 28), s_val[:22], fill=(52, 211, 153), font=font_sub)
            y_offset += row_h
            
        y_offset += 25
        
    out_path = os.path.join(artifact_dir, f"{out_name}.png")
    img.save(out_path)
    print(f"SUCCESS: Rendered {out_path}")

if __name__ == '__main__':
    f1 = "assets/documents/Date_Sheet_FINAL_Term_Exam_FALL_2025 - Version I - 08-12-25.xlsx"
    f2 = "assets/documents/Version I of Date Sheet Mid Term Exam SPRING 2026 25-03-2026.xlsx"
    render_excel_pillow(f1, "excel_visual_final_fall_2025")
    render_excel_pillow(f2, "excel_visual_mid_spring_2026")
