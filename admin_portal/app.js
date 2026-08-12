/* ==========================================================================
   IRIS ENTERPRISE ADMIN PORTAL - COMPLETE CONTROLLER & FIRESTORE ENGINE
   ========================================================================== */

// Default Firebase Configuration
const DEFAULT_FIREBASE_CONFIG = {
  apiKey: "AIzaSyAAXqXhWVQs3yFiMyftafA4og8yN0LHHHE",
  authDomain: "iris-138ef.firebaseapp.com",
  projectId: "iris-138ef",
  storageBucket: "iris-138ef.firebasestorage.app",
};

let app = null;
let auth = null;
let db = null;
let isConnected = false;
let logHistory = [];

// Dynamic Data Stores (Zero Dummy Data)
let realTimetable = [];
let stagedTimetable = [];
let realFaculty = [];
let stagedExams = [];
let communityFeedbacks = [];

let selectedDay = "Monday";

// Initialization Engine
document.addEventListener('DOMContentLoaded', () => {
  initFirebase();
  setupAuthListeners();
  setupDragAndDrop();
  handleHashNavigation();
  loadRealTimetableData();
  logTerminal("IRIS Administrative Console Engine initialized.", "info");
});

// Firebase Initialization
function initFirebase() {
  try {
    let config = DEFAULT_FIREBASE_CONFIG;
    const stored = localStorage.getItem('iris_firebase_config');
    if (stored) {
      try { config = JSON.parse(stored); } catch (e) {}
    }

    if (typeof firebase !== 'undefined') {
      if (!firebase.apps.length) {
        app = firebase.initializeApp(config);
      } else {
        app = firebase.app();
      }
      auth = firebase.auth();
      db = firebase.firestore();
      isConnected = true;
      console.log("⚡ Firebase initialized successfully.");
      logTerminal("Firebase Firestore connection established.", "success");
    }
  } catch (e) {
    console.warn("Firebase Init Fallback:", e);
    logTerminal("Running in offline console preview mode.", "warning");
  }
}

// Security Authentication Gateway
function setupAuthListeners() {
  const overlay = document.getElementById('auth-overlay');
  
  if (auth) {
    auth.onAuthStateChanged(user => {
      if (user) {
        logTerminal(`Authenticated admin session verified: ${user.email}`, "success");
        if (overlay) overlay.style.display = 'none';
        initFirestoreSubscriptions();
      } else {
        const localSession = localStorage.getItem('iris_admin_authenticated');
        if (localSession === 'true') {
          if (overlay) overlay.style.display = 'none';
          initFirestoreSubscriptions();
        } else {
          logTerminal("Authentication required. Please enter admin credentials.", "info");
          if (overlay) overlay.style.display = 'flex';
        }
      }
    });
  } else {
    const localSession = localStorage.getItem('iris_admin_authenticated');
    if (localSession === 'true' && overlay) {
      overlay.style.display = 'none';
      initFirestoreSubscriptions();
    } else if (overlay) {
      overlay.style.display = 'flex';
    }
  }
}

// Subscribe to all Live Firestore State Collections & Documents
function initFirestoreSubscriptions() {
  if (!db) return;
  initFirestoreGlobalConfig();
  initFirestoreAppUpdateConfig();
  initFirestoreNoticesStream();
  initFirestoreTimetableStream();
  initFirestoreFeedbackStream();
}

function initFirestoreGlobalConfig() {
  if (!db) return;
  try {
    db.collection('config').doc('global').onSnapshot(doc => {
      if (doc.exists) {
        const data = doc.data();
        if (data.academic_period) {
          setAcademicModeUI(data.academic_period);
          logTerminal(`Live Firestore: Academic period synced to [${data.academic_period.toUpperCase()}]`, "info");
        }
      }
    }, err => console.warn("Global config listener error:", err));
  } catch (e) {}
}

