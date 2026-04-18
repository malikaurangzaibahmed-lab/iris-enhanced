"""CUI Helpdesk data scraper.

This scraper targets the public JSON endpoints exposed by the CUI Helpdesk
Flutter web app backend.

It collects:
- notices
- faculty
- alumni
- societies
- books
- lost and found entries

Usage:
    python tools/cui_helpdesk_scraper.py
    python tools/cui_helpdesk_scraper.py --output reports/cui_helpdesk_snapshot.json
    python tools/cui_helpdesk_scraper.py --cookie "session=..." --header "Authorization: Bearer ..."
"""

from __future__ import annotations

import argparse
import json
import sys
from datetime import datetime, timezone
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Iterable
from urllib.error import HTTPError, URLError
from urllib.parse import urljoin
from urllib.request import Request, urlopen


BASE_URL = "https://cui-helpdesk-backend.onrender.com"
ENDPOINTS = {
    "notices": "/api/notices",
    "faculty": "/api/faculty",
    "alumni": "/api/alumni/all",
    "societies": "/api/societies",
    "books": "/api/books",
    "lost_found_student": "/api/lostfound?role=student",
    "lost_found_all": "/api/lostfound",
}


@dataclass
class FetchResult:
    name: str
    url: str
    ok: bool
    status: int | None
    data: Any
    error: str | None = None


def build_headers(cookie: str | None, extra_headers: list[str]) -> dict[str, str]:
    headers = {
        "User-Agent": "IRIS-Data-Scraper/1.0",
        "Accept": "application/json, text/plain, */*",
    }
    if cookie:
        headers["Cookie"] = cookie

    for item in extra_headers:
        if ":" not in item:
            raise ValueError(f"Invalid header format: {item!r}. Use 'Name: Value'.")
        name, value = item.split(":", 1)
        headers[name.strip()] = value.strip()

    return headers


def fetch_json(url: str, headers: dict[str, str]) -> FetchResult:
    request = Request(url, headers=headers)
    try:
        with urlopen(request, timeout=30) as response:
            payload = response.read().decode("utf-8", errors="replace")
            try:
                data = json.loads(payload)
            except json.JSONDecodeError:
                data = payload
            return FetchResult(name=url, url=url, ok=True, status=response.status, data=data)
    except HTTPError as exc:
        return FetchResult(name=url, url=url, ok=False, status=exc.code, data=None, error=str(exc))
    except URLError as exc:
        return FetchResult(name=url, url=url, ok=False, status=None, data=None, error=str(exc))


def summarize_items(items: Any, limit: int = 3) -> dict[str, Any]:
    if not isinstance(items, list):
        return {"type": type(items).__name__, "value": items}

    summary = {"count": len(items), "samples": []}
    for item in items[:limit]:
        if isinstance(item, dict):
            summary["samples"].append({k: item.get(k) for k in list(item.keys())[:10]})
        else:
            summary["samples"].append(item)
    return summary


def extract_useful_summary(snapshot: dict[str, Any]) -> dict[str, Any]:
    summary: dict[str, Any] = {}
    for name, payload in snapshot.items():
        if isinstance(payload, list):
            summary[name] = summarize_items(payload)
        else:
            summary[name] = {"type": type(payload).__name__}
    return summary


def scrape(base_url: str, headers: dict[str, str]) -> dict[str, Any]:
    snapshot: dict[str, Any] = {}
    errors: dict[str, str] = {}

    for name, path in ENDPOINTS.items():
        url = urljoin(base_url, path)
        result = fetch_json(url, headers)
        if result.ok:
            snapshot[name] = result.data
        else:
            errors[name] = f"{result.status or 'ERR'}: {result.error}"
            snapshot[name] = None

    return {
        "fetched_at": datetime.now(timezone.utc).isoformat(),
        "base_url": base_url,
        "endpoints": {name: urljoin(base_url, path) for name, path in ENDPOINTS.items()},
        "data": snapshot,
        "summary": extract_useful_summary(snapshot),
        "errors": errors,
    }


