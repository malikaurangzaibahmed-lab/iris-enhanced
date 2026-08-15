const fs = require('fs');
const path = require('path');
const pdfjsLib = require('pdfjs-dist/legacy/build/pdf.js');

// Load app.js and extract the parser functions
const appJs = fs.readFileSync(path.join(__dirname, '../admin_portal/app.js'), 'utf8');

// Isolate and evaluate the helper definitions and parseTimetablePDF
const sandbox = {
  console: console,
  ROOM_PATTERNS: [],
  DURATION_MARKER_RE: null,
  CAPACITY_RE: null,
  KNOWN_DEPARTMENTS: [],
  COURSES_TAXONOMY: [],
  HONORIFICS_TITLES: [],
  TIME_RANGE_RE: null,
  pdfjsLib: pdfjsLib
};

// Evaluate the parser functions in global context
eval(appJs.substring(appJs.indexOf('const ROOM_PATTERNS'), appJs.indexOf('async function handleTimetableFilesSelect')));

const pdfFiles = [
  'CE-1.pdf',
  'CS-12-1.pdf',
  'EE.pdf',
  'FSn,BTY,BCH,HND,RBS.pdf',
  'HUM-1.pdf',
  'ME-1.pdf',
  'MS-2.pdf'
];

async function runTest() {
  console.log("==================================================");
  console.log("RUNNING EXACT JS PARSER TESTS ON ALL 7 ASSET PDFS");
  console.log("==================================================");
  
  let grandTotal = 0;
  let totalUnknownTeachers = 0;
  let totalTbdRooms = 0;
  let totalOneHr = 0;
  let totalBadSubjects = 0;

  for (let file of pdfFiles) {
    const filePath = path.join(__dirname, '../assets/documents', file);
    if (!fs.existsSync(filePath)) {
      console.log(`Skipping missing: ${file}`);
      continue;
    }
    const data = new Uint8Array(fs.readFileSync(filePath));
    const fakeFile = {
      name: file,
      size: data.length,
      arrayBuffer: async () => data.buffer
    };
    
    const sessions = await parseTimetablePDF(fakeFile);
    grandTotal += sessions.length;
    
    let fileUnknownTeachers = 0;
    let fileTbdRooms = 0;
    let fileOneHr = 0;
    let fileBadSubjects = 0;

    for (let s of sessions) {
      if (!s.teacher || s.teacher === 'Unknown') fileUnknownTeachers++;
      if (!s.room || s.room === 'TBD') fileTbdRooms++;
      if (/(1\s*hr|1\s*hour|1hr)/i.test(s.subject)) fileOneHr++;
      if (/^\s*(?:\d+\s+)?\d{1,2}[:.]?\d{2}/.test(s.subject) || /^\d+$/.test(s.subject)) {
        fileBadSubjects++;
        console.error(`  [BAD SUBJECT] in ${file}: "${s.subject}" (Batch: ${s.batch}, Slot: ${s.start}-${s.end})`);
      }
    }
    
    totalUnknownTeachers += fileUnknownTeachers;
    totalTbdRooms += fileTbdRooms;
    totalOneHr += fileOneHr;
    totalBadSubjects += fileBadSubjects;

    console.log(`File: ${file.padEnd(26)} -> Sessions: ${sessions.length.toString().padStart(4)} | Unknown Teachers: ${fileUnknownTeachers} | TBD Rooms: ${fileTbdRooms} | 1-Hr Classes: ${fileOneHr}`);
  }

  console.log("--------------------------------------------------");
  console.log(`TOTAL SESSIONS EXTRACTED : ${grandTotal}`);
  console.log(`TOTAL UNKNOWN TEACHERS   : ${totalUnknownTeachers}`);
  console.log(`TOTAL TBD ROOMS          : ${totalTbdRooms}`);
  console.log(`TOTAL 1-HR CLASSES       : ${totalOneHr}`);
  console.log(`TOTAL BAD/TIME SUBJECTS  : ${totalBadSubjects}`);
  console.log("==================================================");

  if (totalBadSubjects > 0 || totalUnknownTeachers > 0 || totalTbdRooms > 0) {
    console.error("TEST FAILED - Anomalies detected!");
    process.exit(1);
  } else {
    console.log("ALL TESTS PASSED WITH 100% PURITY!");
  }
}

runTest().catch(err => {
  console.error(err);
  process.exit(1);
});
