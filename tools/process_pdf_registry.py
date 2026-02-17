"""
Smart PDF Timetable Parser for CUI Sahiwal.
Extracts class sessions from multi-page PDF timetables with:
  - Carry-forward day detection across pages
  - Department-prefix teacher recognition (handles names without Mr./Ms.)
  - Special lab room handling (Networking Lab, DLD Lab, Physics Lab, etc.)
  - Dept-code stripping from teacher names
  - Room capacity stripping
  - Subject name cleaning (merged room removal)
  - Duplicate elimination
"""
import json
import re
from pathlib import Path
from typing import Dict, List, Optional, Tuple

import pdfplumber

PDF_PATH = Path(r"D:\Flutter\student_organizer\assets\CS (1).pdf")
SEED_PATH = Path(r"D:\Flutter\student_organizer\assets\timetable_seed.json")

# ── Day names ──────────────────────────────────────────────────────────
DAY_NAMES = {
    "mon": "Monday", "monday": "Monday",
    "tue": "Tuesday", "tues": "Tuesday", "tuesday": "Tuesday",
    "wed": "Wednesday", "wednesday": "Wednesday",
    "thu": "Thursday", "thur": "Thursday", "thurs": "Thursday", "thursday": "Thursday",
    "fri": "Friday", "friday": "Friday",
    "sat": "Saturday", "saturday": "Saturday",
    "sun": "Sunday", "sunday": "Sunday",
}

# ── Known department codes (appear as teacher name prefixes in CUI PDFs) ──
DEPT_CODES = {"CS", "SE", "MS", "EE", "ME", "CVE", "BBA", "MBA", "MT", "VS"}

# ── Regex patterns ─────────────────────────────────────────────────────
TIME_RANGE_RE = re.compile(r"(\d{1,2})[:.]?(\d{2})\s*-\s*(\d{1,2})[:.]?(\d{2})")
BATCH_WITH_INTAKE_RE = re.compile(r"([A-Z]{2}\d{2})-([A-Z]{2,4})-(\d+)-([A-Z])")
BATCH_NO_INTAKE_RE = re.compile(r"([A-Z]{2,4})-(\d+)-([A-Z])")
CAPACITY_RE = re.compile(r"\s*\(\d+\)\s*")  # e.g. "(48)", "(77)"
TEACHER_TITLE_RE = re.compile(
    r"\b(Dr\.?|Prof\.?|Engr\.?|Mr\.?|Ms\.?|Mrs\.?|Sir|Mam)\b", re.IGNORECASE
)

# Room patterns — ordered: special lab names first, then generic alphanumeric
ROOM_PATTERNS = [
    re.compile(r"\bPhysics\s+Lab\b", re.IGNORECASE),
    re.compile(r"\bNetworking\s+Lab\b", re.IGNORECASE),
    re.compile(r"\bDLD\s+Lab\b", re.IGNORECASE),
    re.compile(r"\bMOM\s*Lab\b", re.IGNORECASE),
    re.compile(r"\bEFM\s*Lab\b", re.IGNORECASE),
    re.compile(r"\bMechanical\s+Lab\b", re.IGNORECASE),
    re.compile(r"\bElectronics\s+Lab\b", re.IGNORECASE),
    re.compile(r"\bHardware\s+Lab\b", re.IGNORECASE),
    re.compile(r"\bCircuit\s+Lab\b", re.IGNORECASE),
    re.compile(r"\bSoftware\s+Lab\b", re.IGNORECASE),
    re.compile(r"\bComputer\s+Lab\b", re.IGNORECASE),
    re.compile(r"\bCLab-?\d*\b"),
    re.compile(r"\b[A-Z]\d+(?:\.\d)?\b"),  # e.g. C1.2, B7, D9, W2
]