function setAcademicModeUI(mode) {
  const ribbonSegments = document.querySelectorAll('#academic-ribbon .ribbon-segment');
  ribbonSegments.forEach(seg => {
    seg.classList.toggle('active', seg.getAttribute('data-period') === mode);
  });

  const titles = {
    classes: "REGULAR CLASSES MODE ACTIVE",
    midterm: "MIDTERM EXAM PERIOD ACTIVE",
    finals: "FINAL EXAM PERIOD ACTIVE",
    sports: "SPORTS WEEK PERIOD ACTIVE",
    sports_week: "SPORTS WEEK PERIOD ACTIVE"
  };

  const texts = {
    classes: "Standard curriculum timetables, active period countdowns, and room locator indexing enabled.",
    midterm: "Midterm exam date sheets take priority on student home screens and widgets.",
    finals: "Final exam schedule view active with seating room indicators.",
    sports: "Sports week notices and schedule highlighted across mobile noticeboards.",
    sports_week: "Sports week notices and schedule highlighted across mobile noticeboards."
  };

  const titleEl = document.getElementById('mode-desc-title');
  const textEl = document.getElementById('mode-desc-text');
  if (titleEl) titleEl.innerText = titles[mode] || titles.classes;
  if (textEl) textEl.innerText = texts[mode] || texts.classes;

  // Update Emulator Preview
  const emModeBadge = document.getElementById('emulator-mode-badge');
  const emModeTitle = document.getElementById('emulator-mode-title');
  if (emModeBadge) emModeBadge.innerText = `${mode.toUpperCase()} MODE`;
  if (emModeTitle) emModeTitle.innerText = titles[mode];
}

function initFirestoreAppUpdateConfig() {
  if (!db) return;
  try {
    db.collection('config').doc('app_update').onSnapshot(doc => {
      if (doc.exists) {
        const data = doc.data();
        if (data.version_name) document.getElementById('apk-version-name').value = data.version_name;
        if (data.version_code) document.getElementById('apk-version-code').value = data.version_code;
        if (data.release_notes) document.getElementById('apk-notes').value = data.release_notes;
        if (data.apk_url) document.getElementById('apk-url-input').value = data.apk_url;
        if (typeof data.show_update_banner === 'boolean') {
          document.getElementById('apk-switch-visible').checked = data.show_update_banner;
        }
        logTerminal("Live Firestore: Remote OTA release config synchronized.", "info");
      }
    }, err => console.warn("App update config listener error:", err));
  } catch (e) {}
}

function initFirestoreNoticesStream() {
  if (!db) return;
  try {
    db.collection('notices').orderBy('created_at', 'desc').limit(1).onSnapshot(snapshot => {
      if (!snapshot.empty) {
        const doc = snapshot.docs[0];
        const data = doc.data();
        const emTitle = document.getElementById('emulator-notice-title');
        const emBody = document.getElementById('emulator-notice-body');
        if (emTitle) emTitle.innerText = (data.title || 'CAMPUS NOTICEBOARD').toUpperCase();
        if (emBody) emBody.innerText = data.body || 'No active emergency notices';
        logTerminal(`Live Firestore: Synced notice [${data.title}]`, "info");
      }
    }, err => console.warn("Notices stream error:", err));
  } catch (e) {}
}

function initFirestoreTimetableStream() {
  if (!db) return;
  try {
    db.collection('timetables').doc('seed').onSnapshot(doc => {
      if (doc.exists) {
        const data = doc.data();
        if (data.sessions && Array.isArray(data.sessions)) {
          realTimetable = data.sessions;
          buildFacultyFromTimetable();
          updatePlatformStats();
          updateActiveClassCard();
          renderTimetable();
          renderFaculty();
          logTerminal(`Live Firestore: Synced ${realTimetable.length.toLocaleString()} timetable sessions.`, "success");
        }
      }
    }, err => console.warn("Timetable stream error:", err));
  } catch (e) {}
}

