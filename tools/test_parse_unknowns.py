from tools.process_pdf_registry import parse_class_cell, _is_name_continuation, _is_teacher_line

test_cells = [
    """HUM M.Badar Iqbal
M. Drama
B5 (40)""",
    """VS Mehwish Liaqat
L. Stylstcs
B8 (40)""",
    """CS Saiqa Hafeez
Power Plants
W1 (73)""",
    """ME Dr. Ali Raza
IC Engines
A1.1 (63)""",
    """MS Syed Ali Ashiq Kirmani
Corporate Governance
B11 (40)""",
]

for i, cell in enumerate(test_cells, 1):
    print(f"\n=== Test {i} ===")
    lines = [l.strip() for l in cell.split('\n') if l.strip()]
    print(f"Lines: {lines}")
    
    for j, line in enumerate(lines):
        print(f"  Line {j}: {repr(line)}")
        print(f"    is_teacher: {_is_teacher_line(line)}")
        print(f"    is_continuation: {_is_name_continuation(line)}")
    
    result = parse_class_cell(cell)
    print(f"Result: {result}")