# Subject keywords — used to distinguish subject lines from teacher names
_SUBJECT_KEYWORDS = {
    "programming", "engineering", "structures", "systems", "calculus",
    "algebra", "physics", "chemistry", "communication", "technology",
    "network", "database", "security", "intelligence", "learning",
    "design", "architecture", "development", "operating", "digital",
    "web", "mobile", "software", "compiler", "automata", "quran",
    "marketing", "management", "psychology", "commerce", "civics",
    "lab", "fundamentals", "advanced", "introduction", "applied",
    "quantum", "machine", "formal", "methods", "data", "mining",
    "patterns", "interaction", "resource", "functional", "english",
    "pre-calculus", "engagement", "community", "probability",
    "statistics", "analysis", "computing", "science", "theory",
    "information", "numerical", "discrete", "linear", "islamic",
    "studies", "professional", "ethics", "technical", "writing",
    "computer", "organization", "graphics", "visualization",
    "parallel", "distributed", "artificial", "deep",
}


# ── Helpers ────────────────────────────────────────────────────────────

def normalize_day(text: str) -> Optional[str]:
    if not text:
        return None
    match = re.search(
        r"\b(Mon|Monday|Tue|Tues|Tuesday|Wed|Wednesday|"
        r"Thu|Thur|Thurs|Thursday|Fri|Friday|"
        r"Sat|Saturday|Sun|Sunday)\b",
        text, re.IGNORECASE,
    )
    if not match:
        return None
    return DAY_NAMES.get(match.group(0).lower())


def parse_batch(text: str) -> Optional[Tuple[str, str, int, str]]:
    if not text:
        return None
    cleaned = re.sub(r"\(.*?\)", "", text).strip().replace(" ", "")
    m = BATCH_WITH_INTAKE_RE.search(cleaned)
    if m:
        intake, program, semester, section = m.groups()
        return f"{intake}-{program}-{semester}-{section}", program, int(semester), section
    m = BATCH_NO_INTAKE_RE.search(cleaned)
    if m:
        program, semester, section = m.groups()
        return f"NA-{program}-{semester}-{section}", program, int(semester), section
    return None


def parse_time_range(cell_text: str) -> Optional[Tuple[str, str]]:
    if not cell_text:
        return None
    m = TIME_RANGE_RE.search(cell_text)
    if not m:
        return None
    sh, sm, eh, em = m.groups()
    return f"{int(sh)}:{sm}", f"{int(eh)}:{em}"


def _strip_capacity(text: str) -> str:
    """Remove room capacity like (48), (77) from text."""
    return CAPACITY_RE.sub("", text).strip()


def _looks_like_subject(text: str) -> bool:
    """Heuristic: does this text look like a subject name?"""
    lower = text.lower()
    return any(kw in lower for kw in _SUBJECT_KEYWORDS)


def _match_room(text: str) -> Optional[re.Match]:
    """Try to match a room pattern in text. Returns first match or None."""
    stripped = _strip_capacity(text)
    for pat in ROOM_PATTERNS:
        m = pat.search(stripped)
        if m:
            return m
    return None


def _is_teacher_line(line: str) -> bool:
    """Detect if a line is a teacher name.

    CUI PDF formats:
      1) "CS Mr. Fayez Afzaal"   — dept + title + name
      2) "ME Zafar Farooq"       — dept + name (no title)
      3) "Mr. Fayez Afzaal"      — title + name (no dept)
      4) "MT. Ms. Sana Nasir"    — dept-with-dot + title + name
    """
    if TEACHER_TITLE_RE.search(line):
        return True
    # Dept-code + name (no title) — e.g. "ME Zafar Farooq"
    words = line.split()
    if len(words) >= 2:
        first = words[0].rstrip(".")
        if first.upper() in DEPT_CODES:
            rest = " ".join(words[1:])
            # Must not look like a subject and must look like a name
            if not _looks_like_subject(rest) and not _match_room(rest):
                return True
    return False


