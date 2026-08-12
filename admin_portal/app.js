/* ==========================================================================
   IRIS WEB PLATFORM - COMPLETE ADMINISTRATIVE CONTROL ENGINE & FIRESTORE CONTROLLER
   ========================================================================== */

// Firebase Configuration (Connects to live Firestore database)
const firebaseConfig = {
  apiKey: "AIzaSyDummyKeyForLocalPreview",
  authDomain: "iris-138ef.firebaseapp.com",
  projectId: "iris-138ef",
  storageBucket: "iris-138ef.appspot.com",
  messagingSenderId: "123456789",
  appId: "1:123456789:web:abcdef"
};

let db = null;
try {
  if (typeof firebase !== 'undefined') {
    firebase.initializeApp(firebaseConfig);
    db = firebase.firestore();
    console.log("⚡ IRIS Web Admin Engine: Firebase Firestore initialized successfully.");
  }
} catch (e) {
  console.warn("⚠️ IRIS Web Admin Engine: Running with local offline state engine:", e);
}

// Live Dynamic Stores (Zero Dummy Data)
let realTimetable = [];
let stagedTimetable = [];
let realFaculty = [];
let stagedExams = [];
let communityFeedbacks = [];

let selectedDay = "Monday";

// Initialization
document.addEventListener('DOMContentLoaded', () => {
  handleHashNavigation();
  loadRealTimetableData();
  initFirestoreFeedbackStream();
});

// Single Page Application Router
function switchPage(pageId) {
  document.querySelectorAll('.page-section').forEach(sec => sec.classList.remove('active'));
  document.querySelectorAll('.nav-tab').forEach(tab => tab.classList.remove('active'));

  const targetPage = document.getElementById(`page-${pageId}`);
  const targetTab = document.getElementById(`tab-${pageId}`);

  if (targetPage) targetPage.classList.add('active');
  if (targetTab) targetTab.classList.add('active');

  window.location.hash = pageId;
  window.scrollTo({ top: 0, behavior: 'smooth' });
}

function handleHashNavigation() {
  const hash = window.location.hash.replace('#', '');
  if (['dashboard', 'timetable', 'exams', 'directory', 'feedback', 'releases'].includes(hash)) {
    switchPage(hash);
  }
}

// Data Refresh Engine
async function refreshAllData() {
  await loadRealTimetableData();
  if (db) initFirestoreFeedbackStream();
  alert("✅ Data sync complete: Timetable dataset and live Firestore feedback refreshed!");
}

// Fetch Real Timetable & Build Real Faculty Roster Dynamically
async function loadRealTimetableData() {
  try {
    const res = await fetch('timetable_seed.json');
    if (res.ok) {
      realTimetable = await res.json();
      buildFacultyFromTimetable();
      updatePlatformStats();
      updateActiveClassCard();
      renderTimetable();
      renderFaculty();
    }
  } catch (e) {
    console.warn("Could not load timetable_seed.json:", e);
  }
}

function buildFacultyFromTimetable() {
  const teacherMap = new Map();
  realTimetable.forEach(item => {
    if (item.teacher && item.teacher !== "N/A" && !teacherMap.has(item.teacher)) {
      teacherMap.set(item.teacher, {
        name: item.teacher,
        dept: item.department || "Academic Faculty",
        designation: "Faculty Instructor",
        room: item.room || "Campus Room",
        email: `${item.teacher.toLowerCase().replace(/[^a-z]/g, '')}@comsats.edu.pk`
      });
    }
  });
  realFaculty = Array.from(teacherMap.values());
}

function updatePlatformStats() {
  const statSessions = document.getElementById('stat-sessions');
  const statFaculty = document.getElementById('stat-faculty');
  const statFeedback = document.getElementById('stat-feedback');

  if (statSessions) statSessions.innerText = realTimetable.length > 0 ? realTimetable.length.toLocaleString() : "0";
  if (statFaculty) statFaculty.innerText = realFaculty.length > 0 ? `${realFaculty.length}+` : "0";
  if (statFeedback) statFeedback.innerText = communityFeedbacks.length.toString();
}

