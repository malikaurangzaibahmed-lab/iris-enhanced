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

PDF_PATHS = [
    Path(r"D:\Flutter\student_organizer\assets\CS-12-1.pdf"),
    Path(r"D:\Flutter\student_organizer\assets\CE-1.pdf"),
    Path(r"D:\Flutter\student_organizer\assets\EE.pdf"),
    Path(r"D:\Flutter\student_organizer\assets\FSn,BTY,BCH,HND,RBS.pdf"),
    Path(r"D:\Flutter\student_organizer\assets\HUM-1.pdf"),
    Path(r"D:\Flutter\student_organizer\assets\ME-1.pdf"),
    Path(r"D:\Flutter\student_organizer\assets\MS-2.pdf"),
]
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
DEPT_CODES = {
    "CS", "SE", "MS", "EE", "ME", "CVE", "BBA", "MBA", "MT", "VS",
    "HUM", "CE", "BI",
}

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
    re.compile(r"\bBio\s+Lab\b", re.IGNORECASE),
    re.compile(r"\bFP\s+Lab\b", re.IGNORECASE),
    re.compile(r"\bFA\s+Lab\b", re.IGNORECASE),
    re.compile(r"\bDigital\s+Lab\b", re.IGNORECASE),
    re.compile(r"\bElectric\s+Machines\s+Lab\b", re.IGNORECASE),
    re.compile(r"\bMechanical\s+Vibrations\s+Lab\b", re.IGNORECASE),
    re.compile(r"\bIC\s+Engines\s+Lab\b", re.IGNORECASE),
    re.compile(r"\bHMT\s+Lab\b", re.IGNORECASE),
    re.compile(r"\bThermodynamics\s+Lab\b", re.IGNORECASE),
    re.compile(r"\bThermo\s+Lab\b", re.IGNORECASE),
    re.compile(r"\bFluid\s+Mechanics\s+Lab\b", re.IGNORECASE),
    re.compile(r"\bPower\s+Lab\b", re.IGNORECASE),
    re.compile(r"\bC\s*&\s*E\s+Lab\b", re.IGNORECASE),
    re.compile(r"\bD\s*Block\s+Seminar\s+Room\b", re.IGNORECASE),
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
    
    # Handle 2-part batch formats like FA25-RBS, SP26-RHND (common for research/special programs)
    parts = [p for p in cleaned.split("-") if p]
    if len(parts) == 2 and re.match(r"^[A-Z]{2}\d{2}$", parts[0]):
        intake, program = parts
        # Research/special programs (RBS, RHND, RMS, PMS, PCS, RCS) - assign section 01, semester 1
        if program in {"RBS", "RHND", "RMS", "PMS", "PCS", "RCS"}:
            return f"{intake}-{program}-01", program, 1, "01"
        # Regular programs missing section - assign default section 01, semester extracted from intake
        semester_num = 1  # Default for new intakes
        return f"{intake}-{program}-01", program, semester_num, "01"
    
    # Fallback: keep as-is for non-standard batch formats
    if len(parts) >= 2 and re.match(r"^[A-Z]{2}\d{2}$", parts[0]):
        program = parts[1]
        return cleaned, program, 0, "?"
    if len(parts) >= 2:
        program = parts[0]
        return cleaned, program, 0, "?"
    return None


def _extract_department_from_text(text: str) -> Optional[str]:
    if not text:
        return None
    words = text.split()
    if not words:
        return None
    first = words[0].rstrip(".").upper()
    if first in DEPT_CODES:
        return first
    return None


def detect_department(batch_program: Optional[str], row: List[Optional[str]]) -> Optional[str]:
    if batch_program:
        return batch_program
    for cell in row[1:]:
        if not cell:
            continue
        for line in cell.split("\n"):
            dept = _extract_department_from_text(line.strip())
            if dept:
                return dept
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


def _clean_teacher_name(raw: str) -> tuple[str, str]:
    """Strip dept code prefix and capacity numbers from a teacher name.
    Also extract subject abbreviations that appear after teacher names.
    
    Returns: (cleaned_teacher_name, extracted_subject_code)
    
    "CS Mr. Fayez Afzaal"  →  ("Mr. Fayez Afzaal", "")
    "ME Zafar Farooq"      →  ("Zafar Farooq", "")
    "MT. Ms. Sana Nasir"   →  ("Ms. Sana Nasir", "")
    "Dr. Saqib Ali CRM"    →  ("Dr. Saqib Ali", "CRM")
    """
    cleaned = _strip_capacity(raw).strip()
    words = cleaned.split()
    if len(words) >= 2:
        first = words[0].rstrip(".")
        if first.upper() in DEPT_CODES:
            cleaned = " ".join(words[1:])
    
    # If last word is a short all-caps abbreviation (likely a subject), extract it
    # Common subject abbreviations: CRM, HRM, SCM, etc. (2-4 chars, all uppercase)
    subject_code = ""
    words = cleaned.split()
    if len(words) >= 3:  # At least title + name + abbreviation
        last_word = words[-1].strip()
        if re.match(r'^[A-Z]{2,4}$', last_word) and last_word not in DEPT_CODES:
            # This looks like a subject abbreviation, not part of the name
            subject_code = last_word
            cleaned = " ".join(words[:-1])
    
    return cleaned.strip(), subject_code


