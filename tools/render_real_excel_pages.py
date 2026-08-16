import os
import glob
import pdfplumber

artifact_dir = r"C:\Users\MALIK\.gemini\antigravity-ide\brain\83f6734c-1364-4521-80ff-f595797d00c4"

def render_real_excel_pages():
    pdf_files = [
        "real_excel_Date_Sheet_FINAL_Term_Exam_FALL_2025___Version_I___08_12_25.pdf",
        "real_excel_Version_I_of_Date_Sheet_Mid_Term_Exam_SPRING_2026_25_03_2026.pdf"
    ]
    
    for pf in pdf_files:
        full_path = os.path.join(artifact_dir, pf)
        prefix = "real_excel_final_fall" if "FINAL" in pf else "real_excel_mid_spring"
        with pdfplumber.open(full_path) as pdf:
            print(f"\n{pf}: {len(pdf.pages)} pages")
            for idx, page in enumerate(pdf.pages):
                out_name = f"{prefix}_page_{idx+1}.png"
                out_path = os.path.join(artifact_dir, out_name)
                # 200 DPI for high fidelity
                img = page.to_image(resolution=200)
                img.save(out_path)
                print(f"  Rendered {out_name}")

if __name__ == '__main__':
    render_real_excel_pages()