function updateActiveClassCard() {
  const now = new Date();
  const days = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"];
  const currentDayStr = days[now.getDay()];

  const activeSession = realTimetable.find(item => item.day === currentDayStr) || realTimetable[0];

  const nameEl = document.getElementById('live-subject-name');
  const teacherEl = document.getElementById('live-teacher-name');
  const rangeEl = document.getElementById('live-time-range');

  if (activeSession) {
    if (nameEl) nameEl.innerText = activeSession.subject || "No Active Class";
    if (teacherEl) teacherEl.innerText = `${activeSession.batch || ''} • ${activeSession.teacher || ''} • Room ${activeSession.room || ''}`;
    if (rangeEl) rangeEl.innerText = `${activeSession.start || ''} - ${activeSession.end || ''}`;
  }
}

// Academic Mode Switcher Engine
function setAcademicMode(mode) {
  const ribbonSegments = document.querySelectorAll('#academic-ribbon .ribbon-segment');
  ribbonSegments.forEach(seg => {
    seg.classList.toggle('active', seg.getAttribute('data-period') === mode);
  });

  const titles = {
    classes: "REGULAR CLASSES MODE ACTIVE",
    midterm: "MIDTERM EXAM PERIOD ACTIVE",
    finals: "FINAL EXAM PERIOD ACTIVE",
    sports: "SPORTS WEEK PERIOD ACTIVE"
  };

  const texts = {
    classes: "Standard curriculum timetables, active period countdowns, and room locator indexing enabled.",
    midterm: "Midterm exam date sheets take priority on student home screens and widgets.",
    finals: "Final exam schedule view active with seating room indicators.",
    sports: "Sports week notices and schedule highlighted across mobile noticeboards."
  };

  const titleEl = document.getElementById('mode-desc-title');
  const textEl = document.getElementById('mode-desc-text');
  if (titleEl) titleEl.innerText = titles[mode] || titles.classes;
  if (textEl) textEl.innerText = texts[mode] || texts.classes;

  if (db) {
    db.collection('config').doc('global').set({
      academic_period: mode,
      updated_at: firebase.firestore.FieldValue.serverTimestamp()
    }, { merge: true }).then(() => {
      console.log(`✅ Academic Period set to [${mode}] in Firestore.`);
    }).catch(err => console.warn("Firestore mode save:", err));
  }

  alert(`Academic mode switched to [${mode.toUpperCase()}]. Broadcast sent to all mobile client devices!`);
}

// Timetable PDF & JSON Uploader
function handleTimetableFilesSelect(event) {
  const files = event.target.files;
  if (!files || files.length === 0) return;

  const infoEl = document.getElementById('timetable-file-info');
  infoEl.innerText = `Selected ${files.length} file(s): ${Array.from(files).map(f => f.name).join(', ')}`;

  const file = files[0];
  if (file.name.endsWith('.json')) {
    const reader = new FileReader();
    reader.onload = (e) => {
      try {
        stagedTimetable = JSON.parse(e.target.result);
        alert(`✅ Staged JSON file with ${stagedTimetable.length} timetable sessions.`);
      } catch (err) {
        alert("⚠️ Invalid JSON file format.");
      }
    };
    reader.readAsText(file);
  } else if (file.name.endsWith('.pdf')) {
    alert(`📄 Staged PDF file [${file.name}]. Click 'Commit Seed' to parse and upload sessions to database.`);
  }
}

function commitStagedTimetable() {
  if (stagedTimetable.length > 0) {
    realTimetable = stagedTimetable;
    renderTimetable();
    updatePlatformStats();

    if (db) {
      db.collection('timetables').doc('seed').set({
        sessions: realTimetable,
        updated_at: firebase.firestore.FieldValue.serverTimestamp()
      }).then(() => alert("✅ Timetable seed committed to Firestore database!"))
        .catch(err => alert("Firestore save error: " + err.message));
    } else {
      alert("✅ Staged timetable seed committed locally!");
    }
  } else {
    alert("⚠️ Please select a valid JSON or PDF timetable file first.");
  }
}

