# PDF Parser Test Results & Analysis

## Summary
Testing the PDF parser against the actual ME (9).pdf, CVE.pdf, and EE (4).pdf files to identify extraction quality and remaining gaps.

---

## Test 1: ME (9).pdf

### Data Structure Found
- **Extracted text format**: PDF contains timetable with subject, teacher, room, and times
- **Time slots**: 5 main slots (1-5) with specific times:
  - Slot 1: 8:30 - 9:55
  - Slot 2: 9:55 - 11:20
  - Slot 3: 11:20 - 12:45
  - Break: 12:45 - 1:40
  - Slot 4: 1:40 - 3:05
  - Slot 5: 3:05 - 4:30

- **Days covered**: Monday, Tuesday, Wednesday, Thursday, Friday (inferred from standard timetable)

- **Batch info**: Multiple batches in single PDF
  - FA25-BSME-B21-A (29 students)
  - FA24-BSME-B20-A (14 students)
  - FA23-BSME-B19-A (28 students)
  - FA22-BSME-B18-A (32 students)

### Data Sample from Extracted Text
From Page 1:
```
Monday
1 (8:30-9:55):    Programming Fundamentals | ME Khawar Hussain | A1.1 (63)
2 (9:55-11:20):   Linear Algebra... | MT Dr. Najma | W3 (73)
3 (11:20-12:45):  Introduction to Chemistry | EE Maham Fatima | A3 (63)
4 (1:40-3:05):    Mechanics of Materials Lab | ME M Naveed | MOM Lab
5 (3:05-4:30):    Computer Aided Design Lab | ME Dr. Ali Raza | CLab-8
```

### Sample Parsing Results Expected

| Session | Day | Slot | Time | Subject | Teacher | Room | Status |
|---------|-----|------|------|---------|---------|------|--------|
| 1 | Monday | 1 | 8:30-9:55 | Programming Fundamentals | Khawar Hussain | A1.1 | ✅ Should parse |
| 2 | Monday | 2 | 9:55-11:20 | Linear Algebra & Diff Eq | Dr. Najma | W3 | ✅ Should parse |
| 3 | Monday | 3 | 11:20-12:45 | Intro to Chemistry (1hr) | Maham Fatima | A3 | ✅ Should parse |
| 4 | Monday | 4 | 1:40-3:05 | Mechanics of Materials Lab | M Naveed | MOM Lab | ⚠️ Multi-word room |
| 5 | Monday | 5 | 3:05-4:30 | CAD & Manufacturing Lab | Dr. Ali Raza | CLab-8 | ✅ Should parse |

### Key Observations

1. **Room Names**: Mix of formats
   - Single cell: `A1.1` ✅
   - Lab names: `CLab-8`, `MOM Lab`, `EFM Lab` (multi-word) ⚠️
   - Full name: `Mechanical Vibrations Lab` (very long) ⚠️

2. **Teacher Names**: Various formats
   - With title: `Dr. Najma`, `Dr. Ali Raza`, `Dr M Abid` ✅
   - With prefix: `Engr. Hafiz Ammar Zahid` ✅
   - Just first name: `M Naveed`, `Khawar Hussain` ✅
   - Very long names: Currently in "Teacher/Subject" boundary

3. **Subject Names**: Long, sometimes with (duration) notation
   - `Programming Fundamentals` ✅
   - `Linear Algebra and Differential Equation` (long) ✅
   - `Introduction to Chemistry (1hr)` (has duration) ✅
   - `Computer Aided Design and Manufacturing Lab` (very long) ✅
   - Multi-line: "Engineering Drawing and Graphics (1 Hour)" ⚠️

4. **Batch Parsing**: 
   - Format: `FA25-BSME-B21-A` means Batch FA25, Program BSME, Semester B21, Section A
   - Multiple batches in one PDF → Need to separate per-batch extraction
   - Current parser: `BatchKey.parse("ME-2022")` extracts `{program: "ME", semester: 2022, section: "A"}`
   - **Gap**: PDF has multiple batches but parser expects single batch per call

### Parsing Confidence Estimate

**Expected Confidence by Field:**
- Time (8:30-9:55 format): **95%** - Clear numeric pattern with dash
- Day (Monday-Friday): **95%** - Clear regex match
- Subject: **75%** - Long names sometimes merged with teacher
- Teacher: **70%** - Mixed naming conventions, sometimes unclear boundaries  
- Room: **80%** - Mostly alphanumeric, but multi-word labs cause issues

**Overall Average for ME PDF**: ~83% confidence expected

---

## Remaining Parser Gaps Identified

### 1. **Batch-Aware Extraction** (HIGH PRIORITY)
- **Issue**: PDF contains multiple batches (FA25, FA24, FA23, FA22)
- **Current**: Parser takes a single `currentBatch` parameter
- **Solution Needed**: Either:
  - Parse all batches from PDF and return separate session lists
  - Add batch field detection to regex patterns
  - Pre-process to identify which batch is being scheduled

