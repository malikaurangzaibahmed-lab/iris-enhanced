import os
import json
import urllib.request
import urllib.parse

snapshot_path = r"d:\Iris Working backup\MOST RECENT\IRIS\assets\helpdesk_backup\helpdesk_snapshot.json"
output_dir = r"d:\Iris Working backup\MOST RECENT\IRIS\assets\faculty_images"

# Ensure output directory exists
os.makedirs(output_dir, exist_ok=True)

# Base URL of the backend
base_url = "https://cui-helpdesk-backend.onrender.com"

try:
    with open(snapshot_path, "r", encoding="utf-8") as f:
        snapshot = json.load(f)
    
    faculty_list = snapshot.get("data", {}).get("faculty", [])
    print(f"Total faculty profiles: {len(faculty_list)}")
    
    # Extract unique image paths
    image_paths = set()
    for f in faculty_list:
        img = f.get("image", "").strip()
        if img:
            image_paths.add(img)
            
    print(f"Found {len(image_paths)} unique image paths to download.")
    
    downloaded = 0
    skipped = 0
    errors = []
    
    for i, path in enumerate(sorted(image_paths), 1):
        # path is like "/uploads/1768305461979.jpg"
        filename = os.path.basename(path)
        dest_path = os.path.join(output_dir, filename)
        
        if os.path.exists(dest_path) and os.path.getsize(dest_path) > 0:
            skipped += 1
            continue
            
        # construct full URL
        # Handle path encoding if necessary
        full_url = base_url + path
        
        print(f"[{i}/{len(image_paths)}] Downloading {filename}...")
        try:
            # Add User-Agent header to avoid potential bot blockers
            req = urllib.request.Request(
                full_url, 
                headers={'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'}
            )
            with urllib.request.urlopen(req, timeout=10) as response:
                with open(dest_path, "wb") as out_file:
                    out_file.write(response.read())
            downloaded += 1
        except Exception as e:
            print(f"  Error downloading {filename}: {e}")
            errors.append((filename, str(e)))
            
    print("\n--- Download Summary ---")
    print(f"Total processed: {len(image_paths)}")
    print(f"Already existed/Skipped: {skipped}")
    print(f"Newly downloaded: {downloaded}")
    print(f"Failed: {len(errors)}")
    if errors:
        print("Errors:")
        for fn, err in errors[:10]:
            print(f"  {fn}: {err}")
            
except Exception as e:
    print("Error parsing snapshot or downloading images:", e)