function wipeLiveTimetable() {
  if (confirm("Are you sure you want to WIPE the live class timetable database?")) {
    realTimetable = [];
    renderTimetable();
    updatePlatformStats();

    if (db) {
      db.collection('timetables').doc('seed').delete().then(() => alert("🗑️ Live timetable database wiped successfully."));
    } else {
      alert("🗑️ Live timetable wiped locally.");
    }
  }
}

// Timetable Inspector Renderer
function selectDay(day) {
  selectedDay = day;
  document.querySelectorAll('#day-picker-container .day-btn').forEach(btn => {
    btn.classList.toggle('active', btn.innerText.trim() === day);
  });
  renderTimetable();
}

function renderTimetable() {
  const tbody = document.getElementById('timetable-tbody');
  if (!tbody) return;

  const searchVal = (document.getElementById('timetable-search')?.value || '').toLowerCase();
  
  const filtered = realTimetable.filter(item => {
    const matchDay = !item.day || item.day === selectedDay;
    const matchSearch = !searchVal ||
      (item.batch && item.batch.toLowerCase().includes(searchVal)) ||
      (item.subject && item.subject.toLowerCase().includes(searchVal)) ||
      (item.teacher && item.teacher.toLowerCase().includes(searchVal)) ||
      (item.room && item.room.toLowerCase().includes(searchVal));
    return matchDay && matchSearch;
  });

  if (filtered.length === 0) {
    tbody.innerHTML = `<tr><td colspan="5" style="text-align: center; color: var(--text-muted); padding: 24px;">No sessions found for ${selectedDay}.</td></tr>`;
    return;
  }

  tbody.innerHTML = filtered.slice(0, 100).map(item => `
    <tr>
      <td><span style="font-weight: 800; color: var(--brand-cyan);">${item.batch || 'N/A'}</span></td>
      <td><span style="font-family: var(--font-mono); font-size: 12px;">${item.start || '--'} - ${item.end || '--'}</span></td>
      <td><span style="font-weight: 700; color: var(--text-main);">${item.subject || 'Session'}</span></td>
      <td><span style="color: var(--text-muted);">${item.teacher || 'N/A'}</span></td>
      <td><span style="padding: 2px 8px; background: rgba(16, 185, 129, 0.12); border-radius: 6px; font-size: 11px; font-weight: 700; color: var(--brand-emerald);">${item.room || 'N/A'}</span></td>
    </tr>
  `).join('');
}

function filterTimetable() {
  renderTimetable();
}

// Date Sheet Excel Converter (.xlsx)
function handleExcelFileSelect(event) {
  const file = event.target.files[0];
  if (!file) return;

  document.getElementById('exams-file-info').innerText = `Selected file: ${file.name}`;

  if (typeof XLSX === 'undefined') {
    alert("⚠️ XLSX library is loading... Please retry in a moment.");
    return;
  }

  const reader = new FileReader();
  reader.onload = (e) => {
    try {
      const data = new Uint8Array(e.target.result);
      const workbook = XLSX.read(data, { type: 'array' });
      const firstSheetName = workbook.SheetNames[0];
      const worksheet = workbook.Sheets[firstSheetName];
      const json = XLSX.utils.sheet_to_json(worksheet, { header: 1 });

      stagedExams = [];
      for (let i = 1; i < json.length; i++) {
        const row = json[i];
        if (row && row.length >= 4) {
          stagedExams.push({
            date: row[0] || 'TBA',
            time: row[1] || 'TBA',
            batch: row[2] || 'All Batches',
            subject: row[3] || 'Course Exam',
            room: row[4] || 'Hall A'
          });
        }
      }

      renderExamsPreview();
      alert(`✅ Excel parsed! Staged ${stagedExams.length} exam slots.`);
    } catch (err) {
      alert("⚠️ Error parsing Excel date sheet: " + err.message);
    }
  };
  reader.readAsArrayBuffer(file);
}