def _clean_teacher_name(raw: str) -> str:
    """Strip dept code prefix and capacity numbers from a teacher name.
    
    "CS Mr. Fayez Afzaal"  →  "Mr. Fayez Afzaal"
    "ME Zafar Farooq"      →  "Zafar Farooq"
    "MT. Ms. Sana Nasir"   →  "Ms. Sana Nasir"
    """
    cleaned = _strip_capacity(raw).strip()
    words = cleaned.split()
    if len(words) >= 2:
        first = words[0].rstrip(".")
        if first.upper() in DEPT_CODES:
            cleaned = " ".join(words[1:])
    return cleaned.strip()


def _is_name_continuation(line: str) -> bool:
    """Check if a line is a continuation of a teacher name that wrapped in the PDF.
    
    Teacher names like "Mr. Hafiz Muhammad Mudasar Khan" sometimes wrap:
      Line 1: "SE Mr. Hafiz Muhammad Mudasar"
      Line 2: "Khan"       ← this is the continuation
    
    Heuristic: 1-2 short words, all start with uppercase, no subject keywords,
    no room patterns, no numbers (except maybe in names like "M2").
    """
    words = line.split()
    if not words or len(words) > 2:
        return False
    # Each word should look like a proper name (starts uppercase, alphabetic)
    for w in words:
        if not w[0].isupper():
            return False
        # Must be mostly alphabetic (allow dots for initials)
        if not re.match(r"^[A-Za-z.]+$", w):
            return False
    # Must not be a subject keyword or a room
    if _looks_like_subject(line):
        return False
    if _match_room(line):
        return False
    return True


def _clean_subject(text: str) -> str:
    """Clean subject: strip capacity numbers, remove embedded room names, normalize."""
    cleaned = _strip_capacity(text)
    # Remove any embedded room patterns from subject text
    for pat in ROOM_PATTERNS:
        cleaned = pat.sub("", cleaned)
    cleaned = re.sub(r"\s{2,}", " ", cleaned).strip()
    return cleaned


# ── Cell parser ────────────────────────────────────────────────────────

def parse_class_cell(cell_text: str) -> Optional[Dict[str, str]]:
    """Parse a timetable cell into teacher, subject, room.

    CUI PDF cell structure (typically 2-4 lines):
      Line 1: Teacher (with dept prefix, with or without Mr./Ms.)
      Line 2+: Subject name (may span multiple lines)
      Last line: Room + capacity (e.g. "C1.2 (48)")

    Some cells have special lab names (Networking Lab, DLD Lab) that
    appear as a separate line or get merged into the subject.
    """
    if not cell_text:
        return None
    flat = cell_text.replace("\n", " ").strip()
    if not flat:
        return None
    if re.search(r"Break|Prayer|kaerB|reyarP", flat):
        return None

    lines = [l.strip() for l in cell_text.split("\n") if l.strip()]
    if not lines:
        return None

    teacher = "Unknown"
    room = "TBD"
    teacher_idx = -1
    teacher_cont_idx = -1  # Index of teacher name continuation line
    room_idx = -1

    # ── Pass 1: Find teacher (usually first line) ──
    for i, line in enumerate(lines):
        if _is_teacher_line(line):
            teacher = _clean_teacher_name(line)
            teacher_idx = i
            # Check if next line is a name continuation (PDF wraps long names)
            # e.g. "SE Mr. Hafiz Muhammad Mudasar" / "Khan"
            if i + 1 < len(lines):
                next_line = lines[i + 1].strip()
                if _is_name_continuation(next_line):
                    teacher = teacher + " " + next_line
                    teacher_cont_idx = i + 1
            break

    # ── Pass 2: Find room (scan from bottom up) ──
    for i in range(len(lines) - 1, -1, -1):
        if i in (teacher_idx, teacher_cont_idx):
            continue
        line = lines[i]
        stripped = _strip_capacity(line)
        m = _match_room(stripped)
        if m:
            # Check if this line is *primarily* a room
            ratio = len(m.group(0)) / max(len(stripped), 1)
            if ratio > 0.35:
                room = m.group(0)
                room_idx = i
                break

    # ── Pass 3: Assemble subject from remaining lines ──
    subject_parts: List[str] = []
    for i, line in enumerate(lines):
        if i in (teacher_idx, teacher_cont_idx):
            continue
        cleaned = _strip_capacity(line)
        if i == room_idx:
            # Remove only the room portion, keep the subject portion
            for pat in ROOM_PATTERNS:
                cleaned = pat.sub("", cleaned)
            cleaned = _strip_capacity(cleaned).strip()
        if cleaned:
            subject_parts.append(cleaned)

    subject = " ".join(subject_parts) if subject_parts else "Unknown"
    subject = _clean_subject(subject)

    if not subject or not subject.strip():
        return None

    return {"subject": subject, "teacher": teacher, "room": room}