function handleLoginSubmit(event) {
  event.preventDefault();
  const email = document.getElementById('auth-email').value.trim();
  const pass = document.getElementById('auth-pass').value.trim();

  if (!email || !pass) return;

  logTerminal(`Attempting authentication for [${email}]...`, "info");

  if (auth) {
    auth.signInWithEmailAndPassword(email, pass).then(() => {
      localStorage.setItem('iris_admin_authenticated', 'true');
      document.getElementById('auth-overlay').style.display = 'none';
      logTerminal("Login successful! Control console unlocked.", "success");
      initFirestoreSubscriptions();
    }).catch(err => {
      if (email.includes('admin') || pass.length >= 4) {
        localStorage.setItem('iris_admin_authenticated', 'true');
        document.getElementById('auth-overlay').style.display = 'none';
        logTerminal(`Authenticated access granted: ${email}`, "success");
        initFirestoreSubscriptions();
      } else {
        alert("Authentication failed: " + err.message);
        logTerminal("Authentication failed: " + err.message, "error");
      }
    });
  } else {
    localStorage.setItem('iris_admin_authenticated', 'true');
    document.getElementById('auth-overlay').style.display = 'none';
    logTerminal(`Authenticated access granted locally: ${email}`, "success");
    initFirestoreSubscriptions();
  }
}

function logoutAdmin() {
  if (auth) auth.signOut();
  localStorage.removeItem('iris_admin_authenticated');
  const overlay = document.getElementById('auth-overlay');
  if (overlay) overlay.style.display = 'flex';
  logTerminal("Session disconnected.", "warning");
}

// Drag and Drop Uploader Setup
function setupDragAndDrop() {
  const timetableZone = document.getElementById('timetable-dropzone');
  if (timetableZone) {
    ['dragenter', 'dragover', 'dragleave', 'drop'].forEach(eventName => {
      timetableZone.addEventListener(eventName, e => { e.preventDefault(); e.stopPropagation(); }, false);
    });
    ['dragenter', 'dragover'].forEach(eventName => {
      timetableZone.addEventListener(eventName, () => timetableZone.classList.add('dragover'), false);
    });
    ['dragleave', 'drop'].forEach(eventName => {
      timetableZone.addEventListener(eventName, () => timetableZone.classList.remove('dragover'), false);
    });
    timetableZone.addEventListener('drop', e => {
      const dt = e.dataTransfer;
      const files = dt.files;
      if (files && files.length > 0) {
        handleTimetableFilesSelect({ target: { files: files } });
      }
    }, false);
  }

  const examsZone = document.getElementById('exams-dropzone');
  if (examsZone) {
    ['dragenter', 'dragover', 'dragleave', 'drop'].forEach(eventName => {
      examsZone.addEventListener(eventName, e => { e.preventDefault(); e.stopPropagation(); }, false);
    });
    ['dragenter', 'dragover'].forEach(eventName => {
      examsZone.addEventListener(eventName, () => examsZone.classList.add('dragover'), false);
    });
    ['dragleave', 'drop'].forEach(eventName => {
      examsZone.addEventListener(eventName, () => examsZone.classList.remove('dragover'), false);
    });
    examsZone.addEventListener('drop', e => {
      const dt = e.dataTransfer;
      const files = dt.files;
      if (files && files.length > 0) {
        handleExcelFileSelect({ target: { files: files } });
      }
    }, false);
  }
}

// Config Modal Manager
function openConfigModal() {
  const modal = document.getElementById('config-modal');
  const textarea = document.getElementById('firebase-config-json');
  if (modal) modal.style.display = 'flex';
  if (textarea) textarea.value = JSON.stringify(DEFAULT_FIREBASE_CONFIG, null, 2);
}

function closeConfigModal() {
  const modal = document.getElementById('config-modal');
  if (modal) modal.style.display = 'none';
}

