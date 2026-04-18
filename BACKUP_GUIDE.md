# IRIS Project Backup Guide

## How to Safely and Completely Backup Your Project

### 1. Manual File Backup (Recommended for Most Users)
- Copy the entire `D:\IRIS` folder (including all subfolders and files) to a safe location:
  - External hard drive, USB drive, or another partition
  - Cloud storage (Google Drive, OneDrive, Dropbox, etc.)
- Make sure to include hidden files (like `.git`, `.vscode`, etc.) if present.
- To restore, simply copy the folder back to its original or a new location.

### 2. Git Version Control (Best for Developers)
- If not already using Git, initialize a repository:
  1. Open a terminal in `D:\IRIS`
  2. Run: `git init`
  3. Add all files: `git add .`
  4. Commit: `git commit -m "Initial backup"`
- To backup remotely, create a private repo on GitHub/GitLab/Bitbucket and push:
  1. `git remote add origin <your-repo-url>`
  2. `git push -u origin master`
- This method tracks all changes and allows easy restoration or collaboration.

### 3. Automated Backup Script (Windows Example)
- Create a script (e.g., `backup_iris.ps1`):

```
$source = "D:\IRIS"
$dest = "E:\Backups\IRIS_$(Get-Date -Format yyyyMMdd_HHmmss)"
robocopy $source $dest /E /Z /COPYALL /R:2 /W:2
```
- Run this script to create a timestamped backup folder.

### 4. Cloud Sync (Optional)
- Use a cloud sync tool (Google Drive, OneDrive, Dropbox) and point it to your `D:\IRIS` folder or a backup copy.
- Ensure sync is complete before making changes or restoring.

---

## What Each Git Command Does

- `git init` — Initializes a new Git repository in your folder. Creates a hidden `.git` directory to track changes.
- `git add .` — Stages (marks) all files in the folder for the next commit (snapshot).
- `git commit -m "message"` — Saves a snapshot of all staged files with a message describing the changes.
- `git remote add origin <url>` — Links your local repository to a remote (cloud) repository (e.g., GitHub).
- `git push -u origin master` — Uploads your commits to the remote repository for backup.
- `git status` — Shows which files have changed and are staged or unstaged.
- `git log` — Shows the history of all commits (snapshots).

---

## Automated Git Backup Script (Windows)

1. Open Notepad and paste the script below.
2. Save as `backup_git_iris.bat` in your project folder.
3. Double-click to run. It will add, commit, and push changes automatically.

```
@echo off
cd /d D:\IRIS
set msg=%date% %time% Automated backup

git add .
git commit -m "%msg%"
git push

echo Backup complete. Press any key to exit.
pause
```

- Make sure you have Git installed and your remote (GitHub, etc.) is set up and authenticated.
- This script will commit all changes with a timestamped message and push to your remote backup.

---

**No errors were found in your project.**

If you need an automated backup script or Git setup help, let me know!