# ── PDF → Sessions ────────────────────────────────────────────────────

def build_sessions_from_pdf(pdf_path: Path) -> List[Dict[str, str]]:
    sessions: List[Dict[str, str]] = []
    seen: set = set()
    current_day: Optional[str] = None

    with pdfplumber.open(pdf_path) as pdf:
        for page in pdf.pages:
            text = page.extract_text() or ""
            page_day = normalize_day(text)
            if page_day:
                current_day = page_day
            day = current_day

            tables = page.extract_tables()
            if not tables:
                continue

            for table in tables:
                header_idx = None
                time_columns: Dict[int, Tuple[str, str]] = {}
                for idx, row in enumerate(table):
                    if not row:
                        continue
                    found_time = False
                    for col_idx, cell in enumerate(row):
                        if cell and TIME_RANGE_RE.search(cell):
                            found_time = True
                            tr = parse_time_range(cell)
                            if tr:
                                time_columns[col_idx] = tr
                    if found_time:
                        header_idx = idx
                        break

                if header_idx is None or not time_columns:
                    continue

                for row in table[header_idx + 1:]:
                    if not row or not row[0]:
                        continue
                    batch_info = parse_batch(row[0])
                    if not batch_info:
                        continue
                    batch, program, semester, section = batch_info

                    # Walk time columns in order, detecting merged (spanning) cells.
                    # pdfplumber returns None for merged cells vs "" for empty ones.
                    # A lab spanning 2 columns: content in col N, None in col N+1.
                    col_indices = sorted(time_columns.keys())
                    i = 0
                    while i < len(col_indices):
                        col_idx = col_indices[i]
                        cell = row[col_idx] if col_idx < len(row) else None
                        parsed = parse_class_cell(cell or "")
                        if not parsed:
                            i += 1
                            continue

                        # Start with this column's time range
                        start_time = time_columns[col_idx][0]
                        end_time = time_columns[col_idx][1]

                        # Look ahead: extend into consecutive None cells (merged)
                        # but NEVER across the break period (12:45-1:40)
                        j = i + 1
                        while j < len(col_indices):
                            next_col = col_indices[j]
                            # Use sentinel for out-of-bounds (not a merge)
                            next_cell = row[next_col] if next_col < len(row) else "ABSENT"
                            next_tr = time_columns[next_col]
                            is_break = (next_tr[0] == "12:45")
                            # Extend ONLY if: cell is None (merged), consecutive, not break
                            if next_cell is None and end_time == next_tr[0] and not is_break:
                                end_time = next_tr[1]
                                j += 1
                            else:
                                break
                        i = j  # skip past any merged columns

                        session = {
                            "batch": batch,
                            "day": day or "Monday",
                            "start": start_time,
                            "end": end_time,
                            "subject": parsed["subject"],
                            "teacher": parsed["teacher"],
                            "room": parsed["room"],
                        }
                        dedup_key = (
                            session["batch"], session["day"],
                            session["start"], session["end"],
                            session["subject"], session["teacher"],
                            session["room"],
                        )
                        if dedup_key not in seen:
                            seen.add(dedup_key)
                            sessions.append(session)

    # ── Post-processing: merge sessions that span across the break ──
    # Some labs/lectures span 3 columns (pre-break + break + post-break).
    # The parser extracts them as 2 separate sessions: 11:20-12:45 and 1:40-X.
    # Merge them: if same batch+day+subject+teacher+room, and one ends at 12:45
    # and the other starts at 1:40, combine into a single session.
    sessions = _merge_cross_break_sessions(sessions)

    return sessions


