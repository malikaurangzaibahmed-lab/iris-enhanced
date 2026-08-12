/* ==========================================================================
   IRIS WEB PLATFORM - REAL DYNAMIC ENGINE & FIRESTORE CONTROLLER
   ========================================================================== */

// Firebase Configuration
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
    console.log("⚡ IRIS Web Platform: Firebase Firestore initialized successfully.");
  }
} catch (e) {
  console.warn("⚠️ IRIS Web Platform: Running with local offline state engine:", e);
}

// Live Dynamic Stores
let realTimetable = [];
let realFaculty = [];
let communityFeedbacks = [];

let selectedDay = "Monday";
let currentRating = 5;

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
  
  if (statSessions) statSessions.innerText = realTimetable.length > 0 ? realTimetable.length.toLocaleString() : "0";
  if (statFaculty) statFaculty.innerText = realFaculty.length > 0 ? `${realFaculty.length}+` : "0";
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

// Page Router
function switchPage(pageId) {
  document.querySelectorAll('.page-section').forEach(sec => sec.classList.remove('active'));
  document.querySelectorAll('.nav-tab').forEach(tab => tab.classList.remove('active'));

  const targetPage = document.getElementById(`page-${pageId}`);
  const targetTab = document.getElementById(`tab-${pageId}`);

  if (targetPage) targetPage.classList.add('active');
  if (targetTab) targetTab.classList.add('active');

  window.location.hash = pageId;
}

// Day Selection & Timetable Rendering
function selectDay(day) {
  selectedDay = day;
  document.querySelectorAll('.day-btn').forEach(btn => {
    btn.classList.toggle('active', btn.innerText.trim() === day);
  });
  renderTimetable();
}

function renderTimetable() {
  const tbody = document.getElementById('timetable-tbody');
  if (!tbody) return;
  const searchVal = (document.getElementById('timetable-search')?.value || '').toLowerCase();

  const filtered = realTimetable.filter(item => {
    const matchDay = item.day === selectedDay;
    const matchSearch = !searchVal || 
      (item.batch && item.batch.toLowerCase().includes(searchVal)) ||
      (item.subject && item.subject.toLowerCase().includes(searchVal)) ||
      (item.teacher && item.teacher.toLowerCase().includes(searchVal)) ||
      (item.room && item.room.toLowerCase().includes(searchVal));
    return matchDay && matchSearch;
  });

  if (filtered.length === 0) {
    tbody.innerHTML = `<tr><td colspan="5" style="padding: 24px; text-align: center; color: var(--text-muted);">No timetable sessions scheduled for ${selectedDay} matching search.</td></tr>`;
    return;
  }

  tbody.innerHTML = filtered.slice(0, 100).map(item => `
    <tr style="border-bottom: 1px solid var(--border-glass); transition: var(--transition-fast);">
      <td style="padding: 14px; font-weight: 700; color: var(--brand-cyan);">${item.batch || 'N/A'}</td>
      <td style="padding: 14px; font-weight: 600; font-family: var(--font-mono); font-size: 13px;">${item.start || ''} - ${item.end || ''}</td>
      <td style="padding: 14px; font-weight: 700; color: var(--text-main);">${item.subject || ''}</td>
      <td style="padding: 14px; color: var(--text-muted);">${item.teacher || ''}</td>
      <td style="padding: 14px;"><span style="padding: 4px 8px; background: rgba(0, 229, 255, 0.1); border-radius: 6px; font-weight: 700; color: var(--brand-cyan); font-size: 12px;">${item.room || ''}</span></td>
    </tr>
  `).join('');
}

function filterTimetable() {
  renderTimetable();
}

