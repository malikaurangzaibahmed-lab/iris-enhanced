const XLSX = require('xlsx');
const fs = require('fs');
const path = require('path');

function splitCombinedBatches(raw) {
  if (!raw) return [];
  const s = String(raw).trim();
  if (s === '' || s.toLowerCase() === 'none' || s.toLowerCase() === 'date' || s.toLowerCase() === 'time') return [];
  
  // 1. Check if contains standard batch pattern like FA24-BCS-A, SP23-FSN
  const batchMatches = s.match(/(?:FA|SP)\d{2}-[A-Z0-9]+(?:-[A-Z0-9]+)*/gi);
  if (batchMatches && batchMatches.length > 0) {
    // If multiple batches fused like FA25-BME-FA24-BME-FA22-BEE
    let results = [];
    for (let bm of batchMatches) {
      // Split on secondary FA/SP if chained
      const sub = bm.split(/(?=(?:FA|SP)\d{2}-)/i).map(b => b.replace(/^[-/, ]+|[-/, ]+$/g, '').trim()).filter(Boolean);
      results.push(...sub);
    }
    return results;
  }
  
  // 2. Fallback split on slash or comma
  return s.split(/[\/,]+/).map(b => b.trim()).filter(Boolean);
}

function cleanRoomName(raw) {
  if (!raw) return "";
  let r = String(raw).trim();
  // Strip capacity e.g. "A - 3 (42)" -> "A-3", "B 4 (20)" -> "B-4", "C 1.1 (49)" -> "C-1.1", " D1 (42)" -> "D-1"
  r = r.replace(/\s*\(\d+\)\s*/g, '');
  r = r.replace(/\s*-\s*/g, '-');
  r = r.replace(/\s+/g, '-');
  return r.trim();
}

function formatExamTime(raw) {
  if (!raw) return "";
  let t = String(raw).trim();
  // "0900-1200" -> "09:00 AM - 12:00 PM"
  // "0100-0400" -> "01:00 PM - 04:00 PM"
  // "0900-1030" -> "09:00 AM - 10:30 AM"
  // "1100-1230" -> "11:00 AM - 12:30 PM"
  // "0100-0230" -> "01:00 PM - 02:30 PM"
  // "0300-0430" -> "03:00 PM - 04:30 PM"
  const m = t.match(/^(\d{2})(\d{2})\s*-\s*(\d{2})(\d{2})$/);
  if (m) {
    let sh = parseInt(m[1], 10);
    let sm = m[2];
    let eh = parseInt(m[3], 10);
    let em = m[4];
    
    // In university exams, slots are 0900, 1100, 0100 (13:00), 0300 (15:00)
    let sPeriod = (sh >= 8 && sh <= 11) ? "AM" : "PM";
    let ePeriod = (eh >= 8 && eh <= 11) ? "AM" : "PM";
    if (sh === 1 || sh === 2 || sh === 3 || sh === 4 || sh === 5) sPeriod = "PM";
    if (eh === 1 || eh === 2 || eh === 3 || eh === 4 || eh === 5 || eh === 12) ePeriod = "PM";
    
    let sDisp = sh.toString().padStart(2, '0');
    let eDisp = eh.toString().padStart(2, '0');
    return `${sDisp}:${sm} ${sPeriod} - ${eDisp}:${em} ${ePeriod}`;
  }
  return t;
}

