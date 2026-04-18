#!/usr/bin/env python3
"""Scrape all discoverable CUI Helpdesk datasets into one snapshot file.

Usage examples:
  python tools/scrape_helpdesk_everything.py
  python tools/scrape_helpdesk_everything.py --id-token "<firebase-id-token>"
  python tools/scrape_helpdesk_everything.py --out tools/helpdesk_full_snapshot.json
"""

from __future__ import annotations

import argparse
import json
import os
import urllib.error
import urllib.request
from datetime import datetime, timezone
from typing import Any

PUBLIC_ENDPOINTS = {
    "notices": "https://cui-helpdesk-backend.onrender.com/api/notices",
    "faculty": "https://cui-helpdesk-backend.onrender.com/api/faculty",
    "alumni": "https://cui-helpdesk-backend.onrender.com/api/alumni/all",
    "societies": "https://cui-helpdesk-backend.onrender.com/api/societies",
    "books": "https://cui-helpdesk-backend.onrender.com/api/books",
    "lost_found": "https://cui-helpdesk-backend.onrender.com/api/lostfound",
    "lost_found_student": "https://cui-helpdesk-backend.onrender.com/api/lostfound?role=student",
}

RTDB_BASE = "https://cui-helpdesk-479e3-default-rtdb.asia-southeast1.firebasedatabase.app"
RTDB_NODES = [
    "TransportSchedule",
    "Schedules",
    "Deadlines",
    "Events",
    "Library",
    "RoomBookings",
]


def _fetch_json(url: str, timeout: int = 25) -> tuple[bool, Any]:
    try:
        req = urllib.request.Request(
            url,
            headers={
                "Accept": "application/json, text/plain, */*",
                "User-Agent": "IRIS-Helpdesk-Scraper/1.0",
            },
        )
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            charset = resp.headers.get_content_charset() or "utf-8"
            body = resp.read().decode(charset, errors="replace")
            return True, json.loads(body)
    except urllib.error.HTTPError as exc:
        return False, {
            "error": f"HTTP {exc.code}",
            "reason": str(exc.reason),
            "url": url,
        }
    except urllib.error.URLError as exc:
        return False, {"error": f"URL error: {exc.reason}", "url": url}
    except Exception as exc:  # pylint: disable=broad-except
        return False, {"error": str(exc), "url": url}


def _count_shape(value: Any) -> str:
    if isinstance(value, list):
        return f"list[{len(value)}]"
    if isinstance(value, dict):
        return f"object[{len(value)}]"
    if value is None:
        return "null"
    return type(value).__name__


def main() -> None:
    parser = argparse.ArgumentParser(description="Scrape CUI Helpdesk data")
    parser.add_argument(
        "--id-token",
        default=os.getenv("HELPDESK_ID_TOKEN", "").strip(),
        help="Firebase ID token for protected RTDB nodes (optional).",
    )
    parser.add_argument(
        "--out",
        default="tools/helpdesk_full_snapshot.json",
        help="Output JSON path.",
    )
    args = parser.parse_args()

    snapshot: dict[str, Any] = {
        "captured_at": datetime.now(timezone.utc).isoformat(),
        "source": "scrape_helpdesk_everything.py",
        "public": {},
        "rtdb": {},
        "summary": {"public": {}, "rtdb": {}},
    }

    for key, url in PUBLIC_ENDPOINTS.items():
        ok, data = _fetch_json(url)
        snapshot["public"][key] = data
        snapshot["summary"]["public"][key] = {
            "ok": ok,
            "shape": _count_shape(data),
        }

    for node in RTDB_NODES:
        url = f"{RTDB_BASE}/{node}.json"
        if args.id_token:
            url = f"{url}?auth={args.id_token}"
        ok, data = _fetch_json(url)
        snapshot["rtdb"][node] = data
        snapshot["summary"]["rtdb"][node] = {
            "ok": ok,
            "shape": _count_shape(data),
        }

    os.makedirs(os.path.dirname(args.out) or ".", exist_ok=True)
    with open(args.out, "w", encoding="utf-8") as handle:
        json.dump(snapshot, handle, ensure_ascii=False, indent=2)

    print(f"Saved snapshot: {args.out}")
    print("Public summary:")
    for key, info in snapshot["summary"]["public"].items():
        print(f"  - {key}: ok={info['ok']} shape={info['shape']}")
    print("RTDB summary:")
    for key, info in snapshot["summary"]["rtdb"].items():
        print(f"  - {key}: ok={info['ok']} shape={info['shape']}")


if __name__ == "__main__":
    main()
