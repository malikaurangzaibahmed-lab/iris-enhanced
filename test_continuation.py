from tools.process_pdf_registry import _is_name_continuation

test_cases = [
    "Chinese",
    "Khan",
    "Ahmed",
    "CRM",
    "HRM",
    "Marketing",
    "Finance",
    "Ali",
]

for test in test_cases:
    result = _is_name_continuation(test)
    vowels = sum(1 for c in test.lower() if c in 'aeiou')
    print(f"{test:15} len={len(test):2} vowels={vowels} → {result}")