def _is_name_continuation(line: str) -> bool:
    """Check if a line is a continuation of a teacher name that wrapped in the PDF.
    
    Teacher names like "Mr. Hafiz Muhammad Mudasar Khan" sometimes wrap:
      Line 1: "SE Mr. Hafiz Muhammad Mudasar"
      Line 2: "Khan"       ← this is the continuation
    
    Name continuations are typically single words (rarely 2 words for compound names).
    Multi-word lines are almost always subjects, not name parts.
    
    Heuristic: 1-2 short words, all start with uppercase, no subject keywords,
    no room patterns, no numbers. Must look like a typical last name.
    """
    words = line.split()
    if not words:
        return False
    
    # Reject abbreviated subject patterns like "App. Grmr", "Appl. Gram", "Diff. Eq."
    # Pattern: Word. Word where both are short abbreviations/truncations
    if len(words) >= 2 and words[0].endswith('.'):
        # If first word ends with period and next word is also capitalized,
        # and both are short, it's likely an abbreviated subject
        if len(words[0]) <= 6 and len(words[1]) <= 6 and words[0][0].isupper() and words[1][0].isupper():
            # "App. Grmr" → ['App.', 'Grmr'] - 4 + 4 chars
            return False
    
    # Reject multi-word lines (2+ words) - these are almost always subjects
    # Exception: Allow only if both words are very short (like "Al Khan", "De Silva")
    if len(words) >= 2:
        # If any word is longer than 5 chars, it's likely a subject
        if any(len(w) > 5 for w in words):
            return False
        # If total length > 12 chars, it's likely a subject
        if len(line) > 12:
            return False
    
    # Reject lines with period followed by space and uppercase (abbreviated subjects)
    # Examples: "M. Drama", "L. Stylstcs", "IC Engines"
    if re.match(r'^[A-Z]+\.\s+[A-Z]', line):
        return False
    
    # Reject short all-caps abbreviations (likely subject codes like "CRM", "HRM", "SCM")
    if len(words) == 1 and 2 <= len(words[0]) <= 4 and words[0].isupper() and words[0] not in DEPT_CODES:
        return False
    
    # Reject single words that look like English subject names (title case, longer than 5 chars)
    # Typical Pakistani/Arabic last names: Khan, Ali, Shah, Ahmed (short, not descriptive)
    # Subject names: Chinese, Marketing, Finance, etc. (descriptive words)
    if len(words) == 1:
        word = words[0]
        # If it's longer than 6 chars and looks like an English word (not an abbreviation),
        # it's probably a subject, not a name
        if len(word) > 6 and word[0].isupper() and word[1:].islower():
            # Check if it's a common English word (heuristic: contains common vowel patterns)
            vowel_count = sum(1 for c in word.lower() if c in 'aeiou')
            if vowel_count >= 2:  # "Chinese" has 3, "Khan" has 1, "Ahmed" has 2
                return False
    
    # Each word should look like a proper name (starts uppercase, alphabetic)
    for w in words:
        if not w[0].isupper():
            return False
        # Must be mostly alphabetic (allow dots for initials)
        if not re.match(r"^[A-Z][a-z]*\.?$", w):
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
    if re.search(r"Break|kaerB", flat):
        return None

    lines = [l.strip() for l in cell_text.split("\n") if l.strip()]
    if not lines:
        return None

    teacher = "Unknown"
    room = "TBD"
    extracted_subject = ""  # Subject code extracted from teacher name
    teacher_idx = -1
    teacher_cont_idx = -1  # Index of teacher name continuation line
    room_idx = -1

    # ── Pass 1: Find teacher (usually first line) ──
    for i, line in enumerate(lines):
        if _is_teacher_line(line):
            teacher, extracted_subject = _clean_teacher_name(line)
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

    subject = " ".join(subject_parts) if subject_parts else extracted_subject or "Unknown"
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
                    department = detect_department(program, row)

                    # Walk time columns in order, detecting merged (spanning) cells.
                    # pdfplumber returns None for merged cells vs "" for empty ones.
                    # A lab spanning 2 columns: content in col N, None in col N+1.
                    col_indices = sorted(time_columns.keys())
                    i = 0
                    while i < len(col_indices):
                        col_idx = col_indices[i]
                        cell = row[col_idx] if col_idx < len(row) else None
                        # Skip the break column entirely (12:00-1:00)
                        if time_columns[col_idx][0] == "12:00":
                            i += 1
                            continue
                        parsed = parse_class_cell(cell or "")
                        if not parsed:
                            i += 1
                            continue

                        # Start with this column's time range
                        start_time = time_columns[col_idx][0]
                        end_time = time_columns[col_idx][1]

                        # Look ahead: extend into consecutive None cells (merged)
                        # but NEVER across the break period (12:00-1:00)
                        j = i + 1
                        while j < len(col_indices):
                            next_col = col_indices[j]
                            # Use sentinel for out-of-bounds (not a merge)
                            next_cell = row[next_col] if next_col < len(row) else "ABSENT"
                            next_tr = time_columns[next_col]
                            is_break = (next_tr[0] == "12:00")
                            # Extend ONLY if: cell is None (merged), consecutive, not break
                            if next_cell is None and end_time == next_tr[0] and not is_break:
                                end_time = next_tr[1]
                                j += 1
                            else:
                                break
                        i = j  # skip past any merged columns

                        session = {
                            "department": department or "Unknown",
                            "batch": batch,
                            "day": day or "Monday",
                            "start": start_time,
                            "end": end_time,
                            "subject": parsed["subject"],
                            "teacher": parsed["teacher"],
                            "room": parsed["room"],
                        }
                        
                        # Handle "(1 hr)" marker - adjust end time to be exactly 1 hour from start
                        if "(1 hr)" in parsed["subject"].lower() or "(1hr)" in parsed["subject"].lower():
                            # Parse start time and add 1 hour
                            h, m = start_time.split(':')
                            start_decimal = int(h) + int(m) / 60.0
                            end_decimal = start_decimal + 1.0  # Add exactly 1 hour
                            end_h = int(end_decimal)
                            end_m = int((end_decimal - end_h) * 60)
                            session["end"] = f"{end_h}:{end_m:02d}"
                        
                        dedup_key = (
                            session["department"], session["batch"], session["day"],
                            session["start"], session["end"],
                            session["subject"], session["teacher"],
                            session["room"],
                        )
                        if dedup_key not in seen:
                            seen.add(dedup_key)
                            sessions.append(session)

    # ── Post-processing: merge sessions that span across the break ──
    # For Ramadan schedule (1-hour slots, 12:00-1:00 break), we DON'T merge
    # sessions across the break to show them accurately as separate sessions.
    # This allows labs to display as: 11:00-12:00 + 1:00-2:00 (separate entries)
    # instead of merged 11:00-2:00.
    # sessions = _merge_cross_break_sessions(sessions)

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
            # Don't merge if either session has "(1 hr)" marker
            has_1hr_marker = "(1 hr)" in a["subject"].lower() or "(1hr)" in a["subject"].lower()
            if has_1hr_marker:
                merged.extend(group)
                continue
            
            # Check if one ends at 12:00 and the other starts at 1:00
            if a["end"] == "12:00" and b["start"] == "1:00":
                merged.append({**a, "end": b["end"]})
                continue
            if b["end"] == "12:00" and a["start"] == "1:00":
                merged.append({**b, "end": a["end"]})
                continue
        merged.extend(group)

    return merged