### 2. **Multi-Word Room Names** (MEDIUM PRIORITY)
- **Issue**: Rooms like "Engineering Fluid Mechanics Lab", "Mechanical Vibrations Lab" (20+ chars)
- **Current regex**: `[A-Z]{1,3}-?\d{1,3}` → only matches `A1.1` style
- **Examples missing**:
  - `CLab-8`, `MOM Lab`, `EFM Lab`, `Mechanical Vibrations Lab`
- **Fix**: Add pattern like `\b([A-Za-z\s]+\s+Lab|[A-Z]\d+\.[A-Z]?)\b`

### 3. **Duration Notation in Subject** (LOW PRIORITY)
- **Issue**: `"Introduction to Chemistry (1hr)"` includes time notation
- **Current**: Parser treats full string as subject
- **Solution**: Regex to extract `(1hr)`, `(1 Hour)` and store separately if needed

### 4. **Teacher/Subject Boundary** (HIGH PRIORITY)
- **Issue**: Long subject names sometimes merge with teacher name
  - Extracted: `"Engineering Drawing and Graphics | ME Zafar Farooq"`
  - Expected separation: Subject | Teacher | Room
- **Current**: Splits by double-space or `|`
- **Problem**: Some subjects are 3+ words without clear boundaries
- **Solution**: Use contextual heuristics:
  - Subject usually starts each entry
  - Teacher almost always has "Dr.", "Prof.", "Engr.", or initials
  - Room is numeric or ends with "Lab"

### 5. **Multi-Line Subject Names** (MEDIUM PRIORITY)
- **Issue**: Subject spans 2+ lines in table cell
  - Example: "Computer Aided Design and\nManufacturing (1 Hour)"
- **Current**: Might treat as separate rows
- **Solution**: Detect continued subjects across line breaks using paragraph context

### 6. **Table vs. Text Extraction Order** (CRITICAL)
- **Issue**: PDF has both text AND table layout
- **Current**: `PdfTextExtractor` gets raw text, may not preserve table order
- **Problem**: Text from page 1-3 may interleave, not respect table structure
- **Observation**: The `.tables.txt` file shows structured table extraction works better
- **Solution**: Consider using table-aware PDF parsing instead of raw text extraction

---

## Specific Field Examples Needing Verification

### Subjects to Test Parser Against
✅ = Expected to work
⚠️  = Uncertain/may need tuning
❌ = Likely to fail

- ✅ Programming Fundamentals
- ✅ Linear Algebra and Differential Equation  
- ⚠️ Computer Aided Design and Manufacturing Lab (very long)
- ⚠️ Engineering Fluid Mechanics – I (with dash character)
- ✅ Statistics and Probability Theory
- ⚠️ Introduction to Entrepreneurship (1 Hour) (with duration)
- ✅ Machine Learning
- ⚠️ Business Communication
- ⚠️ Finite Element Analysis

### Teachers to Test Parser Against
- ✅ Khawar Hussain
- ✅ Dr. Najma
- ✅ Dr. Ali Raza
- ✅ Dr M Abid (missing period after Dr)
- ⚠️ Engr. Hafiz Ammar Zahid (long name with title)
- ✅ Hassan Iqbal
- ✅ Salman Nawaz
- ⚠️ Dr. Muhammad Rafi Raza (long name)
- ✅ M Naveed (single letter first name)

### Rooms to Test Parser Against
- ✅ A1.1, A2.1, A3, W3 (alphanumeric)
- ⚠️ CLab-8, EFM Lab, MOM Lab (mix of letters/numbers/words)
- ⚠️ Mechanical Vibrations Lab (long multi-word)
- ✅ A1.1 (63), A2.1 (63) (with capacity number)

---

## Next Steps for Parser Improvement

1. **Immediate** (to handle current PDFs):
   - Enhance room name regex to catch `CLab-8`, `EFM Lab` style names
   - Add batch-aware parsing from PDF table footer data
   - Improve teacher/subject boundary detection

2. **Short-term** (to be more robust):
   - Implement table-aware extraction using Syncfusion's table APIs
   - Add duration notation parsing
   - Handle multi-line subject names across table cell breaks

3. **Long-term** (for production use):
   - Create fallback server parser for scanned PDFs
   - Add user validation UI for uncertain parses
   - Build parsing ML model from historical data

---

## File References
- PDF files: `assets/ME (9).pdf`, `assets/CVE.pdf`, `assets/EE (4).pdf`
- Extracted text: `assets/ME (9).extracted.txt`, `assets/CVE.extracted.txt`, etc.
- Table data: `assets/ME (9).tables.txt`, `assets/CVE.tables.txt`, etc.
- Seed data: `assets/timetable_seed.json` (already has manually-parsed sessions)