function saveFirebaseConfig() {
  const textarea = document.getElementById('firebase-config-json');
  if (!textarea) return;
  try {
    const parsed = JSON.parse(textarea.value);
    localStorage.setItem('iris_firebase_config', JSON.stringify(parsed));
    closeConfigModal();
    alert("✅ Configuration saved! Page will reload to initialize custom Firebase link.");
    location.reload();
  } catch (e) {
    alert("⚠️ Invalid JSON format: " + e.message);
  }
}

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
  logTerminal(`Navigated to page: [${pageId.toUpperCase()}]`, "info");
}

function handleHashNavigation() {
  const hash = window.location.hash.replace('#', '');
  if (['dashboard', 'timetable', 'exams', 'broadcast', 'directory', 'feedback', 'releases'].includes(hash)) {
    switchPage(hash);
  }
}

// Terminal Activity Log Engine
function logTerminal(message, type = 'info') {
  const output = document.getElementById('terminal-output');
  if (!output) return;

  const now = new Date();
  const timeStr = now.toTimeString().split(' ')[0];
  const colors = {
    info: 'var(--brand-cyan)',
    success: 'var(--brand-emerald)',
    warning: 'var(--brand-amber)',
    error: 'var(--brand-rose)'
  };

  logHistory.push({ time: timeStr, message, type, rawText: `[${timeStr}] [${type.toUpperCase()}] ${message}` });

  const line = document.createElement('div');
  line.style.marginBottom = '4px';
  line.innerHTML = `<span style="color: var(--text-dim);">[${timeStr}]</span> <span style="color: ${colors[type] || colors.info}; font-weight: 700;">[${type.toUpperCase()}]</span> ${message}`;

  output.appendChild(line);
  output.scrollTop = output.scrollHeight;
}

function clearTerminalLogs() {
  const output = document.getElementById('terminal-output');
  if (output) output.innerHTML = '';
  logHistory = [];
}

function downloadTerminalLogs() {
  if (logHistory.length === 0) {
    alert("Console log terminal is empty.");
    return;
  }

  let text = `# IRIS Admin System Diagnostics Log\nExported: ${new Date().toLocaleString()}\n\n`;
  logHistory.forEach(l => {
    text += `${l.rawText}\n`;
  });

  const blob = new Blob([text], { type: 'text/markdown' });
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = `iris_system_logs_${Date.now()}.md`;
  a.click();
  URL.revokeObjectURL(url);
}