# ── Registry merge ─────────────────────────────────────────────────────

def key_from_batch(batch: str) -> str:
    parts = batch.split("-")
    if len(parts) >= 2 and re.match(r"^[A-Z]{2}\d{2}$", parts[0]):
        return "-".join(parts[1:])
    return batch


def main() -> None:
    missing = [p for p in PDF_PATHS if not p.exists()]
    if missing:
        missing_list = "\n".join(str(p) for p in missing)
        raise SystemExit(f"Missing PDF(s):\n{missing_list}")

    new_sessions: List[Dict[str, str]] = []
    for pdf_path in PDF_PATHS:
        new_sessions.extend(build_sessions_from_pdf(pdf_path))
    if not new_sessions:
        raise SystemExit("No sessions extracted from PDFs.")

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
    departments = {}
    for s in new_sessions:
        days[s["day"]] = days.get(s["day"], 0) + 1
        departments[s.get("department", "Unknown")] = departments.get(s.get("department", "Unknown"), 0) + 1

    print(f"\n{'='*60}")
    print(f"  SMART PARSER RESULTS")
    print(f"{'='*60}")
    print(f"  Sessions extracted : {len(new_sessions)}")
    print(f"  Total in registry  : {len(merged)}")
    print(f"  Unique batches     : {len(batches)}")
    print(f"  Unknown teachers   : {unknown_t}")
    print(f"  TBD rooms          : {tbd_r}")
    print(f"  Day distribution   : {days}")
    print(f"  Dept distribution  : {departments}")
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
