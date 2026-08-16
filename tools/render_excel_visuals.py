import os
import glob
import openpyxl
import matplotlib.pyplot as plt
import matplotlib.patches as patches

artifact_dir = r"C:\Users\MALIK\.gemini\antigravity-ide\brain\83f6734c-1364-4521-80ff-f595797d00c4"

def render_excel_visual(excel_path, out_prefix):
    wb = openpyxl.load_workbook(excel_path, data_only=True)
    sheet = wb.active
    rows = list(sheet.iter_rows(values_only=True))
    
    print(f"Rendering visual for {os.path.basename(excel_path)}: {len(rows)} rows, {len(rows[0]) if rows else 0} cols")
    
    # We will render the first 25 rows and 4 blocks into a high-res image
    # Let's inspect block 1 (cols 0-11), block 2 (cols 12-25), block 3 (cols 26-40), block 4 (cols 41-52)
    blocks = [
        ("Block 1 (Building A / WCR)", 0, 12),
        ("Block 2 (Building B)", 12, 26),
        ("Block 3 (Building C)", 26, 41),
        ("Block 4 (Building D)", 41, len(rows[2]))
    ]
    
    fig, axes = plt.subplots(4, 1, figsize=(24, 28), dpi=150)
    fig.patch.set_facecolor('#0f172a')
    
    for b_idx, (b_name, start_col, end_col) in enumerate(blocks):
        ax = axes[b_idx]
        ax.set_facecolor('#0f172a')
        ax.set_title(b_name, color='#38bdf8', fontsize=14, fontweight='bold', pad=12)
        
        # Prepare table data for first 18 rows
        table_data = []
        col_labels = []
        
        # Row 2 (index 2) is the column header (Date, Time, Rooms)
        raw_headers = rows[2][start_col:end_col]
        for c_val in raw_headers:
            col_labels.append(str(c_val) if c_val is not None else "")
            
        for r_idx in range(3, min(22, len(rows))):
            row = rows[r_idx]
            row_slice = row[start_col:end_col]
            formatted_row = []
            for val in row_slice:
                if val is None:
                    formatted_row.append("")
                else:
                    sval = str(val).strip()
                    # truncate long strings for display
                    if len(sval) > 22:
                        sval = sval[:20] + ".."
                    formatted_row.append(sval)
            table_data.append(formatted_row)
            
        ax.axis('off')
        
        # Create table
        tab = ax.table(
            cellText=table_data,
            colLabels=col_labels,
            loc='center',
            cellLoc='center'
        )
        
        tab.auto_set_font_size(False)
        tab.set_fontsize(8)
        tab.scale(1.0, 1.8)
        
        # Style table
        for (r, c), cell in tab.get_celld().items():
            if r == 0:
                cell.set_facecolor('#1e293b')
                cell.set_text_props(color='#38bdf8', weight='bold')
            else:
                # Even rows (batches) vs Odd rows (subjects)
                is_batch_row = (r % 2 == 1) # r=1 corresponds to r_idx=3 (batch)
                if is_batch_row:
                    cell.set_facecolor('#1e293b' if c % 2 == 0 else '#0f172a')
                    cell.set_text_props(color='#818cf8', weight='bold')
                else:
                    cell.set_facecolor('#1e293b' if c % 2 == 0 else '#0f172a')
                    cell.set_text_props(color='#34d399', weight='normal')
            cell.set_edgecolor('#334155')
            
    plt.tight_layout()
    out_file = os.path.join(artifact_dir, f"{out_prefix}.png")
    plt.savefig(out_file, bbox_inches='tight', facecolor=fig.get_facecolor())
    plt.close()
    print(f"Saved visual render: {out_file}")
    return out_file

if __name__ == '__main__':
    f1 = "assets/documents/Date_Sheet_FINAL_Term_Exam_FALL_2025 - Version I - 08-12-25.xlsx"
    f2 = "assets/documents/Version I of Date Sheet Mid Term Exam SPRING 2026 25-03-2026.xlsx"
    if os.path.exists(f1):
        render_excel_visual(f1, "excel_visual_final_fall_2025")
    if os.path.exists(f2):
        render_excel_visual(f2, "excel_visual_mid_spring_2026")