// Faculty Directory Renderer
function renderFaculty() {
  const grid = document.getElementById('faculty-grid');
  if (!grid) return;
  const searchVal = (document.getElementById('faculty-search')?.value || '').toLowerCase();

  const filtered = realFaculty.filter(f => 
    !searchVal || 
    f.name.toLowerCase().includes(searchVal) || 
    f.dept.toLowerCase().includes(searchVal)
  );

  if (filtered.length === 0) {
    grid.innerHTML = `<div style="grid-column: 1 / -1; padding: 40px; text-align: center; color: var(--text-muted);">No faculty members found matching search.</div>`;
    return;
  }

  grid.innerHTML = filtered.slice(0, 48).map(f => `
    <div class="glass-card">
      <div style="display: flex; align-items: center; gap: 14px; margin-bottom: 14px;">
        <div style="width: 44px; height: 44px; border-radius: 12px; background: linear-gradient(135deg, var(--brand-cyan), var(--brand-blue)); display: flex; align-items: center; justify-content: center; font-weight: 900; color: #050811; font-size: 18px;">
          ${f.name.split(' ').pop()?.[0] || 'F'}
        </div>
        <div>
          <h4 style="font-size: 15px; font-weight: 800; color: var(--text-main);">${f.name}</h4>
          <p style="font-size: 11.5px; color: var(--brand-cyan); font-weight: 600;">${f.designation}</p>
        </div>
      </div>
      <div style="font-size: 12.5px; color: var(--text-muted); margin-bottom: 8px;">
        <i class="fa-solid fa-building-user" style="width: 16px; color: var(--brand-purple);"></i> ${f.dept}
      </div>
      <div style="font-size: 12.5px; color: var(--text-muted); margin-bottom: 8px;">
        <i class="fa-solid fa-door-open" style="width: 16px; color: var(--brand-emerald);"></i> ${f.room}
      </div>
      <div style="font-size: 12px; color: var(--brand-cyan); margin-top: 12px; font-family: var(--font-mono);">
        <i class="fa-solid fa-envelope"></i> ${f.email}
      </div>
    </div>
  `).join('');
}

function filterFaculty() {
  renderFaculty();
}

// Feedback System Handlers
function setRating(stars) {
  currentRating = stars;
  const buttons = document.querySelectorAll('#star-row .star-btn');
  buttons.forEach((btn, idx) => {
    btn.classList.toggle('active', idx < stars);
  });
}

function handleFeedbackSubmit(event) {
  event.preventDefault();
  const name = document.getElementById('fb-name').value.trim();
  const role = document.getElementById('fb-user-role')?.value || 'Student';
  const roll = document.getElementById('fb-roll')?.value.trim() || 'N/A';
  const batch = document.getElementById('fb-batch')?.value.trim() || 'N/A';
  const device = document.getElementById('fb-device')?.value.trim() || 'Web Portal';
  const category = document.getElementById('fb-category').value;
  const comment = document.getElementById('fb-comment').value.trim();

  if (!name || !comment) return;

  const newFeedback = {
    name: name,
    user_role: role,
    roll_number: roll,
    batch: batch,
    device: device,
    category: category,
    rating: currentRating,
    comment: comment,
    date: new Date().toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' }),
    created_at: new Date()
  };

  if (db) {
    db.collection('feedback').add(newFeedback).then(() => {
      console.log("✅ Feedback stored in Firestore!");
    }).catch(err => console.warn("Firestore save fallback:", err));
  }

  communityFeedbacks.unshift(newFeedback);
  renderFeedbackFeed();

  document.getElementById('feedback-form').reset();
  setRating(5);
  alert(`Thank you! Your ${role} feedback has been submitted successfully.`);
}

