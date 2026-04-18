#!/usr/bin/env python3
"""
Simple OTA Deployment Script
Uploads timetable to public location for app updates
"""

import json
import sys
import subprocess
from pathlib import Path
from datetime import datetime

# Configuration
TIMETABLE_FILE = Path("assets/timetable_seed.json")
METADATA_FILE = Path("assets/timetable_metadata.json")

def get_timetable_info():
    """Extract metadata from timetable"""
    with open(TIMETABLE_FILE, 'r', encoding='utf-8') as f:
        data = json.load(f)
    
    sessions = data.get('sessions', [])
    batches = set(s['batch'] for s in sessions)
    
    return {
        'version': int(datetime.now().strftime('%Y%m%d')),
        'session_count': len(sessions),
        'unique_batches': len(batches),
        'updated_at': datetime.now().isoformat(),
        'file_size_kb': TIMETABLE_FILE.stat().st_size // 1024,
    }

def save_metadata():
    """Save metadata JSON"""
    info = get_timetable_info()
    
    with open(METADATA_FILE, 'w', encoding='utf-8') as f:
        json.dump(info, f, indent=2)
    
    print(f"\n{'='*60}")
    print("Timetable Metadata:")
    print(f"{'='*60}")
    for key, value in info.items():
        print(f"{key:20} : {value}")
    return info

def deploy_firebase():
    """Deploy to Firebase Storage"""
    print("\n📤 Deploying to Firebase Storage...")
    print("⚠️  Make sure you have:")
    print("   1. Firebase CLI installed: npm install -g firebase-tools")
    print("   2. Logged in: firebase login")
    print("   3. Project configured: firebase use --add")
    
    try:
        # Check if firebase CLI is available
        result = subprocess.run(['firebase', '--version'], 
                              capture_output=True, text=True)
        print(f"✅ Firebase CLI: {result.stdout.strip()}")
        
        # Upload to Storage
        cmd = [
            'gsutil', 'cp',
            str(TIMETABLE_FILE),
            'gs://YOUR-PROJECT-BUCKET/timetable_seed.json'
        ]
        print(f"\nManually run: {' '.join(cmd)}")
        print("(Replace YOUR-PROJECT-BUCKET with your Firebase project)")
        
    except FileNotFoundError:
        print("❌ Firebase CLI not found")
        print("Install with: npm install -g firebase-tools")

def deploy_github():
    """Deploy to GitHub"""
    print("\n📤 Deploying to GitHub...")
    
    try:
        # Check git status
        result = subprocess.run(['git', 'status', '--porcelain'], 
                              capture_output=True, text=True)
        
        if 'timetable_seed.json' in result.stdout:
            print("📝 Changes detected in timetable_seed.json")
            print("\nTo deploy:")
            print("  git add assets/timetable_seed.json")
            print("  git commit -m 'Update timetable: $(date +%Y-%m-%d)'")
            print("  git push")
        else:
            print("✅ Timetable file unchanged")
    except FileNotFoundError:
        print("❌ Git not found")

def deploy_simple_http():
    """Instructions for simple HTTP deployment"""
    print("\n📤 Deploying to Custom HTTP Server...")
    print("Upload timetable_seed.json to your server:")
    print(f"  scp {TIMETABLE_FILE} user@server:/var/www/api/")
    print("  OR use your web hosting control panel")

def main():
    print("="*60)
    print("OTA TIMETABLE DEPLOYMENT TOOL")
    print("="*60)
    
    # Generate metadata
    info = save_metadata()
    
    # Show options
    print(f"\n{'='*60}")
    print("Deployment Options:")
    print(f"{'='*60}")
    print("1. Firebase Storage (recommended)")
    print("2. GitHub (easiest)")
    print("3. Custom HTTP Server")
    print("0. Just prepare files (no upload)")
    
    choice = input("\nSelect option (0-3): ").strip()
    
    if choice == '1':
        deploy_firebase()
    elif choice == '2':
        deploy_github()
    elif choice == '3':
        deploy_simple_http()
    elif choice == '0':
        print("\n✅ Files prepared, ready to deploy manually")
        print(f"Upload this file: {TIMETABLE_FILE}")
        print(f"File size: {info['file_size_kb']} KB")
    else:
        print("❌ Invalid option")
        return 1
    
    print(f"\n{'='*60}")
    print("✅ Deployment ready!")
    print(f"{'='*60}")
    print("\nGenerated files:")
    print(f"  - {TIMETABLE_FILE} ({info['file_size_kb']} KB, {info['session_count']} sessions)")
    print(f"  - {METADATA_FILE}")
    
    return 0

if __name__ == '__main__':
    sys.exit(main())