def _merge_cross_break_sessions(sessions: List[Dict[str, str]]) -> List[Dict[str, str]]:
    """Merge session pairs that span across the prayer break."""
    from collections import defaultdict

    # Group by (batch, day, subject, teacher, room)
    groups: Dict[tuple, List[Dict[str, str]]] = defaultdict(list)
    for s in sessions:
        key = (s["batch"], s["day"], s["subject"], s["teacher"], s["room"])
        groups[key].append(s)

    merged: List[Dict[str, str]] = []
    for key, group in groups.items():
        if len(group) == 2:
            a, b = group
            # Check if one ends at 12:45 and the other starts at 1:40
            if a["end"] == "12:45" and b["start"] == "1:40":
                merged.append({**a, "end": b["end"]})
                continue
            if b["end"] == "12:45" and a["start"] == "1:40":
                merged.append({**b, "end": a["end"]})
                continue
        merged.extend(group)

    return merged


# ── Registry merge ─────────────────────────────────────────────────────

def key_from_batch(batch: str) -> str:
    parts = batch.split("-")
    if len(parts) >= 4:
        return f"{parts[1]}-{parts[2]}-{parts[3]}"
    if len(parts) == 3:
        return f"{parts[0]}-{parts[1]}-{parts[2]}"
    return batch


def main() -> None:
    if not PDF_PATH.exists():
        raise SystemExit(f"PDF not found: {PDF_PATH}")

    new_sessions = build_sessions_from_pdf(PDF_PATH)
    if not new_sessions:
        raise SystemExit("No sessions extracted from PDF.")

    new_keys = {key_from_batch(s["batch"]) for s in new_sessions}

    # Load existing registry (preserve non-overlapping batches)
    if SEED_PATH.exists():
        existing = json.loads(SEED_PATH.read_text(encoding="utf-8"))
    else:
        existing = []

    merged: List[Dict[str, str]] = []
    for item in existing:
        if key_from_batch(item.get("batch", "")) not in new_keys:
            merged.append(item)
    merged.extend(new_sessions)
    merged.sort(key=lambda s: (s.get("batch", ""), s.get("day", ""), s.get("start", "")))

    SEED_PATH.write_text(json.dumps(merged, indent=2), encoding="utf-8")

    # ── Stats ──
    unknown_t = sum(1 for s in new_sessions if s["teacher"] == "Unknown")
    tbd_r = sum(1 for s in new_sessions if s["room"] == "TBD")
    batches = sorted({s["batch"] for s in new_sessions})
    days = {}
    for s in new_sessions:
        days[s["day"]] = days.get(s["day"], 0) + 1

    print(f"\n{'='*60}")
    print(f"  SMART PARSER RESULTS")
    print(f"{'='*60}")
    print(f"  Sessions extracted : {len(new_sessions)}")
    print(f"  Total in registry  : {len(merged)}")
    print(f"  Unique batches     : {len(batches)}")
    print(f"  Unknown teachers   : {unknown_t}")
    print(f"  TBD rooms          : {tbd_r}")
    print(f"  Day distribution   : {days}")
    print(f"{'='*60}")

    if unknown_t > 0:
        print(f"\n  ⚠️  Sessions with Unknown teacher:")
        for s in new_sessions:
            if s["teacher"] == "Unknown":
                print(f"     {s['batch']} | {s['day']} {s['start']}-{s['end']} | sub={s['subject']}")

    if tbd_r > 0:
        print(f"\n  ⚠️  Sessions with TBD room:")
        for s in new_sessions:
            if s["room"] == "TBD":
                print(f"     {s['batch']} | {s['day']} {s['start']}-{s['end']} | sub={s['subject']} | teacher={s['teacher']}")


if __name__ == "__main__":
    main()
