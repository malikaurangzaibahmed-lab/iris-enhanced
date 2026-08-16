import os
from PIL import Image

artifact_dir = r"C:\Users\MALIK\.gemini\antigravity-ide\brain\83f6734c-1364-4521-80ff-f595797d00c4"

def crop_excel_blocks():
    # Load the high-res native export image
    img_path = os.path.join(artifact_dir, "real_excel_final_fall_page_1.png")
    if not os.path.exists(img_path): return
    img = Image.open(img_path)
    w, h = img.size
    print(f"Loaded Native Excel Image: {w} x {h}")
    
    # 4 Building horizontal blocks:
    # Total width w is split roughly into 4 sections:
    # Section 1: 0% to 24%
    # Section 2: 24% to 50%
    # Section 3: 50% to 77%
    # Section 4: 77% to 100%
    
    # Top 30% contains the first 2 days (Mon, Tue)
    top_h = int(h * 0.45)
    
    crops = [
        ("excel_crop_block1_building_A_wcr.png", 0, 0, int(w * 0.25), top_h),
        ("excel_crop_block2_building_B_mgmt.png", int(w * 0.235), 0, int(w * 0.505), top_h),
        ("excel_crop_block3_building_C_cs.png", int(w * 0.495), 0, int(w * 0.775), top_h),
        ("excel_crop_block4_building_D_mech_civil.png", int(w * 0.765), 0, w, top_h)
    ]
    
    for out_name, x1, y1, x2, y2 in crops:
        cropped = img.crop((x1, y1, x2, y2))
        out_path = os.path.join(artifact_dir, out_name)
        cropped.save(out_path)
        print(f"Saved {out_name}: {cropped.size}")

if __name__ == '__main__':
    crop_excel_blocks()