function renderFeedbackFeed() {
  const container = document.getElementById('feedback-feed-container');
  if (!container) return;

  if (communityFeedbacks.length === 0) {
    container.innerHTML = `
      <div style="padding: 40px 20px; text-align: center; color: var(--text-muted);">
        <i class="fa-solid fa-comments" style="font-size: 32px; color: var(--brand-cyan); margin-bottom: 12px; display: block; opacity: 0.5;"></i>
        <div style="font-weight: 700; font-size: 14px; color: var(--text-main); margin-bottom: 4px;">No Feedback Submissions Yet</div>
        <div style="font-size: 12px; color: var(--text-dim); max-width: 320px; margin: 0 auto;">User feedback submitted from the IRIS mobile app or web portal will appear here in real time.</div>
      </div>
    `;
    return;
  }

  container.innerHTML = communityFeedbacks.map(fb => `
    <div class="feedback-feed-item" style="${fb.user_role === 'Faculty' ? 'border-color: rgba(168, 85, 247, 0.4); background: rgba(109, 40, 217, 0.1);' : ''}">
      <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 6px;">
        <div style="display: flex; align-items: center; gap: 8px;">
          <span style="font-weight: 800; color: var(--text-main); font-size: 14.5px;">${fb.name}</span>
          ${fb.user_role === 'Faculty' 
            ? `<span style="padding: 2px 8px; background: rgba(168, 85, 247, 0.25); border: 1px solid rgba(168, 85, 247, 0.4); border-radius: 6px; font-size: 10px; font-weight: 800; color: #d8b4fe;"><i class="fa-solid fa-graduation-cap"></i> FACULTY</span>`
            : `<span style="padding: 2px 8px; background: rgba(0, 229, 255, 0.12); border-radius: 6px; font-size: 10px; font-weight: 700; color: var(--brand-cyan);">STUDENT</span>`}
          ${fb.roll_number && fb.roll_number !== 'N/A' ? `<span style="font-size: 11px; color: var(--brand-cyan); font-weight: 700;">(${fb.roll_number})</span>` : ''}
        </div>
        <span style="font-size: 11px; color: var(--text-dim); font-weight: 600;">${fb.date}</span>
      </div>
      <div style="display: flex; flex-wrap: wrap; gap: 6px; align-items: center; margin-bottom: 8px;">
        <span style="padding: 2px 8px; background: rgba(0, 229, 255, 0.12); border-radius: 6px; font-size: 10px; font-weight: 700; color: var(--brand-cyan);">${fb.category}</span>
        ${fb.batch && fb.batch !== 'N/A' ? `<span style="padding: 2px 8px; background: rgba(168, 85, 247, 0.12); border-radius: 6px; font-size: 10px; font-weight: 700; color: var(--brand-purple);">${fb.batch}</span>` : ''}
        ${fb.device && fb.device !== 'N/A' ? `<span style="padding: 2px 8px; background: rgba(255, 255, 255, 0.06); border-radius: 6px; font-size: 10px; font-weight: 600; color: var(--text-muted);"><i class="fa-solid fa-mobile-screen-button"></i> ${fb.device}</span>` : ''}
        <span style="color: var(--brand-amber); font-size: 11px; margin-left: auto;">${'★'.repeat(fb.rating || 5)}</span>
      </div>
      <p style="font-size: 13px; color: var(--text-muted); line-height: 1.5;">${fb.comment}</p>
    </div>
  `).join('');
}

// Subscribe to Live Firestore Feedback Stream
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
    }, err => console.warn("Firestore snapshot listener:", err));
  } catch (e) {
    console.warn("Could not start Firestore live listener:", e);
  }
}

function setAcademicMode(mode) {
  document.querySelectorAll('.active-mode-btn').forEach(b => b.classList.remove('active-mode-btn'));
  if (db) {
    db.collection('config').doc('global').set({ academic_period: mode }, { merge: true });
  }
  alert(`Academic Mode set to: ${mode.toUpperCase()}`);
}

function refreshDashboardData() {
  loadRealTimetableData();
  initFirestoreFeedbackStream();
}

// Initialize on Load
window.addEventListener('DOMContentLoaded', () => {
  const hash = window.location.hash.replace('#', '') || 'dashboard';
  switchPage(hash);
  selectDay('Monday');
  loadRealTimetableData();
  initFirestoreFeedbackStream();
});