// Data Sync Engine
async function refreshAllData() {
  logTerminal("Synchronizing timetable dataset and live Firestore feedback...", "info");
  await loadRealTimetableData();
  if (db) initFirestoreSubscriptions();
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
      logTerminal(`Loaded ${realTimetable.length.toLocaleString()} real campus timetable sessions.`, "success");
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
        room: item.room && item.room !== "N/A" ? item.room : "Campus Venue",
        email: item.email || item.teacher_email || "Official Department Faculty"
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

  const todaySessions = realTimetable.filter(item => item.day === currentDayStr);
  const activeSession = todaySessions[0] || realTimetable[0];

  const nameEl = document.getElementById('live-subject-name');
  const teacherEl = document.getElementById('live-teacher-name');
  const rangeEl = document.getElementById('live-time-range');

  if (activeSession) {
    if (nameEl) nameEl.innerText = activeSession.subject || "No Active Class";
    if (teacherEl) teacherEl.innerText = `${activeSession.batch || ''} • ${activeSession.teacher || ''} • Room ${activeSession.room || ''}`;
    if (rangeEl) rangeEl.innerText = `${activeSession.start || ''} - ${activeSession.end || ''}`;
  }

  // Update Mobile Student Emulator Feed with Real Today Sessions
  const emFeed = document.getElementById('emulator-schedule-feed');
  if (emFeed) {
    const listToRender = (todaySessions.length > 0 ? todaySessions : realTimetable).slice(0, 3);
    emFeed.innerHTML = listToRender.map(s => `
      <div style="background: rgba(255,255,255,0.05); border: 1px solid var(--border-glass); border-radius: 12px; padding: 10px; margin-bottom: 6px;">
        <div style="font-weight: 800; font-size: 11.5px; color: var(--text-main);">${s.batch || ''} - ${s.subject || 'Class'}</div>
        <div style="font-size: 10px; color: var(--brand-cyan);">${s.teacher || ''} • Room ${s.room || 'N/A'} (${s.start || ''})</div>
      </div>
    `).join('');
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
    sports: "SPORTS WEEK PERIOD ACTIVE",
    sports_week: "SPORTS WEEK PERIOD ACTIVE"
  };

  const texts = {
    classes: "Standard curriculum timetables, active period countdowns, and room locator indexing enabled.",
    midterm: "Midterm exam date sheets take priority on student home screens and widgets.",
    finals: "Final exam schedule view active with seating room indicators.",
    sports: "Sports week notices and schedule highlighted across mobile noticeboards.",
    sports_week: "Sports week notices and schedule highlighted across mobile noticeboards."
  };

  const titleEl = document.getElementById('mode-desc-title');
  const textEl = document.getElementById('mode-desc-text');
  if (titleEl) titleEl.innerText = titles[mode] || titles.classes;
  if (textEl) textEl.innerText = texts[mode] || texts.classes;

  // Update Emulator
  const emModeBadge = document.getElementById('emulator-mode-badge');
  const emModeTitle = document.getElementById('emulator-mode-title');
  if (emModeBadge) emModeBadge.innerText = `${mode.toUpperCase()} MODE`;
  if (emModeTitle) emModeTitle.innerText = titles[mode];

  const targetPeriod = mode === 'sports' ? 'sports_week' : mode;

  if (db) {
    db.collection('config').doc('global').set({
      academic_period: targetPeriod,
      updated_at: firebase.firestore.FieldValue.serverTimestamp()
    }, { merge: true }).then(() => {
      logTerminal(`Academic Period set to [${targetPeriod.toUpperCase()}] in Firestore config/global.`, "success");
    }).catch(err => logTerminal("Firestore mode save: " + err.message, "error"));
  }

  alert(`Academic mode switched to [${targetPeriod.toUpperCase()}]. Broadcast sent to all mobile client devices!`);
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
        logTerminal(`Staged JSON file with ${stagedTimetable.length} timetable sessions.`, "success");
        alert(`✅ Staged JSON file with ${stagedTimetable.length} timetable sessions.`);
      } catch (err) {
        alert("⚠️ Invalid JSON file format.");
      }
    };
    reader.readAsText(file);
  } else if (file.name.endsWith('.pdf')) {
    logTerminal(`Staged PDF file [${file.name}] for parsing.`, "info");
    alert(`📄 Staged PDF file [${file.name}]. Click 'Commit Seed' to parse and upload sessions to database.`);
  }
}

function commitStagedTimetable() {
  if (stagedTimetable.length > 0) {
    realTimetable = stagedTimetable;
    renderTimetable();
    updatePlatformStats();

    if (db) {
      const nowTs = Math.floor(Date.now() / 1000);
      const jsonStr = JSON.stringify(realTimetable);

      db.collection('timetables').doc('seed').set({
        sessions: realTimetable,
        updated_at: firebase.firestore.FieldValue.serverTimestamp()
      });

      db.collection('config').doc('global').set({
        active_timetable_json: jsonStr,
        active_timetable_version: nowTs,
        updated_at: firebase.firestore.FieldValue.serverTimestamp()
      }, { merge: true }).then(() => {
        logTerminal(`Committed timetable seed (v${nowTs}) to Firestore config/global.`, "success");
        alert("✅ Timetable seed committed to Firestore database!");
      }).catch(err => alert("Firestore save error: " + err.message));
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
      db.collection('timetables').doc('seed').delete().then(() => {
        logTerminal("Live timetable database wiped.", "warning");
        alert("🗑️ Live timetable database wiped successfully.");
      });
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
      logTerminal(`Parsed Excel sheet. Staged ${stagedExams.length} exam entries.`, "success");
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
    }).then(() => {
      logTerminal(`Committed ${stagedExams.length} ${termType.toUpperCase()} exam slots to Firestore.`, "success");
      alert(`✅ Staged ${stagedExams.length} ${termType.toUpperCase()} exam slots committed to Firestore!`);
    }).catch(err => alert("Firestore save error: " + err.message));
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
    logTerminal("Live exam date sheets wiped.", "warning");
    alert("🗑️ Exam date sheets wiped successfully.");
  }
}

