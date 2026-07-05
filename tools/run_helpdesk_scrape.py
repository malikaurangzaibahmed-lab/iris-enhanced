#!/usr/bin/env python3
import json
import urllib.request
import urllib.error
from datetime import datetime, timezone
import sys
import os

API_KEY = "AIzaSyAhF_SrGEXNV-D1tbJtx8hUEITNl3iMFHU"
AUTH_URL = f"https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key={API_KEY}"
RTDB_BASE = "https://cui-helpdesk-479e3-default-rtdb.asia-southeast1.firebasedatabase.app"
BACKEND_BASE = "https://cui-helpdesk-backend.onrender.com"

PUBLIC_ENDPOINTS = {
    "notices": "/api/notices",
    "faculty": "/api/faculty",
    "alumni": "/api/alumni/all",
    "societies": "/api/societies",
    "books": "/api/books",
    "lost_found_student": "/api/lostfound?role=student",
    "lost_found_all": "/api/lostfound",
}

EMAIL = "fa25-bcs-101@students.cuisahiwal.edu.pk"
PASSWORD = "Aurangzaib01$"

def post_json(url, data):
    req_body = json.dumps(data).encode("utf-8")
    req = urllib.request.Request(
        url,
        data=req_body,
        headers={
            "Content-Type": "application/json",
            "User-Agent": "IRIS-Helpdesk-Scraper/1.0"
        }
    )
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            charset = resp.headers.get_content_charset() or "utf-8"
            body = resp.read().decode(charset, errors="replace")
            return json.loads(body)
    except urllib.error.HTTPError as exc:
        print(f"HTTP Error {exc.code} calling {url}", file=sys.stderr)
        print(exc.read().decode("utf-8", errors="replace"), file=sys.stderr)
        raise
    except Exception as exc:
        print(f"Error calling {url}: {exc}", file=sys.stderr)
        raise

def get_json(url, headers=None):
    req = urllib.request.Request(
        url,
        headers=headers or {
            "Accept": "application/json, text/plain, */*",
            "User-Agent": "IRIS-Helpdesk-Scraper/1.0"
        }
    )
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            charset = resp.headers.get_content_charset() or "utf-8"
            body = resp.read().decode(charset, errors="replace")
            return json.loads(body)
    except urllib.error.HTTPError as exc:
        print(f"HTTP Error {exc.code} calling {url}", file=sys.stderr)
        raise
    except Exception as exc:
        print(f"Error calling {url}: {exc}", file=sys.stderr)
        raise

def main():
    print("Authenticating with Firebase Auth...")
    auth_data = {
        "email": EMAIL,
        "password": PASSWORD,
        "returnSecureToken": True
    }
    
    try:
        auth_resp = post_json(AUTH_URL, auth_data)
        id_token = auth_resp.get("idToken")
        if not id_token:
            raise ValueError("No idToken found in auth response")
        print("Successfully authenticated.")
    except Exception as e:
        print(f"Authentication failed: {e}", file=sys.stderr)
        sys.exit(1)

    print("\nFetching RTDB Nodes...")
    # Fetch Schedules, Deadlines, Library, TransportSchedule
    rtdb_data = {}
    rtdb_nodes = {
        "semester_schedule": "Schedules",
        "deadlines": "Deadlines",
        "library_schedule": "Library",
        "transport_routes": "TransportSchedule"
    }

    for key, node in rtdb_nodes.items():
        node_url = f"{RTDB_BASE}/{node}.json?auth={id_token}"
        print(f"  Fetching {node}...")
        try:
            node_resp = get_json(node_url)
            # If the response is a dict or list, parse it.
            # RTDB might return a dict or list. Let's make sure it's mapped correctly.
            if isinstance(node_resp, dict):
                # Check if keys are integers (e.g. index 0, 1, 2 representing list)
                try:
                    sorted_keys = sorted(int(k) for k in node_resp.keys())
                    node_list = [node_resp[str(k)] for k in sorted_keys]
                    rtdb_data[key] = node_list
                except ValueError:
                    rtdb_data[key] = node_resp
            else:
                rtdb_data[key] = node_resp
        except Exception as e:
            print(f"Failed to fetch node {node}: {e}", file=sys.stderr)
            rtdb_data[key] = None

    # Construct helpdesk_schedule_seed.json content
    now_iso = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    
    # Process rtdb list structures (rtdb list lists sometimes have trailing/null elements)
    def clean_list(lst):
        if not isinstance(lst, list):
            return lst
        return [x for x in lst if x is not None]

    schedule_seed = {
        "captured_at": now_iso,
        "captured_from": "authenticated_helpdesk_schedule_tab",
        "semester_schedule": clean_list(rtdb_data.get("semester_schedule") or []),
        "deadlines": clean_list(rtdb_data.get("deadlines") or []),
        "library_schedule": rtdb_data.get("library_schedule") or {},
        "transport_routes": clean_list(rtdb_data.get("transport_routes") or [])
    }

    # Save helpdesk_schedule_seed.json
    seed_path = "assets/helpdesk_backup/helpdesk_schedule_seed.json"
    os.makedirs(os.path.dirname(seed_path), exist_ok=True)
    with open(seed_path, "w", encoding="utf-8") as f:
        json.dump(schedule_seed, f, indent=2, ensure_ascii=False)
    print(f"Saved schedule seed to {seed_path}")

    # Fetch backend API data
    print("\nFetching Backend public API endpoints...")
    public_data = {}
    for key, path in PUBLIC_ENDPOINTS.items():
        endpoint_url = f"{BACKEND_BASE}{path}"
        print(f"  Fetching {key} from {endpoint_url}...")
        try:
            public_data[key] = get_json(endpoint_url)
        except Exception as e:
            print(f"Failed to fetch {key}: {e}", file=sys.stderr)
            public_data[key] = None

    # Construct helpdesk_snapshot.json content
    snapshot = {
        "fetched_at": now_iso,
        "base_url": BACKEND_BASE,
        "endpoints": {k: f"{BACKEND_BASE}{v}" for k, v in PUBLIC_ENDPOINTS.items()},
        "data": public_data,
        "summary": {},
        "errors": {}
    }

    # Generate summary
    for k, v in public_data.items():
        if v is None:
            snapshot["errors"][k] = "Fetch failed"
            snapshot["summary"][k] = {"ok": False, "shape": "null"}
        else:
            ok = True
            shape = f"list[{len(v)}]" if isinstance(v, list) else f"object[{len(v)}]" if isinstance(v, dict) else type(v).__name__
            snapshot["summary"][k] = {"ok": ok, "shape": shape}

    # Save helpdesk_snapshot.json
    snapshot_path = "assets/helpdesk_backup/helpdesk_snapshot.json"
    with open(snapshot_path, "w", encoding="utf-8") as f:
        json.dump(snapshot, f, indent=2, ensure_ascii=False)
    print(f"Saved snapshot data to {snapshot_path}")

    print("\nSuccessfully finished CUI Helpdesk Portal re-scrape.")

if __name__ == "__main__":
    main()
