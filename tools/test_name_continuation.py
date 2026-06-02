"""Test the _is_name_continuation function with edge cases"""
import re

DEPT_CODES = {
    "CS", "SE", "MS", "EE", "ME", "CVE", "BBA", "MBA", "MT", "VS",
    "HUM", "CE", "BI",
}

def _looks_like_subject(text: str) -> bool:
    subject_keywords = {
        'seminar', 'project', 'course', 'lab', 'workshop', 'thesis', 'assignment',
        'class', 'lecture', 'session', 'tutorial', 'exam', 'test', 'practical',
        'english', 'english (', 'communication', 'composition', 'academic', 'professional',
    }
    return any(kw in text.lower() for kw in subject_keywords)

def _match_room(text: str) -> bool:
    # Simple room pattern check
    room_patterns = [r'^[A-Z]\d+', r'Lab', r'Room']
    return any(re.search(p, text) for p in room_patterns)

def _is_name_continuation(line: str) -> bool:
    """Check if a line is a continuation of a teacher name."""
    words = line.split()
    if not words:
        return False
    
    # Reject multi-word lines (2+ words)
    if len(words) >= 2:
        if any(len(w) > 5 for w in words):
            return False
        if len(line) > 12:
            return False
    
    # Reject lines with period followed by space and uppercase
    print(f"  Testing '{line}':")
    print(f"    Matches ^[A-Z]+\\.\\s+[A-Z]: {bool(re.match(r'^[A-Z]+\\.\\s+[A-Z]', line))}")
    if re.match(r'^[A-Z]+\.\s+[A-Z]', line):
        print(f"    → REJECTED (abbreviated subject pattern)")
        return False
    
    # Reject all-caps abbreviations
    if len(words) == 1 and 2 <= len(words[0]) <= 4 and words[0].isupper() and words[0] not in DEPT_CODES:
        print(f"    → REJECTED (all-caps abbreviation)")
        return False
    
    # Reject descriptive English words
    if len(words) == 1:
        word = words[0]
        if len(word) > 6 and word[0].isupper() and word[1:].islower():
            vowel_count = sum(1 for c in word.lower() if c in 'aeiou')
            if vowel_count >= 2:
                print(f"    → REJECTED (English word with {vowel_count} vowels)")
                return False
    
    # Each word should look like proper name
    for w in words:
        if not w[0].isupper():
            print(f"    → REJECTED (word doesn't start uppercase: {w})")
            return False
        if not re.match(r"^[A-Z][a-z]*\.?$", w):
            print(f"    → REJECTED (word doesn't match name pattern: {w})")
            return False
    
    if _looks_like_subject(line):
        print(f"    → REJECTED (looks like subject)")
        return False
    if _match_room(line):
        print(f"    → REJECTED (looks like room)")
        return False
    
    print(f"    ✓ ACCEPTED as name continuation")
    return True

# Test cases
test_cases = [
    "App. Grmr",      # Should be REJECTED as subject
    "App.Grmr",       # Should be REJECTED as subject
    "Applied Grammar", # Should be REJECTED as subject
    "Khan",           # Should be ACCEPTED as name
    "Ali",            # Should be ACCEPTED as name
    "Dr. Ali",        # Should be REJECTED (starts with title doesn't work here)
    "M. Grmr",        # Should be REJECTED as abbreviated subject
    "Grmr",           # Should be REJECTED as subject
]

print("Testing _is_name_continuation:\n")
for test in test_cases:
    result = _is_name_continuation(test)
    print()