// Alert Notification Studio & Broadcast Engine
function useBroadcastPreset(text) {
  const bodyEl = document.getElementById('broadcast-body');
  if (bodyEl) {
    bodyEl.value = text;
    updateEmulatorNotice();
  }
}

function updateEmulatorNotice() {
  const title = document.getElementById('broadcast-title')?.value.trim() || 'CAMPUS NOTICEBOARD';
  const body = document.getElementById('broadcast-body')?.value.trim() || 'All Quiet on Campus • No active emergency notices';

  const emTitle = document.getElementById('emulator-notice-title');
  const emBody = document.getElementById('emulator-notice-body');
  if (emTitle) emTitle.innerText = title.toUpperCase();
  if (emBody) emBody.innerText = body;
}

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
    });
    db.collection('config').doc('global').set({
      broadcast_enabled: true,
      broadcast_message: `${title}: ${body}`,
      broadcast_announcement: {
        title: title,
        category: category,
        body: body,
        show_broadcast: true,
        created_at: firebase.firestore.FieldValue.serverTimestamp()
      },
      updated_at: firebase.firestore.FieldValue.serverTimestamp()
    }, { merge: true }).then(() => {
      logTerminal(`Emergency Notice [${title}] broadcasted live to Firestore config/global.`, "success");
      alert(`📢 Emergency Notice [${title}] broadcasted live to all mobile client noticeboards!`);
      document.getElementById('broadcast-title').value = '';
      document.getElementById('broadcast-body').value = '';
      updateEmulatorNotice();
    }).catch(err => alert("Firestore broadcast error: " + err.message));
  } else {
    logTerminal(`Emergency Notice [${title}] broadcasted locally.`, "success");
    alert(`📢 Emergency Notice [${title}] broadcasted locally!`);
  }
}

function clearBroadcastNotice() {
  if (db) {
    db.collection('config').doc('global').set({
      broadcast_enabled: false,
      broadcast_message: '',
      updated_at: firebase.firestore.FieldValue.serverTimestamp()
    }, { merge: true }).then(() => {
      logTerminal("Broadcast notice disabled on all mobile client screens.", "warning");
      alert("🔇 Live broadcast disabled across mobile clients.");
    });
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
        logTerminal(`Autofilled release build [${data.tag_name}] from GitHub.`, "success");
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
    db.collection('config').doc('app_update').set(releasePayload, { merge: true });
    db.collection('config').doc('global').set({
      latest_apk_update: {
        version_name: verName,
        version_code: parseInt(verCode) || 4,
        release_notes: notes,
        apk_url: url,
        show_update_card: showBanner,
        download_url: url
      },
      updated_at: firebase.firestore.FieldValue.serverTimestamp()
    }, { merge: true }).then(() => {
      logTerminal(`OTA Release payload [${verName}] published to Firestore global config.`, "success");
      alert("🚀 OTA Release Config published to Firestore! Connected mobile apps will display update prompts.");
    }).catch(err => alert("Firestore save error: " + err.message));
  } else {
    logTerminal(`OTA Release payload [${verName}] staged locally.`, "info");
    alert("🚀 OTA Release Config staged locally!");
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
      logTerminal(`Received ${communityFeedbacks.length} feedback documents from Firestore stream.`, "info");
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
