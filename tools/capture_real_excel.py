import os
import win32com.client
import pdfplumber
from PIL import ImageGrab

artifact_dir = r"C:\Users\MALIK\.gemini\antigravity-ide\brain\83f6734c-1364-4521-80ff-f595797d00c4"

def export_excel_via_office(excel_rel_path, out_prefix):
    abs_excel = os.path.abspath(excel_rel_path)
    print(f"\nOpening {os.path.basename(abs_excel)} in Microsoft Excel (Office16)...")
    
    excel_app = win32com.client.DispatchEx("Excel.Application")
    excel_app.Visible = False
    excel_app.DisplayAlerts = False
    
    try:
        wb = excel_app.Workbooks.Open(abs_excel, ReadOnly=True)
        sheet = wb.Worksheets(1)
        
        # 1. Export as native PDF directly from Excel's rendering engine (xlTypePDF = 0)
        temp_pdf = os.path.join(artifact_dir, f"{out_prefix}_native.pdf")
        sheet.ExportAsFixedFormat(0, temp_pdf)
        print(f"Exported Microsoft Excel native PDF: {temp_pdf}")
        
        # 2. Render each page of the exported Excel PDF at 300 DPI
        with pdfplumber.open(temp_pdf) as pdf:
            print(f"Excel rendered into {len(pdf.pages)} PDF pages:")
            for p_idx, page in enumerate(pdf.pages):
                img = page.to_image(resolution=250)
                img_path = os.path.join(artifact_dir, f"{out_prefix}_page_{p_idx+1}.png")
                img.save(img_path)
                print(f"  Saved page {p_idx+1} screenshot: {img_path}")
                
        wb.Close(False)
    except Exception as e:
        print(f"Error automating Excel: {e}")
    finally:
        excel_app.Quit()

if __name__ == '__main__':
    f1 = "assets/documents/Date_Sheet_FINAL_Term_Exam_FALL_2025 - Version I - 08-12-25.xlsx"
    f2 = "assets/documents/Version I of Date Sheet Mid Term Exam SPRING 2026 25-03-2026.xlsx"
    export_excel_via_office(f1, "ms_excel_final_fall_2025")
    export_excel_via_office(f2, "ms_excel_mid_spring_2026")
