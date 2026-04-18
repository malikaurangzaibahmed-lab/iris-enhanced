from tools.process_pdf_registry import parse_class_cell

# Test case from PDF
cell_text = """MS Dr. Saqib Ali
CRM
B5 (40)"""

print("Testing cell:")
print(repr(cell_text))
print()

result = parse_class_cell(cell_text)
print("Result:", result)
