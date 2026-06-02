from tools.process_pdf_registry import _is_teacher_line, _is_name_continuation, _clean_teacher_name

cell_text = """MS Dr. Saqib Ali
CRM
B5 (40)"""

lines = [l.strip() for l in cell_text.split("\n") if l.strip()]
print(f"Lines: {lines}\n")

for i, line in enumerate(lines):
    is_teacher = _is_teacher_line(line)
    is_continuation = _is_name_continuation(line)
    print(f"Line {i}: {repr(line)}")
    print(f"  - is_teacher: {is_teacher}")
    print(f"  - is_continuation: {is_continuation}")
    if is_teacher:
        cleaned = _clean_teacher_name(line)
        print(f"  - cleaned: {cleaned}")
        if i + 1 < len(lines):
            next_line = lines[i + 1]
            is_next_continuation = _is_name_continuation(next_line)
            print(f"  - next line: {repr(next_line)}, is_continuation: {is_next_continuation}")
    print()
