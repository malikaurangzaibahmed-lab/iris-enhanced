from tools.process_pdf_registry import _clean_teacher_name

test_cases = [
    "Dr. Saqib Ali CRM",
    "Mr. Fayez Afzaal",
    "CS Dr. Ahmad Hassan HRM",
]

for test in test_cases:
    result = _clean_teacher_name(test)
    print(f"{test:30} → {result}")