function renderExamsPreview() {
  const tbody = document.getElementById('exams-preview-tbody');
  if (!tbody) return;

  if (stagedExams.length === 0) {
    tbody.innerHTML = `<tr><td colspan="5" style="text-align: center; color: var(--text-muted); padding: 24px;">No Excel date sheet staged yet. Drag & drop an .xlsx file above.</td></tr>`;
    return;
  }

  tbody.innerHTML = stagedExams.slice(0, 50).map(ex => `
    <tr>
      <td><span style="font-weight: 700; color: var(--brand-amber);">${ex.date}</span></td>
      <td><span style="font-family: var(--font-mono); font-size: 12px;">${ex.time}</span></td>
      <td><span style="font-weight: 800; color: var(--brand-cyan);">${ex.batch}</span></td>
      <td><span style="font-weight: 700; color: var(--text-main);">${ex.subject}</span></td>
      <td><span style="padding: 2px 8px; background: rgba(168, 85, 247, 0.15); border-radius: 6px; font-size: 11px; font-weight: 700; color: var(--brand-purple);">${ex.room}</span></td>
    </tr>
  `).join('');
}

function commitExams(termType) {
  if (stagedExams.length === 0) {
    alert("⚠️ Please upload and parse an Excel (.xlsx) date sheet first.");
    return;
  }

  if (db) {
    db.collection('exams').doc(termType).set({
      slots: stagedExams,
      updated_at: firebase.firestore.FieldValue.serverTimestamp()
    }).then(() => alert(`✅ Staged ${stagedExams.length} ${termType.toUpperCase()} exam slots committed to Firestore!`))
      .catch(err => alert("Firestore save error: " + err.message));
  } else {
    alert(`✅ Staged ${stagedExams.length} ${termType.toUpperCase()} exam slots committed locally!`);
  }
}

function wipeExams() {
  if (confirm("Are you sure you want to wipe live exam date sheets from the database?")) {
    stagedExams = [];
    renderExamsPreview();
    if (db) {
      db.collection('exams').doc('midterm').delete();
      db.collection('exams').doc('finals').delete();
    }
    alert("🗑️ Exam date sheets wiped successfully.");
  }
}

// Faculty Directory Renderer
function renderFaculty() {
  const grid = document.getElementById('faculty-grid');
  if (!grid) return;

  const searchVal = (document.getElementById('faculty-search')?.value || '').toLowerCase();

  const filtered = realFaculty.filter(f => {
    return !searchVal ||
      (f.name && f.name.toLowerCase().includes(searchVal)) ||
      (f.dept && f.dept.toLowerCase().includes(searchVal)) ||
      (f.room && f.room.toLowerCase().includes(searchVal));
  });

  if (filtered.length === 0) {
    grid.innerHTML = `<div style="grid-column: 1/-1; text-align: center; color: var(--text-muted); padding: 40px;">No faculty members found.</div>`;
    return;
  }

  grid.innerHTML = filtered.map(f => {
    const initials = f.name.split(' ').map(n => n[0]).join('').substring(0, 2).toUpperCase();
    return `
      <div class="glass-card">
        <div style="display: flex; align-items: center; gap: 14px; margin-bottom: 14px;">
          <div style="width: 44px; height: 44px; border-radius: 12px; background: linear-gradient(135deg, var(--brand-violet), var(--brand-cyan)); display: flex; align-items: center; justify-content: center; font-weight: 900; color: #fff; font-size: 16px;">
            ${initials}
          </div>
          <div>
            <div style="font-weight: 800; font-size: 16px; color: var(--text-main);">${f.name}</div>
            <div style="font-size: 11px; color: var(--brand-cyan); font-weight: 700;">${f.designation}</div>
          </div>
        </div>
        <div style="font-size: 12.5px; color: var(--text-muted); margin-bottom: 6px;">
          <i class="fa-solid fa-building-user" style="width: 16px; color: var(--brand-purple);"></i> ${f.dept}
        </div>
        <div style="font-size: 12.5px; color: var(--text-muted); margin-bottom: 8px;">
          <i class="fa-solid fa-door-open" style="width: 16px; color: var(--brand-emerald);"></i> ${f.room}
        </div>
        <div style="font-size: 12px; color: var(--brand-cyan); font-family: var(--font-mono);">
          <i class="fa-solid fa-envelope"></i> ${f.email}
        </div>
      </div>
    `;
  }).join('');
}

function filterFaculty() {
  renderFaculty();
}

