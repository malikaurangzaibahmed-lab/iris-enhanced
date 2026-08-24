import re
from datetime import datetime, date

sample_dates = [
    "Aug 31 – Sep 4, 2026 (Mon–Fri)",
    "Sep 7, 2026 (Mon)",
    "Oct 2, 2026 (Fri)",
    "Oct 23, 2026 (Fri)",
    "Nov 2, 2026 (Mon)",
    "Nov 9–14, 2026 (Mon–Sat)",
    "Dec 28, 2026 (Mon)",
    "Dec 31, 2026 (Thu)",
    "Jan 28, 2027 (Thu)",
    "One week before Spring 2027",
    "Feb 15, 2027 (Mon)",
    "2026-09-07",
    "2026-08-31 to 2026-09-04",
    "Jul 1–5, 2027 (Thu–Mon)",
    "Jul 6, 2027 (Tue)",
    "Aug 21, 2027 (Sat)"
]

month_map = {
    'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6,
    'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12
}

def parse_milestone_dates(date_str, now=date(2026, 8, 24)):
    clean = date_str.replace('–', '-').replace('—', '-').strip()
    
    # ISO date range: YYYY-MM-DD to YYYY-MM-DD
    iso_range = re.search(r'(\d{4})-(\d{1,2})-(\d{1,2})\s*(?:to|-)\s*(\d{4})-(\d{1,2})-(\d{1,2})', clean)
    if iso_range:
        s = date(int(iso_range.group(1)), int(iso_range.group(2)), int(iso_range.group(3)))
        e = date(int(iso_range.group(4)), int(iso_range.group(5)), int(iso_range.group(6)))
        return s, e

    # Single ISO date: YYYY-MM-DD
    iso_single = re.search(r'(\d{4})-(\d{1,2})-(\d{1,2})', clean)
    if iso_single:
        s = date(int(iso_single.group(1)), int(iso_single.group(2)), int(iso_single.group(3)))
        return s, s

    # Multi-month range: Aug 31 - Sep 4, 2026
    multi_month = re.search(r'([A-Za-z]{3,9})\s+(\d{1,2})\s*-\s*([A-Za-z]{3,9})\s+(\d{1,2})(?:[,\s]+(\d{4}))?', clean)
    if multi_month:
        m1_name = multi_month.group(1)[:3].lower()
        d1 = int(multi_month.group(2))
        m2_name = multi_month.group(3)[:3].lower()
        d2 = int(multi_month.group(4))
        year = int(multi_month.group(5)) if multi_month.group(5) else now.year
        if m1_name in month_map and m2_name in month_map:
            m1 = month_map[m1_name]
            m2 = month_map[m2_name]
            # If cross-year (e.g. Dec - Jan)
            y2 = year + 1 if m2 < m1 else year
            return date(year, m1, d1), date(y2, m2, d2)

    # Same-month range: Nov 9-14, 2026 or Jul 1-5, 2027
    same_month = re.search(r'([A-Za-z]{3,9})\s+(\d{1,2})\s*-\s*(\d{1,2})(?:[,\s]+(\d{4}))?', clean)
    if same_month:
        m_name = same_month.group(1)[:3].lower()
        d1 = int(same_month.group(2))
        d2 = int(same_month.group(3))
        year = int(same_month.group(4)) if same_month.group(4) else now.year
        if m_name in month_map:
            m = month_map[m_name]
            return date(year, m, d1), date(year, m, d2)

    # Single month date: Sep 7, 2026 (Mon) or Oct 2, 2026
    single_month = re.search(r'([A-Za-z]{3,9})\s+(\d{1,2})(?:[,\s]+(\d{4}))?', clean)
    if single_month:
        m_name = single_month.group(1)[:3].lower()
        d = int(single_month.group(2))
        year = int(single_month.group(3)) if single_month.group(3) else now.year
        if m_name in month_map:
            m = month_map[m_name]
            return date(year, m, d), date(year, m, d)

    return None, None

def evaluate_status(date_str, today=date(2026, 8, 24)):
    s, e = parse_milestone_dates(date_str, today)
    if not s or not e:
        return 'upcoming', f"Unparseable date: '{date_str}'"
    if today > e:
        return 'completed', f"Passed on {e.strftime('%b %d, %Y')}"
    elif s <= today <= e:
        return 'active', f"Happening now ({s.strftime('%b %d')} - {e.strftime('%b %d')})"
    else:
        diff = (s - today).days
        return 'upcoming', f"Starts in {diff} days ({s.strftime('%b %d, %Y')})"

print("--- Testing Today = 2026-08-24 ---")
for d in sample_dates:
    status, note = evaluate_status(d, date(2026, 8, 24))
    print(f"[{status.upper():9}] {d:32} -> {note}")

print("\n--- Testing Future Simulation Today = 2026-09-10 ---")
for d in sample_dates[:6]:
    status, note = evaluate_status(d, date(2026, 9, 10))
    print(f"[{status.upper():9}] {d:32} -> {note}")

print("\n--- Testing Future Simulation Today = 2026-11-10 (Student Week) ---")
for d in sample_dates[:7]:
    status, note = evaluate_status(d, date(2026, 11, 10))
    print(f"[{status.upper():9}] {d:32} -> {note}")