function parseExcelQuadMatrix(filePath) {
  console.log(`\n======================================================`);
  console.log(`TESTING EXCEL QUAD-MATRIX PARSER: ${path.basename(filePath)}`);
  console.log(`======================================================`);
  
  const buffer = fs.readFileSync(filePath);
  const workbook = XLSX.read(buffer, { type: 'buffer' });
  const sheet = workbook.Sheets[workbook.SheetNames[0]];
  const rows = XLSX.utils.sheet_to_json(sheet, { header: 1, defval: null });
  
  // Find header row (row with Date / Time / Room names)
  let headerRowIdx = -1;
  for (let rIdx = 0; rIdx < Math.min(rows.length, 10); rIdx++) {
    const row = rows[rIdx] || [];
    const dateCount = row.filter(c => c && String(c).trim().toLowerCase() === 'date').length;
    if (dateCount >= 2) {
      headerRowIdx = rIdx;
      break;
    }
  }
  if (headerRowIdx === -1) headerRowIdx = 2;
  
  const headerRow = rows[headerRowIdx] || [];
  
  // Identify all 4 campus blocks
  const blocks = [];
  for (let c = 0; c < headerRow.length; c++) {
    const val = headerRow[c];
    if (val && String(val).trim().toLowerCase() === 'date') {
      const dateCol = c;
      const timeCol = c + 1;
      blocks.push({ dateCol, timeCol, startCol: c + 2, endCol: headerRow.length });
    }
  }
  for (let i = 0; i < blocks.length; i++) {
    if (i + 1 < blocks.length) {
      blocks[i].endCol = blocks[i + 1].dateCol;
    }
  }
  
  console.log(`Detected ${blocks.length} Horizontal Campus Blocks:`);
  blocks.forEach((b, idx) => {
    const rooms = [];
    for (let c = b.startCol; c < b.endCol; c++) {
      if (headerRow[c]) rooms.push({ colIdx: c, name: cleanRoomName(headerRow[c]) });
    }
    b.rooms = rooms;
    console.log(`  Block ${idx + 1} (Cols ${b.dateCol}..${b.endCol-1}): ${rooms.length} rooms -> ${rooms.map(r => r.name).join(', ')}`);
  });
  
  const parsedExams = [];
  const currentDates = Array(blocks.length).fill(null);
  
  let r = headerRowIdx + 1;
  while (r < rows.length) {
    const row = rows[r] || [];
    const nextRow = rows[r + 1] || [];
    
    // Check if this row is completely empty
    if (!row.some(Boolean) && !nextRow.some(Boolean)) {
      r += 1;
      continue;
    }
    
    // Process each block independently
    for (let bIdx = 0; bIdx < blocks.length; bIdx++) {
      const b = blocks[bIdx];
      const rawDate = row[b.dateCol];
      const rawTime = row[b.timeCol];
      
      const dateStr = rawDate ? String(rawDate).trim() : "";
      const timeStr = rawTime ? String(rawTime).trim() : "";
      
      if (dateStr && dateStr.toLowerCase() !== 'date') {
        currentDates[bIdx] = dateStr;
      }
      
      const activeDate = currentDates[bIdx] || currentDates[0] || "Unknown Date";
      const activeTime = formatExamTime(timeStr);
      
      if (!timeStr || timeStr.toLowerCase() === 'time') {
        continue;
      }
      
      for (const room of b.rooms) {
        const batchCell = row[room.colIdx];
        const subjectCell = nextRow[room.colIdx];
        
        if (batchCell === null || batchCell === undefined) continue;
        const bStr = String(batchCell).trim();
        if (bStr === '' || bStr.toLowerCase() === 'none' || bStr.toLowerCase() === 'date' || bStr.toLowerCase() === 'time') continue;
        
        const sStr = subjectCell !== null && subjectCell !== undefined ? String(subjectCell).trim() : "";
        
        const batches = splitCombinedBatches(bStr);
        if (batches.length === 0) continue;
        
        for (let batch of batches) {
          parsedExams.push({
            date: activeDate,
            time: activeTime,
            room: room.name,
            batch: batch,
            subject: sStr || "EXAM"
          });
        }
      }
    }
    r += 2;
  }
  
  console.log(`\nSuccessfully Parsed ${parsedExams.length} Individual Student Cohort Exam Records!`);
  console.log(`Sample Records:`);
  console.log(parsedExams.slice(0, 5));
  
  const uniqueBatches = new Set(parsedExams.map(e => e.batch));
  console.log(`Unique Batches Count: ${uniqueBatches.size} (e.g. ${Array.from(uniqueBatches).slice(0, 8).join(', ')})`);
  return parsedExams;
}

parseExcelQuadMatrix("assets/documents/Date_Sheet_FINAL_Term_Exam_FALL_2025 - Version I - 08-12-25.xlsx");
parseExcelQuadMatrix("assets/documents/Version I of Date Sheet Mid Term Exam SPRING 2026 25-03-2026.xlsx");