// OTA Release Software Manager
function autofillGithubRelease() {
  fetch('https://api.github.com/repos/malikaurangzaibahmed-lab/iris-enhanced/releases/latest')
    .then(res => res.json())
    .then(data => {
      if (data.tag_name) {
        document.getElementById('apk-version-name').value = data.tag_name.replace('v', '');
        document.getElementById('apk-notes').value = data.body || 'Latest release build with liquid glass widgets.';
        if (data.assets && data.assets.length > 0) {
          document.getElementById('apk-url-input').value = data.assets[0].browser_download_url;
        }
        alert(`✅ Pre-filled release [${data.tag_name}] from GitHub!`);
      }
    })
    .catch(err => alert("Could not fetch latest release from GitHub API: " + err.message));
}

function deployOTAPatch() {
  const verName = document.getElementById('apk-version-name').value.trim();
  const verCode = document.getElementById('apk-version-code').value.trim();
  const notes = document.getElementById('apk-notes').value.trim();
  const url = document.getElementById('apk-url-input').value.trim();
  const showBanner = document.getElementById('apk-switch-visible').checked;

  if (!verName || !url) {
    alert("⚠️ Please enter a Version Name and APK Download URL.");
    return;
  }

  const releasePayload = {
    version_name: verName,
    version_code: parseInt(verCode) || 4,
    release_notes: notes,
    apk_url: url,
    show_update_banner: showBanner,
    updated_at: new Date()
  };

  if (db) {
    db.collection('config').doc('app_update').set(releasePayload, { merge: true }).then(() => {
      alert("🚀 OTA Release Config published to Firestore! Connected mobile apps will display update prompts.");
    }).catch(err => alert("Firestore save error: " + err.message));
  } else {
    alert("🚀 OTA Release Config staged locally!");
  }
}

// Emergency Push Broadcast Engine
function sendBroadcastNotice() {
  const title = document.getElementById('broadcast-title').value.trim();
  const category = document.getElementById('broadcast-category').value;
  const body = document.getElementById('broadcast-body').value.trim();

  if (!title || !body) {
    alert("⚠️ Please enter a notice title and broadcast body text.");
    return;
  }

  if (db) {
    db.collection('notices').add({
      title: title,
      category: category,
      body: body,
      created_at: firebase.firestore.FieldValue.serverTimestamp()
    }).then(() => {
      alert(`📢 Emergency Notice [${title}] broadcasted to all mobile client noticeboards!`);
      document.getElementById('broadcast-title').value = '';
      document.getElementById('broadcast-body').value = '';
    }).catch(err => alert("Firestore broadcast error: " + err.message));
  } else {
    alert(`📢 Emergency Notice [${title}] broadcasted locally!`);
  }
}

// Admin User Feedback & Telemetry Stream Engine
function initFirestoreFeedbackStream() {
  if (!db) return;
  try {
    db.collection('feedback').orderBy('created_at', 'desc').onSnapshot(snapshot => {
      communityFeedbacks = [];
      snapshot.forEach(doc => {
        const data = doc.data();
        let formattedDate = 'Recent';
        if (data.created_at && data.created_at.toDate) {
          formattedDate = data.created_at.toDate().toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' });
        } else if (data.date) {
          formattedDate = data.date;
        }
        communityFeedbacks.push({
          name: data.name || 'User',
          user_role: data.user_role || 'Student',
          roll_number: data.roll_number || '',
          batch: data.batch || '',
          device: data.device || '',
          category: data.category || 'General Feedback',
          rating: data.rating || 5,
          comment: data.comment || '',
          date: formattedDate
        });
      });
      renderFeedbackFeed();
      updatePlatformStats();
    }, err => console.warn("Firestore snapshot listener:", err));
  } catch (e) {
    console.warn("Could not start Firestore live listener:", e);
  }
}