def write_backup_bundle(result: dict[str, Any], backup_root: Path) -> Path:
    timestamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    bundle_dir = backup_root / timestamp
    data_dir = bundle_dir / "data"
    latest_dir = backup_root / "latest"

    data_dir.mkdir(parents=True, exist_ok=True)
    latest_dir.mkdir(parents=True, exist_ok=True)

    snapshot_text = json.dumps(result, indent=2, ensure_ascii=False)
    (bundle_dir / "snapshot.json").write_text(snapshot_text, encoding="utf-8")
    (latest_dir / "snapshot.json").write_text(snapshot_text, encoding="utf-8")

    for name, payload in result.get("data", {}).items():
        payload_text = json.dumps(payload, indent=2, ensure_ascii=False)
        (data_dir / f"{name}.json").write_text(payload_text, encoding="utf-8")
        (latest_dir / f"{name}.json").write_text(payload_text, encoding="utf-8")

    manifest = {
        "fetched_at": result.get("fetched_at"),
        "bundle_dir": str(bundle_dir),
        "datasets": list(result.get("data", {}).keys()),
        "errors": result.get("errors", {}),
    }
    manifest_text = json.dumps(manifest, indent=2, ensure_ascii=False)
    (bundle_dir / "manifest.json").write_text(manifest_text, encoding="utf-8")
    (latest_dir / "manifest.json").write_text(manifest_text, encoding="utf-8")
    return bundle_dir


def print_report(result: dict[str, Any]) -> None:
    summary = result["summary"]
    errors = result["errors"]

    print(f"Base URL: {result['base_url']}")
    print()
    print("Collected data:")
    for name, info in summary.items():
        if "count" in info:
            print(f"- {name}: {info['count']} records")
            for idx, sample in enumerate(info.get("samples", []), start=1):
                title = sample.get("title") or sample.get("name") or sample.get("desc") or sample.get("_id")
                print(f"  sample {idx}: {title}")
        else:
            print(f"- {name}: {info['type']}")

    if errors:
        print()
        print("Errors:")
        for name, error in errors.items():
            print(f"- {name}: {error}")

    print()
    print("Feature opportunities for IRIS:")
    print("- Faculty directory with room/contact lookup")
    print("- Live notices feed with deadline reminders")
    print("- Lost-and-found tracker with photo and contact search")
    print("- Alumni showcase/profile wall")
    print("- Campus society directory with members and social links")
    print("- Book/library catalog with availability and summaries")
    print("- Role-based dashboards for student, faculty, and admin")


def parse_args(argv: Iterable[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Scrape public CUI Helpdesk JSON endpoints")
    parser.add_argument("--base-url", default=BASE_URL, help="Backend base URL")
    parser.add_argument("--output", help="Write full JSON snapshot to a file")
    parser.add_argument(
        "--backup-dir",
        default="reports/helpdesk_backups",
        help="Write timestamped backup bundles under this directory.",
    )
    parser.add_argument(
        "--asset-output",
        help="Optional app fallback asset output path (e.g., assets/helpdesk_backup/helpdesk_snapshot.json).",
    )
    parser.add_argument("--cookie", help="Optional Cookie header value")
    parser.add_argument(
        "--header",
        action="append",
        default=[],
        help="Extra request header in 'Name: Value' format. Repeatable.",
    )
    return parser.parse_args(list(argv))


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv or sys.argv[1:])
    headers = build_headers(args.cookie, args.header)
    result = scrape(args.base_url.rstrip("/"), headers)

    if args.output:
        output_path = Path(args.output)
        output_path.parent.mkdir(parents=True, exist_ok=True)
        output_path.write_text(json.dumps(result, indent=2, ensure_ascii=False), encoding="utf-8")
        print(f"Saved snapshot to {output_path}")
        print()

    backup_dir = Path(args.backup_dir)
    bundle_dir = write_backup_bundle(result, backup_dir)
    print(f"Saved backup bundle to {bundle_dir}")

    if args.asset_output:
        asset_path = Path(args.asset_output)
        asset_path.parent.mkdir(parents=True, exist_ok=True)
        asset_path.write_text(json.dumps(result, indent=2, ensure_ascii=False), encoding="utf-8")
        print(f"Saved app fallback asset to {asset_path}")
        print()

    print_report(result)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