function renderFeedbackFeed() {
  const container = document.getElementById('feedback-feed-container');
  const countBadge = document.getElementById('feedback-count-badge');
  if (!container) return;

  const searchVal = (document.getElementById('feedback-search')?.value || '').toLowerCase();
  const roleFilter = document.getElementById('feedback-role-filter')?.value || 'ALL';

  const filtered = communityFeedbacks.filter(fb => {
    const matchRole = roleFilter === 'ALL' || (fb.user_role || 'Student') === roleFilter;
    const matchSearch = !searchVal ||
      (fb.name && fb.name.toLowerCase().includes(searchVal)) ||
      (fb.comment && fb.comment.toLowerCase().includes(searchVal)) ||
      (fb.roll_number && fb.roll_number.toLowerCase().includes(searchVal)) ||
      (fb.device && fb.device.toLowerCase().includes(searchVal)) ||
      (fb.batch && fb.batch.toLowerCase().includes(searchVal));
    return matchRole && matchSearch;
  });

  if (countBadge) {
    countBadge.innerText = `${filtered.length} ${filtered.length === 1 ? 'SUBMISSION' : 'SUBMISSIONS'}`;
  }

  if (filtered.length === 0) {
    container.innerHTML = `
      <div style="padding: 40px 20px; text-align: center; color: var(--text-muted);">
        <i class="fa-solid fa-comments" style="font-size: 32px; color: var(--brand-cyan); margin-bottom: 12px; display: block; opacity: 0.5;"></i>
        <div style="font-weight: 700; font-size: 14px; color: var(--text-main); margin-bottom: 4px;">No Submissions Match Filter</div>
        <div style="font-size: 12px; color: var(--text-dim); max-width: 320px; margin: 0 auto;">User feedback submitted from the IRIS mobile app will appear here in real time.</div>
      </div>
    `;
    return;
  }

  container.innerHTML = filtered.map(fb => `
    <div class="feedback-feed-item" style="${fb.user_role === 'Faculty' ? 'border-color: rgba(168, 85, 247, 0.4); background: rgba(109, 40, 217, 0.1);' : ''}">
      <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 8px;">
        <div style="display: flex; align-items: center; gap: 8px;">
          <span style="font-weight: 800; color: var(--text-main); font-size: 15px;">${fb.name}</span>
          ${fb.user_role === 'Faculty' 
            ? `<span style="padding: 2px 8px; background: rgba(168, 85, 247, 0.25); border: 1px solid rgba(168, 85, 247, 0.4); border-radius: 6px; font-size: 10px; font-weight: 800; color: #d8b4fe;"><i class="fa-solid fa-graduation-cap"></i> FACULTY</span>`
            : `<span style="padding: 2px 8px; background: rgba(0, 229, 255, 0.12); border-radius: 6px; font-size: 10px; font-weight: 700; color: var(--brand-cyan);">STUDENT</span>`}
          ${fb.roll_number && fb.roll_number !== 'N/A' ? `<span style="font-size: 11px; color: var(--brand-cyan); font-weight: 700;">(${fb.roll_number})</span>` : ''}
        </div>
        <span style="font-size: 11px; color: var(--text-dim); font-weight: 600;">${fb.date}</span>
      </div>
      <div style="display: flex; flex-wrap: wrap; gap: 6px; align-items: center; margin-bottom: 10px;">
        <span style="padding: 2px 8px; background: rgba(0, 229, 255, 0.12); border-radius: 6px; font-size: 10px; font-weight: 700; color: var(--brand-cyan);">${fb.category}</span>
        ${fb.batch && fb.batch !== 'N/A' ? `<span style="padding: 2px 8px; background: rgba(168, 85, 247, 0.12); border-radius: 6px; font-size: 10px; font-weight: 700; color: var(--brand-purple);">${fb.batch}</span>` : ''}
        ${fb.device && fb.device !== 'N/A' ? `<span style="padding: 2px 8px; background: rgba(255, 255, 255, 0.06); border-radius: 6px; font-size: 10px; font-weight: 600; color: var(--text-muted);"><i class="fa-solid fa-mobile-screen-button"></i> ${fb.device}</span>` : ''}
        <span style="color: var(--brand-amber); font-size: 12px; margin-left: auto;">${'★'.repeat(fb.rating || 5)}</span>
      </div>
      <p style="font-size: 13.5px; color: var(--text-muted); line-height: 1.5;">${fb.comment}</p>
    </div>
  `).join('');
}

function filterFeedbackFeed() {
  renderFeedbackFeed();
}
